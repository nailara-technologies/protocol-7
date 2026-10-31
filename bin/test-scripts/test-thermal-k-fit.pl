#!/usr/bin/perl
use v5.24;
use strict;
use warnings;
use English;

###                                                    ###
## thermal k fit : transient least squares regression  ##
###                                                    ###

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
## square wave 42 <-> 220 W [ 300 s load, 180 s pause ], +-0.3 C noise ##
my $sim = { 'temp' => 40, 'now' => 0 };

sub plant_run {
    my ( $gate, $k_true, $seconds ) = @ARG;
    my $until = $sim->{'now'} + $seconds;
    while ( $sim->{'now'} < $until ) {
        $sim->{'now'}++;
        my $phase = $sim->{'now'} % 480;
        my $watts = $phase < 300 ? 220 : 42;
        $sim->{'temp'}
            += ( $k_true * ( $watts - 42 ) - ( $sim->{'temp'} - 40 ) ) / 240;
        my $noisy = $sim->{'temp'} + 0.3 * sin( $sim->{'now'} * 0.611 );
        $code{'thermal.gate.sample'}
            ->( $gate, $noisy, $sim->{'now'}, FALSE, $watts, 42 );
    }
    return;
}

say ': 1. transient fit learns k from a square-wave load';
my $gate = { 'window' => qw| day | };
plant_run( $gate, 0.12, 2400 );
ok( $gate->{'k_samples'} > 0, 'fits are accepted without a settled period' );
while ( ( $gate->{'k_samples'} // 0 ) < 30 and $sim->{'now'} < 14400 ) {
    plant_run( $gate, 0.12, 600 );
}
ok( ( $gate->{'k_samples'} // 0 ) >= 30, 'thirty fits within two hours' );
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
my $fault_guard = 0;
plant_run( $gate, 0.24, 240 )
    while not exists $gate->{'fault'}
    and ++$fault_guard < 30;
ok( exists $gate->{'fault'}, 'doubled true k raises a cooling fault' );
my $k_at_fault = $gate->{'k'};
plant_run( $gate, 0.24, 2400 );
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

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,.,,.,,,..,,,..,,..,,..,.,,,,,.,...,...,.,.,..,,...,...,.,,,,,.,...,,..,,,,,
#LZPLH2CEJO74SJ2NXXKAAFGEIAGLLS2O5GYN6GZMJFJ2NZQM24ZGEMO7JDFCY23XY5BSCJXTKUYUY
#\\\|HLPDYVO2KUS73LXWWQ5XDIN63DJCPOOD6SUE44SJBLEWJUABMH7 \ / AMOS7 \ YOURUM ::
#\[7]TVMVNFSTOILR6LQCPH3ZXZEPC4F26AGS6ISHGUVS57EABPPYHEDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
