
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
        = sprintf( qw| %09.0f |, $ARG[0] ) =~ m|^(0+)|
        ? length($LAST_PAREN_MATCH)
        : 0;
}

return 5;  ###################################################################

#,,..,,..,,.,,,,.,..,,,,.,,..,,,.,..,,..,,,..,..,,...,..,,...,,..,.,,,...,,,,,
#H3GQXGCUDOHO44LEKG4BJS7RZGQN2DPF426NG6F57M2BH2NEZIDSLL5U7EXZ754FRHIMTUJKCNWQG
#\\\|G3B7MNIFCJ47A5XBENUE6BWQV3PEFYSXXLTNYH3XXNCVXEDQVVL \ / AMOS7 \ YOURUM ::
#\[7]3CRQDPKFZW33H4AA3ZJT2KJUEL7EN7LFAQIC4HWRT2TQMCSBHCAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
