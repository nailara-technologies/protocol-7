#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                                  ###
## coding.spawn_inference_server : LD_LIBRARY_PATH gpu-only regression ##
###                                                                  ###

## the live crash found 2026-08-26 -- CPU spawn segfaulting on every launch ##
## regardless of context size -- traced to this exact statement unconditio- ##
## nally prepending <coding.lib_path> [ the CUDA rebuild-out dir, which     ##
## carries its OWN incompatible libggml.so, same filename ] to              ##
## LD_LIBRARY_PATH before exec'ing EITHER backend's binary. confirmed by    ##
## direct reproduction: running llama-server-cpu standalone with that env   ##
## var set segfaults immediately [ exit 139 ], without it, loads cleanly.   ##
##                                                                          ##
## coding.spawn_inference_server as a whole is too entangled with real      ##
## system state [ kill(), /proc scanning, fuser, real process groups ] to   ##
## safely integration-test end to end -- this harness instead extracts the  ##
## EXACT fixed statement straight out of the real source file [ not a       ##
## hand-copied duplicate that could silently drift out of sync ] and        ##
## verifies its behavior in isolation for both backends                     ##

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
    $main::root_path = $root_path;
}

use constant TRUE  => 5;
use constant FALSE => 0;

our %data;
my $fail_count = 0;

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

my $src_path = File::Spec->catfile( $main::root_path,
    qw| src coding.spawn_inference_server | );
open( my $fh, '<', $src_path ) or die "cannot read $src_path : $!";
my $src = join( '', <$fh> );
close($fh);

## pull out exactly the statement between the two markers that bound it in ##
## the real file -- if this fix is ever rewritten, refactored, or removed, ##
## this extraction fails loudly instead of silently testing stale logic    ##
my ($stmt) = $src =~ m{
    (local \s+ \$ENV\{'LD_LIBRARY_PATH'\} .*? ;)
    \s* \n \s* \n \s* my \s+ \$pid \s+ = \s+ eval
}xs;

ok( defined $stmt,
    'extracted the LD_LIBRARY_PATH statement from the real '
        . 'source [ file structure unchanged since this fix ]'
);
die 'cannot continue without the extracted statement' if not defined $stmt;

ok( $stmt =~ m{if \s+ \$backend \s+ eq \s+ qw\| \s* gpu \s* \|}x,
    'the extracted statement is gated on backend eq gpu'
);

sub run_for_backend {
    my $backend = shift;
    local $ENV{'LD_LIBRARY_PATH'} = 'PRE-EXISTING-VALUE';
    $data{'coding'}{'lib_path'} = '/data/source/ik_llama.cpp-rebuild-out';

    ## <coding.lib_path> is a p7 tree-macro -- translate the one read this ##
    ## statement needs into plain %data access for the isolated eval       ##
    ( my $plain_stmt = $stmt )
        =~ s{<coding\.lib_path>}{\$data{'coding'}{'lib_path'}}g;

    ## eval STRING is its own dynamic scope : a `local` taking effect       ##
    ## inside it unwinds the instant the eval call returns, same as leaving ##
    ## any block -- so the captured value must be read from WITHIN the same ##
    ## eval string, before that scope closes, not from the caller afterward ##
    my $captured;
    eval $plain_stmt . "\n" . '$captured = $ENV{\'LD_LIBRARY_PATH\'};';
    die "eval failed : $EVAL_ERROR" if length $EVAL_ERROR;
    return $captured;
}

say ': gpu backend : override applied';
my $gpu_env = run_for_backend('gpu');
ok( $gpu_env =~ m{^/data/source/ik_llama\.cpp-rebuild-out:},
    'gpu : LD_LIBRARY_PATH prefixed with the cuda rebuild-out dir '
        . "[ got: $gpu_env ]"
);
ok( $gpu_env =~ m{PRE-EXISTING-VALUE$},
    'gpu : previous LD_LIBRARY_PATH value preserved as a suffix' );

say ': cpu backend : override NOT applied [ the actual fix ]';
my $cpu_env = run_for_backend('cpu');
ok( $cpu_env eq 'PRE-EXISTING-VALUE',
    'cpu : LD_LIBRARY_PATH is completely untouched '
        . "[ got: $cpu_env ] -- this is what stops the segfault"
);

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,,,,..,,,,,,...,,,.,,,.,.,,,.,,,..,,.,,,.,.,.,.,...,...,.,.,.,.,,.,,,,.,...,
#ODHSBIDO5RMUCD2G5T75QXDE3L3OUNNI3F73XEAYHPRFET6E4LDKBJTXGHRYYAZ2GDJR52TVUASJW
#\\\|4OVMR7WNVTXLMWLJBNVLCAY4WQZ5F6TKSX4EPBY2YFY76TMKMGD \ / AMOS7 \ YOURUM ::
#\[7]6GVLJNLRBS4AHN2I2GEWRGF6GLAAI6OEO3SXTBA7H5BD55T2XOBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
