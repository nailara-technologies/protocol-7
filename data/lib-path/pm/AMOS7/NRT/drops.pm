package AMOS7::NRT::drops;
our $VERSION = qw| AMOS7::NRT::drops-VERSION.WEP4HFQ |;

use v5.32.0;
use strict;
use English;
use warnings;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK |;
use Math::BigInt;

use constant MAX_DROPS => '9999999999999';

@EXPORT_OK = qw| MAX_DROPS integer amount bounded add subtract multiply
    divide pair |;

sub integer {
    my ( $value, $signed ) = @ARG;
    $value //= '';
    my $pattern
        = $signed
        ? qr{\A(?:0|-?[1-9][0-9]*)\z}
        : qr{\A(?:0|[1-9][0-9]*)\z};
    die "nrt : not a canonical integer [ $value ]\n"
        if ref $value or $value !~ $pattern;
    return Math::BigInt->new($value);
}

sub amount {
    my $value = shift // '';
    die "nrt : drops must be a positive canonical integer [ $value ]\n"
        if ref $value or $value !~ m|\A[1-9][0-9]*\z|;
    my $amount = Math::BigInt->new($value);
    die 'nrt : drops exceed the 9999999999999 drop bound' . "\n"
        if $amount->bcmp( Math::BigInt->new(MAX_DROPS) ) > 0;
    return $amount;
}

sub bounded {
    my ( $value, $negative ) = @ARG;
    my $number = ref $value ? $value->copy : integer( $value, $negative );
    my $bound  = Math::BigInt->new(MAX_DROPS);
    die 'nrt : balance exceeds the 9999999999999 drop bound' . "\n"
        if $number->copy->babs->bcmp($bound) > 0;
    die "nrt : balance is below zero\n"
        if not $negative and $number->is_neg;
    return $number;
}

sub add {
    my @values = @ARG;
    my $sum    = Math::BigInt->bzero;
    $sum->badd( integer( $ARG, 1 ) ) for @values;
    return $sum;
}

sub subtract {
    my ( $left, $right ) = @ARG;
    return integer( $left, 1 )->bsub( integer( $right, 1 ) );
}

sub multiply {
    my ( $left, $right ) = @ARG;
    return integer($left)->bmul( integer($right) );
}

sub divide {
    my ( $left, $right, $carry ) = @ARG;
    my $divisor = amount($right);
    my $total   = integer($left)->badd( integer( $carry // 0 ) );
    my ( $whole, $rest ) = $total->bdiv($divisor);
    return ( $whole, $rest );
}

sub pair {
    my $value = shift // '';
    my ( $drops, $units ) = split m|\s*:\s*|, $value, -1;
    die "nrt : expected drops : units [ $value ]\n"
        if not defined $units or $value =~ m|:.*:|;
    return ( amount($drops), amount($units) );
}

1;

#,,..,,.,,.,.,,.,,...,,,,,...,,,,,,,,,.,.,.,,,..,,...,...,.,.,.,,,,..,,..,.,,,
#UPSBRPYGJNWFRICX474FNQZB4JTTU3XIO4H3DLXAPZGRRTPZHSAVPZIWYMXBA73HNGMQ4MHWOL622
#\\\|TBTPJPT2UJF2DSFKXCS2RQSIU2DK5BYQQICR2ZN4MXLOLVQG5G2 \ / AMOS7 \ YOURUM ::
#\[7]NTUJJGUUHZ3TM2UAZSAGCQZFK7IVF44764EHLRFKBV3CFWADYSAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
