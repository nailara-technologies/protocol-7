
package AMOS::Assert;   ######################################################

# BEGIN { use AMOS }

use v5.24;
use strict;
use English;
use warnings;
use AMOS::Assert::Truth;

use base qw| AMOS |;

use vars qw| $VERSION @EXPORT |;
use Exporter;
use base qw| Exporter |;

@EXPORT = qw[ numerical numerical_no_prefix zulum_prefix_length ];

##[ NUMERICAL ASSERTIONS ]####################################################

sub numerical {
    return ( not defined $ARG[0] or $ARG[0] !~ m{^\d+(\.\d+)?$} )
        ? 0
        : 1;
}

sub numerical_no_prefix {
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
#UHVKPB72PII23TSPPCOM7E3RMZZ6ORZRPJ2P6TEUV6CYI2LNVQ5RS47RBWFTCBN25RJAEJJFTBVDK
#::: LAPWEBABFLW3BLJ2THMMCAD5UVGKZ2H7LGLLX4B5C3H422TL5GA :::: NAILARA AMOS :::
# :: DYO66SDBOB2332BRIU5BBIU2ICXSPUHEYLRVNEKYI6FU7743FOAA :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
