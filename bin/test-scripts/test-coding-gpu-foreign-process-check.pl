#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                                  ###
## coding.spawn_inference_server : gpu foreign-process check excludes cpu ##
###                                                                  ###

## live bug found 2026-08-26: the gpu-only "foreign llama process" safety  ##
## check [ meant to refuse a gpu spawn if ANOTHER gpu-competing process is ##
## detected, preventing oom ] used pgrep against ALL                       ##
## llama-server/llama-mtmd-cli processes system-wide and only excluded     ##
## gpu's OWN tracked pid + its forked children. it never excluded the      ##
## running CPU backend's own pid -- so the moment cpu spawning actually    ##
## worked [ this same session's earlier fixes ], EVERY gpu respawn [       ##
## crash-restart, seed-retry-restart, .. ] was permanently refused for as  ##
## long as cpu stayed alive, confirmed live via a real cascade: cat- test  ##
## failure -> seed-retry-restart -> gpu respawn refused, seeing its own    ##
## healthy cpu sibling as a foreign intruder -> infinite backoff loop that ##
## can never succeed while cpu is up. a cpu-only process never threatens   ##
## this check's actual concern [ VRAM/GPU-process collision ] - it runs on ##
## system RAM, not VRAM -- so it should never have counted                 ##
##                                                                         ##
## coding.spawn_inference_server as a whole is too entangled with real     ##
## system state [ kill(), /proc scanning, fuser, real process groups ] to  ##
## safely integration-test end to end [ same judgment made earlier this    ##
## session for the LD_LIBRARY_PATH fix -- see                              ##
## test-coding-cpu-ld-library-path.pl for the same extraction technique    ##
## used here ]. this harness extracts the exact foreign-process-detection  ##
## block straight out of the real source file and drives it against a fake ##
## process list, instead of a hand-copied duplicate that could silently    ##
## drift out of sync                                                       ##

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

## extract from the gpu-only block's own opening line through the closing   ##
## brace of its inner "if (@foreign_procs) { ... }" -- deliberately NOT the ##
## block's true end [ vram sanity check and beyond follow it, not needed    ##
## here ], so this harness supplies its own closing brace to keep the       ##
## extracted snippet syntactically valid on its own                         ##
my ($block) = $src =~ m{
    ( if \s* \( \s* \$backend \s* eq \s* qw\| \s* gpu \s* \| \s* \) \s* \{
      .*?
      if \s* \( \s* \@foreign_procs \s* \) \s* \{
      .*?
      \n \x20{4} \} )
}xs;

ok( defined $block,
    'extracted the foreign-process-detection block from the real source [ if '
        . 'this fails, the block structure changed -- update this harness to '
        . 'match ]'
);
die 'cannot continue without the extracted block' if not defined $block;

for my $marker (qw| $cpu_pid $own_pid @foreign_procs |) {
    ok( index( $block, $marker ) >= 0, "extracted block references $marker" );
}

## replace the real qx{ pgrep ... } with a test-controlled fake process ##
## list -- everything else in the block is byte-identical to the real   ##
## source, only the external-command boundary is substituted            ##
( my $plain_block = $block ) =~ s{
    qx\{ \s* pgrep \s+ -a \s+
    'llama-\(server\|mtmd-cli\)' \s+ 2>/dev/null \s* \}
}{\@fake_procs}xs;
$plain_block
    =~ s{<coding\.inference_servers>}{\$data{'coding'}{'inference_servers'}}g;
$plain_block .= "\n}\n";    ## close the outer if -- see extraction note ##

sub run_check {
    my ( $fake_procs, $own_pid, $cpu_pid, $killed_stale ) = @ARG;
    local our @fake_procs        = @$fake_procs;
    local our @killed_stale_pids = @{ $killed_stale // [] };
    my $backend = 'gpu';
    %data = (
        'coding' => {
            'inference_servers' => {
                'gpu' => { 'pid' => $own_pid },
                'cpu' => { 'pid' => $cpu_pid },
            }
        }
    );
    my @foreign_procs_result;
    my $refused = 0;
    my %code    = (
        'base.logs' => sub {
            my ( $level, $fmt, @args ) = @ARG;
            if ( $fmt =~ m{foreign llama process} ) { $refused = 1; }
            return TRUE;
        },
    );
    my $spawning_in_progress;
    ## eval directly against the real, extracted, byte-verified logic --   ##
    ## <coding.spawning_in_progress> writes and <[base.logs]> calls need   ##
    ## simple stand-ins since this is plain %data / a local %code, not a   ##
    ## full p7 translation pass [ the block itself uses no other p7-only   ##
    ## macro syntax beyond <coding.inference_servers>, already substituted ##
    my $stmt = $plain_block;
    $stmt =~ s{<\[base\.logs\]>}{\$code{'base.logs'}}g;
    $stmt =~ s{<coding\.spawning_in_progress>\s*=\s*FALSE;}{}g;
    my $result = eval $stmt;
    die "eval failed : $EVAL_ERROR" if length $EVAL_ERROR;
    return { refused => $refused, result => $result };
}

say ': 1. cpu backend alive, gpu respawning : must NOT be refused';

my $cpu_cmdline
    = '910278 /data/source/ik_llama.cpp/llama-server-cpu --port 8001';
my $r1 = run_check( [$cpu_cmdline], 0, 910278, [] );
ok( ( not $r1->{'refused'} ),
    'gpu respawn NOT refused when the only '
        . 'other process is our own tracked cpu backend'
);

say ': 2. a genuinely foreign gpu-class process : still correctly refused';

my $r2 = run_check( ['999999 /some/other/llama-server-cuda --port 9000'],
    0, 910278, [] );
ok( $r2->{'refused'},
          'gpu respawn IS refused for a real foreign process [ regression '
        . 'guard -- this exclusion must not become a blanket bypass '
        . ']' );

say ': 3. both cpu backend alive AND a real foreign process present';

my $r3
    = run_check(
    [ $cpu_cmdline, '999999 /some/other/llama-server-cuda --port 9000' ],
    0, 910278, [] );
ok( $r3->{'refused'},
    'still refused when a real foreign process is present alongside cpu' );

say ': 4. gpu\'s own pid excluded exactly as before [ regression guard ]';

my $r4 = run_check( ['12345 /data/source/ik_llama.cpp/llama-server-cuda-fa'],
    12345, 0, [] );
ok( ( not $r4->{'refused'} ),
    'gpu\'s own tracked pid still excluded '
        . '[ pre-existing behavior unchanged ]'
);

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,,,,,..,,,.,,,,,,,.,,.,,..,,,,,,,,.,...,,,.,.,.,...,...,,.,,.,,,,..,,..,...,
#RTGY7TMPSCFW73Z37SG3OA72HZ45PXJAHZBGZTE5FA2CS4FV2OY45XFYSJVJWOM6J7LSCJ6M6IHPU
#\\\|DI74VFU6EWTBPOYGOC76RI3YSI6735ERG34D5NOSTW2OH6GRJQG \ / AMOS7 \ YOURUM ::
#\[7]3WJN63G3BZGA5MOVZX3LZKU2AEHTU4WDM2CBVE23FHUSQRHLKUDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
