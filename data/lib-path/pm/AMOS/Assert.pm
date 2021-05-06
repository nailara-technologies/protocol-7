
package AMOS::Assert;   ######################################################

use v5.24;
use strict;
use English;
use warnings;
use Exporter;

use AMOS::Assert::Truth;

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

#.............................................................................
#PMXX3USQYG2UDFMMMXVJKN23EXAMNV7FFMEHCW4I6GS6IYYXXWKZIC7BWG4DWVFCZ7CIEXPJ2EMQE
#::: TRVU2RZU5ZN4C4Q6ASWRHPWXY2MYN3OJ7VILTD2ERGKRKOXODG3 :::: NAILARA AMOS :::
# :: M3WGCGJMJ4GO2L2WCULMRW2CMII4QNUAH2H7VBNI3ZGJVRKDLKAI :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
