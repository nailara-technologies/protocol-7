
## include for calculating new version ##

package AMOS::Version;

BEGIN {
    use strict;
    use English;
    use warnings;
}

our $VERSION = calc_version( calc_ntime() );

printf ":\n:: our \$VERSION = '%s';\n:\n", $VERSION and exit;

return 1;

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
#MNDI7BWDVX3FE7BUB5S2WBDGCP3TSPLEDHBLYVM4YSCYSSLKRRB43L3EW75XE6W4L4ECLJ6453UE4
#::: ATLJUDEVH5OG2O2DUD447NIZMG4R74BFU7266WGNPQB4GZHLDD5 :::: NAILARA AMOS :::
# :: QFIS4QDYBM4DGU3JFIMHEBKPYAN3KKTI2RQ5TG3ID6SMWSKF3UCY :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
