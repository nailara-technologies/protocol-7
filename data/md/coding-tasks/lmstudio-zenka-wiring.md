## [:< ##

# task: lmstudio zenka — wire placeholder into working zenka

the lmstudio zenka currently has only a `.placeholder` file. all the storage
adapter modules are already built. this task wires them into a working on-demand
zenka that can be queried by coding, models, and lm-vision zenki.


## p7 code style (strictly enforced)

- lowercase comments: `## read config from file` not `## Read Config`
- annotations in [ brackets ] not (parentheses)
- `$ARG` not `$_`
- `<[module.name]>->($args)` — closing `]>` before `->`
- `<[module.name]>` with no args (parser adds `->()` automatically, explicit `->()` is redundant)
- `:flag:` not `--flag` in all p7 command contexts
- `$call->{'args'}` not `$call_args` in cmd modules
- cmd modules: `return { mode => 'size', data => $str }` for output,
  `return { mode => 'false' }` for error/no-output fallback — `$reply` is
  pre-declared in scope as a hashref, use `my $out` for string buffers
- config access: `$data{'lmstudio'}{'external.models.lmstudio.path'}` (no 'cfg' intermediate)
- do NOT generate footer lines — leave files completely clean, signing adds them
- new module header: `## [:< ##\n\n# name  = ...\n# descr = ...`
- syntax check with `ptd -c`, not `perl -c`


## read these files first (understand patterns before writing)

    cfg/zenki/calc/start         — minimal on-demand zenka pattern
    cfg/zenki/models/start       — full-featured zenka with adapter commands
    cfg/external-inference-models — lmstudio config keys
    modules/models.storage.adapter.lmstudio.discover  — main data source
    modules/models.storage.adapter.lmstudio.resolve   — path resolution
    modules/models.storage.adapter.lmstudio.repair    — validation
    modules/models.cmd.adapter-lmstudio-discover      — existing cmd pattern
    modules/models.cmd.app-models                     — thin cmd wrapper pattern


## what to create

### 1. cfg/zenki/lmstudio/start  (new file, replaces .placeholder)

on-demand zenka — starts when first queried, shuts down after idle timeout.

    .:[ lmstudio model management and inference zenka ]:.

    [load_config_file:'shared-params']
    [load_config_file:'external-inference-models']

    system.zenka.verbosity.buffer  = 2
    system.zenka.verbosity.logfile = 2
    system.zenka.verbosity.console = 2

    start.on-demand    = 1
    restart.disabled   = 1
    heartbeat.disabled = 1

    ## idle timeout: shut down after 10 minutes of inactivity ##
    [base.zenki.set_ondemand_timeout:600]

    ## Access Control
    access.cmd.usr.cube = heart verify-instance commands reload \
                          show-buffer show-access \
                          discover resolve repair \
                          status list

    modules.load = auth net protocol io.unix lmstudio

    [load_modules:<modules.load>]
    [init_modules]

    [root.drop_privs:<system.amos-zenka-user>]

    [base.net.connect:'unix']

    [get_session_id]

    [zenka.loop]

note: `modules.load = ... lmstudio` — this loads all modules/lmstudio.* files.
we will create those modules next.


### 2. modules/lmstudio.init_code

    # name  = lmstudio.init_code
    # descr = lmstudio zenka initialization

    called automatically during [init_modules]. sets up the zenka:
    - log that lmstudio zenka is initializing
    - read lmstudio config from $data{'lmstudio'} namespace:
        root path: $data{'lmstudio'}{'external.models.lmstudio.path'}
        url:       $data{'lmstudio'}{'external.models.lmstudio.url'}
    - set $data{'lmstudio'}{'status'} = 'ready'
    - log model root path and API url at verbosity 2


### 3. modules/lmstudio.cmd.discover

    # name  = lmstudio.cmd.discover
    # descr = cmd: scan lmstudio model directory and list models

    calls <[models.storage.adapter.lmstudio.discover]> and returns formatted list.
    same format as models.cmd.adapter-lmstudio-discover but as a native lmstudio
    zenka command.

    my $records = <[models.storage.adapter.lmstudio.discover]>;
    my $count   = scalar @{ $records // [] };
    <[base.logs]>->( 1, "lmstudio: discovered %d models", $count );

    my $out = '';
    for my $rec ( @{ $records // [] } ) {
        $out .= sprintf "%-10s %-8s %-14s %s\n",
            $rec->{'type'} // '', $rec->{'base'} // '',
            $rec->{'quant'} // $rec->{'format'} // '',
            $rec->{'name'} // '';
    }
    return { mode => qw| size |, data => $out };


### 4. modules/lmstudio.cmd.resolve

    # name  = lmstudio.cmd.resolve
    # descr = cmd: resolve model name to on-disk path

    my $model_name = $call->{'args'} // '';
    return { mode => qw| false | } unless length $model_name;

    my $records = <[models.storage.adapter.lmstudio.discover]>;
    my ($rec)   = grep { ( $_->{'name'} // '' ) eq $model_name } @{ $records // [] };

    my $out = '';
    if ($rec) {
        my $path = <[models.storage.adapter.lmstudio.resolve]>->($rec);
        $out = "$path\n" if defined $path;
        <[base.logs]>->( 0, "lmstudio: model not on disk [ %s ]", $model_name )
            unless length $out;
    } else {
        <[base.logs]>->( 0, "lmstudio: model not found [ %s ]", $model_name );
    }
    return { mode => qw| size |, data => $out };


### 5. modules/lmstudio.cmd.repair

    # name  = lmstudio.cmd.repair
    # descr = cmd: validate gguf files and report corrupt/missing

    my @tokens  = split m|\s+|, $call->{'args'} // '';
    my %flags   = map { $_ => 1 } @tokens;
    my $dry_run = $flags{':dry-run:'} ? 1 : 0;

    my $result = <[models.storage.adapter.lmstudio.repair]>->( { dry_run => $dry_run } );
    my $out = sprintf "valid=%d corrupt=%d missing=%d\n",
        $result->{'valid'} // 0, $result->{'corrupt'} // 0, $result->{'missing'} // 0;

    return { mode => qw| size |, data => $out };


### 6. modules/lmstudio.cmd.status

    # name  = lmstudio.cmd.status
    # descr = cmd: show lmstudio zenka status and config

    my $root   = $data{'lmstudio'}{'external.models.lmstudio.path'} // 'not configured';
    my $url    = $data{'lmstudio'}{'external.models.lmstudio.url'}  // 'not configured';
    my $status = $data{'lmstudio'}{'status'} // 'unknown';

    my $out = sprintf "status : %s\nroot   : %s\nurl    : %s\n",
        $status, $root, $url;

    return { mode => qw| size |, data => $out };


### 7. modules/lmstudio.cmd.list

    # name  = lmstudio.cmd.list
    # descr = cmd: alias for discover — list available lmstudio models

    ## delegate to discover ##
    return <[lmstudio.cmd.discover]>->($call);


## also create: cfg/zenki/lmstudio/subroutine.white-list

list all lmstudio.cmd.* module names (one per line):
    lmstudio.init_code
    lmstudio.cmd.discover
    lmstudio.cmd.resolve
    lmstudio.cmd.repair
    lmstudio.cmd.status
    lmstudio.cmd.list

look at cfg/zenki/models/subroutine.white-list for format reference.


## do NOT create

- do NOT create access.* files (lmstudio zenka uses cube's default access rules)
- do NOT create zenka-startup.v7 (not needed for on-demand zenka)
- do NOT create auth.* files (handled by shared-params)


## verify

    ptd -c on all 6 module files
    check cfg/zenki/lmstudio/start looks syntactically reasonable
    check subroutine.white-list has correct format

    to test after signing:
        p7c lmstudio.status
        p7c lmstudio.discover
        p7c lmstudio.list


## what this enables

    - coding zenka can route model queries to lmstudio zenka
    - lm-vision zenka can discover vision-capable GGUF models
    - models zenka unified discover spans invoke + lmstudio via shared adapter modules
    - foundation for lmstudio inference API integration (next step)

#,,.,,.,.,.,.,.,,,.,.,.,,,..,,,,.,.,,,,,,,,,,,..,,...,...,...,,..,.,.,,.,,,..,
#EAGWMVBKCMM7JFY36B4QPROQH2T5PQGELBPEVYLKPXSXXZ6M6NSGOOTAQM5SGKSJTE6SB4ILFCICS
#\\\|I4PPVKBLCCALNC4VEAQ6MYXGZCZJLM4Y3WK2K54MNAGWKFZ6IIS \ / AMOS7 \ YOURUM ::
#\[7]UEPFGM5JEGYPRWRJSXGBGZ6JDADDCIJKB5KEXUAHZLOTML44TYAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
