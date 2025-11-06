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

#,,,.,,.,,.,,,,,.,.,.,,,.,,,.,.,,,,,,,,,,,..,,..,,...,...,,,,,,,,,.,,,,,.,.,,,
#DP25ZLSQ73LXK2MAXRWPEH3HK5MRAF63CCKGCFOKT4NMQ3BCJEAAGBWRED3XLO7HDUMZLV3Y47PJK
#\\\|BWEP7U3FKQZOPQS3RL3NKRUYBTRA32DCXDBWYM3UFFB7NXPYGLH \ / AMOS7 \ YOURUM ::
#\[7]3KPJ3LBUBUULBXQPVHRCWCH6HV3JHUIPX2TDOOLSQUXT5CAUJMDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
