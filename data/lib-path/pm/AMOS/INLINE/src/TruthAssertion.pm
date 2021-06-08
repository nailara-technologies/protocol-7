
package AMOS::INLINE::src::TruthAssertion;    ##############################

## [ target package : AMOS:Assert::Truth ] ##

use v5.24;
use strict;
use English;
use warnings;

use Exporter;
use vars qw| @EXPORT |;
use base qw| Exporter |;
@EXPORT = qw| $VERSION |;

our $VERSION = qw| AMOS-INLINE-SRC-EBVQRJQ |;

##[ NUMERICAL TRUE \ FALSE ASSERTION ]########################################

sub true_int {    ##[  numerical div by 13 truth assertion  ]##

    require qw| AMOS/Assert/Truth.pm |;    ##  has fallback coderef  ##

    ##  valid input size  64 bit [integer]  ##

    my $source = <<~ 'EOC';

    unsigned int true_int ( unsigned long test_num ) {

        unsigned const int TRUE_VAL  = 5;
        unsigned const int FALSE_VAL = 0;

        if ( test_num == 0 )
            return TRUE_VAL; // .0000000 .., TRUE

        bool warn_64_bit = false; // warn at overflow size

        if ( warn_64_bit && test_num == ~0 )
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
                    return FALSE_VAL; // matches after decimal point valid
            }
        }

        return TRUE_VAL; // no match for false
    }

    EOC

    return {
        qw| source | => $source,

        qw| package | => qw| AMOS::Assert::Truth |,    ##  true_int  ##

        ## pure-perl is_true_num alternative [ arbitary number length ] ##
        qw| fallback | => \&AMOS::Assert::Truth::calc_true
    };
}

sub true_float {    ##[  numerical div by 13 truth assertion  ]##

    require qw| AMOS/Assert/Truth.pm |;    ##  has fallback coderef  ##

    ##  valid input length  <  17  ##

    my $source = <<~ 'EOC';

    unsigned int true_float ( double test_num ) {

        unsigned const int TRUE_VAL  = 5;
        unsigned const int FALSE_VAL = 0;

        if ( test_num == 0 )
            return TRUE_VAL; // .0000000 .., TRUE

        bool limit_warn = false; // warn at overflow size

        if ( limit_warn && test_num == ~0 )
            fprintf( stderr,
                "true_float : input value is at overflow limit .,\n"
            );

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
                    return FALSE_VAL; // matches after decimal point valid
            }
        }

        return TRUE_VAL; // no match for false
    }

    EOC

    return {
        qw| source | => $source,

        qw| package | => qw| AMOS::Assert::Truth |,    ##  true_float  ##

        ## pure-perl is_true_num alternative [ arbitary number length ] ##
        qw| fallback | => \&AMOS::Assert::Truth::calc_true,
    };
}

#########################################################################

return 5;    ##  true  ##




#,,.,,,..,,,.,,..,..,,...,,..,.,,,...,..,,..,,..,,...,..,,,,,,,..,,..,..,,..,,
#FG5EB5I7AT4BYLV7S2FWDN4Y5LGWH4C56TIWCACGUMIPMHH7GAT3MR6FT77MWDOCLAZEKXADHGKSI
#\\\|CE46FTOFNJN3WGXHTGDS4BGNOOABFSP2EMUCNALAG5DT54P25SI \ / AMOS7 \ YOURUM ::
#\[7]YYU4QCZI5TOED52UL4UXI2OW3MAROZH5GB24EJ7UUWEGCSDTSGAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
