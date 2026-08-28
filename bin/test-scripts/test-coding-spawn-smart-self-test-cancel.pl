#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                                        ###
## spawn_smart self-test cancellation harness [ task JEG ]                 ##
###                                                                        ###

## exercises the real translated source of coding.handler.spawn_smart +     ##
## coding.async.http_cleanup + coding.async.backend_release directly [      ##
## spawn_smart is a plain function call, no event/timer stubbing needed ].  ##
## covers the fix : force=1 respawn now cancels any in-flight self-test on  ##
## the target backend BEFORE killing its server, instead of leaving the     ##
## guard/lock dangling with nothing telling the probe's own pipeline. every ##
## scenario deliberately fails the memory check right after [ real          ##
## /proc/meminfo read, backend=cpu, an absurdly large model size guarantees ##
## insufficient memory on any machine ] so the test terminates cleanly      ##
## right past the code under test without needing to stub actual process    ##
## spawning at all                                                          ##

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

my @waitpid_calls;
my @http_cleanup_calls;

%code = (
    'base.logs'    => sub { return TRUE },
    'base.waitpid' => sub { push @waitpid_calls, shift; return },
    'coding.spawn_inference_server' =>
        sub { return { mode => qw| false |, data => 'not reached' } },
);

## huge, guaranteeing "insufficient memory" on any real machine's actual ##
## free RAM, so a cpu-backend call always returns FALSE right after the  ##
## code under test runs, without ever reaching real process-spawn logic  ##
$data{'coding'}{'model_metadata'}{'test-model'} = {
    'amos'    => qw| TESTMD5X:CHKSUMXY |,
    'size_gb' => 999_999_999,
};
$data{'inference'}{'backend'}{'cpu'}{'model_id'} = qw| test-model |;

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

compile_module('coding.async.http_cleanup');
compile_module('coding.async.backend_release');
compile_module('coding.handler.spawn_smart');

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

## fresh streaming-request state, same shape coding.async.http_client makes ##
sub mk_http_state {
    my ($on_error_fired) = @ARG;
    return {
        'chunks_received' => 12,
        'completed'       => FALSE,
        'callbacks'       => {
            'backend'  => qw| cpu |,
            'on_error' => sub { ${$on_error_fired} = TRUE; return },
        },
    };
}

sub reset_state {
    delete $data{'coding'}{'self_test_probe_state'};
    delete $data{'coding'}{'self_test_probe_in_flight'};
    delete $data{'coding'}{'state'}{'backend'};
    delete $data{'coding'}{'inference_servers'};
    @waitpid_calls = ();
    return;
}

sub call_spawn_smart {
    return $code{'coding.handler.spawn_smart'}
        ->( { backend => qw| cpu |, force => 1 } );
}

##[ 1. genuinely in-flight, alive probe : cancelled through its own pipe ]###

say ': 1. force respawn cancels a genuinely in-flight self-test probe';
{
    reset_state();
    my $on_error_fired = FALSE;
    my $http_state     = mk_http_state( \$on_error_fired );

    $data{'coding'}{'self_test_probe_in_flight'}{'cpu'} = TRUE;
    $data{'coding'}{'self_test_probe_state'}{'PROBE1'}  = {
        'backend'    => qw| cpu |,
        'in_flight'  => TRUE,
        'http_state' => $http_state,
    };
    $data{'coding'}{'state'}{'backend'}{'cpu'}{'lock'} = qw| PROBE1 |;

    call_spawn_smart();

    ok( $on_error_fired,
              'probe on_error callback fired [ real '
            . 'cancellation, not silent deletion ]' );
    ok( !defined $data{'coding'}{'self_test_probe_state'}{'PROBE1'},
        'probe state entry removed' );
    ok( !$data{'coding'}{'self_test_probe_in_flight'}{'cpu'},
        'in-flight guard cleared' );
    ok( ( $data{'coding'}{'state'}{'backend'}{'cpu'}{'lock'} // '' ) eq '',
        'backend lock released' );
}

##[ 2. stale guard, no matching probe state : cleared defensively ]###########

say ': 2. stale guard with no matching probe state : cleared, no error';
{
    reset_state();
    $data{'coding'}{'self_test_probe_in_flight'}{'cpu'} = TRUE;

    my $result = eval { call_spawn_smart(); 1 };
    ok( $result, 'call completes without dying on a stale guard' );
    ok( !$data{'coding'}{'self_test_probe_in_flight'}{'cpu'},
        'stale guard cleared defensively' );
}

##[ 3. no self-test in flight at all : new block is a complete no-op ]########

say ': 3. no self-test in flight : unchanged from before the fix';
{
    reset_state();
    ## deliberately not setting self_test_probe_in_flight at all ##

    my $result = eval { call_spawn_smart(); 1 };
    ok( $result, 'call completes normally with no guard set at all' );
    ok( !exists $data{'coding'}{'self_test_probe_in_flight'}{'cpu'},
        'guard was never touched -- nothing to clear' );
}

##[ 4. probe exists for this backend but is NOT in_flight : still cleared ]##

say ': 4. probe state exists but not in_flight [ eg record '
    . 'phase ] : guard still cleared, no cancel attempted';
{
    reset_state();
    my $on_error_fired = FALSE;
    my $http_state     = mk_http_state( \$on_error_fired );

    $data{'coding'}{'self_test_probe_in_flight'}{'cpu'} = TRUE;
    $data{'coding'}{'self_test_probe_state'}{'PROBE2'}  = {
        'backend'    => qw| cpu |,
        'in_flight'  => FALSE,      ## eg between prompts, doing local work ##
        'http_state' => $http_state,
    };

    call_spawn_smart();

    ok( !$on_error_fired,
        'not in_flight : no cancellation attempted through the pipeline' );
    ok( !defined $data{'coding'}{'self_test_probe_state'}{'PROBE2'},
        'probe state entry still removed [ '
            . 'server is being killed regardless ]'
    );
    ok( !$data{'coding'}{'self_test_probe_in_flight'}{'cpu'},
        'in-flight guard cleared' );
}

##[ 5. a probe on a DIFFERENT backend is untouched ]##########################

say ': 5. a probe on a different backend is left completely alone';
{
    reset_state();
    my $on_error_fired = FALSE;
    my $http_state     = mk_http_state( \$on_error_fired );

    ## gpu has its own in-flight probe ; this call targets cpu only ##
    $data{'coding'}{'self_test_probe_in_flight'}{'gpu'} = TRUE;
    $data{'coding'}{'self_test_probe_state'}{'PROBE3'}  = {
        'backend'    => qw| gpu |,
        'in_flight'  => TRUE,
        'http_state' => $http_state,
    };

    call_spawn_smart();

    ok( !$on_error_fired,
        'gpu probe never cancelled by ' . 'a cpu-targeted force respawn' );
    ok( defined $data{'coding'}{'self_test_probe_state'}{'PROBE3'},
        'gpu probe state left intact' );
    ok( $data{'coding'}{'self_test_probe_in_flight'}{'gpu'},
        'gpu guard left set' );
}

say '';
if ($fail_count) {
    say "$fail_count check(s) FAILED";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,.,,.,,,,,.,.,,,,..,,..,...,.,.,,..,.,,,,..,..,,...,...,..,,.,.,.,,,.,.,...,
#RAIVVRBIDTIRHEJKXDBMOP7VNVKGXH3BNHBG237JUMAIPRBXHECO2KHGRZFLDRSHF4KYNWSKDJA5C
#\\\|LZUWW5HKE3ICCZLDMB5QURVH4ZNAFMBDRGE3IZWHA5LCAS7SNNY \ / AMOS7 \ YOURUM ::
#\[7]3Q5OZFUOJLRNGQPPHAKZAZNOGKJTDMTU4OZ3BZIU5ZDU4LV24YBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
