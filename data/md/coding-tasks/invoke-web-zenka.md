## [:< ##

# task: invoke-web zenka — process manager for invoke.ai web server

create the invoke-web zenka: a process manager that spawns, monitors, and
controls the invoke.ai web server process. modeled on the coding zenka's
proven async spawn infrastructure (IPC::Open3 + non-blocking I/O watchers).

the invoke.ai web process runs as:
    /home/taeki/miniconda3/envs/invokeai/bin/invokeai-web --root=~/.invokeai/

it listens on http://127.0.0.1:9090 and takes 30-90 seconds to become ready.


## p7 code style (strictly enforced)

- lowercase comments, [ brackets ] for annotations, no capitals in comments
- `$ARG` not `$_`
- `<[module.name]>->($args)` — closing `]>` before `->`
- `<[module.name]>` with no args (parser adds `->()` automatically)
- `:flag:` not `--flag`
- `$call->{'args'}` not `$call_args` in cmd modules
- cmd modules: `return { mode => 'size', data => $str }` for output
  `return { mode => 'false' }` for no-output/error fallback
  `$reply` is pre-declared as a hashref in cmd scope — use `my $out` for strings
- config: `$data{'invoke-web'}{'external.models.invokeai.path'}` (no 'cfg' key)
- do NOT generate any footer lines whatsoever — signing adds the full AMOS7 footer
- do NOT add `#,,...` stub lines
- syntax check with `ptd -c`, not `perl -c`
- new module header format: `## [:< ##\n\n# name  = ...\n# descr = ...`


## key reference files — read these first

    modules/coding.spawn_inference_server      — IPC::Open3 spawn pattern,
                                                 non-blocking pipes, pid file,
                                                 orphan detection, watcher setup
    modules/coding.handler.monitor_inference_startup  — I/O watcher handler,
                                                        non-blocking read,
                                                        readiness detection,
                                                        crash detection + EOF
    modules/coding.async_spawn_inference_servers      — timer-based deferred spawn
    cfg/zenki/calc/start             — minimal on-demand zenka
    cfg/zenki/coding/start           — full zenka with spawn infra
    cfg/external-inference-models    — invokeai config keys


## invoke.ai process facts

    binary:   /home/taeki/miniconda3/envs/invokeai/bin/invokeai-web
    args:     --root=~/.invokeai/
    port:     9090  (config: external.models.invokeai.url = http://127.0.0.1:9090)
    user:     must run as 'taeki' (has GPU access, conda env, .invokeai dir)
    startup:  30-90 seconds — readiness indicated by log line containing:
              "Uvicorn running on" or "Application startup complete"
    shutdown: SIGTERM first, then SIGKILL after 10s if still running
    pid file: state/invokeai.pid  (in zenka state dir, for orphan detection)

    the zenka itself runs as protocol-7 (after drop_privs), but must spawn
    the invokeai-web process as 'taeki'. use setuid via sudo or su:
        sudo -u taeki /home/taeki/miniconda3/envs/invokeai/bin/invokeai-web \
            --root=/home/taeki/.invokeai/
    (or check if there is a setuid wrapper pattern elsewhere in p7)
    alternatively: spawn as root before drop_privs, then drop.
    look at how other zenki handle cross-user process spawning.


## files to create

### cfg/zenki/invoke-web/start

on-demand zenka. starts when queried, shuts down after idle timeout if
invoke.ai process is not running.

    .:[ invoke.ai web process manager zenka ]:.

    [load_config_file:'shared-params']
    [load_config_file:'external-inference-models']

    system.zenka.verbosity.buffer  = 2
    system.zenka.verbosity.logfile = 2
    system.zenka.verbosity.console = 2

    start.on-demand    = 1
    restart.disabled   = 1
    heartbeat.disabled = 1

    ## idle timeout: 5 minutes — invoke process keeps running independently ##
    [base.zenki.set_ondemand_timeout:300]

    access.cmd.usr.cube = heart verify-instance commands reload \
                          show-buffer show-access \
                          start stop restart status health \
                          attach detach

    modules.load = auth net protocol io.unix invoke-web

    [load_modules:<modules.load>]
    [init_modules]

    [root.drop_privs:<system.amos-zenka-user>]

    [base.net.connect:'unix']

    [get_session_id]

    [zenka.loop]


### cfg/zenki/invoke-web/subroutine.white-list

    invoke-web.init_code
    invoke-web.cmd.start
    invoke-web.cmd.stop
    invoke-web.cmd.restart
    invoke-web.cmd.status
    invoke-web.cmd.health
    invoke-web.handler.monitor_startup
    invoke-web.handler.check_health

look at cfg/zenki/models/subroutine.white-list for exact format.


### modules/invoke-web.init_code

    # name  = invoke-web.init_code
    # descr = invoke-web zenka initialization

    - load IPC::Open3, Symbol, Fcntl via base.perlmod.autoload (one at a time)
    - initialize state:
        $data{'invoke-web'}{'status'}  = 'idle'
        $data{'invoke-web'}{'pid'}     = undef
        $data{'invoke-web'}{'url'}     = config 'external.models.invokeai.url'
                                         // 'http://127.0.0.1:9090'
        $data{'invoke-web'}{'binary'}  = '/home/taeki/miniconda3/envs/invokeai/bin/invokeai-web'
        $data{'invoke-web'}{'root'}    = '/home/taeki/.invokeai'
    - check for orphan invoke.ai process from previous run:
        read pid from state/invokeai.pid via <[file.zenka_dir.load]>
        if pid exists and process is alive (kill 0, $pid):
            verify it's actually invokeai-web via /proc/$pid/cmdline
            if yes: adopt it — set status='running', pid=$pid, log adoption
            if no: delete stale pid file
    - schedule health check timer: every 30 seconds
        <[event.add_timer]>->({
            'after'    => 30,
            'interval' => 30,
            'repeat'   => TRUE,
            'handler'  => 'invoke-web.handler.check_health',
        })
    - log initialization complete


### modules/invoke-web.cmd.start

    # name  = invoke-web.cmd.start
    # descr = cmd: start the invoke.ai web server process

    if already running (status eq 'running' or 'starting'):
        return { mode => 'size', data => "invoke.ai already running [pid:$pid]\n" }

    ## spawn via IPC::Open3 — adapt from coding.spawn_inference_server ##

    key differences from coding zenka spawn:
    - command: sudo -u taeki $binary --root=$root
      (or: su -c "$binary --root=$root" taeki)
    - no model path, no port args — invokeai manages its own port
    - readiness strings: "Uvicorn running on" or "Application startup complete"
    - longer startup: up to 120 seconds before declaring crash
    - stdout/stderr both go to monitor_startup handler

    implementation:
    1. check binary exists and is executable (as path, not -x since running as taeki)
    2. build command: [ 'sudo', '-u', 'taeki', $binary, "--root=$root" ]
    3. IPC::Open3::open3(undef, $stdout_fh, $stderr_fh, @cmd)
    4. set both pipes non-blocking (fcntl F_GETFL/F_SETFL O_NONBLOCK)
    5. store: pid, io_stdout, io_stderr, status='starting', start_time
    6. persist pid to state/invokeai.pid via <[file.zenka_dir.write]>
    7. report child pid: <[base.zenki.report_child_pid]>->($pid)
    8. register I/O watchers for both stdout and stderr:
        <[event.add_io]>->({
            fd      => $stdout_fh,
            handler => 'invoke-web.handler.monitor_startup',
            data    => { pid => $pid },
            poll    => 're',
        })
    9. return { mode => 'size', data => "invoke.ai starting [pid:$pid]\n" }


### modules/invoke-web.cmd.stop

    # name  = invoke-web.cmd.stop
    # descr = cmd: stop the invoke.ai web server process

    my $pid = $data{'invoke-web'}{'pid'};
    unless ( defined $pid && kill(0, $pid) ) {
        return { mode => 'size', data => "invoke.ai is not running\n" };
    }

    ## cancel I/O watchers ##
    for my $key (qw| watcher_stdout watcher_stderr |) {
        my $w = $data{'invoke-web'}{$key};
        $w->cancel if defined $w and $w->is_active;
    }

    ## SIGTERM first, then SIGKILL after 10s ##
    kill('TERM', $pid);
    $data{'invoke-web'}{'status'} = 'stopping';

    ## schedule SIGKILL after 10s in case SIGTERM is ignored ##
    <[event.add_timer]>->({
        'after'   => 10,
        'handler' => 'invoke-web.handler.check_health',
    });

    <[file.zenka_dir.unlink_file]>->('state/invokeai.pid');
    $data{'invoke-web'}{'pid'}    = undef;
    $data{'invoke-web'}{'status'} = 'idle';

    return { mode => 'size', data => "invoke.ai stopping [pid:$pid sent SIGTERM]\n" };


### modules/invoke-web.cmd.restart

    # name  = invoke-web.cmd.restart
    # descr = cmd: restart the invoke.ai web server

    ## stop if running, then start ##
    if ( defined $data{'invoke-web'}{'pid'} ) {
        <[invoke-web.cmd.stop]>->($call);
        ## brief pause for process to exit ##
        <[base.sleep]>->(2);
    }
    return <[invoke-web.cmd.start]>->($call);


### modules/invoke-web.cmd.status

    # name  = invoke-web.cmd.status
    # descr = cmd: show invoke-web zenka and process status

    my $status = $data{'invoke-web'}{'status'} // 'idle';
    my $pid    = $data{'invoke-web'}{'pid'}    // '-';
    my $url    = $data{'invoke-web'}{'url'}    // '-';

    ## verify pid is still alive if we think it's running ##
    if ( $status eq 'running' && defined $data{'invoke-web'}{'pid'} ) {
        unless ( kill(0, $data{'invoke-web'}{'pid'}) ) {
            $status = 'crashed';
            $data{'invoke-web'}{'status'} = 'crashed';
        }
    }

    my $uptime = '';
    if ( defined $data{'invoke-web'}{'start_time'} ) {
        my $elapsed = <[base.time]>->(3) - $data{'invoke-web'}{'start_time'};
        $uptime = sprintf " [uptime: %ds]", $elapsed;
    }

    my $out = sprintf "status : %s%s\npid    : %s\nurl    : %s\n",
        $status, $uptime, $pid, $url;
    return { mode => 'size', data => $out };


### modules/invoke-web.cmd.health

    # name  = invoke-web.cmd.health
    # descr = cmd: check invoke.ai HTTP health endpoint

    use LWP::UserAgent (autoload via base.perlmod.autoload).
    GET http://127.0.0.1:9090/api/v1/app/version with 3s timeout.
    if 200: return { mode => 'size', data => "healthy: $version_string\n" }
    if fail: return { mode => 'size', data => "unreachable: $error\n" }


### modules/invoke-web.handler.monitor_startup

    # name  = invoke-web.handler.monitor_startup
    # descr = monitor invoke.ai startup output and detect readiness or crash

    adapted from coding.handler.monitor_inference_startup.
    key differences:
    - readiness strings: "Uvicorn running on" or "Application startup complete"
    - no dependency/jobqueue integration (simpler)
    - on ready: set status='running', log url (http://127.0.0.1:9090)
    - on crash (EOF before ready): set status='crashed', log last 5 lines
    - on EOF after ready: normal — invoke.ai detaches stdout/stderr

    structure:
        my $event        = shift->w;
        my $handler_data = $event->data;
        my $expected_pid = $handler_data->{'pid'};

        ## stale watcher guard ##
        if ( !defined $data{'invoke-web'}{'pid'}
            || $data{'invoke-web'}{'pid'} != $expected_pid ) {
            $event->cancel if $event->is_active;
            return;
        }

        ## non-blocking read ##
        my $bytes = <[base.s_read]>->( $event->fd,
            \$data{'invoke-web'}{'output'}, 4096 );

        ## check for readiness ##
        my $output = $data{'invoke-web'}{'output'} // '';
        if ( $output =~ m{uvicorn running on|application startup complete}i ) {
            unless ( $data{'invoke-web'}{'ready_logged'} ) {
                $data{'invoke-web'}{'status'}       = 'running';
                $data{'invoke-web'}{'ready_logged'} = TRUE;
                <[base.logs]>->( 1, 'invoke.ai ready at %s',
                    $data{'invoke-web'}{'url'} );
            }
        }

        ## EOF handling ##
        if ( $bytes <= 0 ) {
            close( $event->fd );
            $event->cancel if $event->is_active;
            if ( !$data{'invoke-web'}{'ready_logged'}
                && !$data{'invoke-web'}{'crash_logged'} ) {
                $data{'invoke-web'}{'crash_logged'} = TRUE;
                $data{'invoke-web'}{'status'}       = 'crashed';
                <[base.logs]>->( 0, 'invoke.ai crashed before ready' );
                ## log last lines for diagnosis ##
                my @lines = grep {length} split /\n/, $output;
                my @tail  = @lines > 5 ? @lines[-5..-1] : @lines;
                <[base.logs]>->( 0, ':. %s', $_ ) for @tail;
            }
        }


### modules/invoke-web.handler.check_health

    # name  = invoke-web.handler.check_health
    # descr = periodic timer handler: verify invoke.ai process is still alive

    ## called by 30s repeating timer ##
    my $pid = $data{'invoke-web'}{'pid'};
    return unless defined $pid;

    unless ( kill(0, $pid) ) {
        <[base.logs]>->( 0, 'invoke.ai process [pid:%d] disappeared', $pid );
        $data{'invoke-web'}{'status'} = 'crashed';
        $data{'invoke-web'}{'pid'}    = undef;
        <[file.zenka_dir.unlink_file]>->('state/invokeai.pid');
    }


## verify

    ptd -c on all 8 module files
    check zero footer lines in all files
    check subroutine.white-list format matches other zenki

    do not attempt to run — invoke.ai process management requires the
    full zenka environment. report any uncertainties as inline comments.

#,,,,,...,,..,,..,.,.,..,,...,,.,,.,,,,,,,.,.,..,,...,...,...,.,.,.,,,.,,,.,,,
#6HEQUQRPNL3K436NNII24UU3EPJKM6KKGOAZFBASEMETOY6ZIYUDT757ELJEBAVKRW5MJX26OBWNO
#\\\|QHACMZ7IQZSDNGD7Y55RBZ4RK3ONZAFZ3HCHHXIZ6LLH5JCYFAS \ / AMOS7 \ YOURUM ::
#\[7]6ITXGF26KTEC4JIYVAYSRG7XTAQAI56N47TJMOEWGFZ4XCQ7K4AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
