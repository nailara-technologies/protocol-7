
package AMOS::Assert;

BEGIN { use AMOS }

use v5.24;
use strict;
use English;
use warnings;
use AMOS::Assert::Truth;

# print " module version : $VERSION\n"; exit;

use vars qw| $VERSION @EXPORT |;
use Exporter;
use base qw| Exporter |;

@EXPORT = qw| numerical numerical_no_prefix |;

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

return 1;  ###################################################################

#.............................................................................
#D5YGJHP7SC6QXNLBAQUPBNMMLAAOYELQ2TL3CREUBJSANI2IK7YCEKIDZTIEJJHFSQSQFOCM7LWQK
#::: EHCMD62GRBXBBYHPCD3AKF7KKHGDPFGKXFAQXWSNFT3TV27CQVZ :::: NAILARA AMOS :::
# :: N5VB2UGVEFTFLTXGEOP277N52JN7LCI6P6BLP5DTJLTMLGDFCYCA :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
