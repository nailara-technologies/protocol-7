#!/usr/bin/perl
use v5.24;
use strict;
use warnings;
use English;

###                                      ###
## thermal gate : standalone regression  ##
###                                      ###

use File::Spec;
use File::Temp qw| tempdir |;
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

use constant TRUE  => 5;
use constant FALSE => 0;

our %data;
our %code;

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

compile_module('thermal.gate.sample');
compile_module('thermal.gate.decide');
compile_module('thermal.mem.read');
compile_module('thermal.mem.decide');
compile_module('thermal.verdict');
compile_module('thermal.init_code');

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

sub sample {
    my ( $gate, $temp, $now ) = @ARG;
    $code{'thermal.gate.sample'}->( $gate, $temp, $now );
    return $code{'thermal.gate.decide'}->( $gate, $now );
}

say ': 1. baseline learns only while cold';
my $gate = {};
ok( sample( $gate, 40, 0 ) eq qw| cold |, 'first sample starts cold' );
ok( $gate->{'baseline'} == 40, 'first sample initializes baseline' );
sample( $gate, 41, 1800 );
my $expected = 40 + ( 1 - exp(-1) ) * 1;
ok( abs( $gate->{'baseline'} - $expected ) < 0.000001,
    'cold sample updates baseline with real dt'
);
my $before_band = $gate->{'baseline'};
sample( $gate, 44, 3600 );
ok( $gate->{'baseline'} == $before_band,
    'cold sample outside the band leaves baseline [ no creep ]' );
my $hot_start = {};
sample( $hot_start, 70, 0 );
ok( $hot_start->{'baseline'} == 55, 'hot start baseline capped at 55' );
$gate->{'state'} = qw| warm |;
my $baseline = $gate->{'baseline'};
sample( $gate, 60, 3600 );
ok( $gate->{'baseline'} == $baseline,
    'warm sample leaves baseline unchanged'
);

say ': 2. relative marks follow the baseline';
$gate = {
    'baseline'    => 40,
    'avg_short'   => 44.4,
    'avg_long'    => 44.4,
    'state'       => qw| cold |,
    'state_since' => 0,
};
ok( $code{'thermal.gate.decide'}->( $gate, 120 ) eq qw| cold |,
    'below baseline plus cold mark stays cold' );
$gate->{'avg_short'} = $gate->{'avg_long'} = 44.6;
ok( $code{'thermal.gate.decide'}->( $gate, 240 ) eq qw| warm |,
    'above baseline plus cold mark becomes warm' );

say ': 3. dwell blocks a fast flip';
$gate = {
    'baseline'    => 40,
    'avg_short'   => 60,
    'avg_long'    => 60,
    'state'       => qw| cold |,
    'state_since' => 1000,
};
ok( $code{'thermal.gate.decide'}->( $gate, 1100 ) eq qw| cold |,
    'hot candidate cannot flip before dwell' );
ok( $code{'thermal.gate.decide'}->( $gate, 1120 ) eq qw| hot |,
    'hot candidate flips when dwell elapsed' );
ok( $gate->{'state_since'} == 1120, 'state change records state_since' );

say ': 4. absolute ceiling is immediate';
$gate = {
    'baseline'    => 40,
    'avg_short'   => 84,
    'avg_long'    => 84,
    'state'       => qw| cold |,
    'state_since' => 2000,
};
ok( $code{'thermal.gate.decide'}->( $gate, 2001 ) eq qw| hot |,
    'ceiling bypasses dwell' );
ok( $gate->{'state_since'} == 2001,
    'ceiling transition records state_since' );

say ': 5. memory defaults are initialized';
$code{'thermal.init_code'}->();
ok( $data{'thermal'}{'cfg'}{'unload'}{'hold'} == 900
        && $data{'thermal'}{'cfg'}{'mem'}{'psi_some_soft'} == 10
        && $data{'thermal'}{'cfg'}{'mem'}{'psi_full_hard'} == 5
        && $data{'thermal'}{'cfg'}{'mem'}{'avail_min_pct'} == 15
        && $data{'thermal'}{'cfg'}{'mem'}{'hold'} == 60,
    'memory and unload defaults match the design'
);

say ': 6. memory readings use psi and meminfo fixtures';
my $tmp_dir      = tempdir( CLEANUP => 1 );
my $psi_path     = File::Spec->catfile( $tmp_dir, 'memory-pressure' );
my $meminfo_path = File::Spec->catfile( $tmp_dir, 'meminfo' );
open( my $psi_fh, '>', $psi_path ) or die "cannot write $psi_path : $!";
print {$psi_fh} "some avg10=1.00 avg60=12.34 avg300=2.00 total=1\n";
print {$psi_fh} "full avg10=0.50 avg60=6.50 avg300=1.00 total=1\n";
close($psi_fh);
open( my $meminfo_fh, '>', $meminfo_path )
    or die "cannot write $meminfo_path : $!";
print {$meminfo_fh} "MemTotal:        1000 kB\nMemAvailable:     120 kB\n";
close($meminfo_fh);
my $reading = $code{'thermal.mem.read'}
    ->( { 'psi' => $psi_path, 'meminfo' => $meminfo_path } );
ok( $reading->{'psi_some_avg60'} == 12.34
        && $reading->{'psi_full_avg60'} == 6.5
        && $reading->{'avail_pct'} == 12,
    'psi and available memory are parsed'
);
$reading = $code{'thermal.mem.read'}->(
    {   'psi'     => File::Spec->catfile( $tmp_dir, 'missing-psi' ),
        'meminfo' => $meminfo_path,
    }
);
ok(
    (          not defined $reading->{'psi_some_avg60'}
            && not defined $reading->{'psi_full_avg60'}
            && $reading->{'avail_pct'} == 12
    ),
    'missing psi leaves pressure values undefined'
);

say ': 7. memory thresholds set calm, soft, and hard';
my $mem_gate = {};
ok( $code{'thermal.mem.decide'}->(
        $mem_gate,
        {   'psi_some_avg60' => 9.99,
            'psi_full_avg60' => 4.99,
            'avail_pct'      => 15,
        },
        100
    ) eq qw| calm |,
    'values below all thresholds are calm'
);
ok( $mem_gate->{'state_since'} == 100, 'calm records state_since' );
ok( $code{'thermal.mem.decide'}
        ->( $mem_gate, { 'psi_some_avg60' => 10, 'avail_pct' => 50 }, 200 )
        eq qw| soft |,
    'some pressure at the soft threshold is soft'
);
ok( $code{'thermal.mem.decide'}
        ->( $mem_gate, { 'psi_full_avg60' => 5, 'avail_pct' => 50 }, 300 ) eq
        qw| hard |,
    'full pressure at the hard threshold is hard'
);
ok( $mem_gate->{'hard_since'} == 300, 'hard transition records hard_since' );
$code{'thermal.mem.decide'}
    ->( $mem_gate, { 'psi_full_avg60' => 6, 'avail_pct' => 50 }, 400 );
ok( $mem_gate->{'hard_since'} == 300, 'continued hard preserves hard_since' );
$code{'thermal.mem.decide'}->( $mem_gate, { 'avail_pct' => 14.9 }, 500 );
ok(
    (   $mem_gate->{'state'} eq qw| soft |
            && not exists $mem_gate->{'hard_since'}
    ),
    'low available memory is soft and clears hard_since'
);
$code{'thermal.mem.decide'}->( $mem_gate, { 'avail_pct' => 7.49 }, 600 );
ok( $mem_gate->{'state'} eq qw| hard | && $mem_gate->{'hard_since'} == 600,
    'available memory below half the floor is hard' );
$code{'thermal.mem.decide'}->( $mem_gate, {}, 700 );
ok(
    (   $mem_gate->{'state'} eq qw| calm |
            && not exists $mem_gate->{'hard_since'}
    ),
    'missing pressure values do not trigger a state'
);

say ': 8. verdicts combine temperature and memory';
my $verdict = sub {
    return $code{'thermal.verdict'}->(@ARG);
};
ok( $verdict->( {}, { 'state' => qw| calm | }, 1000 ) eq qw| run |,
    'calm gates run' );
ok( $verdict->( {}, { 'state' => qw| soft | }, 1000 ) eq qw| no_new |,
    'soft memory accepts no new jobs' );
ok( $verdict->( { 'state' => qw| warm | }, {}, 1000 ) eq qw| slow |,
    'warm temperature stays in the pool, reduced weight'
);
ok( $verdict->( { 'state' => qw| warm | }, { 'state' => qw| soft | }, 1000 )
        eq qw| no_new |,
    'soft memory wins over warm temperature'
);
ok( $verdict->( {}, { 'state' => qw| hard |, 'hard_since' => 950 }, 1000 ) eq
        qw| pause |,
    'recent hard memory pauses'
);
ok( $verdict->( {}, { 'state' => qw| hard |, 'hard_since' => 900 }, 1000 ) eq
        qw| unload |,
    'sustained hard memory unloads'
);
ok( $verdict->( { 'state' => qw| hot |, 'state_since' => 200 }, {}, 1000 ) eq
        qw| pause |,
    'recent hot temperature pauses'
);
ok( $verdict->( { 'state' => qw| hot |, 'state_since' => 100 }, {}, 1000 ) eq
        qw| unload |,
    'sustained hot temperature unloads'
);
ok( $verdict->(
        { 'state' => qw| hot |,  'state_since' => 100 },
        { 'state' => qw| hard |, 'hard_since'  => 950 },
        1000
    ) eq qw| pause |,
    'memory hard wins over sustained hot temperature'
);
ok( $verdict->(
        { 'state' => qw| cold |, 'state_since' => 0 },
        { 'state' => qw| hard |, 'hard_since'  => 900 },
        1000
    ) eq qw| unload |,
    'memory unload wins over cold temperature'
);
ok( $verdict->( undef, { 'state' => qw| soft | }, 1000 ) eq qw| no_new |,
    'gpu-less nodes use memory alone' );
ok( $verdict->( undef, { 'state' => qw| calm | }, 1000 ) eq qw| run |,
    'gpu-less calm nodes run' );

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,..,,..,..,,,..,,,.,,,.,.,,,,,.,,..,,.,,...,..,,...,..,,..,,,..,.,,,.,.,,,.,
#OZIESBEZ7ASXILJB4FNESYPGKPP24YHUHS2CM4CWZSNJNST7VFZHGM3N3AINQ2BYRY7RFSQRX3VDE
#\\\|PBDHYOOOEWJUMDNEGYDE3ACCS5LAOKI2SUOTHJ74T5AQG5C2WKB \ / AMOS7 \ YOURUM ::
#\[7]3KB6PYT545ZJQ5PKBDZFKAN36IYFINBAZ5XJI6VGXB6ZI3JEPQDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
