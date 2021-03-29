
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
    my $c_version = sprintf "%.3f", $ntime_dec / 7**16;
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
