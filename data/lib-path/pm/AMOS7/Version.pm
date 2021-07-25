
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

#,,,.,,.,,,,,,,,,,,..,,,,,,,,,..,,,,,,,.,,,,,,..,,...,..,,.,,,,..,,..,.,.,.,.,
#BWF35KZDDRAIDHFJ3AKVFHZJLNWTFWZOOEXYENP5RUA76KFA7AEPD62J37BPSZWXGAATPFGFT3W6K
#\\\|CGYEF5QVDPPOP6YHFJKU4KAAGBJK7XS2TLXKDBTLVMBVQDIG5NU \ / AMOS7 \ YOURUM ::
#\[7]ITPV25HXQ66BNIBAS3L2ML3NCN6VJJLMS3VAPCSLVOKNZNMEECBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
