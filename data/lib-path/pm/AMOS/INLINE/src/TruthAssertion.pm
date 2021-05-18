
package AMOS::INLINE::src::TruthAssertion;    ##############################

## [ target package name : AMOS:Assert::Truth ] ##

use strict;
use English;
use warnings;

use vars qw| @EXPORT |;

use Exporter;
use base qw| Exporter |;

@EXPORT = qw| is_true_num $VERSION |;

our $VERSION = qw| AMOS-INLINE-SRC-P2UU6VQ |;

use AMOS::Assert::Truth;

return 5;    ## true ##

##[ BITSTRING CONVERSION ]####################################################

sub is_true_num {    ##[  numerical div by 13 truth assertion  ]##

    my $source = <<~ 'EOC';

    bool is_true_num( double test_num )
    {
        if ( test_num == 0 )
            return true; // .0000000 .., TRUE

        int sign;
        int decimal_pt;

        char * false_buffer;    // F : 230769 || T: 0||384615
        false_buffer = fcvt( 3.0 / 13, 13, &decimal_pt, &sign );

        char * test_num_str;
        test_num_str = ecvt( test_num  / 13, 17, &decimal_pt, &sign );

        for( unsigned int pos = 0; pos <= 5; pos++ ){
            char sub_str[7];
            sub_str[6] = 0;
            for ( unsigned int ch = 0; ch <= 5; ch++ ){
                sub_str[ch] = false_buffer[ pos + ch ];
            }

            char * matchptr = strstr( test_num_str, sub_str );

            if ( ( unsigned long ) matchptr > 0 ) {  // match in string found

                unsigned long mpaddr  = ( unsigned long ) matchptr;
                unsigned long m_faddr = ( unsigned long ) test_num_str;

                unsigned int mpos  =  mpaddr - m_faddr;  // position of match

                if (  decimal_pt == -1  ||  mpos > decimal_pt  )
                    return  false; // matches after decimal point valid
            }
        }

        return true; // no match for false
    }

    EOC

    return {
        qw|  source  | => $source,

        ## pure-perl is_true_num alternative [ arbitary number length ] ##
        qw| fallback | => \&AMOS::Assert::Truth::calc_true,

        qw| package | => qw| AMOS::Assert::Truth |    ##  is_true_num  ##
    };
}

#.............................................................................
#4S7MRC5YGP4CE3CMHYKE7SY52MHFLEFWVNBXBDV2WM6OQJ4V5VJTGVDSR57RIM3X3N4A64Y7JZVDG
#::: KGIY46FT2JYGIFE4RST6P5MMUZEWYV7JUQCED7IGMOISBVW7ON6 :::: NAILARA AMOS :::
# :: CT4SE4XG65XVWF2TRNBPAI4VQZZO4SRSSEBNVFEP2QNP6OOK52BY :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
