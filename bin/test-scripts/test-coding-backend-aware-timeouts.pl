#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                            ###
## backend-aware timeout scaling : live tps + outer cap harness ##
###                                                            ###

##     exercises the real translated source of  coding.async.stream_tps     ##
##     + coding.handler.http_timeout +                                      ##
##     coding.self_test.handler.poll_probe against an in-process %data      ##
##     / %code stub environment -- no live coding zenka required, time      ##
##     is stubbed throughout [ settable $now ]. covers items 0-2 of         ##
##     data/tasks/coding-backend-aware-timeout-scaling.md :                 ##
##                                                                          ##
##     - live stream extends past the old flat 780s hard ceiling            ##
##     REPEATEDLY, failing only at the auto-derived outer cap               ##
##     - stalled stream still fails fast [ no extend while stalled ],       ##
##     the short per-chunk stall window stays the hang detector             ##
##     - task-based branch stays one-shot via round_soft_restart            ##
##     - auto-cap computes from measured t/s once the minimum-sample        ##
##     floor is met, falls back to the static per-backend default           ##
##     before it                                                            ##
##     - auto-cap FREEZES across simulated stalled ticks [ asserted         ##
##     bit-for-bit unchanged while stub-time advances ]                     ##
##     - poll_probe's max_total watchdog defers for slow-but-live           ##
##     probes up to the outer cap, and still aborts stalled /               ##
##     not-in-flight probes immediately                                     ##

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

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %data;
our %code;
our $call;

##[ fake event objects ]######################################################

package FakeTimer {
    use strict;    ## one-shot timers, fired manually by the harness ##
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
    use strict;    ## handler receives this : ->w->data, ->w->cancel ##
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

package FakeSock {
    ## defined-ness is all http_timeout checks ##
    sub new { bless {}, shift }
}

package main;

my $now = 10_000;    ## stub time [ seconds ], advanced per scenario       ##

my @timer_calls;     ## event.add_timer invocations [ FakeTimer objects ]  ##
my @log_calls;       ## every base.logs invocation [ [ level, rendered ] ] ##
my @errors;          ## on_error callback invocations                      ##
my @cleanup_calls;   ## coding.async.http_cleanup invocations              ##
my @restart_calls;   ## coding.async.round_soft_restart invocations        ##
my %task_states;     ## task_id => hashref [ state_manager stub backing ]  ##

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
    'coding.async.state_manager' => sub {
        my ( $op, $task_id ) = @ARG;
        return $task_states{$task_id};
    },
    'coding.async.http_cleanup' => sub {
        push @cleanup_calls, shift;
        return { success => TRUE };
    },
    'coding.async.round_soft_restart' => sub {
        push @restart_calls, [@ARG];
        return TRUE;
    },
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
compile_module('coding.handler.http_timeout');
compile_module('coding.self_test.handler.poll_probe');

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

sub update   { $code{'coding.async.stream_tps'}->( qw| update |,   shift ) }
sub get_cap  { $code{'coding.async.stream_tps'}->( qw| get_cap |,  shift ) }
sub get_tps  { $code{'coding.async.stream_tps'}->( qw| get_tps |,  shift ) }
sub is_alive { $code{'coding.async.stream_tps'}->( qw| is_alive |, shift ) }

sub fire_timeout {
    my $state = shift;
    $code{'coding.handler.http_timeout'}
        ->( FakeEvent->new( { state => $state, io_watcher => undef } ) );
    return;
}

sub fire_poll_probe {
    my $probe_id = shift;
    $code{'coding.self_test.handler.poll_probe'}
        ->( FakeEvent->new( { probe_id => $probe_id } ) );
    return;
}

## fresh streaming-request state, same shape coding.async.http_client makes ##
sub mk_http_state {
    my ( $backend, $timeout ) = @ARG;
    return {
        'sock'              => FakeSock->new,
        'buffer'            => '',
        'chunks_received'   => 0,
        'bytes_received'    => 0,
        'last_activity'     => $now,
        'request_start'     => $now,
        'stall_timeout_sec' => 77,
        'completed'         => FALSE,
        'task_id'           => '',
        'callbacks'         => {
            'backend'  => $backend,
            'timeout'  => $timeout,
            'on_error' => sub { push @errors, shift; return },
        },
    };
}

say ': setup -- pinned cfg + one 8192-ctx server per backend';

$data{'coding'}{'http-timeouts'}{'request-completed'} = 780;
$data{'coding'}{'cfg'}{'round_cap_margin'}            = 1.3;
$data{'coding'}{'cfg'}{'round_cap_min_samples'}       = 32;
$data{'coding'}{'cfg'}{'round_cap_static'}            = {
    'gpu'     => 900,
    'cpu'     => 5400,
    'default' => 2700,
};
$data{'coding'}{'cfg'}{'self_test_max_total'} = 1700;
$data{'coding'}{'inference_servers'} = {
    'gpu' => { 'n_ctx' => 8192 },
    'cpu' => { 'n_ctx' => 8192 },
};

say ': 1. static per-backend fallback before the minimum-sample floor';

{
    my $st = mk_http_state( 'cpu', 127 );
    $st->{'chunks_received'} = 5;
    $st->{'last_activity'}   = $now;
    update($st);
    ok( get_cap($st) == 5400,
        'cpu cap is the static 5400 fallback with 5 chunks [ < 32 ]' );
    ok( !defined get_tps($st),
        'no live tps reported before the sample floor' );
    ok( ( $st->{'tps'}{'token_count'} // 0 ) == 5,
        'token_count tracked from chunks_received'
    );
    ok( defined $st->{'tps'}{'first_token_time'},
        'first-token timestamp latched on first chunk'
    );
}

say ': 2. auto-cap computes from measured t/s once the floor is met';

{
    my $st = mk_http_state( 'gpu', 127 );
    $st->{'chunks_received'} = 1;
    update($st);    ## latches first_token_time at $now                   ##
    $now += 16;
    $st->{'chunks_received'} = 64;     ## 64 tokens in 16s = 4 t/s         ##
    $st->{'last_activity'}   = $now;
    update($st);
    my $expected = int( ( 8192 / 4 ) * 1.3 );    ## 2662 ##
    ok( get_cap($st) == $expected,
        "live cap = int( n_ctx / tps * margin ) = $expected [ gpu, 4 t/s ]" );
    ok( get_tps($st) == 4,
        'live tps measured as 4 [ time-since-FIRST-TOKEN ]' );
    ok( get_cap($st) > 900,
        'live estimate raised the cap above the gpu floor' );

    say ': 3. cap FREEZES across stalled ticks '
        . '[ the backwards-inversion check ]';

    my $frozen = get_cap($st);
    $now += 100;    ## no chunks : last_activity now 100s stale [ > 77 ]  ##
    ok( !is_alive($st), 'stream reads stalled after 100s of silence' );
    my @caps;
    for my $tick ( 1 .. 3 ) {
        push @caps, get_cap($st);
        $now += 100;    ## elapsed keeps advancing, no new tokens         ##
    }
    ok(
        (           $caps[0] == $frozen
                and $caps[1] == $frozen
                and $caps[2] == $frozen
        ),
        "cap frozen at $frozen across 3 stalled ticks [ +300s elapsed ]"
    );
    my $naive
        = int( ( 8192 / ( 64 / ( $now - $st->{'tps'}{'first_token_time'} ) ) )
        * 1.3 );
    ok( $naive > $frozen,
        "a naive recompute would have ballooned "
            . "to $naive -- freeze prevented it"
    );
    ok( get_tps($st) == 4, 'tps frozen at last good value as well' );
}

say ': 4. live stream extends REPEATEDLY past the old 780s flat ceiling';

{
    @errors = ();
    my $st = mk_http_state( 'cpu', 127 );
    $st->{'chunks_received'} = 100;    ## alive, but tps never updated :  ##
    ## no first_token_time -> get_cap stays at the static 5400 throughout ##
    my @ceilings;
    my $trips = 0;
    while ( $trips < 12 and !@errors ) {
        $st->{'last_activity'} = $now;    ## chunks flowing at trip time  ##
        fire_timeout($st);
        $trips++;
        push @ceilings, $st->{'callbacks'}{'timeout'};
        $now += 780;
    }
    ok( scalar(@errors) == 1,
        'stream eventually failed exactly once [ at the outer cap ]' );
    ok( ( $errors[0] // '' ) eq 'Request timeout',
        'failure is the genuine-timeout path'
    );
    ok( $ceilings[0] == 907,
        'first extend : 127 + 780 = 907 [ was one-shot to 780 before ]' );
    ok( ( scalar grep { $ARG > 780 } @ceilings ) >= 5,
        'extended past the old flat 780s hard ceiling repeatedly'
    );
    ok( $ceilings[-1] == 5400,
        'final extension capped ' . 'at the outer cap 5400' );
    ok( scalar(@restart_calls) == 0,
        'round_soft_restart never involved [ no task_id ]' );
    ok( scalar(
            grep { $ARG->handler eq qw| coding.handler.http_timeout | }
                @timer_calls
        ) >= 7,
        'timeout timer re-armed on every extension'
    );
    ok( scalar(
            grep {
                $ARG->[1] =~ m{genuine failure} and $ARG->[1] =~ m{cap=5400}
            } @log_calls
        ) == 1,
        'genuine failure logged once, naming the outer cap'
    );
}

say ': 5. stalled stream fails fast -- NOT deferred to the outer cap';

{
    @errors      = ();
    @timer_calls = ();
    my $st = mk_http_state( 'cpu', 127 );
    $st->{'chunks_received'} = 50;
    $st->{'last_activity'}   = $now - 100;    ## stalled [ > 77s silence ] ##
    fire_timeout($st);
    ok( scalar(@errors) == 1,
        'stalled stream failed on the spot [ ceiling 127 << cap 5400 ]' );
    ok( scalar(@timer_calls) == 0, 'no extension timer armed for a stall' );
    ok( ( $log_calls[-1][1] =~ m{stream_alive=0} ),
        'failure log records stream_alive=0'
    );
}

say ': 6. task-based branch stays ONE-SHOT via round_soft_restart';

{
    @errors        = ();
    @restart_calls = ();
    @cleanup_calls = ();
    my $st = mk_http_state( 'gpu', 384 );
    $st->{'task_id'}         = 'T1';
    $st->{'chunks_received'} = 20;
    $task_states{'T1'}       = { 'task_id' => 'T1' };
    $st->{'last_activity'}   = $now;
    fire_timeout($st);    ## soft trip with live stream + task            ##
    ok( scalar(@restart_calls) == 1,
        'first live trip restarted the round once' );
    ok( ( $restart_calls[0][0] eq 'T1' and $restart_calls[0][1] == 780 ),
        'restart got the task id and the full hard ceiling'
    );
    ok( scalar(@errors) == 0, 'no failure on the first task trip' );
    ## simulate the restarted round tripping again at the hard ceiling :  ##
    ## the task branch must NOT repeat [ each restart re-fires generation ##
    ## from scratch -- repeating would livelock a slow round ]            ##
    $now += 780;
    $st->{'callbacks'}{'timeout'} = 780;
    $st->{'last_activity'} = $now;
    fire_timeout($st);
    ok( scalar(@restart_calls) == 1,
        'second trip did NOT restart again [ one-shot, by design ]' );
    ok( scalar(@errors) == 1,
        'second trip hard-failed [ same as before this change ]' );
    delete $task_states{'T1'};
}

say ': 7. poll_probe : slow-but-live probe past max_total is NOT aborted';

$data{'coding'}{'self_test_probe_in_flight'} = { 'cpu' => TRUE };
{
    my $probe_id = 'P1';
    my @done;
    my $http = mk_http_state( 'cpu', 127 );
    $http->{'chunks_received'} = 20;     ## < min samples : cap stays 5400 ##
    $http->{'last_activity'}   = $now;
    $now += 1800;                        ## elapsed 1800 > max_total 1700  ##
    $data{'coding'}{'self_test_probe_state'}{$probe_id} = {
        'backend'    => 'cpu',
        'model_id'   => 'TESTID7:CPU',
        'started'    => $now - 1800,
        'phase'      => qw| probe |,
        'in_flight'  => TRUE,
        'http_state' => $http,
        'prompts'    => [],
        'idx'        => 0,
        'results'    => [],
        'pass_count' => 0,
        'test_count' => 0,
        'all_passed' => TRUE,
        'ntime'      => 3211206825624,
        'on_done'    => sub { push @done, shift; return },
    };
    $http->{'last_activity'} = $now;    ## streaming right now            ##
    fire_poll_probe($probe_id);
    my $st = $data{'coding'}{'self_test_probe_state'}{$probe_id};
    ok( ( defined $st and !$st->{'watchdog_abort'} ),
        'live probe past 1700s budget survived the watchdog'
    );
    ok( ( defined $st and $st->{'phase'} eq qw| probe | ),
        'probe still in its probe phase [ not forced done ]'
    );
    ok( scalar(@done) == 0, 'no completion callback fired' );
    ok( scalar( grep { $ARG->[1] =~ m{deferring to outer cap} } @log_calls )
            >= 1,
        'deferral logged, naming the outer cap'
    );

    say ': 8. same probe aborts once even the outer cap is exceeded';

    $now += 3800;                       ## elapsed now 5600 > cap 5400    ##
    $http->{'last_activity'} = $now;    ## STILL streaming                ##
    fire_poll_probe($probe_id);
    $st = $data{'coding'}{'self_test_probe_state'}{$probe_id};
    ok( !defined $st, 'probe state settled+deleted past the outer cap' );
    ok( scalar(@done) == 1, 'completion callback fired at the cap' );
    ok( ( $done[0]{'mode'} // '' ) eq qw| false |,
        'completed as failure [ watchdog abort, partial results ]' );
    ok( scalar( grep { $_ eq 'probe watchdog abort' } @errors ) == 1,
        'the probe pipeline got its watchdog-abort error exactly once'
    );
    ok( !$data{'coding'}{'self_test_probe_in_flight'}{'cpu'},
        'per-backend guard slot cleared on the way out'
    );
}

say ': 9. stalled probe past max_total aborts IMMEDIATELY [ not deferred ]';

{
    my $probe_id = 'P2';
    my @done;
    my $http = mk_http_state( 'cpu', 127 );
    $http->{'chunks_received'} = 20;
    $http->{'last_activity'}   = $now - 200;    ## stalled                ##
    $data{'coding'}{'self_test_probe_state'}{$probe_id} = {
        'backend'    => 'cpu',
        'model_id'   => 'TESTID7:CPU',
        'started'    => $now - 1800,            ## elapsed 1800 > 1700    ##
        'phase'      => qw| probe |,
        'in_flight'  => TRUE,
        'http_state' => $http,
        'prompts'    => [],
        'idx'        => 0,
        'results'    => [],
        'pass_count' => 0,
        'test_count' => 0,
        'all_passed' => TRUE,
        'ntime'      => 3211206825624,
        'on_done'    => sub { push @done, shift; return },
    };
    fire_poll_probe($probe_id);
    ok( !defined $data{'coding'}{'self_test_probe_state'}{$probe_id},
        'stalled probe aborted at max_total, not at the outer cap'
    );
    ok( scalar(@done) == 1, 'stalled probe completion fired' );
}

say ': 10. not-in-flight probe [ phase stuck, no request ] still aborts';

{
    my $probe_id = 'P3';
    my @done;
    $data{'coding'}{'self_test_probe_state'}{$probe_id} = {
        'backend'    => 'cpu',
        'model_id'   => 'TESTID7:CPU',
        'started'    => $now - 1800,
        'phase'      => qw| probe |,
        'in_flight'  => FALSE,           ## no live request to be alive for ##
        'http_state' => undef,
        'prompts'    => [],
        'idx'        => 0,
        'results'    => [],
        'pass_count' => 0,
        'test_count' => 0,
        'all_passed' => TRUE,
        'ntime'      => 3211206825624,
        'on_done'    => sub { push @done, shift; return },
    };
    fire_poll_probe($probe_id);
    ok( !defined $data{'coding'}{'self_test_probe_state'}{$probe_id},
        'stuck phase with no in-flight request aborted as before'
    );
    ok( scalar(@done) == 1, 'completion callback fired' );
}

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,.,,.,,,..,,..,,,,.,...,,.,,,..,,,,,,.,,.,,,..,,...,...,.,,,,,.,,,,,.,,,.,.,
#DCDZ25OP67EFNQMN6Q32DENIAVRZXISSHYZWQVNMWZA43G4AVKNVV6LUP6JTHIDJYWX2JDOOWTLQC
#\\\|ADCBFVHEJA5LBVJZSOGIBQRM6RKPEB7T6AT6SJRU7SHYJPW5VY3 \ / AMOS7 \ YOURUM ::
#\[7]5ZLMWXYKBZO2LUPWCYSGZXBTXQNTGXDHHOTKC3ZC3H4MKD2HNGCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
