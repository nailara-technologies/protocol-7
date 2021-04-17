
package AMOS::CHKSUM;  #######################################################

use vars qw| @EXPORT |;

use Exporter;
use base qw| Exporter |;

use v5.24;
use strict;
use English;
use warnings;
use Crypt::Misc;       ## encode_b32r ##
use Digest::Elf;       ## check for overflow [ import p7 version \ inline ? ]
use Math::BigFloat;

use AMOS::Assert::Truth qw| is_true |;
use AMOS::CHKSUM::ELF::Inline qw| compile_inline_elf_to |;

compile_inline_elf_to(qw| /tmp/ELF |);

@EXPORT = qw| amos_chksum |;

## algorithm configuration ##
our $algorithm_set_up //= {
    ## permanent switches ##
    'follow_truth'     => 0,
    'return_modbits'   => 0,
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
our $checksum_num;
our $bmw_mod_step;
our $checksum_bits;

##[ CHECKSUM CALCULATION ]####################################################

sub amos_chksum {

    warn "expected input string for AMOS-checksum calculation\n" if not @ARG;

    my $data_ref = ref( $ARG[0] ) eq 'SCALAR' ? shift : \$ARG[0];

    ## reset \ init ##
    @mod_bits      = ();
    $elf_bits      = '';
    $bmw_b_R       = '';
    $bmw_b_L       = '';
    $checksum_bits = '';
    $bmw_mod_step  = 0;
    $checksum_num  = 0;

    my $elf_csum;
    if ( defined &main::inline_elf ) {  ## improve \ import code and loader ##
        $elf_csum = main::inline_elf($$data_ref);
    } else {
        $elf_csum = Digest::Elf::elf($$data_ref); ## check for overflow !!! ##
    }

    $elf_bits = sprintf( '%032b', join( '', reverse split '', $elf_csum ) );

    my $bmw_512b = unpack( 'B512', Digest::BMW::bmw_512($$data_ref) );
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

            if ($algorithm_set_up->{'chksum_numerical'}
                and not is_true( $checksum_num, 1, 0 )

                or $algorithm_set_up->{'chksum_bits'}
                and not is_true( sprintf( "%032b", $checksum_num ), 0, 1 )

                or $algorithm_set_up->{'chksum_B32'}
                and not is_true($checksum_encoded)
            ) {

                ++$bmw_mod_step and substr( $bmw_mod_bits, 0, 1, '' );
                goto INVERT_TRUTH_STATE;
            }

        } else {    ## ENCODED + FOLLOW TRUTH ##

            my $input_true = is_true( $$data_ref, 1, 1 );

            if (    $algorithm_set_up->{'chksum_numerical'}
                and $input_true != is_true( $checksum_num, 1, 1 )

                or $algorithm_set_up->{'chksum_bits'}
                and $input_true
                != is_true( sprintf( "%032b", $checksum_num ), 0, 1 )

                or $algorithm_set_up->{'chksum_B32'}
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

    ## resetting per-call override to algorithm configuration ##
    $follow_truth = $algorithm_set_up->{'follow_truth'};
    $ret_modbits  = $algorithm_set_up->{'return_modbits'};

    return $checksum_encoded;
}

return 1;  ###################################################################

#.............................................................................
#NQD5IOKP6WTDSTDZMWDFROEB5UHCJ535TNTWPFNHYWGD55E4PC3ESQPIUWFABQCTSLSQEYZPX2SUE
#::: C34CZLMOFALL7TDBJZKI24W2ZGS7YNCXN2PPRO7JX66KBVJJZJU :::: NAILARA AMOS :::
# :: SO5OSE4YV4TDFFS2IZ34UXUF3ZXMB3Y2R23Z35HJ64AXYGBEQCBY :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::