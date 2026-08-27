#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                            ###
## coding self-test per-backend guard : parallel + retry harness ##
###                                                            ###

## exercises the real translated source of                                  ##
## coding.helper.trigger_backend_self_test +                                ##
## coding.helper.self_test_guard_watcher +                                  ##
## coding.helper.resume_task_queue_for_backend against an in-process %data  ##
## / %code stub environment -- no live coding zenka required. covers the    ##
## per-backend parallelization of the self-test in-flight guard [ task :    ##
## coding-self-test-true-parallelization, 2026-08-27 ] : the guard is now a ##
## HASH keyed by backend id, so both backends' coding.self_test.run calls   ##
## succeed with mode='deferred' simultaneously and complete independently.  ##
## same-backend contention [ a second trigger while that backend's own      ##
## self-test is still in flight ] is still marked pending and woken by a    ##
## PER-BACKEND variable watcher on that backend's own guard hash value slot ##
## [ one event.add_var watcher per backend, the                             ##
## jobqueue.event.register_job_queues precedent : a single watcher over the ##
## hash's top-level slot would never fire on key mutations ], with a        ##
## per-backend safety-net timeout in case the slot never clears             ##
##                                                                          ##
## mechanism note : base.event.add_var routes through Event->var [ a real   ##
## Event-module call, not %code ], which cannot run standalone here -- so   ##
## this harness stubs 'event.add_var' itself in %code as a call-recorder [  ##
## choice (a) from the task brief, matching how 'event.add_timer' is        ##
## already stubbed ] and manually FIRES the recorded handler per backend to ##
## simulate the guard slot changing, the same way the Event loop would      ##
## deliver it [ edge-triggered, coalesced ]. timer stubs return fake        ##
## watcher objects with is_active/cancel so the module's cancellation       ##
## guards run against realistic semantics                                   ##

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
    use strict;    ## returns : is_active/cancel + param accessors     ##
    use English;

    sub new {
        my ( $class, $params ) = @ARG;
        return bless { 'params' => $params, 'active' => 1 }, $class;
    }
    sub is_active { shift->{'active'} }
    sub cancel    { shift->{'active'} = 0; return }
    sub after     { shift->{'params'}{'after'} }
    sub desc      { shift->{'params'}{'desc'} // '' }

    sub fire {     ## one-shot semantics : inactive after firing [ Event ] ##
        my $self = shift;
        $self->{'active'} = 0;
        $self->{'params'}{'cb'}->();
        return;
    }
}

package FakeVarWatcher {
    use strict;    ## add_var returns [ handler stored in %code, ##
    use English;

    sub new {      ## fired manually by the harness ]            ##
        my ( $class, $params ) = @ARG;
        return bless { 'params' => $params, 'active' => 1 }, $class;
    }
    sub is_active { shift->{'active'} }
    sub cancel    { shift->{'active'} = 0; return }
    sub params    { shift->{'params'} }
    sub w         {shift}    ## handler receives the watcher : ->w->data ##
    sub data      { shift->{'params'}{'data'} }
}

package main;

my @run_calls;      ## every coding.self_test.run invocation [ params ]     ##
my @timer_calls;    ## event.add_timer invocations [ FakeTimer objects ]    ##
my @var_calls;      ## event.add_var invocations [ FakeVarWatcher objects ] ##
my @log_calls;      ## every base.logs invocation [ [ level, rendered ] ]   ##
my %resumed;        ## backend => count of resume invocations               ##
my %on_done_for;    ## backend => on_done coderef captured by the run stub  ##

## when set, run stub always fails with this reason ##
my $force_error = '';

%code = (
    'base.logs' => sub {
        my ( $level, $fmt, @args ) = @ARG;
        push @log_calls, [ $level, sprintf( $fmt, @args ) ];
        return TRUE;
    },
    'base.log'    => sub { return TRUE },
    'base.gen_id' => sub {
        my $href = shift;
        my $id   = 1;
        $id++ while exists $href->{$id};
        return $id;
    },
    'base.time'       => sub { return 1000 },
    'event.add_timer' => sub {
        my $timer = FakeTimer->new(shift);
        push @timer_calls, $timer;
        return $timer;
    },
    'event.add_var' => sub {
        my $watcher = FakeVarWatcher->new(shift);
        push @var_calls, $watcher;
        return $watcher;
    },
    'jobqueue.check_dependencies' => sub { return TRUE },
    'coding.self_test.run'        => sub {
        my $params  = shift;
        my $backend = $params->{'backend'} // '';
        push @run_calls, $params;
        return { mode => 'false', data => $force_error }
            if length $force_error;
        ## the guard is a PER-BACKEND hash now : only a same-backend slot ##
        ## blocks a new self-test, a different backend's slot never does  ##
        return { mode => 'false', data => 'self-test already in progress' }
            if $data{'coding'}{'self_test_probe_in_flight'}{$backend};
        ## the REAL %data slot is the guard : the watcher handler reads it ##
        $data{'coding'}{'self_test_probe_in_flight'}{$backend} = TRUE;
        $on_done_for{$backend} = $params->{'on_done'};
        return { mode => 'deferred' };
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

compile_module('coding.helper.resume_task_queue_for_backend');
compile_module('coding.helper.self_test_guard_watcher');
compile_module('coding.helper.trigger_backend_self_test');

## count resume invocations per backend around the REAL named helper --    ##
## trigger's default resume_queue closure resolves <[coding.helper...]> at ##
## call time, so wrapping the %code entry covers every path                ##
{
    my $real_resume = $code{'coding.helper.resume_task_queue_for_backend'};
    $code{'coding.helper.resume_task_queue_for_backend'} = sub {
        my $backend = shift;
        $resumed{$backend}++;
        return $real_resume->($backend);
    };
}

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

sub trigger {
    my $backend = shift;
    return $code{'coding.helper.trigger_backend_self_test'}->(
        {   'backend'    => $backend,
            'server'     => $data{'coding'}{'inference_servers'}{$backend},
            'tested_pid' =>
                $data{'coding'}{'inference_servers'}{$backend}{'pid'} // 0,
            ## NO resume_queue passed : exercises the default path through ##
            ## coding.helper.resume_task_queue_for_backend [ exactly how   ##
            ## the var watcher handler re-invokes it ]                     ##
        }
    );
}

sub retry_pending { $data{'coding'}{'self_test_retry_pending'} // {} }

## per-backend guard slot accessors [ hash guard, not a scalar any more ] ##
sub guard_set {
    $data{'coding'}{'self_test_probe_in_flight'}{ shift() } = TRUE;
}

sub guard_clear {
    $data{'coding'}{'self_test_probe_in_flight'}{ shift() } = FALSE;
}

sub guard_is {
    $data{'coding'}{'self_test_probe_in_flight'}{ shift() } // FALSE;
}

## most recently registered, still-active guard watcher for a backend [ the ##
## watcher's data array carries the backend as its first element ]          ##
sub watcher_for {
    my $backend = shift;
    my ($found) = reverse grep {
        $ARG->is_active
            and ( $ARG->params->{'data'}[0] // '' ) eq $backend
    } @var_calls;
    return $found;
}

## simulate the Event loop delivering one backend's guard slot change :     ##
## invoke the recorded add_var handler the way base.event.add_var's wrapper ##
## would, passing that backend's own watcher object                         ##
sub fire_guard_watcher {
    my $backend = shift;
    my $watcher = watcher_for($backend)
        or die "no active var watcher for backend=$backend";
    $code{ $watcher->params->{'handler'} }->($watcher);
    return;
}

## most recently armed, still-active safety timer for a backend ##
sub safety_timer_for {
    my $backend = shift;
    my ($found)
        = reverse
        grep { $ARG->is_active and $ARG->desc =~ m{backend=$backend} }
        @timer_calls;
    return $found;
}

## simulate a passing probe finishing [ clears THIS backend's guard slot,  ##
## then runs its on_done - the same order poll_probe's done phase uses ].  ##
## the slot clearing is what the Event loop would deliver to the backend's ##
## guard watcher; the harness fires that watcher manually where a pending  ##
## wake-up is under test                                                   ##
sub complete_probe_ok {
    my $backend = shift;
    guard_clear($backend);
    my $cb = $on_done_for{$backend} or die "no on_done captured for $backend";
    $cb->(
        {   mode => 'true',
            data => {
                all_passed => TRUE,
                results    => [
                    { prompt_id => 1, passed => TRUE },
                    { prompt_id => 2, passed => TRUE },
                    { prompt_id => 3, passed => TRUE },
                ],
            },
        }
    );
    return;
}

say ': setup -- two backends ready close together';

$data{'coding'}{'inference_servers'} = {
    'gpu' => {
        pid   => 1111,
        model => 'TESTID7:GPU',
        url   => 'http://127.0.0.1:8000',
        port  => 8000,
    },
    'cpu' => {
        pid   => 2222,
        model => 'TESTID7:CPU',
        url   => 'http://127.0.0.1:8001',
        port  => 8001,
    },
};

## pin the safety timeout explicitly : the real default derives from     ##
## <coding.cfg.self_test_max_total> [ ~1700s worst-case ] -- correct for ##
## production, but this harness tests the MECHANISM, not the derivation  ##
## arithmetic [ derivation itself is scenario 9 ]                        ##
$data{'coding'}{'cfg'}{'self_test_retry_max'} = 60;

say ': 1. genuine concurrency : BOTH backends start, neither waits';

my $r_gpu = trigger('gpu');
ok( ( ref $r_gpu and $r_gpu->{'mode'} eq 'deferred' ),
    'gpu self-test started [ mode=deferred ]'
);
my $r_cpu = trigger('cpu');
ok( ( ref $r_cpu and $r_cpu->{'mode'} eq 'deferred' ),
    'cpu self-test ALSO started [ mode=deferred ] -- no cross-backend wait' );
ok( scalar(@run_calls) == 2, 'two self_test.run calls, one per backend' );
ok( ( $run_calls[0]->{'backend'}  // '' ) eq 'gpu', 'first call is gpu' );
ok( ( $run_calls[1]->{'backend'}  // '' ) eq 'cpu', 'second call is cpu' );
ok( ( $run_calls[0]->{'model_id'} // '' ) eq 'TESTID7:GPU',
    'gpu call carries its model_id' );
ok( ( $run_calls[1]->{'model_id'} // '' ) eq 'TESTID7:CPU',
    'cpu call carries its model_id' );
ok( ( guard_is('gpu') and guard_is('cpu') ),
    'both per-backend guard slots set simultaneously'
);
ok( scalar(@var_calls) == 0,   'no guard watcher needed [ no contention ]' );
ok( scalar(@timer_calls) == 0, 'no safety timer armed [ no contention ]' );
ok(
    (           not exists retry_pending()->{'gpu'}
            and not exists retry_pending()->{'cpu'}
    ),
    'no pending state for either backend'
);

say ': 2. both on_done callbacks in flight at once, completing independently';

complete_probe_ok('gpu');
ok( ( $resumed{'gpu'} // 0 ) == 1,
    'gpu queue resumed from its on_done completion' );
ok( ( $resumed{'cpu'} // 0 ) == 0,
    'cpu queue NOT resumed yet [ its probe still running ]' );
ok( ( not guard_is('gpu') and guard_is('cpu') ),
    'gpu slot cleared, cpu slot still set [ independent state ]' );

complete_probe_ok('cpu');
ok( ( $resumed{'cpu'} // 0 ) == 1,
    'cpu queue resumed after its own self-test completed' );
ok( ( not guard_is('cpu') ), 'cpu slot cleared on its own completion' );

say ': 3. same-backend contention : pending, '
    . 'ONE per-backend watcher, one safety timer';

guard_set('cpu');    ## cpu probe [ simulated ] still in flight            ##
my $r_cpu2 = trigger('cpu');
ok( scalar(@run_calls) == 3, 'contended cpu trigger reached self_test.run' );
ok( ( not defined $r_cpu2 ), 'cpu trigger returned undef [ wait path ]' );
ok( scalar(@var_calls) == 1, 'exactly one var watcher registered' );
ok(
    (   ref $var_calls[0]->params->{'var'} eq 'SCALAR'
            and $var_calls[0]->params->{'var'}
            == \$data{'coding'}{'self_test_probe_in_flight'}{'cpu'}
    ),
    'watcher watches the REAL per-backend guard slot [ cpu hash value ]'
);
ok( ( ( $var_calls[0]->params->{'data'} // [] )->[0] // '' ) eq 'cpu',
    'watcher data carries its own backend name' );
ok( ( $var_calls[0]->params->{'handler'} // '' ) eq
        'coding.helper.self_test_guard_watcher',
    'watcher handler is the named %code sub [ no closure possible ]'
);
ok( ( $var_calls[0]->params->{'poll'} // '' ) eq qw| w |,
    'watcher fires on writes to the guard slot'
);
ok( scalar(@timer_calls) == 1, 'exactly one safety timer armed' );
ok( ( $timer_calls[0]->after // 0 ) == 60,
    'safety timeout is the [ pinned ] cfg value, in SECONDS' );
ok(
    (           $timer_calls[0]->desc =~ m{guard wait timeout}
            and $timer_calls[0]->desc =~ m{backend=cpu}
    ),
    'safety timer is a guard-wait timeout for backend=cpu'
);
ok(
    (   ref retry_pending()->{'cpu'} eq 'HASH'
            and retry_pending()->{'cpu'}{'tested_pid'} == 2222
    ),
    'cpu pending entry carries the tested pid for the stale guard'
);
ok( ( not exists retry_pending()->{'gpu'} ),
    'gpu retry state never touched by cpu wait cycle'
);
ok( ( $resumed{'cpu'} // 0 ) == 1,
    'cpu queue NOT resumed yet [ waiting, not given up ]' );

say ': 4. pending guard : a stacked trigger does not double-schedule';

my $timers_after_first = scalar @timer_calls;
my $vars_after_first   = scalar @var_calls;
trigger('cpu');    ## same backend again while already waiting             ##
ok( scalar(@timer_calls) == $timers_after_first,
    'no second safety timer stacked while one is pending'
);
ok( scalar(@var_calls) == $vars_after_first,
    'guard watcher NOT re-registered [ pending wait owns the watcher ]' );
ok( ( $resumed{'cpu'} // 0 ) == 1,
    'no premature resume [ pending wait owns the resume ]' );

say ': 5. watcher firing while the guard slot is still SET is a no-op';

my $runs_before = scalar @run_calls;
my $armed_timer = safety_timer_for('cpu');
fire_guard_watcher('cpu');    ## slot SET : watcher must not act           ##
ok( scalar(@run_calls) == $runs_before,
    'no re-trigger while the slot is still set'
);
ok( exists retry_pending()->{'cpu'}, 'cpu stays pending' );
ok( $armed_timer->is_active,         'safety timer not cancelled' );

say ': 6. slot clears [ cpu probe done ], its watcher fires, cpu wakes';

guard_clear('cpu');
fire_guard_watcher('cpu');
ok( scalar(@run_calls) == $runs_before + 1,
    'watcher re-invoked self_test.run for cpu'
);
ok( ( $run_calls[-1]->{'backend'} // '' ) eq 'cpu', 'the call is cpu' );
ok( ( $run_calls[-1]->{'url'} // '' ) eq 'http://127.0.0.1:8001',
    'cpu retry re-fetched the live server [ correct url ]'
);
ok( ( not exists retry_pending()->{'cpu'} ),
    'cpu pending flag cleared once its self-test started' );
ok( ( not $armed_timer->is_active ),
    'safety timer CANCELLED once the watcher re-triggered the backend' );
ok( ( $resumed{'cpu'} // 0 ) == 1,
    'cpu queue still paused until its own on_done fires' );

complete_probe_ok('cpu');
ok( ( $resumed{'cpu'} // 0 ) == 2, 'cpu queue resumed after its self-test' );
ok( ( not exists retry_pending()->{'gpu'} ),
    'gpu retry state still untouched after full cpu cycle' );

say ': 7. non-race failure [ model_id required ] is NOT retried';

$force_error = 'model_id required';
my $log_before = scalar @log_calls;
trigger('gpu');
ok( scalar(@timer_calls) == $timers_after_first,
    'no new timer scheduled for a real error'
);
ok( scalar(@var_calls) == $vars_after_first,
    'no new var watcher for a real error'
);
ok( ( $resumed{'gpu'} // 0 ) == 2,
    'queue resumed immediately on a real error [ nothing hangs ]' );
ok( scalar(
        grep {
                    $ARG->[0] == 0
                and $ARG->[1] =~ m{did not start : model_id required}
        } @log_calls[ $log_before .. $#log_calls ]
    ) == 1,
    'real error logged at level 0 with its reason'
);
ok( ( not exists retry_pending()->{'gpu'} ),
    'real error does not create pending state'
);
$force_error = '';

say ': 8. per-backend watchers : two pending '
    . 'backends, TWO watchers, each on its own slot';

delete $data{'coding'}{'self_test_retry_pending'};
delete $data{'coding'}{'self_test_retry_timer'};
guard_set('gpu');
guard_set('cpu');
my $vars_before_two = scalar @var_calls;
trigger('gpu');
trigger('cpu');
ok( ( exists retry_pending()->{'gpu'} and exists retry_pending()->{'cpu'} ),
    'both backends pending on their own slots' );
ok( scalar(@var_calls) == $vars_before_two + 2,
    'ONE watcher PER BACKEND [ two new watchers, not one shared ]' );
ok(
    (   watcher_for('gpu')->params->{'var'}
            == \$data{'coding'}{'self_test_probe_in_flight'}{'gpu'}
    ),
    'gpu watcher watches the gpu slot'
);
ok(
    (   watcher_for('cpu')->params->{'var'}
            == \$data{'coding'}{'self_test_probe_in_flight'}{'cpu'}
    ),
    'cpu watcher watches the cpu slot'
);

$runs_before = scalar @run_calls;
guard_clear('gpu');           ## only gpu's slot clears                    ##
fire_guard_watcher('gpu');    ## only gpu's watcher fires                  ##
ok( scalar(@run_calls) == $runs_before + 1,  'gpu re-triggered' );
ok( ( not exists retry_pending()->{'gpu'} ), 'gpu woke' );
ok( exists retry_pending()->{'cpu'}, 'cpu STILL pending [ its slot set ]' );
ok( ( defined safety_timer_for('cpu') ),
    'cpu safety timer still armed [ untouched by gpu wake ]' );
complete_probe_ok('gpu');

guard_clear('cpu');
fire_guard_watcher('cpu');
ok( ( not exists retry_pending()->{'cpu'} ),
    'cpu got its turn once its own slot cleared'
);
complete_probe_ok('cpu');
ok( ( ( $resumed{'gpu'} // 0 ) >= 3 and ( $resumed{'cpu'} // 0 ) >= 3 ),
    'both queues resumed through the full cycle' );

say ': 9. cfg budget : retry_max overrides, else self_test_max_total, '
    . 'else 1700s fallback -- all as total wait SECONDS';

delete $data{'coding'}{'self_test_retry_pending'};
delete $data{'coding'}{'self_test_retry_timer'};

guard_set('cpu');
$data{'coding'}{'cfg'}{'self_test_retry_max'} = 42;
trigger('cpu');
ok( ( safety_timer_for('cpu')->after // 0 ) == 42,
    'explicit cfg.self_test_retry_max wins [ 42s ]'
);
safety_timer_for('cpu')->fire();    ## give up, clear state ##

delete $data{'coding'}{'cfg'}{'self_test_retry_max'};
$data{'coding'}{'cfg'}{'self_test_max_total'} = 900;
trigger('cpu');
ok( ( safety_timer_for('cpu')->after // 0 ) == 900,
    'cfg.self_test_max_total used directly as seconds when no override' );
safety_timer_for('cpu')->fire();

delete $data{'coding'}{'cfg'}{'self_test_max_total'};
trigger('cpu');
ok( ( safety_timer_for('cpu')->after // 0 ) == 1700,
    'hardcoded 1700s fallback when neither cfg value is set'
);
safety_timer_for('cpu')->fire();

guard_clear('cpu');

say ': 10. safety timeout fires [ slot never clears ] : clean give-up';

delete $data{'coding'}{'self_test_retry_pending'};
delete $data{'coding'}{'self_test_retry_timer'};
$data{'coding'}{'cfg'}{'self_test_retry_max'} = 60;
guard_set('cpu');
trigger('cpu');
my $resumed_before = $resumed{'cpu'} // 0;
my $safety = safety_timer_for('cpu') or die 'no active cpu safety timer';
$safety->fire();
ok( ( not exists retry_pending()->{'cpu'} ),
    'pending state cleared on safety-timeout give-up'
);
ok( ( $resumed{'cpu'} // 0 ) == $resumed_before + 1,
    'queue resumed exactly once on give-up [ nothing hangs ]'
);
ok( scalar(
        grep {
            $ARG->[0] == 0 and $ARG->[1] =~ m{WITHOUT self-test validation}
        } @log_calls
    ) >= 1,
    'give-up logged at level 0 [ into service unvalidated ]'
);
ok( scalar( grep { $ARG->[1] =~ m{backend=cpu} } @log_calls ) >= 1,
    'wait/give-up logs name the backend' );
ok( ( not defined safety_timer_for('cpu') ),
    'safety timer slot cleared after give-up'
);
ok( ( not guard_is('gpu') ),
    'gpu guard slot never touched by the cpu wait cycle' );

say ': 11. cancel-if-still-active-before-reregistering [ jobqueue pattern ]';

## the safety give-up above left cpu's guard watcher ACTIVE [ the safety ##
## timer callback deliberately does not touch it ] - the next contention ##
## must cancel that stale instance and register a fresh one, tracked per ##
## backend in <coding.watcher.self_test_guard>->{$backend}               ##
my $old_watcher = watcher_for('cpu')
    or die 'no still-active cpu watcher after give-up';
guard_set('cpu');
trigger('cpu');
my $new_watcher = watcher_for('cpu');
ok( ( not $old_watcher->is_active ),
    'previous watcher cancelled before re-registering' );
ok( ( defined $new_watcher and $new_watcher->is_active ),
    'fresh per-backend watcher registered and active'
);
ok( ( $new_watcher != $old_watcher ), 'new watcher is a new instance' );
ok(
    (   $new_watcher->params->{'var'}
            == \$data{'coding'}{'self_test_probe_in_flight'}{'cpu'}
    ),
    'fresh watcher still watches the real cpu slot'
);
ok(
    (           defined $data{'coding'}{'watcher'}{'self_test_guard'}
            and ref $data{'coding'}{'watcher'}{'self_test_guard'} eq 'HASH'
            and $data{'coding'}{'watcher'}{'self_test_guard'}{'cpu'}
            == $new_watcher
    ),
    'watcher tracked per backend in <coding.watcher.self_test_guard>'
);
guard_clear('cpu');
fire_guard_watcher('cpu');
complete_probe_ok('cpu');

say ': 12. stale server while pending : watcher resumes and bails';

delete $data{'coding'}{'self_test_retry_pending'};
delete $data{'coding'}{'self_test_retry_timer'};
guard_set('cpu');
trigger('cpu');    ## pending with tested_pid 2222                          ##
my $stale_timer = safety_timer_for('cpu');
$data{'coding'}{'inference_servers'}{'cpu'} = {
    pid   => 3333,
    model => 'TESTID7:CPU',
    url   => 'http://127.0.0.1:8001',
    port  => 8001,
};                 ## replaced by a newer spawn while waiting        ##
$runs_before    = scalar @run_calls;
$log_before     = scalar @log_calls;
$resumed_before = $resumed{'cpu'} // 0;
guard_clear('cpu');
fire_guard_watcher('cpu');
ok( scalar(@run_calls) == $runs_before,
    'no self-test started for the stale server pid' );
ok( ( $resumed{'cpu'} // 0 ) == $resumed_before + 1,
    'stale backend queue resumed [ its replacement runs its own cycle ]' );
ok( scalar(
        grep { $ARG->[1] =~ m{stale server} }
            @log_calls[ $log_before .. $#log_calls ]
    ) == 1,
    'stale give-up logged'
);
ok( ( not $stale_timer->is_active ), 'stale backend safety timer cancelled' );
ok( ( not exists retry_pending()->{'cpu'} ), 'stale pending entry cleared' );

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,..,,,.,,.,,.,,,,,.,...,,.,,,.,,..,,.,,,.,,,..,,...,...,..,,,.,,,,.,,,.,.,.,
#A33DZBB2ESGSGD5HUYNYQSW4PEMIURUKIQEHKLQLWT5V2Q5XU4NPZO5FYQL2BAR4JOY2JKGUB2TQI
#\\\|32665QOU6D3JT6DBO3GD5NOODDMONPVCEO26N3TWO6SQXRPWQC3 \ / AMOS7 \ YOURUM ::
#\[7]VMTBLBV346EURPNRDY7N4XZXNQ7X5T5VQ6OBGLCW2CKUIM2AFCDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
