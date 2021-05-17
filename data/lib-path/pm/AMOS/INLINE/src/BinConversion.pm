
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

sub bitstring_to_num {    ## bit_to_num ##  [ much faster than eval '0b'.., ]

    my $source = <<~ 'EOC';

    unsigned long bit_to_num( char *str ) {

        STRLEN slen = strlen(str);

        if ( slen > 64 )
            croak("input string size exceeds 64");

        if ( slen <= 32 ) {
            I32 flags = PERL_SCAN_DISALLOW_PREFIX;
            return grok_bin( str, &slen, &flags, NULL );
        }

        unsigned long result = 0;
        STRLEN pos           = 0;

        while ( *str ) {  // manual version without non-portable warnings
            int character = (int) *str++;
            pos++;

            if ( character == 49 )
                result += ldexpl( 1 , slen - pos );

            else if ( character != 48 )
                croak("input not a bit string");
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

sub num_to_bitstring {  ## bit_to_num ## [ note : slower than sprintf '%0*b' ]
    ##                                            kept as an example only .,
    my $source = <<~ 'EOC';

    void num_to_bit( unsigned long num, ... ) {

        // SV* result = newSVpvn( "", 0 );
        SV* result = newSV( 64 );
        SvPOK_only( result );
        inline_stack_vars;
        int min_len = 0;

        if( inline_stack_items > 2 )
            croak( "too many arguments, expected : <num> [, <bitsize> ]" );

        if( num > UV_MAX ) // 18446744073709551615
            croak( "input value exceeds 64 bit size" );

        if( inline_stack_items == 2 && SvOK(inline_stack_item(1)) ) {
            if( !looks_like_number( inline_stack_item(1) ) )
                croak("number of bits is not an integer [0..64]");

            min_len = POPl; // number of bits parameter

            if( min_len < 0 || min_len > 64 )
                croak("number of bits out of range [0..64]");
        }

        for ( int pos = 63; pos > -1; --pos ) {
            unsigned long b_val = ldexpl( 1 , pos );

            if( num >= b_val ) {
                sv_catpvs(result, "1");
                num -= b_val;
            } else if ( sv_len(result) || min_len > 0 && pos < min_len ) {
                sv_catpvs(result, "0");
            }
        }

        if ( sv_len(result) == 0 )
            sv_catpvs(result, "0");

        inline_stack_reset;
        inline_stack_push(sv_2mortal( result ));
        inline_stack_done;
    }

    EOC

    my $fallback_sub = sub {    ## pure-perl bit_to_num alternative ##
        return warn_err("too many arguments, expected : <num> [, <bitsize> ]")
            if @ARG > 2;
        return warn_err( 'expected numerical parameter', 1 )
            if not defined $ARG[0]
            or $ARG[0] =~ m|\D|;
        return warn_err( 'input value exceeds 64 bit size', 1 )
            if $ARG[0] > 18446744073709551615;
        return warn_err( 'number of bits is not an integer [0..64]', 1 )
            if defined $ARG[1]
            and ( $ARG[1] =~ m|\D| or $ARG[1] < 0 or $ARG[1] > 64 );

        return sprintf( qw| %0*b |, $ARG[1] // 0, $ARG[0] );
    };

    return {
        qw|  source  | => $source,
        qw| fallback | => $fallback_sub,

        qw| package | => qw| AMOS::BinConversion |    ##  num_to_bit()  ##
    };
}

#.............................................................................
#JOBEKM73MFSRNSBQO64APSFRYWNUWTEDYKRMDL6TY7HBTVKSOPPXU7HBICFVENWN47FAMXOJ2MTJA
#::: HC2VCAOP7WP65FKX4E4VW2XQ3UDWHQXHVOBSRBXOI5COYMKGUZ5 :::: NAILARA AMOS :::
# :: LD7W6GU32RRWN2KGI5UXFSE5PNATOOQBME27YQLJ62XL2P2YN4DA :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
