#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                                  ###
## coding.helper.calculate_safe_context : CPU RAM-clamp acceptance harness ##
###                                                                  ###

## exercises the real translated coding.helper.calculate_safe_context      ##
## against real /proc/meminfo [ no abstraction to stub -- same convention  ##
## coding.handler.spawn_smart's own RAM check already uses ] and sparse    ##
## temp files [ -s reads only file-size metadata, so a multi-GB "model     ##
## file" costs no real disk space ]. covers the live crash found           ##
## 2026-08-26: the CPU branch previously ignored RAM entirely and could    ##
## auto-expand context to a GPU-tuned coding.cfg.context_max [144993] with ##
## zero memory check, crashing the CPU llama-server on every spawn attempt ##

use File::Spec;
use File::Temp qw| tempfile |;
use Cwd        qw| abs_path |;
use FindBin    qw| $RealBin |;

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

%code = (
    'base.log'  => sub { return TRUE },
    'base.logs' => sub { return TRUE },
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

compile_module('coding.helper.calculate_safe_context');

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

## sparse file : real size metadata, zero real disk usage ##
sub sparse_file_of_mb {
    my $mb = shift;
    my ( $fh, $path ) = tempfile( UNLINK => 1 );
    truncate( $fh, $mb * 1024 * 1024 ) or die "truncate failed : $!";
    close($fh);
    return $path;
}

my $real_mem_available_mb = 0;
if ( open my $fh, '<', '/proc/meminfo' ) {
    while (<$fh>) {
        if (/^MemAvailable:\s+(\d+)/) {
            $real_mem_available_mb = int( $1 / 1024 );
            last;
        }
    }
    close $fh;
}
ok( $real_mem_available_mb > 0, 'real /proc/meminfo MemAvailable readable' );

say ': 1. small model, real host RAM : sane bounded context, not unbounded';

my $small_model  = sparse_file_of_mb(100);    ## ~100MB : small-class model ##
my $small_result = $code{'coding.helper.calculate_safe_context'}
    ->( { 'model_path' => $small_model, 'backend' => 'cpu' } );
ok( $small_result->{'context_length'} >= 7777,
    'context at or above MIN_CONTEXT floor'
);
ok( $small_result->{'context_length'} <= 131072,
    'context does not exceed the default MAX_CONTEXT ceiling' );
ok( $small_result->{'explanation'} =~ m|^RAM=|,
    'explanation reports real RAM math, not the old flat default' );
ok( $small_result->{'limited_by'} =~ m{^(none|minimum|maximum)$},
    'limited_by is one of the CPU-branch\'s valid values'
);

say ': 2. the exact live-crash shape : 9B-class model against a '
    . 'GPU-tuned coding.cfg.context_max, must NOT reach 144993 blindly';

## model_size_mb ~ 9GB [ Q8_0, matches the live "9b-abliterated-Q8_0.gguf"  ##
## that crashed ] -- est_params_gb lands in the 7-12 bracket [ 42KB/token ] ##
my $nineb_model = sparse_file_of_mb(9000);
$data{'coding'}{'cfg'}{'context_max'} = 144993;    ## mirror the live cfg ##
my $nineb_result = $code{'coding.helper.calculate_safe_context'}
    ->( { 'model_path' => $nineb_model, 'backend' => 'cpu' } );
ok( $nineb_result->{'context_length'} <= 144993,
    'never exceeds the configured ceiling'
);
ok(
    (          $nineb_result->{'context_length'} < 144993
            or $real_mem_available_mb > 200_000
    ),
    'does NOT blindly hit the GPU-tuned '
        . 'ceiling on an ordinary host [ context='
        . $nineb_result->{'context_length'}
        . ', real available='
        . $real_mem_available_mb . 'MB ]'
);
delete $data{'coding'}{'cfg'}{'context_max'};

say ': 3. model larger than available RAM : '
    . 'safe minimum, not a crash-sized number';

my $huge_model  = sparse_file_of_mb( $real_mem_available_mb + 50_000 );
my $huge_result = $code{'coding.helper.calculate_safe_context'}
    ->( { 'model_path' => $huge_model, 'backend' => 'cpu' } );
ok( $huge_result->{'context_length'} == 7777,
    'falls back to MIN_CONTEXT when the model cannot fit in RAM at all' );
ok( $huge_result->{'limited_by'} eq 'model_size',
    'limited_by correctly reports model_size'
);
ok( $huge_result->{'explanation'} =~ m|too large for RAM|,
    'explanation names RAM, not the old unconditional-default behavior'
);

say ': 4. RAM query failure : safe minimum, no die/crash';

## simulate by pointing at a model path that still resolves fine -- the  ##
## real /proc/meminfo is always readable on Linux, so this just confirms ##
## the function doesn't die when given odd but valid inputs              ##
my $odd_result = $code{'coding.helper.calculate_safe_context'}
    ->( { 'model_path' => '', 'mmproj_path' => '', 'backend' => 'cpu' } );
ok( defined $odd_result->{'context_length'},
    'no model_path : still returns a defined context_length' );
ok( $odd_result->{'context_length'} >= 7777,
    'no model_path : context still at or above MIN_CONTEXT' );

say ': 5. GPU backend path unaffected by the CPU-branch restructuring';

## whether or not this host has a real GPU, the GPU branch must behave      ##
## exactly as before this fix : either real VRAM-based math [ if nvidia-smi ##
## succeeds here ] or the pre-existing gpu_query_failed fallback -- either  ##
## way it must never take the new RAM-clamp code path                       ##
my $gpu_result = $code{'coding.helper.calculate_safe_context'}
    ->( { 'model_path' => $small_model, 'backend' => 'gpu' } );
ok( defined $gpu_result->{'context_length'}
        and $gpu_result->{'context_length'} >= 7777,
    'gpu path : returns a defined, sane context_length'
);
ok( $gpu_result->{'explanation'} !~ m|^RAM=|,
    'gpu path : explanation is VRAM-flavored, not the new RAM branch [ got: '
        . $gpu_result->{'explanation'} . ' ]'
);
ok( $gpu_result->{'limited_by'}
        =~ m{^(none|minimum|maximum|gpu_query_failed|model_size)$},
    'gpu path : limited_by is one of the pre-existing GPU-branch values'
);

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,,.,,.,,,.,,,,,,,,,,,..,...,.,,,...,..,,,..,.,.,...,..,,..,,...,...,,,,,,,.,
#62F26WQUHO2YI56Q6LF673UKGKTDCEA5VHRUQPXXF4CU3M5BSZKQHAA667C5TBL4PVIFUQ2ZDCOJW
#\\\|GSZGOQFOA777VGEXVTRV7W53ONB3SSFEY3BGTHCH3WPXES2Y54M \ / AMOS7 \ YOURUM ::
#\[7]RUZBON3R247SAW4ZRGZCREXHDCLDU4CW5T453PFN6TIC3NZ3HUBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
