#!/usr/bin/perl
use v5.24;
use strict;
use warnings;
use English;

###                                      ###
## thermal gate : standalone regression  ##
###                                      ###

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

compile_module('thermal.gate.sample');
compile_module('thermal.gate.decide');

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

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,..,,..,,..,...,..,,,..,,,,,,.,,..,,,..,..,,..,,...,...,.,.,...,,.,,...,.,.,
#QRD34423NUY6VWWT6YRU7Q2XUV6X37RRJT7JKEP4NMUN65N2ASM4TXHFIVTSPRUVKI2WJ64UPZA7C
#\\\|DBRWHMRB7SMPISX4X4QHEO7QDVQLPFUURP2LFLVOE4KPE2S5TMR \ / AMOS7 \ YOURUM ::
#\[7]Y27CWJDCKBNFX6TOMKUIGYWRCZTAVT37KQVRRQY7IUIOML544SAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
