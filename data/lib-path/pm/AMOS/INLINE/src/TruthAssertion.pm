
package AMOS::INLINE::src::TruthAssertion;    ##############################

## [ target package : AMOS:Assert::Truth ] ##

use strict;
use English;
use warnings;

use vars qw| @EXPORT |;

use Exporter;
use base qw| Exporter |;

@EXPORT = qw| true_int true_float $VERSION |;

our $VERSION = qw| AMOS-INLINE-SRC-2BPRJKI |;

use AMOS::Assert::Truth;

return 5;    ## true ##

##[ BITSTRING CONVERSION ]####################################################

sub true_float {    ##[  numerical div by 13 truth assertion  ]##
    ##  valid input length  <  17  ##
    my $source = <<~ 'EOC';

    bool true_float ( double test_num ) {

        if ( test_num == 0 )
            return true; // .0000000 .., TRUE

        // reduce size of assertion number [ modulo based 13 \ float version ]
        long double  assert_number = fmodl ( test_num, 13.00000 );

        int sign;
        int decimal_pt;

        char * false_buffer;    // F : 230769 || T: 0||384615
        false_buffer = ecvt( 3.0 / 13, 13, &decimal_pt, &sign );

        char * test_num_str;
        test_num_str = fcvt( assert_number / 13, 17, &decimal_pt, &sign );

        for( unsigned int pos = 0; pos <= 5; pos++ ){
            char sub_str[7];
            sub_str[6] = 0;
            for ( unsigned int ch = 0; ch <= 5; ch++ ){
                sub_str[ch] = false_buffer[ pos + ch ];
            }

            char * matchptr = strstr( test_num_str, sub_str );

            if ( ( unsigned long ) matchptr > 0 ) {  // match in string found

                unsigned long mpaddr   =  ( unsigned long ) matchptr;
                unsigned long m_faddr  =  ( unsigned long ) test_num_str;

                unsigned int mpos  =  mpaddr - m_faddr;  // position of match

                if (  decimal_pt == -1  ||  mpos > decimal_pt  )
                    return  false; // matches after decimal point valid
            }
        }

        return true; // no match for false
    }

    EOC

    return {
        qw| source | => $source,

        qw| package | => qw| AMOS::Assert::Truth |,    ##  true_float  ##

        ## pure-perl is_true_num alternative [ arbitary number length ] ##
        qw| fallback | => \&AMOS::Assert::Truth::calc_true,
    };
}

sub true_int {    ##[  numerical div by 13 truth assertion  ]##
    ##  valid input size  64 bit [integer]  ##
    my $source = <<~ 'EOC';

    bool true_int ( unsigned long test_num ) {

        if ( test_num == 0 )
            return true; // .0000000 .., TRUE

        bool warn_64_bit = false; // warn at overflow size

        if ( warn_64_bit && test_num == 18446744073709551615 )
            fprintf( stderr,
                "true_int : input at 64-bit limit [ 18446744073709551615 ]\n"
            );

        // reduce size of assertion  [ modulo 13 ]  ### INTEGER VERSION ###
        long double assert_number = test_num % 13;

        int sign;
        int decimal_pt;

        char * false_buffer;    // F : 230769 || T: 0||384615
        false_buffer = ecvt( 3.0 / 13, 13, &decimal_pt, &sign );

        char * test_num_str;
        test_num_str = fcvt( assert_number / 13, 13, &decimal_pt, &sign );

        for( unsigned int pos = 0; pos <= 5; pos++ ){
            char sub_str[7];
            sub_str[6] = 0;
            for ( unsigned int ch = 0; ch <= 5; ch++ ){
                sub_str[ch] = false_buffer[ pos + ch ];
            }

            char * matchptr = strstr( test_num_str, sub_str );

            if ( ( unsigned long ) matchptr > 0 ) {  // match in string found

                unsigned long mpaddr   =  ( unsigned long ) matchptr;
                unsigned long m_faddr  =  ( unsigned long ) test_num_str;

                unsigned int mpos  =  mpaddr - m_faddr;  // position of match

                if (  decimal_pt == -1  ||  mpos > decimal_pt  )
                    return  false; // matches after decimal point valid
            }
        }

        return true; // no match for false
    }

    EOC

    return {
        qw| source | => $source,

        qw| package | => qw| AMOS::Assert::Truth |,    ##  true_int  ##

        ## pure-perl is_true_num alternative [ arbitary number length ] ##
        qw| fallback | => \&AMOS::Assert::Truth::calc_true
    };
}

#.............................................................................
#4OZ724C4UNEIOOTEDJOGEELUZJFIQHW72XMYUAMDBXE6RZ4564PD3GW2O5IMPLDV4MBMYZIQUOGFY
#::: ET6ROMZR5XQS53LB6TDXRTXURTWSMBSXBBF4BJPKYXN2MSOXIVX :::: NAILARA AMOS :::
# :: FKCK2VWILBSJMGDYPMMW2PPQBPEXV4V4KQDYFZFVMDNEYMTIF2AY :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
