package AMOS7::NRT::frame;
our $VERSION = qw| AMOS7::NRT::frame-VERSION.WQTK7QI |;

use v5.32.0;
use strict;
use English;
use warnings;

use Exporter;
use base        qw| Exporter |;
use vars        qw| @EXPORT_OK |;
use Time::HiRes qw| time |;
use Math::BigInt;
use AMOS7::NTIME      qw| unix_to_ntime |;
use AMOS7::cell::time qw| frame |;

@EXPORT_OK = qw| now stamp index clock |;

sub now {
    my $value = $ENV{'NRT_TEST_NTIME'} // unix_to_ntime( time, 0 );
    die "nrt : clock returned no whole ntime\n"
        if not defined $value or $value !~ m|\A[0-9]+\z|;
    return Math::BigInt->new($value)->bstr;
}

sub stamp {
    my $value = shift // '';
    die "nrt : not a whole 14 digit ntime [ $value ]\n"
        if $value !~ m|\A[0-9]{1,14}\z|;
    return ( '0' x ( 14 - length $value ) ) . $value;
}

sub index {
    my ( $ntime, $level ) = @ARG;
    die "nrt : frame level is not 0 .. 7\n"
        if not defined $level or $level !~ m|\A[0-7]\z|;
    my $index = frame( $ntime, $level );
    die "nrt : cannot derive frame from ntime\n" if not defined $index;
    return $index;
}

sub clock {
    my ( $last, %opt ) = @ARG;
    my $now = Math::BigInt->new( now() );
    if ( defined $last and length $last ) {
        my $previous = Math::BigInt->new($last);
        die "nrt : clock is behind the last record [ use -accept-clock ]\n"
            if $now->bcmp($previous) < 0 and not $opt{'accept_clock'};
        $now = $previous->copy if $now->bcmp($previous) < 0;
    }
    return stamp( $now->bstr );
}

1;

#,,,,,..,,,.,,...,...,,..,,..,,.,,...,,,,,.,,,..,,...,...,.,,,.,,,,,,,.,,,,,.,
#3LYNPKRIBH4UJQWVN6VTI55NJER2BAPI4UY5UM6J6QWHCU7TGGSB5XMJ3WE6ND6VPWISNHZXWVNVK
#\\\|SMTOI4PEZN65PE6GS4PCWP5FQY4XSMKQQRHRGNL2UXJCJHN3NWJ \ / AMOS7 \ YOURUM ::
#\[7]SY5L53BWZFN74H7UVOTLKMWTEOOYZWQXTIPLILRVTXBEFV6O6YCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
