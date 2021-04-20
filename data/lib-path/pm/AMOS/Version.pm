
## include for calculating new version ##

package AMOS::Version;  ######################################################

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

#.............................................................................
#AFKZGGEU3RDYMRH4PWYOSES7L4LV7HQLULXLNLFSQJAPVTTZY3KUPM54GHOR2BXYR2EKHCOCOCWYU
#::: N2UABJSHKBMMECGV2P7HH5N2QRDW7MRCA7WW3RVZMFHUDN653G3 :::: NAILARA AMOS :::
# :: 34C43NQBRLJMVO4C6DBJJGACJVHP5XUO5E74DEEPA7HB7EGERUAA :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
