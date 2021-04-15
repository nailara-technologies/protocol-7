
package AMOS::CHKSUM;  #######################################################

use vars qw| @EXPORT |;

use Exporter;
use base qw| Exporter |;

use v5.24;
use strict;
use English;
use warnings;
use Digest::Elf;       ## check for overflow [ import p7 version \ inline ? ]
use Math::BigFloat;
use AMOS::Assert::Truth qw| is_true |;

@EXPORT = qw| amos_chksum |;

## algorithm configuration ##
our $check_truth //= {
    'chksum_numerical' => 1,
    'chksum_bits'      => 1,
    'chksum_B32'       => 1
};

our $ret_modbits  //= 0;    ## return truth state mod bits ? ##
our $follow_truth //= 0;    ## flip truth state to follow input ##

## accessible internal variables [ for visualizations ] ##
our @mod_bits;
our $elf_bits;
our $bmw_b_R;
our $bmw_b_L;
our $bmw_mod_step;
our $checksum_bits;
our $checksum_num;

##[ CHECKSUM CALCULATION ]####################################################

sub amos_chksum {

    warn "expected input string for AMOS-checksum calculation\n" if not @ARG;

    my $data_str = join( ' ', @ARG );

    ## reset \ init ##
    @mod_bits      = ();
    $elf_bits      = '';
    $bmw_b_R       = '';
    $bmw_b_L       = '';
    $checksum_bits = '';
    $bmw_mod_step  = 0;
    $checksum_num  = 0;

    $elf_bits = sprintf( '%032b',
        join( '', reverse split '', Digest::Elf::elf($data_str) ) );

    my $bmw_512b = unpack( 'B512', Digest::BMW::bmw_512($data_str) );
    my $bmw_512R = join( '', reverse split '', $bmw_512b );

    $bmw_b_L = substr( $bmw_512b, 0, 32 );
    $bmw_b_R = substr( $bmw_512R, 0, 32 );

    my $bmw_mod_bits = scalar( '0' x 32 ) . $bmw_512b . scalar( '0' x 32 );

    ( $checksum_bits = $elf_bits ) =~ s|^0+|
                                        substr $bmw_b_L, 0, length($MATCH) |e;
    $checksum_bits =~ s|0+$|
                    substr $bmw_b_R, 0, length($MATCH) |e;

    $checksum_num = eval "0b$checksum_bits";    ## numerical ##

INVERT_TRUTH_STATE:

    if ($bmw_mod_step) {    ## enforce required \ requested truth state ##
        my $cur_mod_bits = substr( $bmw_mod_bits, 0, 32 );
        if ( $cur_mod_bits eq '0' x 32 ) {    ## skip '0' prefixes ##8
            ++$bmw_mod_step and substr( $bmw_mod_bits, 0, 1, '' );
            goto INVERT_TRUTH_STATE;
        }
        $checksum_num ^= eval join( '', '0b', $cur_mod_bits );

        push( @mod_bits, $cur_mod_bits ) if 1 or $AMOS::CHKSUM::modbits;
    }

    my $checksum_encoded
        = Crypt::Misc::encode_b32r( pack( 'V', $checksum_num ) );

    if ( length($bmw_mod_bits) > 32 ) {

        ## ENCODED + VALUE AND STRING HARMONY ##
        if ( not $AMOS::CHKSUM::follow_truth ) {

            if ($check_truth->{'chksum_numerical'}
                and not is_true( $checksum_num, 1, 0 )

                or $check_truth->{'chksum_bits'}
                and not is_true( sprintf( "%032b", $checksum_num ), 0, 1 )

                or $check_truth->{'chksum_B32'}
                and not is_true($checksum_encoded)
            ) {

                ++$bmw_mod_step and substr( $bmw_mod_bits, 0, 1, '' );
                goto INVERT_TRUTH_STATE;
            }

        } else {    ## ENCODED + FOLLOW TRUTH ##

            my $input_true = is_true( $data_str, 1, 1 );

            if (    $check_truth->{'chksum_numerical'}
                and $input_true != is_true( $checksum_num, 1, 1 )

                or $check_truth->{'chksum_bits'}
                and $input_true
                != is_true( sprintf( "%032b", $checksum_num ), 0, 1 )

                or $check_truth->{'chksum_B32'}
                and $input_true != is_true( $checksum_encoded, 0, 1 )
            ) {

                ++$bmw_mod_step and substr( $bmw_mod_bits, 0, 1, '' );
                goto INVERT_TRUTH_STATE;
            }
        }
    } else {
        warn 'bit modification entropy depleted'
            . " [ cannot enforce truth state ]\n";   ## report caller ## [LLL]
    }

    return $checksum_encoded;
}

return 1;  ###################################################################

#.............................................................................
#GONGIYQGUAOSCNUXDBIGI2S2AYBO6FVMFQ5B547Q6JJFNN4H2O3DQZZHYQRT7DZS4LEJ6R4ISCM4K
#::: A2XVBL67Q5TZO36KWBXSIKSRGNFBTGW6WX7IGPGECQGFC2PI552 :::: NAILARA AMOS :::
# :: IP3YR2ARMPUDOXTHBW5SZHAEIIHYHEEV32WJZ2LVGNUIWFWUZ6BI :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
