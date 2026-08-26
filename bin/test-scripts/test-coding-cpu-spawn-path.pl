#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                                  ###
## coding cpu-only startup spawn path : standalone acceptance harness ##
###                                                                  ###

## exercises the real translated module sources against an in-process %data ##
## / %code stub environment -- no live coding zenka required.  covers the   ##
## per-backend extension of the model-path dependency gating [ gpu-only     ##
## landed 2026-08-26, cpu added on top ] : independent spawn_precondition   ##
## roots per backend, per-backend in-flight guards, backend tagging of      ##
## cube.models.get_path_by_amos replies, and the symmetric gpu/cpu spawn    ##
## blocks in coding.async_spawn_inference_servers                           ##

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

my @send_calls;    ## records every cube.models.get_path_by_amos attempt ##
my $NEXT_ID = 1;

## mutable debounce delta : 0 = resolve hook debounced after first fire, >= ##
## min_interval [ 5 ] = resolve hook fires again, so the per-backend        ##
## in-flight guard [ not the generic debounce ] is what blocks resends      ##
my $ntime_delta = 0;

%code = (
    'base.log'    => sub { return TRUE },
    'base.logs'   => sub { return TRUE },
    'base.gen_id' => sub {
        my $href = shift;
        my $id;
        do { $id = $NEXT_ID++ } while exists $href->{$id};
        return $id;
    },
    'base.ntime' => sub { return 1000 },    ## constant : no time passes ##
    'base.ntime.delta_seconds'      => sub { return $ntime_delta },
    'base.str.eval_error'           => sub { return "$EVAL_ERROR" },
    'protocol-7.command.send.local' => sub {
        my $args = shift;
        push @send_calls, $args;
        return 1;    ## 1 client reached, matches the real success case ##
    },
);

## shared single-model config only : cpu has NO backend-scoped amos_id, ##
## exercising the fallback to <inference.model.amos_id>                 ##
$data{'inference'}{'model'}{'amos_id'} = 'TESTID7:ABCDEFG';

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

compile_module($_) foreach qw|
    base.dependency.setup
    base.dependency.add_object
    base.dependency.add
    base.dependency.ok
    base.dependency.install_callbacks
    coding.callback.object.model_path
    coding.resolve.object.model_path
    coding.resolve_model_path
    |;

## real runtime aliases : short forms used by translated sources ##
$code{'dependency.setup'}      = $code{'base.dependency.setup'};
$code{'dependency.ok'}         = $code{'base.dependency.ok'};
$code{'dependency.add'}        = $code{'base.dependency.add'};
$code{'dependency.add_object'} = $code{'base.dependency.add_object'};

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

say ': setup -- two independent spawn_precondition roots';

## mirrors coding.init_dependencies' gpu/cpu pairs exactly : each backend ##
## gets its own model_path object plus a spawn_precondition root that     ##
## DEPENDS ON it [ dependency.ok(X) only checks X's OWN chain members ]   ##
$code{'base.dependency.setup'}->(
    'model_path',
    {   'callback' => $code{'coding.callback.object.model_path'},
        'resolve'  => $code{'coding.resolve.object.model_path'},
    }
);

my $obj_gpu = $code{'base.dependency.add_object'}
    ->( { 'type' => 'model_path', 'backend' => 'gpu' } );
my $root_gpu = $code{'base.dependency.add_object'}
    ->( { 'type' => 'spawn_precondition', 'backend' => 'gpu' } );
$code{'base.dependency.add'}->( $root_gpu, $obj_gpu );

my $obj_cpu = $code{'base.dependency.add_object'}
    ->( { 'type' => 'model_path', 'backend' => 'cpu' } );
my $root_cpu = $code{'base.dependency.add_object'}
    ->( { 'type' => 'spawn_precondition', 'backend' => 'cpu' } );
$code{'base.dependency.add'}->( $root_cpu, $obj_cpu );

ok( $root_gpu != $root_cpu and $obj_gpu != $obj_cpu,
    'two independent root/object pairs created'
);

say ': 1. both backends unresolved initially';

## checked via the callbacks directly : dependency.ok would already fire ##
## the resolve hook, which is test 2's job                               ##
ok( ( not $code{'coding.callback.object.model_path'}->($obj_gpu) ),
    'gpu callback FALSE when <inference.model.path> is unset'
);
ok( ( not $code{'coding.callback.object.model_path'}->($obj_cpu) ),
    'cpu callback FALSE when <inference.backend.cpu.path> is unset'
);

say ': 2. triggering dependency.ok(root_cpu) fires exactly one cpu send';

my $ok_cpu_1 = $code{'base.dependency.ok'}->($root_cpu);
ok( ( not $ok_cpu_1 ), 'dependency.ok(root_cpu) FALSE [ unresolved ]' );
ok( scalar(@send_calls) == 1, 'exactly one send fired' );
ok( ( $send_calls[0]->{'reply'}->{'params'}->{'backend'} // '' ) eq 'cpu',
    'send carries backend=cpu in reply params' );
ok( ( $data{'coding'}{'model_path_request_in_flight'}{'cpu'} ? 1 : 0 ) == 1,
    'cpu in-flight guard set' );
ok( ( $data{'coding'}{'model_path_request_in_flight'}{'gpu'} ? 1 : 0 ) == 0,
    'gpu in-flight guard NOT set by the cpu send' );

say ': 3. triggering dependency.ok(root_gpu) fires its own gpu send';

my $ok_gpu_1 = $code{'base.dependency.ok'}->($root_gpu);
ok( ( not $ok_gpu_1 ), 'dependency.ok(root_gpu) FALSE [ unresolved ]' );
ok( scalar(@send_calls) == 2, 'second send fired [ 2 total ]' );
ok( ( $send_calls[1]->{'reply'}->{'params'}->{'backend'} // '' ) eq 'gpu',
    'second send carries backend=gpu in reply params' );
ok( ( $data{'coding'}{'model_path_request_in_flight'}{'gpu'} ? 1 : 0 ) == 1,
    'gpu in-flight guard now set independently' );

say ': 4. re-checking either backend while in-flight sends nothing new';

## defeat the generic debounce deliberately : the per-backend in-flight ##
## guard in coding.resolve_model_path must be what blocks these resends ##
$ntime_delta = 10;
$code{'base.dependency.ok'}->($root_cpu);
$code{'base.dependency.ok'}->($root_gpu);
ok( scalar(@send_calls) == 2,
    'still 2 total sends [ per-backend in-flight guards hold ]' );
$ntime_delta = 0;

say ': 5. cpu reply resolves cpu only';

## simulates coding.handler.model_path_reply's per-backend success path  ##
$data{'inference'}{'backend'}{'cpu'}{'path'} = '/mnt/models/test-cpu.gguf';
$data{'coding'}{'model_path_request_in_flight'}{'cpu'} = FALSE;

ok( $code{'coding.callback.object.model_path'}->($obj_cpu),
    'cpu callback TRUE once <inference.backend.cpu.path> is set'
);
ok( $code{'base.dependency.ok'}->($root_cpu),
    'dependency.ok(root_cpu) now TRUE'
);
ok( ( not $code{'coding.callback.object.model_path'}->($obj_gpu) ),
    'gpu callback still FALSE [ cpu reply did not touch gpu state ]'
);
ok( ( not $code{'base.dependency.ok'}->($root_gpu) ),
    'dependency.ok(root_gpu) still FALSE'
);
ok( scalar(@send_calls) == 2,
    'no resend [ gpu guard still set, cpu side resolved ]' );

say ': 6. gpu reply resolves gpu without affecting cpu';

$data{'inference'}{'model'}{'path'} = '/mnt/models/test-gpu.gguf';
$data{'coding'}{'model_path_request_in_flight'}{'gpu'} = FALSE;

ok( $code{'coding.callback.object.model_path'}->($obj_gpu),
    'gpu callback TRUE once <inference.model.path> is set'
);
ok( $code{'base.dependency.ok'}->($root_gpu),
    'dependency.ok(root_gpu) now TRUE'
);
ok( $code{'base.dependency.ok'}->($root_cpu),
    'dependency.ok(root_cpu) still TRUE [ unaffected ]'
);

say ': 7. clearing both paths lets both resolve again [ guards not stuck ]';

delete $data{'inference'}{'backend'}{'cpu'}{'path'};
delete $data{'inference'}{'model'}{'path'};

my $r_cpu = $code{'coding.resolve_model_path'}->('cpu');
my $r_gpu = $code{'coding.resolve_model_path'}->('gpu');
ok( $r_cpu and $r_gpu,        'both fresh resolve calls succeed' );
ok( scalar(@send_calls) == 4, 'exactly 2 new sends [ 4 total ]' );
ok( ( $send_calls[2]->{'reply'}->{'params'}->{'backend'} // '' ) eq 'cpu',
    'third send is cpu' );
ok( ( $send_calls[3]->{'reply'}->{'params'}->{'backend'} // '' ) eq 'gpu',
    'fourth send is gpu' );

say ': 8. sub-harness : async_spawn_inference_servers spawn blocks';

my @spawn_calls;    ## records coding.spawn_inference_server calls ##
my @timer_calls;    ## records event.add_timer calls ##

my $spawn_should_fail = 0;
$code{'coding.spawn_inference_server'} = sub {
    my $params = shift;
    push @spawn_calls, $params;
    return { 'success' => FALSE, 'error' => 'mock spawn failure' }
        if $spawn_should_fail;
    return { 'success' => TRUE, 'pid' => 42000 + scalar @spawn_calls };
};
$code{'event.add_timer'} = sub {
    my $timer = shift;
    push @timer_calls, $timer;
    return 1;
};

compile_module('coding.async_spawn_inference_servers');

## fresh spawn-facing state : both backends enabled + resolved ##
$data{'coding'}{'awaiting_resources'}        = FALSE;
$data{'coding'}{'system_mem_pct'}            = 0;
$data{'inference'}{'model'}{'path'}          = '/mnt/models/test-gpu.gguf';
$data{'inference'}{'model'}{'mmproj_path'}   = '';
$data{'inference'}{'backend'}{'cpu'}{'path'} = '/mnt/models/test-cpu.gguf';
$data{'inference'}{'backend'}{'gpu'}{'port'} = 8000;
$data{'inference'}{'backend'}{'cpu'}{'port'} = 8001;
$data{'coding'}{'dep'}{'spawn_ready_gpu'}    = $root_gpu;
$data{'coding'}{'dep'}{'spawn_ready_cpu'}    = $root_cpu;
$data{'coding'}{'spawn_params'}              = {
    'gpu_enabled'  => TRUE,
    'cpu_enabled'  => TRUE,
    'gpu_model_id' => 'test-gpu-model',
    'gpu_binary'   => '/bin/test-llama-gpu',
    'gpu_layers'   => 33,
    'cpu_binary'   => '/bin/test-llama-cpu',
    'cpu_threads'  => 7,
};
delete $data{'inference'}{'gpu_pid'};
delete $data{'inference'}{'cpu_pid'};
delete $data{'coding'}{'spawn_retry_count_gpu'};
delete $data{'coding'}{'spawn_retry_count_cpu'};

say ': 8a. both backends enabled + resolved : two spawn calls';

my $spawn_ok = $code{'coding.async_spawn_inference_servers'}->();
ok( $spawn_ok,                 'returns TRUE when both spawned' );
ok( scalar(@spawn_calls) == 2, 'exactly two spawn calls recorded' );

my ( $gpu_call, $cpu_call ) = @spawn_calls;
ok( ( $gpu_call->{'backend'}    // '' ) eq 'gpu', 'first call is gpu' );
ok( ( $gpu_call->{'port'}       // 0 ) == 8000,   'gpu port 8000' );
ok( ( $gpu_call->{'model_path'} // '' ) eq '/mnt/models/test-gpu.gguf',
    'gpu model_path from <inference.model.path>' );
ok( ( $gpu_call->{'gpu_layers'} // 0 ) == 33, 'gpu_layers passed' );
ok( ( $gpu_call->{'binary'}     // '' ) eq '/bin/test-llama-gpu',
    'gpu binary from spawn_params' );
ok( ( not exists $gpu_call->{'threads'} ),
    'gpu call has no threads param [ gpu-only shape ]' );

ok( ( $cpu_call->{'backend'}    // '' ) eq 'cpu', 'second call is cpu' );
ok( ( $cpu_call->{'port'}       // 0 ) == 8001,   'cpu port 8001' );
ok( ( $cpu_call->{'model_path'} // '' ) eq '/mnt/models/test-cpu.gguf',
    'cpu model_path from <inference.backend.cpu.path>' );
ok( ( $cpu_call->{'threads'} // 0 ) == 7, 'cpu threads 7' );
ok( ( $cpu_call->{'binary'}  // '' ) eq '/bin/test-llama-cpu',
    'cpu binary from spawn_params' );
ok(
    (           not exists $cpu_call->{'gpu_layers'}
            and not exists $cpu_call->{'mmproj_path'}
    ),
    'cpu call has no gpu_layers/mmproj_path [ cpu-only shape ]'
);

ok( ( $data{'inference'}{'gpu_pid'} // 0 ) == 42001, 'gpu_pid recorded' );
ok( ( $data{'inference'}{'cpu_pid'} // 0 ) == 42002, 'cpu_pid recorded' );
ok( ( $data{'coding'}{'spawn_retry_count_gpu'} // -1 ) == 0,
    'gpu retry counter reset' );
ok( ( $data{'coding'}{'spawn_retry_count_cpu'} // -1 ) == 0,
    'cpu retry counter reset' );

say ': 8b. only cpu enabled : only the cpu call fires';

@spawn_calls = ();
@timer_calls = ();
delete $data{'inference'}{'gpu_pid'};
delete $data{'inference'}{'cpu_pid'};
$data{'coding'}{'spawn_params'}{'gpu_enabled'} = FALSE;

$code{'coding.async_spawn_inference_servers'}->();
ok( scalar(@spawn_calls) == 1, 'exactly one spawn call' );
ok( ( $spawn_calls[0]->{'backend'} // '' ) eq 'cpu', 'it is the cpu call' );

say ': 8c. only gpu enabled : only the gpu call fires';

@spawn_calls = ();
delete $data{'inference'}{'cpu_pid'};
$data{'coding'}{'spawn_params'}{'gpu_enabled'} = TRUE;
$data{'coding'}{'spawn_params'}{'cpu_enabled'} = FALSE;

$code{'coding.async_spawn_inference_servers'}->();
ok( scalar(@spawn_calls) == 1, 'exactly one spawn call' );
ok( ( $spawn_calls[0]->{'backend'} // '' ) eq 'gpu', 'it is the gpu call' );

say ': 8d. failed gpu spawn : per-backend retry counter + backoff timer';

@spawn_calls = ();
@timer_calls = ();
delete $data{'inference'}{'gpu_pid'};
delete $data{'coding'}{'spawn_retry_count_gpu'};
$spawn_should_fail = 1;

my $fail_ok = $code{'coding.async_spawn_inference_servers'}->();
ok( ( not $fail_ok ), 'returns FALSE on failed spawn' );
ok( ( $data{'coding'}{'spawn_retry_count_gpu'} // -1 ) == 1,
    'gpu retry counter incremented to 1' );
ok( ( $data{'coding'}{'spawn_retry_count_cpu'} // 0 ) == 0,
    'cpu retry counter untouched by gpu failure'
);
ok( scalar(@timer_calls) == 1,                'one backoff timer scheduled' );
ok( ( $timer_calls[0]->{'after'} // 0 ) == 1, 'first backoff is 2**0 = 1s' );
ok( ( $timer_calls[0]->{'handler'} // '' ) eq
        'coding.handler.spawn_servers_deferred',
    'backoff timer re-enters via spawn_servers_deferred'
);

$code{'coding.async_spawn_inference_servers'}->();
ok( ( $data{'coding'}{'spawn_retry_count_gpu'} // -1 ) == 2,
    'second failure increments gpu counter to 2'
);
ok( ( $timer_calls[1]->{'after'} // 0 ) == 2, 'second backoff is 2**1 = 2s' );

say ': 8e. failed cpu spawn : cpu retry counter, gpu counter untouched';

@spawn_calls                                   = ();
@timer_calls                                   = ();
$data{'coding'}{'spawn_params'}{'gpu_enabled'} = FALSE;
$data{'coding'}{'spawn_params'}{'cpu_enabled'} = TRUE;
delete $data{'inference'}{'cpu_pid'};
delete $data{'coding'}{'spawn_retry_count_cpu'};

$code{'coding.async_spawn_inference_servers'}->();
ok( ( $data{'coding'}{'spawn_retry_count_cpu'} // -1 ) == 1,
    'cpu retry counter incremented to 1' );
ok( ( $data{'coding'}{'spawn_retry_count_gpu'} // 0 ) == 2,
    'gpu retry counter untouched by cpu failure'
);
ok( scalar(@timer_calls) == 1, 'cpu backoff timer scheduled' );

$spawn_should_fail = 0;

say ': 8f. blocks independent : gpu already up, cpu unresolved';

@spawn_calls = ();
$data{'coding'}{'spawn_params'}{'gpu_enabled'} = TRUE;
$data{'inference'}{'gpu_pid'} = 42001;    ## gpu already running ##
delete $data{'inference'}{'backend'}{'cpu'}{'path'};
delete $data{'inference'}{'model'}{'path'};
delete $data{'inference'}{'cpu_pid'};

my $mixed_ok = $code{'coding.async_spawn_inference_servers'}->();
ok( scalar(@spawn_calls) == 0,
    'no spawn calls [ gpu no-ops on its own pid, cpu defers ]' );
ok( ( not $mixed_ok ), 'returns FALSE while cpu still unresolved' );

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,,.,,,.,...,,,,,,,,,,,,,,,.,...,,.,,.,,,.,.,..,,...,..,,,,.,,,,,,.,,,.,,.,,,
#MAGPX2TEC4BP7X6USMLLFA2ESVFT724POQ7KNXA3ZW3JUBVFUUQIZD6CRDEBEJRFUOAAXIHE44V7Q
#\\\|UQZBWQVZX3KTWFENHT7LLQDUCFM22NTDRBBXC3NDCYR2TC3SPKU \ / AMOS7 \ YOURUM ::
#\[7]LRQYD2WJY6WO27PTV2QDZ5KAQUQJWHZ62NZ72TRI2ID2JJ5XPQCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
