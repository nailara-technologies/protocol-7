#!/usr/bin/perl
use v5.24;
use strict;
use warnings;
use English;

###                                       ###
## model pin swap : standalone regression  ##
###                                       ###

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
use YAML::XS                  qw| Load |;

use constant TRUE    => 5;
use constant FALSE   => 0;
use constant UNKNOWN => 2;

our %data;
our %code;
our $call = {};

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

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

my $available = TRUE;
my $log_count = 0;
$code{'base.cfg_bool'} = sub {
    my $value = shift // FALSE;
    return FALSE if $value =~ m{^(0|no?|false|off)$}i;
    return TRUE;
};
$code{'base.logs'} = sub {
    my ( $level, $format ) = @ARG;
    $log_count++
        if $level == 1 and $format =~ m{not loaded : swap accepted};
    return TRUE;
};
$code{'models.registry.lookup'}
    = sub { return $available ? { 'file_path' => '/model.gguf' } : undef };

compile_module('models.task.pin-accepted');
compile_module('models.task.claim-ok');
compile_module('models.task.set-local-models');

sub reset_pin_state {
    $data{'models'}{'cfg'}{'task_swap'}      = TRUE;
    $data{'models'}{'cfg'}{'task_swap_idle'} = 1800;
    $data{'models'}{'cfg'}{'task_models'}    = '';
    $data{'models'}{'task'}{'local_models'}  = {
        'at'        => time,
        'ids'       => ['AAAAAAA:BBBBBBB'],
        'idle_secs' => 2000,
    };
    $data{'models'}{'task'}{'swap_accepted'}  = {};
    $data{'models'}{'task'}{'claimed'}        = {};
    $data{'models'}{'cfg'}{'task_max_claims'} = '';
    $available                                = TRUE;
    $log_count                                = 0;
    return;
}

say ': 1. loaded and idle swap decisions';
reset_pin_state();
ok( $code{'models.task.pin-accepted'}->(':BBBBBBB') == TRUE,
    'loaded content match is accepted' );
ok( $code{'models.task.pin-accepted'}->(':CCCCCCC') == TRUE,
    'idle available pin is swap-accepted' );
$code{'models.task.pin-accepted'}->(':CCCCCCC');
ok( $log_count == 1, 'an accepted swap is logged only once' );

reset_pin_state();
$data{'models'}{'task'}{'local_models'}{'idle_secs'} = 100;
ok( $code{'models.task.pin-accepted'}->(':CCCCCCC') == FALSE,
    'idle below the threshold is refused' );

reset_pin_state();
$data{'models'}{'task'}{'local_models'}{'idle_secs'} = undef;
ok( $code{'models.task.pin-accepted'}->(':CCCCCCC') == UNKNOWN,
    'unknown idle time returns unknown' );

reset_pin_state();
$data{'models'}{'cfg'}{'task_swap'} = FALSE;
ok( $code{'models.task.pin-accepted'}->(':CCCCCCC') == FALSE,
    'disabled swapping keeps the loaded-only behavior'
);

reset_pin_state();
$available = FALSE;
ok( $code{'models.task.pin-accepted'}->(':CCCCCCC') == FALSE,
    'a pin without a local registry entry is refused'
);

reset_pin_state();
$data{'models'}{'cfg'}{'task_models'} = 'AAAAAAA:BBBBBBB';
ok( $code{'models.task.pin-accepted'}->(':CCCCCCC') == FALSE,
    'explicit task models disable swapping' );

say ': 2. swap acceptance retains default claim capacity';
reset_pin_state();
ok( $code{'models.task.pin-accepted'}->(':CCCCCCC') == TRUE
        && $code{'models.task.claim-ok'}->(':CCCCCCC') == TRUE,
    'a swap-accepted pin receives a ready-backend slot'
);
$data{'models'}{'task'}{'claimed'}{'task-1'} = time;
ok( $code{'models.task.claim-ok'}->(':CCCCCCC') == FALSE,
    'the swap slot still counts in-flight claims'
);

say ': 3. status caching keeps the smallest backend idle time';
my $ids
    = $code{'models.task.set-local-models'}
    ->(   "gpu:\n  model_id: AAAAAAA:BBBBBBB\n  idle_secs: 2000\ncpu:\n "
        . " model_id: AAAAAAA:DDDDDDD\n  idle_secs: 900\n" );
ok( scalar( @{$ids} ) == 2
        && $data{'models'}{'task'}{'local_models'}{'idle_secs'} == 900,
    'the conservative cache uses the smallest backend idle time'
);

say ': 4. request completion and status use the epoch clock';
my $clock_now = 100000;
$code{'base.time'} = sub {
    my ($precision) = @ARG;
    return $precision == 3 ? $clock_now + 0.25 : $clock_now;
};
$code{'base.ntime'}                 = sub { return 3234362257055 };
$code{'coding.async.state_manager'} = sub {
    return {
        'backend'         => 'gpu',
        'request_seq'     => 7,
        'state'           => 'complete',
        'timeout_ceiling' => 10,
    };
};
$code{'coding.async.backend_release'} = sub { return TRUE };
$code{'coding.async.lock_token'}      = sub { return 'token' };
compile_module('coding.callback.http_complete');
$code{'coding.callback.http_complete'}
    ->( 'task-clock', { 'bytes_received' => 1, 'chunks_received' => 1 }, 7 );
ok( $data{'coding'}{'model_last_used'}{'gpu'} == 100000,
    'http completion stamps base.time, not base.ntime'
);

$code{'coding.async.state_manager'} = sub {
    return {
        'backend'       => 'cpu',
        'request_seq'   => 8,
        'retry_pending' => TRUE,
    };
};
compile_module('coding.callback.http_error');
$code{'coding.callback.http_error'}->( 'task-clock', 'HTTP error: 500', 8 );
ok( $data{'coding'}{'model_last_used'}{'cpu'} == 100000,
    'http errors stamp the same epoch clock'
);

$data{'coding'}{'inference_servers'} = {
    'gpu' => { 'model' => 'AAAAAAA:BBBBBBB', 'status' => 'ready' },
    'cpu' => { 'model' => 'AAAAAAA:DDDDDDD', 'status' => 'ready' },
};
$data{'coding'}{'model_last_used'}{'gpu'} = 98000;
delete $data{'coding'}{'model_last_used'}{'cpu'};
$data{'coding'}{'vram_status_cache'} = {
    'at'       => 100000,
    'used_mb'  => 1,
    'total_mb' => 2
};
$code{'coding.helper.query_gpu_memory'}
    = sub { return { 'ok' => TRUE, 'free_mb' => 1, 'total_mb' => 2 } };
compile_module('coding.cmd.inference-status');
my $reply  = $code{'coding.cmd.inference-status'}->();
my $status = Load( $reply->{'data'} );
$clock_now = 101000;
$reply     = $code{'coding.cmd.inference-status'}->();
$status    = Load( $reply->{'data'} );
ok( $status->{'gpu'}{'idle_secs'} == 3000
        && $status->{'cpu'}{'idle_secs'} eq '',
    'inference status reports elapsed and unknown backend idle times'
);

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,,.,,,,,,,.,.,.,,..,...,..,,.,.,.,.,,,,,...,..,,...,...,..,,,.,,..,,...,..,,
#WKCL336WBKLY7SQPLSGPDUK3RX7YPLDJZV4IFMAB7AKDT7M6NG4SWSHLVZ7HHSF7SY7DG4AIPF5HE
#\\\|TA7QVKJ45X36UXRQRKQ37KX6PRDDHFB446ORJ2IJFEUSAC2H4HN \ / AMOS7 \ YOURUM ::
#\[7]LB75N57ZQMXZTR2XZR6MFYR4FKCJMJHRTPPCF2UXATWW5BDW4IAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
