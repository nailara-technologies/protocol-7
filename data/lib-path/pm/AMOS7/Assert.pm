
package AMOS7::Assert;  ######################################################

use v5.24;
use strict;
use English;
use warnings;
use Exporter;

use AMOS7::Assert::Truth;

use base qw| Exporter |;
use vars qw| $VERSION @EXPORT |;

@EXPORT = qw[ is_number numerical_no_0_prefix zulum_prefix_length ];

##[ is_number ASSERTIONS ]####################################################

sub is_number {
    return ( not defined $ARG[0] or $ARG[0] !~ m{^\d+(\.\d+)?$} )
        ? 0
        : 1;
}

sub numerical_no_0_prefix {
    return ( not defined $ARG[0] or $ARG[0] !~ m{^(0+|[1-9]\d*)(\.\d+)?$} )
        ? 0
        : 1;
}

sub zulum_prefix_length {
    return 0 if not defined $ARG[0];
    my $num_len
        = sprintf( '%09.0f', $ARG[0] ) =~ m|^(0+)|
        ? length($LAST_PAREN_MATCH)
        : 0;
}

return 1;  ###################################################################

#,,,,,..,,,,,,.,.,..,,,.,,,,,,.,.,,.,,..,,...,..,,...,...,.,,,,.,,.,,,.,.,..,,
#WL43OYTO7BVO3WLBTMRMOJZJCHPZJWM6ELVHA275QP7QQQ2Y3OMXIOGS22QSNM4725YQ7VMOFT6V2
#\\\|5K4MHYI2NV6CAE5XUHXLA6IOQTGYSJU3O3HKBVDVR2WMSRMR4CX \ / AMOS7 \ YOURUM ::
#\[7]FW5DBZVDWYGUMHNLT7LUTEHHVVWZVLLR5WAFJ2ZC4EZWSMAKZKBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
