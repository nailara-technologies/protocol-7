#!/usr/bin/perl
use v5.24;
use strict;
use warnings;
use English;

###                                      ###
## thermal gate : standalone regression  ##
###                                      ###

use File::Spec;
use File::Temp  qw| tempdir |;
use Cwd         qw| abs_path |;
use FindBin     qw| $RealBin |;
use Time::Local qw| timelocal |;

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

compile_module('thermal.window.in_range');
compile_module('thermal.window.current');
compile_module('thermal.window.tariff');
compile_module('thermal.window.weight');
compile_module('thermal.outdoor.poll');
compile_module('thermal.handler.outdoor-reply');
compile_module('thermal.outdoor.amp');
compile_module('thermal.gate.sample');
compile_module('thermal.gate.decide');
compile_module('thermal.feed.register');
compile_module('task.handler.gpu_power_update');
compile_module('task.handler.gpu_temp_update');
compile_module('thermal.mem.read');
compile_module('thermal.mem.decide');
compile_module('thermal.idle.sample');
compile_module('thermal.idle.held');
compile_module('thermal.idle.loadavg');
compile_module('thermal.start.ready');
compile_module('thermal.override.set');
compile_module('thermal.override.active');
compile_module('thermal.verdict');
compile_module('thermal.init_code');

$code{'base.cfg_bool'} = sub {
    my $value = shift // FALSE;
    return FALSE if $value =~ m{^(0|no?|false|off)$}i;
    return TRUE;
};

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
    'window'      => qw| day |,
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
    'window'      => qw| day |,
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

say ': 9. window and idle defaults are initialized';
ok( $data{'thermal'}{'cfg'}{'start'}{'hold'} == 600
        && $data{'thermal'}{'cfg'}{'idle'}{'hold'} == 600
        && $data{'thermal'}{'cfg'}{'idle'}{'load_max'} == 0.6
        && $data{'thermal'}{'cfg'}{'idle'}{'power_max'} == 60
        && $data{'thermal'}{'cfg'}{'window'}{'night'} eq qw| 22:00-06:00 |
        && $data{'thermal'}{'cfg'}{'night'}{'cold'} == 8
        && $data{'thermal'}{'cfg'}{'night'}{'hot'} == 25
        && $data{'thermal'}{'cfg'}{'night'}{'weight'} == 1
        && $data{'thermal'}{'cfg'}{'day'}{'weight'} == 0.25,
    'window idle start and weight defaults match the design'
);

say ': 10. schedule windows handle midnight and malformed ranges';
my $at_time = sub {
    my ( $hour, $minute ) = @ARG;
    return timelocal( 0, $minute, $hour, 15, 0, 2026 );
};
my $window_current = sub {
    return $code{'thermal.window.current'}->(@ARG);
};
ok( $window_current->( $at_time->( 23, 0 ) ) eq qw| night |
        && $window_current->( $at_time->( 5, 59 ) ) eq qw| night |,
    'crossing midnight includes late evening and early morning'
);
ok( $window_current->( $at_time->( 6, 0 ) ) eq qw| day |
        && $window_current->( $at_time->( 21, 59 ) ) eq qw| day |,
    'crossing midnight excludes the daytime'
);
{
    local $data{'thermal'}{'cfg'}{'window'}{'night'} = qw| 01:00-05:00 |;
    ok( $window_current->( $at_time->( 1, 0 ) ) eq qw| night |
            && $window_current->( $at_time->( 4, 59 ) ) eq qw| night |,
        'non-crossing range includes its interior'
    );
    ok( $window_current->( $at_time->( 0, 59 ) ) eq qw| day |
            && $window_current->( $at_time->( 5, 0 ) ) eq qw| day |,
        'non-crossing range excludes its exterior'
    );
}
{
    local $data{'thermal'}{'cfg'}{'window'}{'night'} = qw| 25:99-night |;
    ok( $window_current->( $at_time->( 23, 0 ) ) eq qw| day |,
        'malformed range falls back to day' );
}
ok( $code{'thermal.window.weight'}->(qw| night |) == 1
        && $code{'thermal.window.weight'}->(qw| day |) == 0.25,
    'window weight selects night and day values'
);

say ': 11. night and day marks preserve the absolute ceiling';
$gate = {
    'baseline'    => 40,
    'avg_short'   => 47.9,
    'avg_long'    => 47.9,
    'state'       => qw| warm |,
    'state_since' => 0,
    'window'      => qw| night |,
};
ok( $code{'thermal.gate.decide'}->( $gate, 120 ) eq qw| cold |,
    'night relative cold mark is baseline plus eight'
);
$gate->{'avg_short'} = $gate->{'avg_long'} = 48.1;
ok( $code{'thermal.gate.decide'}->( $gate, 240 ) eq qw| warm |,
    'temperature above the night cold mark is warm'
);
$gate->{'avg_short'} = $gate->{'avg_long'} = 65.1;
ok( $code{'thermal.gate.decide'}->( $gate, 360 ) eq qw| hot |,
    'night relative hot mark is baseline plus twenty five'
);
$gate->{'window'}    = qw| day |;
$gate->{'avg_short'} = $gate->{'avg_long'} = 44.6;
ok( $code{'thermal.gate.decide'}->( $gate, 480 ) eq qw| warm |,
    'day keeps the original relative cold mark' );
{
    local $data{'thermal'}{'cfg'}{'mode'} = qw| absolute |;
    $gate = {
        'avg_short'   => 7.9,
        'avg_long'    => 7.9,
        'state'       => qw| warm |,
        'state_since' => 0,
        'window'      => qw| night |,
    };
    ok( $code{'thermal.gate.decide'}->( $gate, 120 ) eq qw| cold |,
        'night absolute cold mark is eight degrees' );
    $gate->{'avg_short'} = $gate->{'avg_long'} = 8.1;
    ok( $code{'thermal.gate.decide'}->( $gate, 240 ) eq qw| warm |,
        'night absolute threshold does not use the baseline'
    );
}
$gate = {
    'baseline'    => 40,
    'avg_short'   => 83,
    'avg_long'    => 83,
    'state'       => qw| cold |,
    'state_since' => 1000,
    'window'      => qw| night |,
};
ok( $code{'thermal.gate.decide'}->( $gate, 1001 ) eq qw| hot |,
    'night window never raises the absolute ceiling'
);

say ': 12. idle samples track continuous idle duration';
my $idle_gate = {};
ok( $code{'thermal.idle.sample'}
        ->( $idle_gate, { 'load_per_core' => 0.6, 'busy' => FALSE }, 100 ) eq
        qw| idle |,
    'load at the idle maximum without inference is idle'
);
ok( $idle_gate->{'idle_since'} == 100, 'idle start records idle_since' );
$code{'thermal.idle.sample'}
    ->( $idle_gate, { 'load_per_core' => 0.5, 'busy' => FALSE }, 200 );
ok( $idle_gate->{'idle_since'} == 100,
    'continued idle preserves idle_since' );
ok( $code{'thermal.idle.held'}->( $idle_gate, 699, 600 ) == FALSE
        && $code{'thermal.idle.held'}->( $idle_gate, 700, 600 ) == TRUE,
    'idle hold uses the full requested duration'
);
ok( $code{'thermal.idle.sample'}
        ->( $idle_gate, { 'load_per_core' => 0.1, 'busy' => TRUE }, 300 ) eq
        qw| active | && !exists $idle_gate->{'idle_since'},
    'inference in flight clears idle_since'
);
$code{'thermal.idle.sample'}
    ->( $idle_gate, { 'load_per_core' => 0.61, 'busy' => FALSE }, 400 );
ok( !exists $idle_gate->{'idle_since'}, 'load above the maximum is active' );

say ': 13. loadavg uses fixture load and processor counts';
my $loadavg_path = File::Spec->catfile( $tmp_dir, 'loadavg' );
my $cpuinfo_path = File::Spec->catfile( $tmp_dir, 'cpuinfo' );
open( my $loadavg_fh, '>', $loadavg_path )
    or die "cannot write $loadavg_path : $!";
print {$loadavg_fh} "2.40 1.20 0.60 1/100 123\n";
close($loadavg_fh);
open( my $cpuinfo_fh, '>', $cpuinfo_path )
    or die "cannot write $cpuinfo_path : $!";
print {$cpuinfo_fh} "processor : 0\nprocessor: 1\n";
close($cpuinfo_fh);
ok( abs($code{'thermal.idle.loadavg'}->( $loadavg_path, $cpuinfo_path ) - 1.2
    ) < 0.000001,
    'one minute loadavg is divided by processor count'
);
ok( $code{'thermal.idle.loadavg'}->(
        File::Spec->catfile( $tmp_dir, 'missing-loadavg' ),
        $cpuinfo_path
    ) == 0,
    'missing loadavg fixture returns zero instead of dying'
);

say ': 14. real idle baseline learns up and down without a band';
$gate = {};
$code{'thermal.gate.sample'}->( $gate, 40, 0,    FALSE );
$code{'thermal.gate.sample'}->( $gate, 50, 1800, TRUE );
$expected = 40 + ( 1 - exp(-1) ) * 10;
ok( abs( $gate->{'baseline'} - $expected ) < 0.000001,
    'held idle learns upward outside the fallback band'
);
$code{'thermal.gate.sample'}->( $gate, 30, 3600, TRUE );
$expected += ( 1 - exp(-1) ) * ( 30 - $expected );
ok( abs( $gate->{'baseline'} - $expected ) < 0.000001,
    'held idle also learns downward' );
$gate = {};
$code{'thermal.gate.sample'}->( $gate, 70, 0, TRUE );
ok( $gate->{'baseline'} == 55, 'held idle baseline remains capped' );
$gate = {
    'baseline'       => 40,
    'avg_short'      => 40,
    'avg_long'       => 40,
    'state'          => qw| warm |,
    'last_sample_at' => 0,
};
$code{'thermal.gate.sample'}->( $gate, 30, 1800, FALSE );
ok( $gate->{'baseline'} == 40,
    'warm fallback without idle remains unchanged' );

say ': 15. cold start requires calm memory and held idle';
$gate      = { 'state'      => qw| cold | };
$mem_gate  = { 'state'      => qw| calm | };
$idle_gate = { 'idle_since' => 400 };
ok( $code{'thermal.start.ready'}->( $gate, $mem_gate, $idle_gate, 1000 )
        == TRUE,
    'cold calm and held idle gates permit start'
);
ok( $code{'thermal.start.ready'}->( undef, $mem_gate, $idle_gate, 1000 )
        == TRUE,
    'missing temperature data does not block start'
);
ok( $code{'thermal.start.ready'}
        ->( { 'state' => qw| warm | }, $mem_gate, $idle_gate, 1000 ) == FALSE,
    'warm temperature blocks start'
);
ok( $code{'thermal.start.ready'}
        ->( $gate, { 'state' => qw| soft | }, $idle_gate, 1000 ) == FALSE,
    'soft memory blocks start'
);
ok( $code{'thermal.start.ready'}->( $gate, $mem_gate, $idle_gate, 999 )
        == FALSE,
    'idle shorter than start hold blocks start'
);

say ': 16. manual override expires at the window switch';
my $override = {};
ok( $code{'thermal.override.set'}
        ->( $override, qw| run |, $at_time->( 23, 0 ) ) == TRUE
        && $override->{'window'} eq qw| night |,
    'override stores its verdict and window'
);
ok( $code{'thermal.override.active'}->( $override, $at_time->( 5, 59 ) ) eq
        qw| run |,
    'override remains active within its window'
);
ok( !defined $code{'thermal.override.active'}
        ->( $override, $at_time->( 6, 0 ) ) && !exists $override->{'verdict'},
    'window switch clears and expires the override'
);

say ': 17. outdoor replies store only numeric temperatures';
my ( $reply_ok, $reply_text, $reply_why, $log_count ) = ( TRUE, '', '', 0 );
$code{'base.reply.value'} = sub {
    return ( $reply_ok, $reply_text, $reply_why );
};
$code{'base.logs'} = sub { $log_count++; return TRUE };
$code{'base.time'} = sub { return 12345 };
my $outdoor_reply = sub {
    return $code{'thermal.handler.outdoor-reply'}->( {} );
};
$reply_text = "6.36\x{B0}C";
ok( $outdoor_reply->() == TRUE
        && $data{'thermal'}{'outdoor'}{'temp'} == 6.36
        && $data{'thermal'}{'outdoor'}{'at'} == 12345,
    'character degree reply stores temperature and timestamp'
);
$reply_text = "6.36\xC2\xB0C";
ok( $outdoor_reply->() == TRUE && $data{'thermal'}{'outdoor'}{'temp'} == 6.36,
    'utf-8 octet degree reply stores the same temperature'
);
$reply_text = 'n|a';
ok( $outdoor_reply->() == FALSE
        && $data{'thermal'}{'outdoor'}{'temp'} == 6.36
        && $log_count == 1,
    'unparsable reply logs once and preserves the old value'
);
( $reply_ok, $reply_text, $reply_why ) = ( FALSE, undef, qw| route failed | );
ok( $outdoor_reply->() == FALSE
        && $data{'thermal'}{'outdoor'}{'temp'} == 6.36
        && $log_count == 2,
    'false reply logs once and preserves the old value'
);
$code{'base.cfg_bool'} = sub {
    my $value = shift // FALSE;
    return FALSE if $value =~ m{^(0|no?|false|off)$}i;
    return TRUE;
};

say ': 18. outdoor amplifier handles cold stale and disabled data';
my $outdoor_amp = sub {
    return $code{'thermal.outdoor.amp'}->(@ARG);
};
ok( $outdoor_amp->( 15, 1000, 2000 ) == 1,
    'reference temperature gives no amplification'
);
ok( abs( $outdoor_amp->( 7, 1000, 2000 ) - 1.32 ) < 0.000001,
    'seven degrees gives the proportional amplifier'
);
ok( $outdoor_amp->( -5, 1000, 2000 ) == 1.5
        && $outdoor_amp->( -30, 1000, 2000 ) == 1.5,
    'extreme cold clamps to the amplifier maximum'
);
ok( $outdoor_amp->( 7, 1000, 4601 ) == 1,
    'stale outdoor data gives no amplification'
);
{
    local $data{'thermal'}{'cfg'}{'outdoor'}{'enabled'} = qw| no |;
    ok( $outdoor_amp->( -30, 1000, 2000 ) == 1,
        'disabled outdoor data gives no amplification'
    );
}

say ': 19. only relative night offsets are amplified';
$gate = {
    'baseline'    => 40,
    'avg_short'   => 51.9,
    'avg_long'    => 51.9,
    'state'       => qw| warm |,
    'state_since' => 0,
    'window'      => qw| night |,
    'amp'         => 1.5,
};
ok( $code{'thermal.gate.decide'}->( $gate, 120 ) eq qw| cold |,
    'amplified night cold offset admits colder temperatures'
);
$gate->{'avg_short'} = $gate->{'avg_long'} = 52.1;
ok( $code{'thermal.gate.decide'}->( $gate, 240 ) eq qw| warm |,
    'temperature above the amplified cold offset is warm'
);
$gate->{'window'}    = qw| day |;
$gate->{'avg_short'} = $gate->{'avg_long'} = 44.6;
ok( $code{'thermal.gate.decide'}->( $gate, 360 ) eq qw| warm |,
    'day offsets remain unamplified' );
$gate->{'window'}    = qw| night |;
$gate->{'amp'}       = 2;
$gate->{'avg_short'} = $gate->{'avg_long'} = 82.9;
ok( $code{'thermal.gate.decide'}->( $gate, 480 ) ne qw| hot |,
    'amplified hot mark is clamped below the absolute ceiling'
);
$gate->{'avg_short'} = $gate->{'avg_long'} = 83;
ok( $code{'thermal.gate.decide'}->( $gate, 481 ) eq qw| hot |,
    'absolute ceiling remains immediate after amplification'
);
{
    local $data{'thermal'}{'cfg'}{'mode'} = qw| absolute |;
    $gate = {
        'avg_short'   => 7.9,
        'avg_long'    => 7.9,
        'state'       => qw| warm |,
        'state_since' => 0,
        'window'      => qw| night |,
        'amp'         => 2,
    };
    ok( $code{'thermal.gate.decide'}->( $gate, 120 ) eq qw| cold |,
        'absolute night marks remain unamplified' );
}

say ': 20. tariff ranges and weights preserve existing callers';
ok( $code{'thermal.window.in_range'}
        ->( qw| 22:00-06:00 |, $at_time->( 23, 0 ) ) == TRUE
        && $code{'thermal.window.in_range'}
        ->( qw| 22:00-06:00 |, $at_time->( 5, 59 ) ) == TRUE
        && $code{'thermal.window.in_range'}
        ->( qw| 22:00-06:00 |, $at_time->( 6, 0 ) ) == FALSE,
    'shared range parser handles midnight boundaries'
);
ok( $code{'thermal.window.tariff'}->( $at_time->( 23, 0 ) ) == FALSE,
    'empty tariff range is disabled' );
{
    local $data{'thermal'}{'cfg'}{'window'}{'tariff'} = qw| 22:00-06:00 |;
    ok( $code{'thermal.window.tariff'}->( $at_time->( 23, 0 ) ) == TRUE,
        'configured tariff range is active' );
}
ok( $code{'thermal.window.weight'}->( qw| day |, TRUE ) == 1
        && $code{'thermal.window.weight'}->( qw| day |, FALSE ) == 0.25
        && $code{'thermal.window.weight'}->(qw| night |) == 1,
    'tariff selects night weight and one argument calls are unchanged'
);
ok( $data{'thermal'}{'cfg'}{'window'}{'tariff'} eq ''
        && $data{'thermal'}{'cfg'}{'outdoor'}{'enabled'} eq qw| yes |
        && $data{'thermal'}{'cfg'}{'outdoor'}{'t_ref'} == 15
        && $data{'thermal'}{'cfg'}{'outdoor'}{'k'} == 0.04
        && $data{'thermal'}{'cfg'}{'outdoor'}{'max'} == 1.5
        && $data{'thermal'}{'cfg'}{'outdoor'}{'max_age'} == 3600
        && $data{'thermal'}{'cfg'}{'outdoor'}{'forecast'} eq qw| yes |,
    'outdoor and tariff defaults match the design'
);

say ': 21. task idle wiring fails closed and learns after the hold';
my %task_streams;
my $task_now = 100;
$code{'base.time'} = sub { return $task_now };
## ntime is a different clock : the gate compares base.time only ##
$code{'base.ntime'}          = sub { return 3_234_362_257_055 };
$code{'base.logs'}           = sub { return TRUE };
$code{'strm.local.register'} = sub {
    my ( $cmd_id, $args ) = @ARG;
    $task_streams{$cmd_id} = $args->{'watcher'};
    return TRUE;
};
$code{'thermal.idle.loadavg'} = sub { return 0.1 };
$code{'task.handler.gpu_power_update'}
    ->( { 'cmd' => qw| STRM |, 'args' => qw| open |, 'cmd_id' => 501 } );
$code{'task.handler.gpu_temp_update'}
    ->( { 'cmd' => qw| STRM |, 'args' => qw| open |, 'cmd_id' => 502 } );
my $task_stream_sample = sub {
    my ( $cmd_id, $payload ) = @ARG;
    $task_streams{$cmd_id}->( { 'buf' => $payload } );
};
$task_stream_sample->( 501, "80.0\n" );
$task_stream_sample->( 502, "40\n" );
ok( $data{'task'}{'thermal'}{'idle'}{'state'} eq qw| active |
        && !exists $data{'task'}{'thermal'}{'idle'}{'idle_since'},
    'fresh power above the maximum is active'
);
$data{'task'}{'stats'}{'gpu'}{'power'}{'watts'} = 42;
$task_now = 131;
$task_stream_sample->( 502, "40\n" );
ok( $data{'task'}{'thermal'}{'idle'}{'state'} eq qw| active |
        && !exists $data{'task'}{'thermal'}{'idle'}{'idle_since'},
    'power older than thirty seconds is active'
);
$task_now = 1000;
$data{'task'}{'thermal'}{'gate'} = {};
$task_stream_sample->( 501, "42\n" );
$task_stream_sample->( 502, "40\n" );
ok( $data{'task'}{'thermal'}{'idle'}{'state'} eq qw| idle |
        && $data{'task'}{'thermal'}{'idle'}{'idle_since'} == 1000
        && $data{'task'}{'thermal'}{'idle'}{'power_watts'} == 42,
    'fresh power below the maximum records idle state and watts'
);
$task_now = 1600;
$task_stream_sample->( 501, "42\n" );
$task_stream_sample->( 502, "50\n" );
$expected = 40 + ( 1 - exp( -600 / 1800 ) ) * 10;
ok( abs( $data{'task'}{'thermal'}{'gate'}{'baseline'} - $expected )
        < 0.000001,
    'task callback learns upward outside the band after held idle'
);
$task_now = 2200;
$task_stream_sample->( 501, "42\n" );
$task_stream_sample->( 502, "30\n" );
$expected += ( 1 - exp( -600 / 1800 ) ) * ( 30 - $expected );
ok( abs( $data{'task'}{'thermal'}{'gate'}{'baseline'} - $expected )
        < 0.000001,
    'task callback also learns downward after held idle'
);
$code{'task.handler.gpu_power_update'}->(
    { 'cmd' => qw| FALSE |, 'call_args' => { 'args' => qw| unavailable | } }
);
ok( !defined $data{'task'}{'stats'}{'gpu'}{'power'}{'updated_at'},
    'failed power subscription invalidates freshness'
);

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,,,,..,,,,,,,..,,..,,,,,,..,,.,,..,,..,,,.,,..,,...,...,.,.,.,.,.,,,,..,,..,
#2C52JN6DK2K64CKK6FWHGVF6OLOYEKUP7HYR24MM76WF2UN37HLXRY26HHHLOD5RYOAC3LNSTQ3WC
#\\\|GGNPHTGIZ4K4FUBAHFN6PWY3SH6NW6IWB6GUW5XRDQFNMAQT7QF \ / AMOS7 \ YOURUM ::
#\[7]NURP7IYVGLCOXTZB3IIJGIYT624R7VAMQAURQUF7NUKJALW2X2DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
