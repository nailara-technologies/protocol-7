
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
    return ( not defined $ARG[0] or $ARG[0] !~ m{^\d+(\.\d+)?$} )
        ? FALSE
        : TRUE;
}

sub numerical_no_0_prefix {
    return ( not defined $ARG[0] or $ARG[0] !~ m{^(0+|[1-9]\d*)(\.\d+)?$} )
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

#,,,,,...,.,,,,,,,,,.,,.,,,,,,...,..,,...,.,,,..,,...,...,..,,,,.,,.,,,..,,..,
#MMUR7DLIJSNSSHYXJWNW4SQEIH3EAMSZYG2Q5KUEQP7VTRHPK4UHQ2YLIN5QZ2TJBBRYR2TJHL4K4
#\\\|LFQBLZTONS6PCRKGXCHZPJ5KHIG53QZTE64RXSFDTIJ4NMWRC6X \ / AMOS7 \ YOURUM ::
#\[7]FAZAFGUUIPLRB7WZB55O6NRWGCEP3A3TUEQOOKFE7MLUK3YAO2CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
