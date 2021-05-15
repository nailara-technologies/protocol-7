
package AMOS::INLINE::src::BinConversion;  ###################################

## [ target package name : AMOS::BinConversion ] ##

use strict;
use English;
use warnings;

use vars qw| @EXPORT |;

use Exporter;
use base qw| Exporter |;

@EXPORT = qw| bitstring_to_num $VERSION |;

our $VERSION = qw| AMOS-INLINE-SRC-3PVIREI |;

return 5;    ## true ##

##[ BITSTRING CONVERSION ]####################################################

sub bitstring_to_num {    ## bit_to_num ##

    my $source = <<~ 'EOC';

    unsigned long bit_to_num( char *str ) {

        unsigned long result = 0;
        unsigned int pos     = 0;
        unsigned int slen    = strlen(str);

        if ( slen > 64 ) {
            fprintf(stderr, "bit_to_num: input string size exceeds 64\n");
            exit(ERANGE);
        }

        while ( *str ) {
            int character = (int) *str++;
            pos++;

            if ( character == 49 )
                result += ldexpl( 1 , slen - pos );

            else if ( character != 48 ) {
                fprintf(stderr, "bit_to_num: input not a bit string\n");
                exit(EINVAL);
            }
        }
        return result;
    }

    EOC

    my $fallback_sub = sub {    ## pure-perl bit_to_num alternative ##

        return warn_err( 'bit_to_num: expected bitstring parameter', 1 )
            if not defined $ARG[0];
        return warn_err( 'bit_to_num: input string size exceeds 64', 1 )
            if length $ARG[0] > 64;
        return warn_err( 'bit_to_num: input not a bit string', 1 )
            if $ARG[0] =~ m|[^01]|;

        return eval sprintf qw| 0b%s |, $ARG[0];
    };

    return {
        qw|  source  | => $source,
        qw| fallback | => $fallback_sub,

        qw| package | => qw| AMOS::BinConversion |    ##  bit_to_num()  ##
    };
}

#.............................................................................
#SN4HGEKVBF3FRC4QNPU42WCPMZLZ6I2O7G7BGQWWFPDWZR2YQBBPSNDYYDWJAH3J246UCZJ7ZTYA4
#::: EYFM4BV3XQI4QPFOHCAC2NWSX6UJD3GATMN3XN22I4BTSSSQ7LV :::: NAILARA AMOS :::
# :: RGV3XUS6V5DVBI5AE2IHOWMRWRTQ3DZSJKNMIJSGPSN37VRZLSDY :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
