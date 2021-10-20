
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

#,,,.,,,,,,..,,,,,,..,...,,.,,,.,,,.,,.,,,,.,,..,,...,...,,..,...,.,.,,,.,..,,
#PF3TDH4A7GY6SWVDPLOCCMEJQY6OODWN5IJ4RIYV7WRDLYXKHKKWYHQBVJOFUX7FMOJPURSFKPBUQ
#\\\|VV7WVA35OKIDDXYFWTRZIPSCT66CFUHC6OIGXFFOVWV5OSZRQTK \ / AMOS7 \ YOURUM ::
#\[7]XXLLITNEPEHWFRJKDG74TMS4AHDTJFOVN7JS2W53TDANXIJFCUBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
