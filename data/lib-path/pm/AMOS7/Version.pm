
## include for calculating new version ##

package AMOS7::Version; ######################################################

BEGIN {
    use strict;
    use English;
    use warnings;
}

our $VERSION = calc_version( calc_ntime() );

use Exporter;
use base qw| Exporter |;
use vars qw| $VERSION @EXPORT |;

@EXPORT = qw| $VERSION |;

printf( ":\n: our \$VERSION = qw| AMOS-MODULE-%s |;\n:\n", $VERSION );

return 1;  ###################################################################

sub calc_version {
    ( my $ntime_dec = shift ) =~ s|\D+||;
    my $c_version = sprintf( "%.3f", ( $ntime_dec / 7**14 ) - 3.6 ); #[magic]#

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

#,,,,,,,,,...,,..,...,.,,,,..,,.,,,.,,,,.,.,.,..,,...,...,,..,..,,.,,,,,,,,.,,
#X3KODGCN4WSOAIL37YIAI6S5QEY3NE7YFDSXDJ5WPOI3247FFLWK33ZN4DIZYOYSMALTDX53UFG5Q
#\\\|XWXU6M4QAI5VIECNCE2SV2G5MVKXZZVKHU4FKF7RKW6WLO7G2R2 \ / AMOS7 \ YOURUM ::
#\[7]SBTBU7LHI72RER67OJ44DDZVIYCL325JZ2EX4PW35Q7WRBSQKCCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
