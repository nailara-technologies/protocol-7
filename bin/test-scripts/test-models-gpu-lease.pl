#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

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
    unshift @INC, File::Spec->catdir( $root_path, qw| data lib-path pm | );
    $main::root_path    = $root_path;
    $main::TEST_NOW     = 1000;
    *CORE::GLOBAL::time = sub {$main::TEST_NOW};
}

use AMOS7::Protocol::P7Syntax qw| p7_syntax__translate |;
use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %data;
our %code;
our $call;
my $fail_count = 0;
my @routes;
my @timers;
my @logs;
my @llama_pids;
my $route_ok = 1;
my $vram_ok  = 1;

{

    package MockWatcher;

    sub new {
        my ( $class, $data ) = @_;
        return bless { 'data' => $data, 'active' => 1 }, $class;
    }
    sub data      { return $_[0]->{'data'} }
    sub is_active { return $_[0]->{'active'} }
    sub cancel    { $_[0]->{'active'} = 0; return 1 }
    sub stop      { return $_[0]->cancel }
}
{

    package MockEvent;

    sub new {
        my ( $class, $data ) = @_;
        return bless { 'w' => MockWatcher->new($data) }, $class;
    }
    sub w { return $_[0]->{'w'} }
}

%code = (
    'base.logs' => sub {
        push @logs, [@ARG];
        return TRUE;
    },
    'base.time'     => sub { return $main::TEST_NOW },
    'base.cfg_bool' => sub {
        my $value = shift // 0;
        return $value =~ m{^(?:yes|true|on|1|5)$}i ? TRUE : FALSE;
    },
    'protocol-7.route-send' => sub {
        push @routes, shift;
        return $route_ok;
    },
    'event.add_timer' => sub {
        my $timer = shift;
        push @timers, $timer;
        return MockWatcher->new( $timer->{'data'} // {} );
    },
    'base.gpu.query_memory' => sub {
        return { 'ok' => FALSE } if not $vram_ok;
        return {
            'ok'       => TRUE,
            'total_mb' => 12111,
            'free_mb'  => $vram_ok == 2 ? 1000 : 11051,
        };
    },
    'models.gpu_lease.llama_compute_pids' => sub { return [@llama_pids] },
    'base.reply.mode_text'                => sub {
        my $reply = shift;
        return ( $reply->{'cmd'} // '', $reply->{'data'} // '' );
    },
);

sub compile_module {
    my $module_name = shift;
    my $path = File::Spec->catfile( $main::root_path, 'src', $module_name );
    open my $fh, '<', $path or die "cannot read $path : $OS_ERROR";
    my $source = join '', <$fh>;
    close $fh;
    my $translated = p7_syntax__translate($source);
    my $cref       = eval "sub {\n# line 1 \"$module_name\"\n$translated\n}";
    die "compile failed for $module_name : $EVAL_ERROR" if not $cref;
    $code{$module_name} = $cref;
    return $cref;
}

sub ok {
    my ( $condition, $label ) = @ARG;
    if ($condition) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
}

sub reset_lease {
    delete $data{'models'}{'gpu_lease'};
    $data{'models'}{'cfg'}{'gpu_lease'} = {
        'enabled'          => 'yes',
        'priority'         => 'invoke-web',
        'timeout'          => 5,
        'handover_timeout' => 3,
        'grace'            => 7,
        'min_free_mb'      => 4096,
    };
    @routes     = ();
    @timers     = ();
    @logs       = ();
    @llama_pids = ();
    $route_ok   = 1;
    $vram_ok    = 1;
}

sub presence {
    my ( $from, $requester, $connected ) = @_;
    return $code{'models.gpu_lease.handler.presence'}->(
        {   'cmd'    => $connected ? 'true' : 'false',
            'params' => { 'from' => $from, 'requester' => $requester },
        }
    );
}

sub ack {
    my ( $from, $requester ) = @_;
    presence( $from, $requester, TRUE )
        if $data{'models'}{'gpu_lease'}{'pending'}{'presence'};
    local $call = { 'args' => "$from $requester" };
    return $code{'models.cmd.gpu-lease-released'}->();
}

sub grant {
    my $owner = shift;
    $code{'models.gpu_lease.acquire'}->($owner);
    my $from = $owner eq 'coding' ? 'invoke-web' : 'coding';
    ack( $from, $owner );
    return $data{'models'}{'gpu_lease'}{'holder'} // '';
}

compile_module($ARG) for qw|
    models.gpu_lease.state models.gpu_lease.vram_free
    models.gpu_lease.acquire models.gpu_lease.release
    models.gpu_lease.renew models.gpu_lease.handler.tick
    models.gpu_lease.handler.presence
    models.cmd.gpu-lease-released models.cmd.gpu-lease-release-task
    coding.gpu_lease.request coding.gpu_lease.gate
    coding.gpu_lease.cancel_activity coding.async.send_request
    models.task.claim-ok invoke-web.gpu_lease.queue_changed
    invoke-web.gpu_lease.handler.grace invoke-web.gpu_lease.unload
    invoke-web.gpu_lease.handler.unload_pause_reply
    invoke-web.gpu_lease.handler.verify_unload
    coding.cmd.gpu-lease-yield coding.spawn_inference_server
    coding.async_spawn_inference_servers coding.task.enqueue
    |;

say ': 1. acquire, verified grant, renew and release';
reset_lease();
ok( !$code{'models.gpu_lease.acquire'}->('coding'),
    'acquire waits for the other side to unload'
);
ok( ( $data{'models'}{'gpu_lease'}{'holder'} // '' ) eq '',
    'no holder before the unload acknowledgement'
);
ack( 'invoke-web', 'coding' );
ok( ( $data{'models'}{'gpu_lease'}{'holder'} // '' ) eq 'coding',
    'acknowledgement plus free vram grants coding' );
$main::TEST_NOW++;
ok( $code{'models.gpu_lease.renew'}->('coding'), 'holder renewal succeeds' );
ok( !$code{'models.gpu_lease.renew'}->('invoke-web'),
    'non-holder cannot renew' );
ok( $code{'models.gpu_lease.release'}->('coding'),
    'holder release succeeds' );
ok( ( $data{'models'}{'gpu_lease'}{'holder'} // '' ) eq '',
    'release leaves no holder' );

say ': 2. vram verification and bounded handover';
reset_lease();
$code{'models.gpu_lease.acquire'}->('coding');
$vram_ok = 2;
ack( 'invoke-web', 'coding' );
ok( ( $data{'models'}{'gpu_lease'}{'holder'} // '' ) eq '',
    'unload acknowledgement alone does not grant while vram is busy'
);
$vram_ok = 1;
$code{'models.gpu_lease.handler.tick'}->();
ok( ( $data{'models'}{'gpu_lease'}{'holder'} // '' ) eq 'coding',
    'grant follows the later free-vram observation'
);
$code{'models.gpu_lease.release'}->('coding');
$code{'models.gpu_lease.acquire'}->('coding');
$vram_ok = 2;
$main::TEST_NOW += 4;
$code{'models.gpu_lease.handler.tick'}->();
ok( ( $data{'models'}{'gpu_lease'}{'holder'} // '' ) eq '',
    'handover timeout cannot grant while the requester lacks free vram'
);
ok( ref $data{'models'}{'gpu_lease'}{'pending'} eq 'HASH'
        && $data{'models'}{'gpu_lease'}{'pending'}{'wait_reason'}
        =~ m{1000 MB free, 4096 MB needed},
    'state explains the vram refusal after timeout'
);
my $refusal_logs
    = grep { ( $ARG->[1] // '' ) =~ m{waits : vram admission} } @logs;
$code{'models.gpu_lease.handler.tick'}->();
ok( ( grep { ( $ARG->[1] // '' ) =~ m{waits : vram admission} } @logs )
        == $refusal_logs,
    'a continuing refusal is logged only once'
);
$vram_ok = 1;
$code{'models.gpu_lease.handler.tick'}->();
ok( ( $data{'models'}{'gpu_lease'}{'holder'} // '' ) eq 'coding',
    'timeout grants as soon as vram admits the requester'
);

say ': 3. handover coding -> invoke-web [ default priority ]';
reset_lease();
ok( grant('coding') eq 'coding', 'coding initially resident' );
$code{'models.gpu_lease.acquire'}->('invoke-web');
ok( ( $data{'models'}{'gpu_lease'}{'pending'}{'from'} // '' ) eq 'coding',
    'render request preempts coding' );
ok( ( $data{'models'}{'gpu_lease'}{'holder'} // '' ) eq '',
    'old holder is revoked before the new grant'
);
ack( 'coding', 'invoke-web' );
ok( ( $data{'models'}{'gpu_lease'}{'holder'} // '' ) eq 'invoke-web',
    'invoke-web becomes sole holder after coding unload'
);
$code{'models.gpu_lease.acquire'}->('coding');
ok( ( $data{'models'}{'gpu_lease'}{'holder'} // '' ) eq 'invoke-web'
        && !defined $data{'models'}{'gpu_lease'}{'pending'},
    'default policy does not preempt a render for coding'
);

say ': 4. handover invoke-web -> coding [ policy allowing ]';
reset_lease();
$data{'models'}{'cfg'}{'gpu_lease'}{'priority'} = 'coding';
ok( grant('invoke-web') eq 'invoke-web', 'invoke-web initially resident' );
$code{'models.gpu_lease.acquire'}->('coding');
ok( ( $data{'models'}{'gpu_lease'}{'pending'}{'from'} // '' ) eq 'invoke-web',
    'coding priority preempts invoke-web'
);
ack( 'invoke-web', 'coding' );
ok( ( $data{'models'}{'gpu_lease'}{'holder'} // '' ) eq 'coding',
    'coding grant waits for invoke-web unload' );

say ': 5. holder death expires and waiting work proceeds';
reset_lease();
$data{'models'}{'cfg'}{'gpu_lease'}{'priority'} = 'coding';
grant('coding');
$code{'models.gpu_lease.acquire'}->('invoke-web');
$main::TEST_NOW += 6;
$code{'models.gpu_lease.handler.tick'}->();
ok( ( $data{'models'}{'gpu_lease'}{'pending'}{'requester'} // '' ) eq
        'invoke-web',
    'expired holder no longer blocks the queued requester'
);
$code{'models.gpu_lease.handler.tick'}->();
ok( ( $data{'models'}{'gpu_lease'}{'holder'} // '' ) eq 'invoke-web',
    'dead holder needs no ack when vram verification proves the gpu free'
);

say ': 6. feature off preserves the old behavior';
reset_lease();
$data{'models'}{'cfg'}{'gpu_lease'}{'enabled'} = 'no';
ok( !$code{'models.gpu_lease.acquire'}->('coding'),
    'models refuses lease acquisition while disabled'
);
ok( $code{'coding.gpu_lease.gate'}->() == TRUE,
    'coding gpu gate is open while disabled'
);

say ': 7. models unreachable falls back to the memory-check path';
reset_lease();
$route_ok = 0;
ok( $code{'coding.gpu_lease.gate'}->() == UNKNOWN,
    'unroutable models returns UNKNOWN instead of blocking forever' );
ok( $data{'coding'}{'gpu_lease'}{'unavailable'},
    'temporary models-unavailable fallback is recorded'
);

say ': 8. local gpu claims refused while cpu claims continue';
reset_lease();
grant('invoke-web');
$data{'models'}{'task'}{'claimed'}        = {};
$data{'models'}{'cfg'}{'task_max_claims'} = 0;
$data{'models'}{'task'}{'local_models'}   = {
    'at'       => time,
    'ids'      => ['TESTID7:ABCDEFG'],
    'backends' => { 'TESTID7:ABCDEFG' => ['gpu'] },
};
ok( !$code{'models.task.claim-ok'}->('TESTID7:ABCDEFG'),
    'gpu-pinned task is refused while invoke-web holds the lease'
);
$data{'models'}{'task'}{'local_models'}{'backends'}
    = { 'TESTID7:ABCDEFG' => ['cpu'] };
ok( $code{'models.task.claim-ok'}->('TESTID7:ABCDEFG') == TRUE,
    'the same pin is accepted on cpu' );
$data{'models'}{'task'}{'local_models'}{'backends'}
    = { 'TESTID7:ABCDEFG' => [ 'gpu', 'cpu' ] };
ok( $code{'models.task.claim-ok'}->('') == TRUE,
    'unpinned work remains eligible with a cpu backend ready' );

say ': 9. coding spawn gate and evaluation gpu+cpu setup';
reset_lease();
$code{'coding.gpu_lease.gate'} = sub { return FALSE };
my $spawn_result = $code{'coding.spawn_inference_server'}
    ->( { 'backend' => 'gpu', 'model_path' => '' } );
ok( !$spawn_result->{'success'}
        && $spawn_result->{'error'} eq 'gpu lease held elsewhere',
    'central gpu spawn refuses while another holder owns the lease'
);

my @spawns;
$code{'coding.spawn_inference_server'} = sub {
    push @spawns, shift;
    return { 'success' => TRUE, 'pid' => 42000 + scalar @spawns };
};
$code{'dependency.ok_resolve'} = sub { return TRUE };
$code{'coding.helper.resolve_model_checksum'}
    = sub { return { 'amos_id' => '' } };
$data{'coding'} = {
    'awaiting_resources' => FALSE,
    'system_mem_pct'     => 0,
    'spawn_params'       => {
        'gpu_enabled' => 'yes',
        'cpu_enabled' => 'yes',
        'gpu_layers'  => 33,
        'cpu_threads' => 2,
    },
    'dep' => { 'spawn_ready_gpu' => 1, 'spawn_ready_cpu' => 1 },
};
$data{'inference'} = {
    'model'   => { 'path' => '/unused-gpu', 'amos_id' => '' },
    'backend' => {
        'gpu' => { 'port' => 8000 },
        'cpu' => { 'port' => 8001, 'path' => '/unused-cpu' },
    },
};
@spawns = ();
$code{'coding.async_spawn_inference_servers'}->();
ok( @spawns == 1 && $spawns[0]->{'backend'} eq 'cpu',
    'held gpu lease does not prevent the cpu evaluation backend'
);
$data{'models'}{'cfg'}{'gpu_lease'}{'enabled'} = 'no';
delete $data{'inference'}{'cpu_pid'};
@spawns = ();
$code{'coding.async_spawn_inference_servers'}->();
ok( @spawns == 2, 'feature off spawns both evaluation backends as before' );

say ': 10. invoke-web queue grace and real cache-empty api sequence';
reset_lease();
my ( $db_in_progress, $db_pending ) = ( 0, 0 );
my $db = bless {}, 'MockDB';
{

    package MockDB;
    sub selectrow_array { return ( $db_in_progress, $db_pending ) }
}
$data{'invoke_web'} = {};
$data{'invoke-web'} = {
    'status'    => 'running',
    'gpu_lease' => { 'holder' => 'invoke-web' },
};
$code{'invoke-web.queue.db'} = sub { return $db };
@timers = ();
$code{'invoke-web.gpu_lease.queue_changed'}->();
my ($grace) = grep {
    ( $ARG->{'handler'} // '' ) eq 'invoke-web.gpu_lease.handler.grace'
} @timers;
ok( defined $grace && $grace->{'after'} == 7,
    'empty queue arms the configurable release grace'
);
my $grace_watcher = MockWatcher->new( $grace->{'data'} // {} );
$data{'invoke-web'}{'gpu_lease'}{'grace_timer'} = $grace_watcher;
$db_pending                                     = 1;
$code{'invoke-web.gpu_lease.request'}           = sub { return TRUE };
$code{'invoke-web.gpu_lease.queue_changed'}->();
ok( !$grace_watcher->is_active, 'new render work cancels the grace release' );

my @api;
$code{'invoke-web.api_async'} = sub {
    push @api, [ @ARG[ 0, 1, 3 ] ];
    return TRUE;
};
@routes = ();
$data{'invoke-web'}{'gpu_lease'}{'holder'} = 'invoke-web';
$code{'invoke-web.gpu_lease.unload'}->( 'coding', 'handover' );
ok( @api == 1 && $api[0]->[1] eq '/api/v1/queue/default/processor/pause',
    'invoke-web pauses its queue before unloading' );
$code{'invoke-web.gpu_lease.handler.unload_pause_reply'}
    ->( { 'ok' => TRUE } );
ok( @api == 2
        && $api[1]->[0] eq 'POST'
        && $api[1]->[1] eq '/api/v2/models/empty_model_cache',
    'the installed invoke.ai cache-empty endpoint is called'
);
$code{'invoke-web.gpu_lease.handler.verify_unload'}
    ->( MockEvent->new( { 'attempt' => 1 } ) );
ok( scalar(
        grep {
                   $ARG->{'command'} eq 'models.gpu-lease-released'
                && $ARG->{'call_args'}{'args'} eq 'invoke-web coding'
        } @routes
    ),
    'invoke-web acknowledges only after verified vram release'
);

say ': 11. coding yield requeues gpu work only';
reset_lease();
@routes = ();
$data{'coding'} = {
    'gpu_lease'         => { 'holder' => 'coding' },
    'inference_servers' => {},
    'async'             => {
        'task_state' => {
            'GPUID7A' => { 'backend' => 'gpu' },
            'CPUID7A' => { 'backend' => 'cpu' },
        },
    },
    'task' => {
        'queue' => {
            'GPUID7A' => {},
            'CPUID7A' => {},
        },
    },
};
$code{'coding.async.state_machine'} = sub { return TRUE };
local $call = { 'args' => 'invoke-web' };
$code{'coding.cmd.gpu-lease-yield'}->();
my @released
    = grep { $ARG->{'command'} eq 'models.gpu-lease-release-task' } @routes;
ok( @released == 1 && $released[0]->{'call_args'}{'args'} eq 'GPUID7A',
    'only the running gpu task claim is handed back' );
ok( $data{'coding'}{'task'}{'queue'}{'GPUID7A'}{'pause_requested'}
        && !$data{'coding'}{'task'}{'queue'}{'CPUID7A'}{'pause_requested'},
    'gpu task pauses while cpu task state is untouched'
);
ok( $data{'coding'}{'gpu_lease'}{'dispatch_hold'},
    'local gpu dispatch is held until a later grant'
);
my $requeued = $code{'coding.task.enqueue'}->( { 'id' => 'GPUID7A' } );
ok( $requeued->{'success'} && $requeued->{'resumed'},
    'the requeued task resumes its paused '
        . 'context instead of failing as a duplicate'
);

say ': 12. disconnected peer is never woken for a yield';
reset_lease();
$code{'models.gpu_lease.acquire'}->('coding');
@routes = ();
presence( 'invoke-web', 'coding', FALSE );
ok( ( $data{'models'}{'gpu_lease'}{'holder'} // '' ) eq 'coding',
    'disconnected peer permits a vram-verified grant'
);
ok( !scalar(
        grep { $ARG->{'command'} eq 'invoke-web.gpu-lease-yield' } @routes
    ),
    'no on-demand yield route is sent to the disconnected zenka'
);
ok( ( $routes[0]->{'command'} // '' ) ne 'invoke-web.gpu-lease-yield',
    'presence lookup replaces the former direct yield first message'
);

say ': 13. WSL desktop allowance, requester need and llama occupancy';
reset_lease();
$code{'models.gpu_lease.acquire'}->( 'coding', 8000 );
ack( 'invoke-web', 'coding' );
ok( ( $data{'models'}{'gpu_lease'}{'holder'} // '' ) eq 'coding',
    '11051 of 12111 MB free passes despite 1060 MB desktop use'
);
$code{'models.gpu_lease.release'}->('coding');
$vram_ok = 2;
$code{'models.gpu_lease.acquire'}->( 'coding', 8000 );
ack( 'invoke-web', 'coding' );
ok( ( $data{'models'}{'gpu_lease'}{'holder'} // '' ) eq ''
        && $data{'models'}{'gpu_lease'}{'pending'}{'need_mb'} == 8000,
    'requester-specific 8000 MB requirement refuses insufficient vram'
);
$vram_ok    = 1;
@llama_pids = (4242);
$code{'models.gpu_lease.handler.tick'}->();
ok( ( $data{'models'}{'gpu_lease'}{'holder'} // '' ) eq '',
    'a remaining llama compute process blocks the grant'
);
@llama_pids = ();
$code{'models.gpu_lease.handler.tick'}->();
ok( ( $data{'models'}{'gpu_lease'}{'holder'} // '' ) eq 'coding',
    'grant proceeds when llama exits and required vram is free'
);

say ': 14. absent or stale backend status refuses claims during render';
reset_lease();
grant('invoke-web');
$data{'models'}{'task'}{'local_models'}
    = { 'at' => time, 'ids' => [], 'backends' => {} };
ok( !$code{'models.task.claim-ok'}->('TESTID7:ABCDEFG'),
    'pinned claim is refused when no backend id remains'
);
ok( !$code{'models.task.claim-ok'}->(''),
    'unpinned claim is refused when no cpu backend is known' );
$data{'models'}{'task'}{'local_models'} = {
    'at'       => time - 61,
    'ids'      => ['TESTID7:ABCDEFG'],
    'backends' => { 'TESTID7:ABCDEFG' => ['cpu'] },
};
ok( !$code{'models.task.claim-ok'}->('TESTID7:ABCDEFG'),
    'even a matching cpu backend is refused when its status is stale'
);

say ': 15. route grants are explicit and state alone is generally readable';
my $access_path
    = File::Spec->catfile( $main::root_path,
    qw| cfg zenki cube access.zenki | );
open my $access_fh, '<', $access_path or die $OS_ERROR;
my $access_text = join '', <$access_fh>;
close $access_fh;
for my $grant_text (
    'coding.gpu-lease-yield',        'coding.gpu-lease-granted',
    'invoke-web.gpu-lease-yield',    'invoke-web.gpu-lease-granted',
    'models.gpu-lease-acquire',      'models.gpu-lease-release',
    'models.gpu-lease-renew',        'models.gpu-lease-released',
    'models.gpu-lease-release-task', 'models.gpu-lease-state'
) {
    ok( $access_text =~ m|\Q$grant_text\E|,
        "route grant present : $grant_text"
    );
}
ok( $access_text !~ m|\*\.gpu-lease|,
    'no wildcard allows another zenka to kill a gpu server' );

say ': 16. one shared configuration and one gpu memory helper';
my $shared_path
    = File::Spec->catfile( $main::root_path, 'cfg/shared-params' );
open my $shared_fh, '<', $shared_path or die $OS_ERROR;
my $shared_text = join '', <$shared_fh>;
close $shared_fh;
ok( ( () = $shared_text =~ m|^models\.cfg\.gpu_lease\.enabled|mg ) == 1,
    'shared-params contains the single enabled setting' );
my $duplicates = 0;

for my $zenka (qw| models coding invoke-web |) {
    my $path = File::Spec->catfile( $main::root_path, qw| cfg zenki |,
        $zenka, 'zenka.v7' );
    open my $fh, '<', $path or die $OS_ERROR;
    my $text = join '', <$fh>;
    close $fh;
    $duplicates++ if $text =~ m|^models\.cfg\.gpu_lease\.enabled|m;
}
ok( !$duplicates, 'no per-zenka enabled copy can drift' );
ok( !-e File::Spec->catfile(
        $main::root_path, 'src/models.gpu_lease.query_gpu_memory'
    ),
    'lease reuses base.gpu.query_memory instead of a duplicate'
);

say ': 17. yield cancels switches, self-tests, sweeps and spawn guard';
reset_lease();
my $switch_timer = MockWatcher->new( {} );
my $probe_timer  = MockWatcher->new( {} );
my $fit_timer    = MockWatcher->new( {} );
my @switch_done;
$code{'test.switch_done'} = sub { push @switch_done, shift };
$data{'coding'}           = {
    'spawning_in_progress' => TRUE,
    'switch_model_active'  => TRUE,
    'timer'                => { 'gpu_fit_recheck' => $fit_timer },
    'pending_switch'       => {
        'gpu' => {
            'timer_w' => $switch_timer,
            'on_done' => {
                'handler' => 'test.switch_done',
                'params'  => {}
            },
        },
    },
    'switching_backend'         => { 'gpu' => TRUE },
    'self_test_probe_in_flight' => { 'gpu' => TRUE },
    'self_test_probe_state'     => {
        'probe1' => {
            'backend'   => 'gpu',
            'timer'     => $probe_timer,
            'in_flight' => FALSE,
        },
    },
    'self_test_switch_state' => { 'switch1' => { 'backend' => 'gpu' }, },
    'self_test_switch_in_progress' => TRUE,
    'model_sweep_state'            => { 'gpu' => { 'state' => 'running' } },
};
$code{'coding.gpu_lease.cancel_activity'}->();
ok( !$data{'coding'}{'spawning_in_progress'},
    'yield clears spawning_in_progress'
);
ok( !$fit_timer->is_active
        && !$switch_timer->is_active
        && !$probe_timer->is_active,
    'fit, pending-switch and self-test watchers are cancelled'
);
ok( @switch_done == 1 && !$switch_done[0]->{'spawn_result'},
    'pending switch receives a terminal failure instead of respawning'
);
ok( !exists $data{'coding'}{'self_test_probe_state'}{'probe1'}
        && !exists $data{'coding'}{'self_test_switch_state'}{'switch1'},
    'gpu self-test state is removed before its server dies'
);
ok( $data{'coding'}{'model_sweep_state'}{'gpu'}{'state'} eq 'paused',
    'model sweep is paused during the lease handover' );

say ': 18. lease retry logging is quiet';
$data{'coding'} = {
    'gpu_lease' => { 'dispatch_hold' => TRUE },
    'task'      => { 'queue'         => { 'GPUID7A' => {} } },
};
$code{'coding.helper.task_backend'} = sub { return 'gpu' };
$code{'coding.async.state_machine'}
    = sub { return { 'round' => 0, 'backend' => 'gpu' } };
$code{'coding.async.backend_release'} = sub { return TRUE };
$code{'coding.async.lock_token'}      = sub { return 1 };
@logs                                 = ();
$code{'coding.async.send_request'}->('GPUID7A');
ok( @logs && !scalar( grep { ( $ARG->[0] // 0 ) < 2 } @logs ),
    'five-second lease rescheduling logs only at level 2'
);

say ': reply contract : every lease command returns mode and data';
foreach my $file ( glob "$main::root_path/src/*.cmd.gpu-lease-*" ) {
    open my $fh, qw| < |, $file or die "$file : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR;
    my $src = <$fh>;
    close $fh;
    my @returns = $src =~ m{return\s*\{\s*('mode'.*?)\}}sg;
    ok( @returns && !grep( { !m{'data'} or m{'data'\s*=>\s*''} } @returns ),
        "$file : reply has data" );
}

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,,.,,.,,,,.,,..,,.,,...,,,,,,,.,,,,,,.,,.,,,..,,...,.,.,...,,..,..,,..,,..,,
#NT5ETJHD2G5ZE4Q2Z57KQSTQZSKK457MHF4DRC5GKO5VRR7W7MK5YIIZYTGF4MZWJKZPHYBGKK3QC
#\\\|XKA3IP5B335XDNUDBZWFCWB5JTZFMT5XT3LQWU7ZG4FSUQYU5FH \ / AMOS7 \ YOURUM ::
#\[7]7SMPQ3KP2HLBNOTNY6VHZZ52Y54WNSZWM2ATWYQYLLHNB47CVCCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
