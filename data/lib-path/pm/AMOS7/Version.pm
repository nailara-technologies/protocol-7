## [:< ##

## include for calculating new version ##

##  todo  :  rewrite using AMOS7::TEMPLATE functionality  ##

package AMOS7::Version; ######################################################

BEGIN {
    use strict;
    use English;
    use warnings;
}

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

our $VERSION = calc_version( calc_ntime() );

use Exporter;
use base qw| Exporter |;
use vars qw| $VERSION @EXPORT |;

@EXPORT = qw| $VERSION |;

printf ":\n: our \$VERSION = qw| AMOS-MODULE-%s |;\n:\n", $VERSION;

sub calc_version {
    ( my $ntime_val = shift ) =~ s|\D+||;
    my $c_version = sprintf( '%.3f', ( $ntime_val / 7**14 ) - 3.6 ); #[magic]#

    $c_version =~ s|\d{2}$|\.$MATCH|;
    $c_version =~ s|0$||;
    return $c_version;
}

sub calc_ntime {    # [ network time : secs from 2002-06-05 * 4200 ]
    my $precision      = 0;
    my $ntime_start    = 1023228000;
    my $unix_precision = $precision + 2;
    my $unix_time      = sprintf( "%.0${unix_precision}f", time() );
    my $ntime          = sprintf( "%.0${precision}f",
        ( ( $unix_time - $ntime_start ) * 4200 ) );

    return $ntime;
}

return TRUE ##################################################################

#,,,.,,.,,,,,,.,.,,,,,.,.,,,,,,,,,.,.,,,,,,,.,..,,...,...,.,,,...,,.,,...,,.,,
#FDAR5CE4IO2G5INOAYKCYWXTQHF45XEURFEC7TUAA4MA3MFR7UMOLRL3JGXJBUH4SUAW5CU5Z7EIK
#\\\|I6N3HC5ENF4EGZRZ7PHYECMOSWPNJQNIMCTDKYKTJZPWA7G6TXC \ / AMOS7 \ YOURUM ::
#\[7]RPPG66GOK7M6KPLYFQ6SVEPLRQFUY5OXQPOYW2RSCKAG2S6LN6CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
