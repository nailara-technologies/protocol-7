
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

#,,,,,.,.,,..,,,.,.,.,,.,,,..,,,.,.,,,,.,,.,,,..,,...,...,,,.,.,,,,.,,...,.,.,
#NJ7L6TFCLVN5JWKJG32TBJWMX75X65SLEJKOMOQFP4EQSCO53DOKPCSY66HXF7YM6BDZ7CMHEIUHM
#\\\|2VBEERT5E2UPPLOR3DSWVYITX22PRDJORLH75SKYVKX2F6MZKPQ \ / AMOS7 \ YOURUM ::
#\[7]W2QCT2NPNLJIYDR3YQFWDTVWU62HFXQLS6SBJQIJETYIRQLAKEAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
