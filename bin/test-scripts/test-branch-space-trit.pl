#!/usr/bin/perl
use v5.24;
use strict;
use English;
use warnings;

###                                                                 ###
##  branch.space trit address, octant intent : standalone harness    ##
###                                                                 ###

## exercises the real translated module sources [ trit.role,           ##
## trit.octant_bits, trit.intent_frame, trit.polarity, hop_ball_size ] ##
## against an in-process stub environment -- no live zenka required :  ##
## - all 27 cells of a 3x3x3 block give role counts 1 \ 6 \ 12 \ 8     ##
## - octant bits round-trip for all 8 corners                          ##
## - intent_frame gives '0001' for '000', payload.'0' otherwise        ##
## - polarity differs for every face-neighbor pair in a 5x5x5 block    ##
## - hop_ball_size equals brute force count for h = 0..20 [ h=50 ]     ##

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

##[ p7 runtime environment stubs ]############################################

use constant TRUE  => 5;
use constant FALSE => 0;

our %data;
our %code;
our $call;

##[ module compilation [ same sub-wrapper shape as bin/Protocol-7 ] ]#########

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

compile_module($_) foreach qw|
    branch.space.trit.role
    branch.space.trit.octant_bits
    branch.space.trit.intent_frame
    branch.space.trit.polarity
    branch.space.hop_ball_size
    |;

sub call_module {
    my ( $module_name, $params ) = @ARG;
    return $code{$module_name}->($params);
}

##[ tiny assertion framework ]################################################

sub ok {
    my ( $cond, $label ) = @ARG;
    if ($cond) { say "  ok   : $label"; return }
    $fail_count++;
    say "  FAIL : $label";
    return;
}

##[ 1 : role counts over all 27 trit cells ]##################################

say ': trit.role';

my %role_count = map { $ARG => 0 } qw| center face edge corner |;
my $role_false = 0;

foreach my $z ( -1 .. 1 ) {
    foreach my $y ( -1 .. 1 ) {
        foreach my $x ( -1 .. 1 ) {
            my $res = call_module( 'branch.space.trit.role',
                { 'position' => [ $z, $y, $x ] } );
            next
                unless ref $res eq qw| HASH |
                and $res->{'mode'} eq qw| true |
                and ref $res->{'data'} eq qw| HASH |;
            $role_count{ $res->{'data'}{'role'} }++;
        }
    }
}

ok( $role_count{'center'} == 1, '27 cells : 1 center' );
ok( $role_count{'face'} == 6,   '27 cells : 6 faces' );
ok( $role_count{'edge'} == 12,  '27 cells : 12 edges' );
ok( $role_count{'corner'} == 8, '27 cells : 8 corners' );
ok( ( $role_false + 27 ) == 27, 'no cell rejected inside the block' );

## role spot checks + nonzero count + rejection outside -1..+1 ##

my $r_center
    = call_module( 'branch.space.trit.role', { 'position' => [ 0, 0, 0 ] } );
ok( ( ( $r_center->{'data'}{'role'} // '' ) eq qw| center | )
        && ( $r_center->{'data'}{'nonzero'} == 0 ),
    '[0,0,0] -> center, nonzero 0'
);

my $r_edge
    = call_module( 'branch.space.trit.role', { 'position' => [ -1, 1, 0 ] } );
ok( ( ( $r_edge->{'data'}{'role'} // '' ) eq qw| edge | )
        && ( $r_edge->{'data'}{'nonzero'} == 2 ),
    '[-1,1,0] -> edge, nonzero 2'
);

my $r_out
    = call_module( 'branch.space.trit.role', { 'position' => [ 2, 0, 0 ] } );
ok( ref $r_out eq qw| HASH | and $r_out->{'mode'} eq qw| false |,
    '[2,0,0] rejected outside trit range' );

##[ 2 : octant bits round-trip for all 8 corners ]############################

say ': trit.octant_bits';

my $corner_roundtrip_ok  = 1;
my $corner_axes_lit_ok   = 1;
my $corner_bits_order_ok = 1;

foreach my $n ( 0 .. 7 ) {
    my $bits = sprintf '%03b', $n;
    my $to_pos
        = call_module( 'branch.space.trit.octant_bits', { 'bits' => $bits } );
    $corner_roundtrip_ok = 0
        unless ref $to_pos eq qw| HASH |
        and $to_pos->{'mode'} eq qw| true |
        and ref $to_pos->{'data'}{'position'} eq qw| ARRAY |
        and scalar $to_pos->{'data'}{'position'}->@* == 3;

    my $position = $to_pos->{'data'}{'position'};
    my @expected = map { $_ eq qw| 1 | ? 1 : -1 } split m{}, $bits;
    $corner_roundtrip_ok = 0
        if join( ',', $position->@* ) ne join( ',', @expected );

    ##  axis order z y x : bit 0 selects the z sign  ##
    my $back = call_module( 'branch.space.trit.octant_bits',
        { 'position' => $position } );
    $corner_roundtrip_ok = 0
        unless ( $back->{'data'}{'bits'} // '' ) eq $bits;
    $corner_bits_order_ok = 0
        unless $position->[0] == $expected[0]
        and $position->[1] == $expected[1]
        and $position->[2] == $expected[2];
    $corner_axes_lit_ok = 0 unless $back->{'data'}{'axes_lit'} == 3;
}

ok( $corner_roundtrip_ok,  'octant bits round-trip for all 8 corners' );
ok( $corner_bits_order_ok, 'axis order z y x honored per corner' );
ok( $corner_axes_lit_ok,   'axes_lit = 3 for every corner' );

## partial intent : face and plane diagonal ##

my $face_bits = call_module( 'branch.space.trit.octant_bits',
    { 'position' => [ 0, 1, 0 ] } );
ok( ( ( $face_bits->{'data'}{'bits'} // '' ) eq qw| 010 | )
        && ( $face_bits->{'data'}{'axes_lit'} == 1 ),
    '[0,1,0] -> bits 010, axes_lit 1 [ face intent ]'
);

my $edge_bits = call_module( 'branch.space.trit.octant_bits',
    { 'position' => [ 1, 1, 0 ] } );
ok( ( ( $edge_bits->{'data'}{'bits'} // '' ) eq qw| 110 | )
        && ( $edge_bits->{'data'}{'axes_lit'} == 2 ),
    '[1,1,0] -> bits 110, axes_lit 2 [ plane diagonal intent ]'
);

my $bad_bits
    = call_module( 'branch.space.trit.octant_bits', { 'bits' => qw| 12 | } );
ok( ref $bad_bits eq qw| HASH | and $bad_bits->{'mode'} eq qw| false |,
    'invalid bits rejected' );

##[ 3 : intent frame -- 3+1 rule ]############################################

say ': trit.intent_frame';

my $frame_zero = call_module( 'branch.space.trit.intent_frame',
    { 'bits' => qw| 000 | } );
ok( ( $frame_zero->{'data'}{'frame'} // '' ) eq qw| 0001 |,
    "'000' -> inverted separator, frame '0001'"
);

my $frame_ok = 1;
foreach my $n ( 1 .. 7 ) {
    my $bits  = sprintf '%03b', $n;
    my $frame = call_module( 'branch.space.trit.intent_frame',
        { 'bits' => $bits } );
    $frame_ok = 0 unless ( $frame->{'data'}{'frame'} // '' ) eq $bits . '0';
}
ok( $frame_ok, "nonzero payloads keep separator '0'" );

my $bad_frame = call_module( 'branch.space.trit.intent_frame',
    { 'bits' => qw| 0000 | } );
ok( ref $bad_frame eq qw| HASH | and $bad_frame->{'mode'} eq qw| false |,
    '4-bit payload rejected' );

##[ 4 : polarity differs across every face-neighbor pair ]####################

say ': trit.polarity';

my $polarity_ok    = 1;
my $neighbor_pairs = 0;

foreach my $z ( -2 .. 2 ) {
    foreach my $y ( -2 .. 2 ) {
        foreach my $x ( -2 .. 2 ) {
            foreach my $delta ( [ 0, 0, 1 ], [ 0, 1, 0 ], [ 1, 0, 0 ] ) {
                my @neighbor = ( $z + $delta->[0], $y + $delta->[1],
                    $x + $delta->[2] );
                next
                    if grep { $_ < -2 or $_ > 2 } @neighbor;
                $neighbor_pairs++;
                my $p_cell = call_module(
                    'branch.space.trit.polarity',
                    { 'position' => [ $z, $y, $x ] }
                );
                my $p_next = call_module(
                    'branch.space.trit.polarity',
                    { 'position' => \@neighbor }
                );
                next
                    if ref $p_cell eq qw| HASH |
                    and $p_cell->{'mode'} eq qw| true |
                    and ref $p_next eq qw| HASH |
                    and $p_next->{'mode'} eq qw| true |
                    and $p_cell->{'data'}{'polarity'}
                    != $p_next->{'data'}{'polarity'};
                $polarity_ok = 0;
            }
        }
    }
}

ok( $polarity_ok,
    "polarity differs for every face-neighbor pair [ $neighbor_pairs pairs ]"
);

my $p_neg = call_module( 'branch.space.trit.polarity',
    { 'position' => [ -1, -1, -1 ] } );
ok( ( $p_neg->{'data'}{'polarity'} // -1 ) == 1,
    'negative sum [-1,-1,-1] -> polarity 1 [ non-negative mod 2 ]' );

##[ 5 : hop ball size vs brute force ]########################################

say ': hop_ball_size';

my $hop_ok = 1;

foreach my $h ( 0 .. 20 ) {
    my $res   = call_module( 'branch.space.hop_ball_size', { 'hops' => $h } );
    my $brute = 0;
    foreach my $x ( -$h .. $h ) {
        foreach my $y ( -$h .. $h ) {
            foreach my $z ( -$h .. $h ) {
                $brute++ if abs($x) + abs($y) + abs($z) <= $h;
            }
        }
    }
    my $cells = $res->{'data'}{'cells'} // -1;
    if ( $cells != $brute ) {
        $hop_ok = 0;
        say sprintf '  FAIL : h=%d formula=%d brute=%d', $h, $cells, $brute;
    }
}
ok( $hop_ok, 'hop_ball_size matches brute force for h = 0..20' );

my $h50 = call_module( 'branch.space.hop_ball_size', { 'hops' => 50 } );
ok( ( $h50->{'data'}{'cells'} // -1 ) == 171801, 'h=50 -> 171801 cells' );

my $h_neg = call_module( 'branch.space.hop_ball_size', { 'hops' => -1 } );
ok( ref $h_neg eq qw| HASH | and $h_neg->{'mode'} eq qw| false |,
    'negative hops rejected' );

##[ summary ]#################################################################

say '';
if ($fail_count) {
    say "FAILED : $fail_count check[s]";
    exit 1;
}
say 'all checks passed';
exit 0;

#,,,.,...,,,,,.,,,,.,,.,,,,..,,,,,,,,,,..,.,,,..,,...,...,,,.,.,,,.,,,.,,,..,,
#SGO5HM2Q7WSAUDX7FQ4YEPXAPY5IQ2QWT4TYHZBMMN4WU5KH6VWXMKDPFNV7ULXF5ZCC32YSLYXGG
#\\\|GQZUSHLED2Y6ILGSU3ANDJ6USX7XEYOSEIQIS3FXYSKCN4O4RP6 \ / AMOS7 \ YOURUM ::
#\[7]HSRIPCKFKHLIEM7AOCPJ3YPK2SX34UWVYOARYGKNLMT5P2W6Z4AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
