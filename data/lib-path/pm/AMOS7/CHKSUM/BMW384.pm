## [:< ##

package AMOS7::CHKSUM::BMW384;  ##############################################

use v5.24;
use strict;
use English;
use warnings;

##[ global constants ]##
use constant TRUE  => 5;        ##  TRUE.  ##
use constant FALSE => 0;        ##  false  ##

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT $VERSION |;

use Digest::BMW;
use Math::BigInt;

$VERSION = qw| AMOS7::CHKSUM::BMW384-VERSION.7UA5BUI |;

@EXPORT = qw|
    bmw384_color
    bmw384_angle_bits
    bmw384_color_dist
    bmw384_arc_segment
    bmw384_group
    bmw384_coordinate
    bmw384_coordinate_str
    |;

##[ COLOR EXTRACTION ]########################################################

sub bmw384_color {

    my $digest_bytes = shift;

    return warn 'expected 48-byte digest <{C1}>'
        if not defined $digest_bytes
        or length $digest_bytes != 48;

    my $color = 0;
    for my $i ( 0 .. 23 ) {
        $color = ( $color << 1 ) | vec( $digest_bytes, $i, 1 );
    }
    return $color;
}

##[ ANGLE BITSTRING EXTRACTION ]##############################################

sub bmw384_angle_bits {

    my $digest_bytes = shift;

    return warn 'expected 48-byte digest <{C1}>'
        if not defined $digest_bytes
        or length $digest_bytes != 48;

    my $angle_str = '';
    for my $i ( 24 .. 383 ) {
        $angle_str .= vec( $digest_bytes, $i, 1 );
    }
    return $angle_str;
}

##[ CLOSED-WHEEL COLOR DISTANCE ]#############################################

sub bmw384_color_dist {

    my $color_a = shift;
    my $color_b = shift;

    return warn 'color values must be defined <{C1}>'
        if not defined $color_a
        or not defined $color_b;

    my $max  = 2**24;
    my $diff = abs( $color_a - $color_b );
    return $diff < $max / 2 ? $diff : $max - $diff;
}

##[ ARC SEGMENT MAPPING ]#####################################################

sub bmw384_arc_segment {

    my $color = shift;

    return warn 'color value must be defined <{C1}>'
        if not defined $color;

    my $segment = int( $color / ( 2**24 / 26 ) );
    return $segment > 25 ? 25 : $segment;
}

##[ GROUP BY COLOR PROXIMITY ]################################################

sub bmw384_group {

    my $center_color = shift;
    my $radius       = shift;

    return warn 'center color and radius required <{C1}>'
        if not defined $center_color
        or not defined $radius;

    my @result;
    for my $digest (@ARG) {
        next
            if not defined $digest
            or length $digest != 48;
        my $color = bmw384_color($digest);
        push @result, $digest
            if bmw384_color_dist( $center_color, $color ) <= $radius;
    }
    return \@result;
}

##[ UNIVERSAL NODE COORDINATE ]###############################################

sub bmw384_coordinate {

    my $input = shift;

    return warn 'input must be defined <{C1}>'
        if not defined $input;

    my $bmw = Digest::BMW->new(384);
    $bmw->add($input);
    my $digest = $bmw->digest;

    my $color = bmw384_color($digest);
    my $arc   = bmw384_arc_segment($color);

    my $angle_bits = bmw384_angle_bits($digest);
    my $angle_int  = Math::BigInt->new( '0b' . $angle_bits );

    return {
        qw| color         | => $color,
        qw| arc           | => $arc,
        qw| segment_label | => chr( ord('A') + $arc ),
        qw| angle_bits    | => $angle_bits,
        qw| angle_int     | => $angle_int,
        qw| digest        | => $digest,
    };
}

##[ COMPACT COORDINATE STRING ]###############################################

sub bmw384_coordinate_str {

    my $input = shift;

    return warn 'input must be defined <{C1}>'
        if not defined $input;

    my $coord = bmw384_coordinate($input);

    return sprintf '%s:%06X:%s',
        $coord->{'segment_label'},
        $coord->{'color'},
        substr( $coord->{'angle_bits'}, 0, 16 );
}

return TRUE ##################################################################

#,,,.,,..,...,.,,,,,.,.,,,...,..,,,,.,,.,,.,.,..,,...,..,,,,,,,.,,..,,,..,.,.,
#3UNCOXFLBV4DGAQ6XZAGM3XZSVWCW7VZL26WS437E4CWXTJXO6QFXIMPIJWO5GPKYO2WA46HNUTHG
#\\\|EDYWUGSYO5J7EAYPPZQ5WJGAW2G5OZOP32Y5A47VDLYNFYAGZMB \ / AMOS7 \ YOURUM ::
#\[7]NHS2O5T4KOJPX6INRNPZCOVXTUBUUEP27LMAGWBMAGUQ37XK44DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
