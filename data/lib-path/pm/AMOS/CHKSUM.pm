
package AMOS::CHKSUM;  #######################################################

use vars qw| @EXPORT $VERSION %algorithm_set_up |;

use Exporter;
use base qw| Exporter |;

use v5.24;
use strict;
use English;
use warnings;

use Encode;
use Crypt::Misc;
use Digest::BMW;

##[ AMOS MODULE ]#############################################################

use AMOS::Assert::Truth qw| is_true |;
use AMOS::CHKSUM::ELF qw| elf_chksum |;

our $VERSION = qw| AMOS-JKBK7XY |;    ##  amos-chksum -VA  ##

@EXPORT = qw| amos_chksum $VERSION |;

##[ SET-UP \ INIT ]###########################################################

## algorithm configuration ##
%algorithm_set_up = (
    ## permanent switches ##
    'follow_truth'     => 0,
    'return_modbits'   => 0,
    'chksum_numerical' => 1,
    'chksum_bits'      => 1,
    'chksum_B32'       => 1,
    'elf_truth_modes'  => [@AMOS::Assert::Truth::assertion_modes] ## elf modes

) if !keys %algorithm_set_up;

## accessible internal variables [ for visualizations ] ##
our @mod_bits;
our $elf_bits;
our $bmw_b_R;
our $bmw_b_L;
our $bmw_b_C;
our $num_amos_csum;
our $bmw_mod_step;
our $checksum_bits;

##[ CHECKSUM CALCULATION ]####################################################

sub amos_chksum {

    my $input_elf_chksum;
    my $input_BMW_checksum;

    my $data_ref = shift // '';

    my $data_ref_type = ref($data_ref);
    if ( not length $data_ref_type ) {

        $data_ref = \"$data_ref";    ## creating scalar reference ##

    } elsif ( $data_ref_type eq qw| HASH | ) {

        $input_elf_chksum = $data_ref->{'elf_checksum'}
            if defined $data_ref->{'elf_checksum'};

        $input_BMW_checksum = $data_ref->{'BMW_checksum'}
            if defined $data_ref->{'BMW_checksum'};

    } elsif ( $data_ref_type ne qw|SCALAR| and $data_ref_type ne qw|REF| ) {
        die sprintf "unexpected reference type '%s' supplied", $data_ref_type;
    }

    if (    not defined $input_elf_chksum
        and not defined $input_BMW_checksum
        and not Encode::is_utf8( $$data_ref, 1 ) ) {

        my $data_copy = Encode::decode( qw| UTF-8 |, $$data_ref, 8 );
        $data_ref = \$data_copy;
    }

    my @elf_modes    ## setting elf-modes ##  [ for truth assertion ]  ##
        = sort ( @ARG ? @ARG : @{ $algorithm_set_up{'elf_truth_modes'} } );

    map { die "not a valid elf mode ['$ARG']" if $ARG !~ m|^\d{1,2}$| }
        @elf_modes;

    ## reset \ init ##
    @mod_bits      = ();
    $elf_bits      = '';
    $bmw_b_R       = '';
    $bmw_b_L       = '';
    $checksum_bits = '';
    $bmw_mod_step  = 0;
    $num_amos_csum = 0;

    ##  left shift 7 [ modified ] elf checksum algorithm  ##
    ##
    my $elf_csum //= $input_elf_chksum;    ##  use parameter when given  ##

    ## elf-checksum mode 7 ##
    $elf_csum = sprintf '%09d', elf_chksum( $$data_ref, 0, 7 )
        if not defined $elf_csum;
    ##

    $elf_bits = sprintf( '%032b', join( '', reverse split '', $elf_csum ) );

    ## calculate blue midnight wish checksum [ if not given ] ##
    my $bmw_512b = unpack( qw| B512 |,
        $input_BMW_checksum // Digest::BMW::bmw_512($$data_ref) );
    ##

    my $bmw_512R = join( '', reverse split '', $bmw_512b );

    $bmw_b_R = substr( $bmw_512R, 0,   32 );
    $bmw_b_C = substr( $bmw_512b, 240, 32 );
    $bmw_b_L = substr( $bmw_512b, 0,   32 );

    my $bmw_mod_bits = scalar( '0' x 32 ) . $bmw_512b;

    ( $checksum_bits = $elf_bits ) =~ s|^0+|
                                        substr $bmw_b_L, 0, length($MATCH) |e;
    $checksum_bits =~ s|0+$|
                    substr $bmw_b_R, 0, length($MATCH) |e;

    $num_amos_csum = eval "0b$checksum_bits";    ## numerical ##

    $num_amos_csum ^= eval "0b$bmw_b_L";         ## elf checksum protection ##

    my $resaturation_offset = 0;

INVERT_TRUTH_STATE:

    if ($bmw_mod_step) {    ##  modifying to requested truth state  ##

        my $cur_mod_bits = reverse split '', substr( $bmw_mod_bits, 0, 32 );

        if ( $cur_mod_bits eq '0' x 32 ) {    ## skip '0' prefixes ##
            ++$bmw_mod_step and substr( $bmw_mod_bits, 0, 1, '' );
            goto INVERT_TRUTH_STATE;          ##  <--  modify checksum   ##
        }
        $num_amos_csum ^= eval join( '', qw| 0b |, $cur_mod_bits ); ## XOR-bin

        push( @mod_bits, $cur_mod_bits )
            if $algorithm_set_up{'return_modbits'};
    }

    my $checksum_encoded    ## VAX-B32 ##
        = Crypt::Misc::encode_b32r( pack( 'V', $num_amos_csum ) );

    ## ENCODED + VALUE AND STRING HARMONY ##

    if ($algorithm_set_up{'chksum_numerical'}
        and not is_true( $num_amos_csum, 1, 1, @elf_modes )  ##  numerical  ##

        or $algorithm_set_up{'chksum_bits'}    ##  binary [ as string ]  ##
        and
        not is_true( sprintf( '%032b', $num_amos_csum ), 0, 1, @elf_modes )

        or $algorithm_set_up{'chksum_B32'}     ##  encoded result string  ##
        and not is_true( $checksum_encoded, 0, 1, @elf_modes )
    ) {

        ++$bmw_mod_step and substr( $bmw_mod_bits, 0, 1, '' );

        if ( length($bmw_mod_bits) <= 32 ) {    ## resaturate entropy pool ##

            my $bmw_offset = $resaturation_offset += 13;

            while ( $bmw_offset > 512 - 32 ) { $bmw_offset -= ( 512 - 32 ) }

            $bmw_mod_bits .= sprintf(
                '%032b',
                eval(
                    join( '', '0b', substr( $bmw_512b, $bmw_offset, 32 ) )
                ) ^ $num_amos_csum
            );
        }

        goto INVERT_TRUTH_STATE;    ##  <--  modify checksum   ##
    }

    return $checksum_encoded;       ##  VAX AND BASE32 ENCODED  ##
}

return 1;  ###################################################################

#.............................................................................
#I7LUXV2SLYBDGP4FWE6F2IXA4VYKO5ZJLZTTMIQKS2JOUPKOCT7MJDLIGSOOFIHCPFLP5OK4MZJCI
#::: ORDTTU5A4AAVFJ54QCIPW5AKAF5DBVHVEPBFGLY4K55JWPPJ7K4 :::: NAILARA AMOS :::
# :: ZSP5G64ODHSQIXXFBTVEBEZTX4RZAOTXD4VFXOBLZPM55ISJJAAQ :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
