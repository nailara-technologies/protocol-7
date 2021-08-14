
package AMOS7::Assert;  ######################################################

use v5.24;
use strict;
use English;
use warnings;
use Exporter;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

use AMOS7::Assert::Truth;

use base qw| Exporter |;
use vars qw| $VERSION @EXPORT |;

@EXPORT = qw[ is_number numerical_no_0_prefix zulum_prefix_length ];

##[ is_number ASSERTIONS ]####################################################

sub is_number {
    return ( not defined $ARG[0] or $ARG[0] !~ m{^\d+(\.\d+)?(e\+\d+)?$} )
        ? FALSE
        : TRUE;
}

sub numerical_no_0_prefix {
    return (
        not defined $ARG[0]
            or $ARG[0] !~ m{^(0+|[1-9]\d*)(\.\d+)?(e\+\d+)?$}
        )
        ? FALSE
        : TRUE;
}

sub zulum_prefix_length {
    return 0 if not defined $ARG[0];
    my $num_len
        = sprintf( qw| %09.0f |, $ARG[0] ) =~ m|^(0+)|
        ? length($LAST_PAREN_MATCH)
        : 0;
}

return TRUE ##################################################################

#,,,.,,,,,,..,,,,,,..,...,,.,,,.,,,.,,.,,,,.,,..,,...,...,..,,...,.,,,,.,,...,
#4LMA6E2Q72U4SRBSOE7P7TQCFVUDKSDB4SQSQHS4MZVARANXNXIA3S2XUOEHXFHYXC4Z7FSJICNGA
#\\\|ZQBGCXPN2UGIQAUC5I6KA37A3EWI2DDETJSXZNWMEVMLUKDKQPV \ / AMOS7 \ YOURUM ::
#\[7]OL6KSDZQUZ6T3OHHC6PEIPMRG2EUIHEQIV7ITNP5CTVW23LFEEDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
