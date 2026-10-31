#!/usr/bin/perl
use v5.24;
use strict;
use warnings;
use English;

###                                                    ###
## thermal k fit : transient least squares regression  ##
###                                                    ###

use File::Spec;
use Cwd         qw| abs_path |;
use FindBin     qw| $RealBin |;
use Time::Local qw| timegm |;

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

compile_module('thermal.gate.k_trusted');
compile_module('thermal.gate.predict');
compile_module('thermal.gate.hot_mark');
compile_module('thermal.gate.decide');
compile_module('thermal.gate.sample');
compile_module('thermal.init_code');

$code{'thermal.init_code'}->();
$data{'thermal'}{'cfg'}{'k'}{'fit'}{'taus'}   = [ 30, 60, 90, 120, 180, 240 ];
$data{'thermal'}{'cfg'}{'k'}{'fit'}{'window'} = 2400;
$data{'thermal'}{'cfg'}{'k'}{'window'}        = 1;

my @fault_notices;
$code{'base.logs'}             = sub { return TRUE };
$code{'protocol-7.route-send'} = sub {
    push @fault_notices, shift;
    return TRUE;
};

sub ok ($;$) {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

## simulated first-order plant : k = 0.12 C/W, tau = 240 s, idle 42 W, ##
## square wave 42 <-> 220 W, integer temperature and jittery power     ##
my $sim = { 'temp' => 40, 'now' => 0 };

sub plant_run {
    my ( $gate, $k_true, $seconds ) = @ARG;
    my $until = $sim->{'now'} + $seconds;
    while ( $sim->{'now'} < $until ) {
        $sim->{'now'}++;
        my $phase = $sim->{'now'} % 1200;
        my $watts = $phase < 900 ? 300 : 42;
        $sim->{'temp'}
            += ( $k_true * ( $watts - 42 ) - ( $sim->{'temp'} - 40 ) ) / 240;
        my $measured_temp = int( $sim->{'temp'} + 0.5 );
        my $measured_watts
            = $watts
            + 5 * sin( $sim->{'now'} * 1.731 )
            + 2 * cos( $sim->{'now'} );
        $code{'thermal.gate.sample'}->(
            $gate, $measured_temp, $sim->{'now'}, FALSE, $measured_watts, 42
        );
    }
    return;
}

say ': 1. level fit learns k through sensor rounding and power jitter';
my $gate = { 'window' => qw| day | };
plant_run( $gate, 0.12, 2400 );
ok( $gate->{'k_samples'} > 0, 'fits are accepted without a settled period' );
while (
    (      ( $gate->{'k_samples'} // 0 ) < 30
        or not defined $gate->{'k'}
        or abs( $gate->{'k'} - 0.12 ) > 0.012
    )
    and $sim->{'now'} < 28800
) {
    plant_run( $gate, 0.12, 600 );
}
ok( ( $gate->{'k_samples'} // 0 ) >= 30, 'thirty fits during learning' );
ok( defined $gate->{'k'} && abs( $gate->{'k'} - 0.12 ) <= 0.012,
    sprintf(
        'k within ten percent of 0.12 [ got %.4f ]', $gate->{'k'} // -1
    )
);
ok( defined $gate->{'k_fit_tau'}
        && $gate->{'k_fit_tau'} > 100
        && $gate->{'k_fit_tau'} < 1000,
    sprintf( 'fitted tau near 240 s [ got %.1f ]',
        $gate->{'k_fit_tau'} // -1 )
);
ok( defined $gate->{'k_fit_r2'} && $gate->{'k_fit_r2'} >= 0.8,
    sprintf( 'accepted fit meets the r2 floor [ got %.3f ]',
        $gate->{'k_fit_r2'} // -1 )
);
ok( defined $gate->{'k_fit_at'} && $sim->{'now'} - $gate->{'k_fit_at'} <= 120,
    'fit timestamp exposed in the gate state'
);
ok( @{ $gate->{'k_ring'} } <= 1800, 'sample ring stays bounded' );

say ': 2. a fan stop mid-run freezes k and notifies once';
$data{'thermal'}{'cfg'}{'k'}{'window'} = 3600;
my $fault_guard = 0;
plant_run( $gate, 0.24, 240 )
    while not exists $gate->{'fault'}
    and ++$fault_guard < 30;
ok( exists $gate->{'fault'}, 'doubled true k raises a cooling fault' );
my $k_at_fault = $gate->{'k'};
$gate->{'k_ring'} = [];    ## isolate the persistent-fault observations ##
plant_run( $gate, 0.24, 600 );
ok( $gate->{'k'} == $k_at_fault, 'k is frozen while the fault stands' );
ok( @fault_notices == 1 && $fault_notices[0]{'command'} eq qw| notify.warn |,
    'exactly one owner notification'
);
ok( $code{'thermal.gate.decide'}->( $gate, $sim->{'now'} ) eq qw| hot |,
    'fault holds the gate hot' );
plant_run( $gate, 0.12, 3600 );
ok( !exists $gate->{'fault'} && abs( $gate->{'k'} - 0.12 ) <= 0.012,
    'normal fitted observations clear the fault and resume learning'
);

say ': 3. flat idle power accepts no fit';
my $idle_gate = { 'window' => qw| day | };
my $idle_now  = 0;
for ( 1 .. 2400 ) {
    $idle_now++;
    $code{'thermal.gate.sample'}->(
        $idle_gate, 40 + 0.3 * sin( $idle_now * 0.611 ),
        $idle_now,  TRUE, 42, 42
    );
}
ok( ( $idle_gate->{'k_samples'} // 0 ) == 0 && !defined $idle_gate->{'k'},
    'no power variation learns nothing' );
ok( !defined $idle_gate->{'k_fit_at'}, 'no fit is recorded either' );

say ': 4. real RTX 3060 log replays through the level fit';
my $fixture_path
    = File::Spec->catfile( $main::root_path,
    qw| bin test-scripts fixtures thermal |,
    'rtx3060-2026-10-31.csv' );
open( my $fixture_fh, '<', $fixture_path )
    or die "cannot read $fixture_path : $!";
my @replay_rows;
my @idle_power;

while ( my $line = readline($fixture_fh) ) {
    my @field = split( m|\s*,\s*|, $line );
    next if @field < 3;
    my ( $year, $month, $day, $hour, $minute, $second, $fraction )
        = $field[0] =~ m|^(\d+)/(\d+)/(\d+) (\d+):(\d+):(\d+)\.(\d+)$|
        or next;
    my $at = timegm( $second, $minute, $hour, $day, $month - 1, $year )
        + "0.$fraction";
    push @replay_rows, [ $at, $field[1], $field[2] ];
    push @idle_power,  $field[2] if $field[2] < 60;
}
close($fixture_fh);
@idle_power = sort { $a <=> $b } @idle_power;
my $replay_idle = $idle_power[ int( @idle_power / 2 ) ];
$data{'thermal'}{'cfg'}{'k'}{'fit'} = {
    'taus'        => [ 30, 60, 90, 120, 180 ],
    'window'      => 36000,
    'max_samples' => 10000,
    'every'       => 120,
    'min_r2'      => 0.8,
    'min_points'  => 20,
};
my $replay_gate = { 'window' => qw| day | };
for my $row (@replay_rows) {
    $code{'thermal.gate.sample'}->(
        $replay_gate, $row->[1], $row->[0], FALSE, $row->[2], $replay_idle
    );
}
ok( ( $replay_gate->{'k_samples'} // 0 ) > 0,
    'real log produces accepted fits'
);
ok( defined $replay_gate->{'k_fit_r2'} && $replay_gate->{'k_fit_r2'} >= 0.8,
    sprintf( 'real log accepted fit r2 [ got %.3f ]',
        $replay_gate->{'k_fit_r2'} // -1 )
);
ok( defined $replay_gate->{'k'}
        && $replay_gate->{'k'} >= 0.25
        && $replay_gate->{'k'} <= 0.37,
    sprintf( 'real log learned k in range [ got %.4f C/W ]',
        $replay_gate->{'k'} // -1 )
);
ok( defined $replay_gate->{'k_fit_tau'}
        && $replay_gate->{'k_fit_tau'} >= 60
        && $replay_gate->{'k_fit_tau'} <= 120,
    sprintf( 'real log fitted tau in range [ got %.1f s ]',
        $replay_gate->{'k_fit_tau'} // -1 )
);
ok( defined $replay_gate->{'k_fit_base'} && $replay_gate->{'baseline'} <= 55,
    'fit intercept is exposed and the gate baseline remains capped'
);

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,..,,.,,,.,,...,,.,,,.,,..,,,,.,,,.,,,.,,,.,..,,...,...,,.,,...,,..,,,,,,,,,
#4MPWXBLQV76H2TPSG7PX3NVBPKC2CZLA4R3SHWIPS5I7WN6AHZX3BTRGHAZHUCZWAYDN4BHLND35S
#\\\|SE4GTTV2FLKEUKUUOUVR7WMEMLGA2277QZBJJVEM47IJHBBCZFF \ / AMOS7 \ YOURUM ::
#\[7]5IXR6NJGJ3BAPZ4PY6E33CTL4Q5YZDI75OHBBPRQVM3JCHL7ZOCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
