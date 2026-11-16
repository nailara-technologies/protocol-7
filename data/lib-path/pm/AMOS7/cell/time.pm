## [:< ##

package AMOS7::cell::time;    ##############################################
our $VERSION = qw| AMOS7::cell::time-VERSION.7SG2XTY |;

## exact Y-grid frames [ one ntime year is 4200 * 86400 * 365 units ] ##

use v5.32.0;
use strict;
use English;
use warnings;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK |;

use Math::BigInt;
use Math::BigRat;

use constant NTIME_YEAR   => 132451200000;
use constant EPOCHS_TOTAL => 385280;

@EXPORT_OK = qw| NTIME_YEAR EPOCHS_TOTAL frame window path |;

sub frame {
    my $ntime = shift // return undef;
    my $level = shift // return undef;
    return undef if $ntime !~ m|\A\d+(?:\.\d+)?\z|;
    return undef if $level !~ m|\A[0-7]\z|;

    my $factor = Math::BigInt->new(13)->bpow($level);
    return Math::BigInt->new($ntime)
        ->bmul($factor)
        ->bdiv( Math::BigInt->new(NTIME_YEAR) )
        ->bstr()
        if index( $ntime, qw| . | ) == -1;

    my $value
        = Math::BigRat->new($ntime)
        ->bmul($factor)
        ->bdiv( Math::BigInt->new(NTIME_YEAR) )
        ->bfloor();
    return $value->as_int()->bstr();
}

sub window {
    my $current = @ARG == 1 ? shift : frame(@ARG);
    return if not defined $current or $current !~ m|\A\d+\z|;
    $current = Math::BigInt->new($current)
        ->bmod( Math::BigInt->new(EPOCHS_TOTAL) );
    my $previous
        = $current->copy()->bsub(1)->bmod( Math::BigInt->new(EPOCHS_TOTAL) );
    my $next
        = $current->copy()->badd(1)->bmod( Math::BigInt->new(EPOCHS_TOTAL) );
    return map { $ARG->bstr() } $previous, $current, $next;
}

sub path {
    my $ntime = shift                   // return;
    my $level = shift                   // return;
    my $index = frame( $ntime, $level ) // return;

    my $base  = Math::BigInt->new(13);
    my $value = Math::BigInt->new($index);
    my @path;
    while ( $value->is_pos() ) {
        unshift @path, $value->copy()->bmod($base)->numify();
        $value->bdiv($base);
    }
    return (0) if not @path;
    return @path;
}

1;

#,,.,,.,.,.,.,,.,,,,,,,,,,,..,,,.,,.,,,,,,..,,..,,...,...,,..,,,.,,,,,..,,,,,,
#HH7AHZR6ZD5RMK3ONLTRGX7I33NMIFF5MM6UIDQNGDLON3H2YGLZ2GZ4KNPWPGB4EWXVA5ZWYBK7C
#\\\|7PZD6RZJPWCJK6XGTZLPEBK6OROBHNS6OCXTPOKVAQOSUNAIMLU \ / AMOS7 \ YOURUM ::
#\[7]XGCCCFRZO2H23EATF2IXGWCPPFBJ4YXQSO7TNQ765NT54ABAVECA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
