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

#,,,.,,.,,,,,,.,.,,,,,.,.,,,,,,,,,.,.,,,,,,,.,..,,...,...,...,,,.,..,,,,,,,,,,
#INNZDRYJ7TJ5X254IZPAXHPRKNC7J72Z5UXG6EMVZEVSXYQG3FP2X7YGOROW2RWAM7C4QJTKNYFYA
#\\\|F5UWKEBQOU6QYYTIACBQKQ6GVUDGXK72ORH35WBTOMDNONME3KQ \ / AMOS7 \ YOURUM ::
#\[7]OOWUPETQHT53IAGG3U7ORCCB432TRZ34ZBRD2PLRNNBJN6QGSKBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
