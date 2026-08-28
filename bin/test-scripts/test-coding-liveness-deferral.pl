#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                            ###
## liveness-aware deferral harness [ items 3, 4, 5 ]            ##
###                                                            ###

##     exercises the real translated source of                              ##
##     coding.handler.verify_inference_startup +                            ##
##     coding.self_test.handler.poll_switch +                               ##
##     coding.handler.defer_seed_restart [ + coding.async.stream_tps,       ##
##     the shared liveness/cap signal ] against an in-process %data /       ##
##     %code stub environment -- no live coding zenka required, time is     ##
##     stubbed throughout [ settable $now ]. covers items 3-5 of            ##
##     data/tasks/coding-backend-aware-timeout-scaling.md :                 ##
##                                                                          ##
##     - item 3 [ the 5d32f8783-class regression check ] :                  ##
##     verify_inference_startup's fallback queue-resume does NOT fire       ##
##     while poll_probe's own deferred-but-alive round is still running     ##
##     [ probe past self_test_max_total + 120 but stream alive and          ##
##     under the outer cap ], fires once the round exceeds that same        ##
##     outer cap, fires at the plain budget for a stalled probe, and        ##
##     keeps a bounded wall-clock fallback for a stale guard slot with      ##
##     no probe state                                                       ##
##     - item 4 : poll_switch's testing phase waits past the flat 300s      ##
##     max_wait while the probe it started is still streaming, and          ##
##     falls through to restore the moment the stream stalls                ##
##     - item 5 : defer_seed_restart keeps waiting past its 120s            ##
##     ceiling while the backend lock is held by a live self-test           ##
##     probe, gives up once that probe stalls, and still gives up at        ##
##     120s for a lock held by a real task                                  ##

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

BEGIN {
    my $up_dir    = File::Spec->updir;
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    my $local_lib_path
        = File::Spec->catdir( $root_path, qw| data lib-path pm | );
    die "not found : $local_lib_path" if !-d $local_lib_path;
    unshift( @INC, $local_lib_path );
    $main::root_path = $root_path;
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;
use YAML::XS                  ();

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %data;
our %code;
our $call;

##[ fake event objects ]######################################################

package FakeTimer {
    use strict;    ## one-shot/repeat timers, recorded + fired manually ##
    use English;

    sub new {
        my ( $class, $params ) = @ARG;
        return bless { 'params' => $params, 'active' => 1 }, $class;
    }
    sub is_active { shift->{'active'} }
    sub cancel    { shift->{'active'} = 0; return }
    sub after     { shift->{'params'}{'after'} }
    sub handler   { shift->{'params'}{'handler'} // '' }
    sub data      { shift->{'params'}{'data'} }
}

package FakeEvent {
    use strict;    ## handlers receive this : ->w->data, ->w->cancel ##
    use English;

    sub new {
        my ( $class, $data ) = @ARG;
        return bless { 'data' => $data, 'active' => 1 }, $class;
    }
    sub w    {shift}               ## the watcher IS the event wrapper here ##
    sub data { shift->{'data'} }
    sub is_active { shift->{'active'} }
    sub cancel    { shift->{'active'} = 0; return }
}

package main;

my $now = 10_000;    ## stub time [ seconds ], advanced per scenario       ##

my @timer_calls;         ## event.add_timer invocations [ FakeTimer ]       ##
my @log_calls;           ## every base.logs invocation [ level, rendered ]  ##
my @switch_model_calls;  ## coding.cmd.switch-model invocations [ params ]  ##

## preset by each scenario : what the inference-status stub reports ##
my $status_yaml
    = YAML::XS::Dump(
    { 'gpu' => { 'status' => 'ready', 'model_id' => 'MNEW', 'pid' => 4242 } }
    );

%code = (
    'base.logs' => sub {
        my ( $level, $fmt, @args ) = @ARG;
        push @log_calls, [ $level, sprintf( $fmt, @args ) ];
        return TRUE;
    },
    'base.log'        => sub { return TRUE },
    'base.time'       => sub { return $now },
    'base.ntime'      => sub { return 3211206825624 },
    'event.add_timer' => sub {
        my $timer = FakeTimer->new(shift);
        push @timer_calls, $timer;
        return $timer;
    },
    'jobqueue.check_dependencies' => sub { return TRUE },
    'coding.cmd.inference-status' => sub {
        return { 'mode' => qw| true |, 'data' => $status_yaml };
    },
    'coding.cmd.switch-model' => sub {
        push @switch_model_calls, shift;
        return { 'mode' => qw| true | };
    },
    'base.callback.cmd_reply' => sub { return TRUE },
);

my $fail_count = 0;

sub compile_module {
    my $module_name = shift;
    my $src_path
        = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
    my $src = join( '', <$fh> );
    close($fh);
    my $translated = p7_syntax__translate($src);
    my $cref       = eval "sub {\n# line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR"
        if not defined $cref;
    $code{$module_name} = $cref;
    return $cref;
}

compile_module('coding.async.stream_tps');
compile_module('coding.handler.verify_inference_startup');
compile_module('coding.self_test.handler.poll_switch');
compile_module('coding.handler.defer_seed_restart');

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

sub fire_verify {
    my $backend = shift;
    return $code{'coding.handler.verify_inference_startup'}
        ->( FakeEvent->new( { 'backend' => $backend } ) );
}

sub fire_poll_switch {
    my $switch_id = shift;
    return $code{'coding.self_test.handler.poll_switch'}
        ->( FakeEvent->new( { 'switch_id' => $switch_id } ) );
}

sub fire_defer {
    my $defer_id = shift;
    return $code{'coding.handler.defer_seed_restart'}
        ->( FakeEvent->new( { 'defer_id' => $defer_id } ) );
}

## fresh streaming-request state, same shape coding.async.http_client makes ##
sub mk_http_state {
    my ( $backend, $timeout ) = @ARG;
    return {
        'chunks_received'   => 0,
        'bytes_received'    => 0,
        'last_activity'     => $now,
        'request_start'     => $now,
        'stall_timeout_sec' => 77,
        'completed'         => FALSE,
        'task_id'           => '',
        'callbacks' => { 'backend' => $backend, 'timeout' => $timeout },
    };
}

sub mk_probe_state {
    my ( $backend, $started, $http_state ) = @ARG;
    return {
        'backend'    => $backend,
        'model_id'   => 'TESTID7:X',
        'started'    => $started,
        'phase'      => qw| probe |,
        'in_flight'  => TRUE,
        'http_state' => $http_state,
    };
}

sub reset_state {
    @log_calls                                   = ();
    $data{'coding'}{'task'}                      = { 'queue_paused' => 1 };
    $data{'coding'}{'self_test_probe_state'}     = {};
    $data{'coding'}{'self_test_probe_in_flight'} = {};
    $data{'coding'}{'self_test_switch_state'}    = {};
    $data{'coding'}{'seed_restart_defer'}        = {};
    $data{'coding'}{'state'}{'backend'}          = {};
    return;
}

say ': setup -- pinned cfg, one 8192-ctx server entry per backend';

$data{'coding'}{'http-timeouts'}{'request-completed'} = 780;
$data{'coding'}{'cfg'}{'round_cap_margin'}            = 1.3;
$data{'coding'}{'cfg'}{'round_cap_min_samples'}       = 32;
$data{'coding'}{'cfg'}{'round_cap_static'}            = {
    'gpu'     => 900,
    'cpu'     => 5400,
    'default' => 2700,
};
$data{'coding'}{'cfg'}{'self_test_max_total'} = 1700;

my $cpu_server = sub {
    $data{'coding'}{'inference_servers'}{'cpu'} = {
        'status' => qw| ready |,
        'pid'    => $PROCESS_ID,    ## kill 0 on our own pid always true ##
        'n_ctx'  => 8192,
    };
    return;
};

say ': 1. [item 3 / 5d32f8783 regression] fallback does NOT resume the queue '
    . 'while poll_probe`s deferred-but-alive round is still running';

reset_state();
$cpu_server->();
{
    my $http = mk_http_state( 'cpu', 127 );
    $http->{'chunks_received'} = 20;   ## < min samples : cap = static 5400 ##
    $http->{'last_activity'}   = $now; ## streaming right now              ##
    $data{'coding'}{'self_test_probe_state'}{'P100'}
        = mk_probe_state( 'cpu', $now - 2000, $http );
    ## elapsed 2000s : PAST the old flat ceiling [ 1700 + 120 = 1820 ] at ##
    ## which the pre-liveness fallback would have force-resumed the queue ##
    ## mid-round                                                          ##
    $data{'coding'}{'self_test_probe_in_flight'}{'cpu'} = TRUE;

    my $ret = fire_verify('cpu');
    ok( !$ret, 'verify deferred [ returns FALSE ]' );
    ok( $data{'coding'}{'task'}{'queue_paused'} == 1,
        'task queue still paused past the old 1820s ceiling'
    );
    ok( scalar( grep { $ARG->[1] =~ m{resuming queue anyway} } @log_calls )
            == 0,
        'fallback did NOT fire [ the 5d32f8783 bug class ]'
    );
    ok( scalar(
            grep {
                $ARG->handler eq qw| coding.handler.verify_inference_startup |
                    && ( $ARG->after // 0 ) == 2.0
            } @timer_calls
        ) == 1,
        '2s recheck timer re-armed'
    );
    ok( scalar(
            grep {
                        $ARG->[1] =~ m{stream alive}
                    and $ARG->[1] =~ m{outer cap 5400}
            } @log_calls
        ) == 1,
        'live deferral logged once, naming the shared outer cap'
    );
}

say ': 2. [item 3] fallback fires once the round exceeds the SAME outer cap';

{
    $now += 3600;    ## probe elapsed now 5600 > 5400 + 120 slack         ##
    my $st = $data{'coding'}{'self_test_probe_state'}{'P100'};
    $st->{'http_state'}{'last_activity'} = $now;    ## STILL streaming     ##
    my $ret = fire_verify('cpu');
    ok( $ret, 'verify proceeded [ returns TRUE ]' );
    ok( $data{'coding'}{'task'}{'queue_paused'} == 0, 'task queue resumed' );
    ok( scalar(
            grep {
                        $ARG->[1] =~ m{resuming queue anyway}
                    and $ARG->[1] =~ m{5400}
            } @log_calls
        ) == 1,
        'give-up logged, naming the outer cap it waited past'
    );
    ok( !exists $data{'coding'}{'inference_servers'}{'cpu'}
            {'queue_resume_defer_count'},
        'defer counter cleared on resume'
    );
}

say ': 3. [item 3] stalled probe : fallback fires at the '
    . 'plain budget [ no cap extension through a stall ]';

reset_state();
$cpu_server->();
{
    my $http = mk_http_state( 'cpu', 127 );
    $http->{'chunks_received'} = 20;
    $http->{'last_activity'}   = $now - 200;    ## stalled [ > 77s ]       ##
    $data{'coding'}{'self_test_probe_state'}{'P101'}
        = mk_probe_state( 'cpu', $now - 2000, $http );
    $data{'coding'}{'self_test_probe_in_flight'}{'cpu'} = TRUE;

    my $ret = fire_verify('cpu');    ## elapsed 2000 > 1700 + 120 slack   ##
    ok( $ret, 'stalled probe does NOT extend the fallback bound' );
    ok( $data{'coding'}{'task'}{'queue_paused'} == 0, 'task queue resumed' );
    ok( scalar(
            grep {
                        $ARG->[1] =~ m{resuming queue anyway}
                    and $ARG->[1] =~ m{1700}
            } @log_calls
        ) == 1,
        'give-up logged against the plain max_total bound'
    );
}

say ': 4. [item 3] stale guard [ no probe '
    . 'state ] keeps a bounded wall-clock fallback';

reset_state();
$cpu_server->();
{
    $data{'coding'}{'self_test_probe_in_flight'}{'cpu'} = TRUE;
    ## no entry in self_test_probe_state at all : probe state machine died ##
    $data{'coding'}{'cfg'}{'self_test_max_total'} = 8;    ## shrink for test
    ## defer_ceiling = int( ( 8 + 120 ) / 2 ) = 64 ticks                   ##

    my $ret = fire_verify('cpu');
    ok( !$ret, 'first tick defers [ count 1 < 64 ]' );
    ok( $data{'coding'}{'task'}{'queue_paused'} == 1, 'queue still paused' );
    ok( $data{'coding'}{'inference_servers'}{'cpu'}
            {'queue_resume_defer_count'} == 1,
        'defer counter incremented'
    );

    $data{'coding'}{'inference_servers'}{'cpu'}{'queue_resume_defer_count'}
        = 63;
    $ret = fire_verify('cpu');
    ok( !$ret, 'tick 64 still defers [ count reaches ceiling ]' );

    $ret = fire_verify('cpu');
    ok( $ret, 'stale guard gives up at the bounded wall-clock ceiling' );
    ok( $data{'coding'}{'task'}{'queue_paused'} == 0, 'task queue resumed' );

    $data{'coding'}{'cfg'}{'self_test_max_total'} = 1700;    ## restore ##
}

say ': 5. [item 4] poll_switch testing '
    . 'phase waits past 300s for a live probe';

reset_state();
{
    $data{'coding'}{'inference_servers'}{'gpu'}
        = { 'status' => qw| ready |, 'pid' => 4242, 'n_ctx' => 8192 };
    my $http = mk_http_state( 'gpu', 127 );
    $http->{'chunks_received'} = 20;     ## cap = static gpu 900 > 300      ##
    $http->{'last_activity'}   = $now;
    $data{'coding'}{'self_test_probe_state'}{'P200'}
        = mk_probe_state( 'gpu', $now - 400, $http );
    $data{'coding'}{'self_test_probe_in_flight'}{'gpu'} = TRUE;
    $data{'coding'}{'self_test_switch_state'}{'SW1'}    = {
        'phase'          => qw| testing |,
        'started'        => $now - 400,      ## past the flat 300s max_wait ##
        'target_model'   => 'MNEW',
        'test_model'     => 'MNEW',
        'original_model' => 'MOLD',
        'prior_pid'      => 0,
        'reply_id'       => '',
        'dep_id'         => 0,
    };

    fire_poll_switch('SW1');
    my $st = $data{'coding'}{'self_test_switch_state'}{'SW1'};
    ok( scalar(@switch_model_calls) == 0,
        'NO restore initiated while the probe stream is alive' );
    ok( ( defined $st and !defined $st->{'error'} ),
        'no timeout error recorded' );
    ok( ( defined $st and $st->{'phase'} eq qw| testing | ),
        'state machine stays in the testing phase'
    );
    ok( scalar(
            grep {
                        $ARG->[1] =~ m{stream alive}
                    and $ARG->[1] =~ m{outer cap 900}
            } @log_calls
        ) == 1,
        'live wait logged, naming the outer cap'
    );

    say ': 6. [item 4] same phase falls through '
        . 'to restore once the stream stalls';

    $http->{'last_activity'} = $now - 200;    ## stalled ##
    fire_poll_switch('SW1');
    $st = $data{'coding'}{'self_test_switch_state'}{'SW1'};
    ok( scalar(@switch_model_calls) == 1,
        'restore switch-model call initiated on stall' );
    ok( ( $switch_model_calls[0]{'args'} // '' ) eq 'MOLD',
        'restore targets the original model' );
    ok( ( defined $st and ( $st->{'error'} // '' ) =~ m{timeout after 300s} ),
        'timeout error recorded against the flat max_wait'
    );
    ok( ( defined $st and $st->{'phase'} eq qw| restoring | ),
        'state machine moved to restoring' );
}

say ': 7. [item 5] defer_seed_restart waits '
    . 'past 120s for a lock held by a live probe';

reset_state();
{
    $data{'coding'}{'inference_servers'}{'cpu'}
        = { 'status' => qw| ready |, 'pid' => 2222, 'n_ctx' => 8192 };
    my $http = mk_http_state( 'cpu', 127 );
    $http->{'chunks_received'} = 20;
    $http->{'last_activity'}   = $now;
    $data{'coding'}{'self_test_probe_state'}{'P300'}
        = mk_probe_state( 'cpu', $now - 200, $http );
    ## the backend lock value IS the probe_id [ poll_probe acquires with ##
    ## probe_id ] - the handler resolves the probe straight through it   ##
    $data{'coding'}{'state'}{'backend'}{'cpu'}
        = { 'lock' => 'P300', 'queue' => [] };
    $data{'coding'}{'seed_restart_defer'}{'D1'} = {
        'backend'  => 'cpu',
        'model_id' => 'TESTID7:CPU',
        'pid'      => 2222,
        'started'  => $now - 200,      ## past the flat 120s ceiling ##
    };

    fire_defer('D1');
    ok( exists $data{'coding'}{'seed_restart_defer'}{'D1'},
        'defer entry NOT given up while the probe stream is alive'
    );
    ok( scalar( grep { $ARG->[1] =~ m{giving up} } @log_calls ) == 0,
        'no give-up logged' );
    ok( scalar(
            grep {
                $ARG->handler eq qw| coding.handler.spawn_servers_deferred |
            } @timer_calls
        ) == 0,
        'no respawn armed'
    );
    ok( scalar(
            grep {
                        $ARG->[1] =~ m{probe P300 alive}
                    and $ARG->[1] =~ m{outer cap 5400}
            } @log_calls
        ) == 1,
        'live wait logged, naming probe and outer cap'
    );

    say ': 8. [item 5] gives up once the holding probe stalls';

    $http->{'last_activity'} = $now - 200;    ## stalled ##
    fire_defer('D1');
    ok( !exists $data{'coding'}{'seed_restart_defer'}{'D1'},
        'defer entry cleaned up on give-up' );
    ok( scalar(
            grep { $ARG->[1] =~ m{still busy after 120s : giving up} }
                @log_calls
        ) == 1,
        'give-up logged [ server left running ]'
    );
}

say ': 9. [item 5] a lock held by a REAL TASK still gives up at 120s';

reset_state();
{
    $data{'coding'}{'inference_servers'}{'cpu'}
        = { 'status' => qw| ready |, 'pid' => 2222, 'n_ctx' => 8192 };
    $data{'coding'}{'state'}{'backend'}{'cpu'}
        = { 'lock' => 'TASK9', 'queue' => [] };    ## no probe state at all ##
    $data{'coding'}{'seed_restart_defer'}{'D2'} = {
        'backend'  => 'cpu',
        'model_id' => 'TESTID7:CPU',
        'pid'      => 2222,
        'started'  => $now - 200,
    };

    fire_defer('D2');
    ok( !exists $data{'coding'}{'seed_restart_defer'}{'D2'},
        'task-held lock keeps the flat 120s ceiling [ unchanged behavior ]' );
    ok( scalar( grep { $ARG->[1] =~ m{giving up} } @log_calls ) == 1,
        'give-up logged' );
}

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,.,,..,,,,.,,,,,.,.,,.,,,.,,.,,,.,,,,,.,...,..,,...,...,,,,,,..,..,,,,.,.,.,
#2C6USUV2RS7KQLZEZT3HWYTRBK5SWKAENIM66XU5RAWRZYGKERY5BGL2Y2VQJKBGV3SQFFQBNGUNQ
#\\\|2GWLBMEJ5R4HAFWIXCENHWW2UVJVL6DLO6LOWL3WC4HVHTH7K5O \ / AMOS7 \ YOURUM ::
#\[7]ZIU4A3TQEPR3LL76XINUEXXCHACQZ5EKQXJ75VVQFTLSKXSWO6AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
