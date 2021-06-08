
package AMOS::CHKSUM;  #######################################################

use v5.24;
use strict;
use English;
use warnings;

use Encode;
use Crypt::Misc;
use Digest::BMW;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT $VERSION %algorithm_set_up |;

@EXPORT = qw| amos_chksum $VERSION |;

our $VERSION = qw| AMOS-13-ELF-7-YM2JGIY |;    ##  amos-chksum -VCS  ##

##[ AMOS MODULE ]#############################################################

use AMOS;                                      ##  error handler  ##
use AMOS::13;

use AMOS::INLINE;                              ## compile_inline_source ##
use AMOS::CHKSUM::ELF;                         ## elf_chksum ##
use AMOS::Assert::Truth;                       ## is_true ##

##  AMOS::BitConv::bit_string_to_num  ##
##
compile_inline_source( { qw| subroutine-name | => qw| bit_string_to_num | } );

##[ SET-UP \ INIT ]###########################################################

## algorithm configuration ##
%algorithm_set_up = (
    ## permanent switches ##
    qw| return_modbits   | => 0,
    qw| chksum_numerical | => 1,
    qw| chksum_bits      | => 1,
    qw| chksum_B32       | => 1,
    qw| chksum_elf_mode  | => 7,    ##  <--  AMOS-13 CHKSUM elf mode [ 7 ]
    qw| elf_shift_bits   | => $AMOS::Assert::Truth::elf_shift_bits,     ## 13
    qw| elf_truth_modes  | => [@AMOS::Assert::Truth::assertion_modes]   ## 4 7
) if not keys %algorithm_set_up;

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

    my @elf_modes;
    my $start_elfsum = 0;
    my $input_elf_chksum;
    my $input_BMW_checksum;
    my $shift_bits      = $algorithm_set_up{'elf_shift_bits'};
    my $chksum_elf_mode = $algorithm_set_up{'chksum_elf_mode'};

    my $data_ref = shift // '';

    my $data_ref_type = ref($data_ref);
    if ( not length $data_ref_type ) {

        $data_ref = \"$data_ref";    ## creating scalar reference ##

    } elsif ( $data_ref_type eq qw| HASH | ) {

        $shift_bits = $data_ref->{'elf-shift-bits'}
            if defined $data_ref->{'elf-shift-bits'};

        $input_elf_chksum = $data_ref->{'elf_checksum'}
            if defined $data_ref->{'elf_checksum'};

        $input_BMW_checksum = $data_ref->{'BMW_checksum'}
            if defined $data_ref->{'BMW_checksum'};

        @elf_modes = @{ $data_ref->{'elf-modes'} }
            if defined $data_ref->{'elf-modes'}
            and ref( $data_ref->{'elf-modes'} ) eq qw| ARRAY |;

    } elsif ( $data_ref_type ne qw| SCALAR | ) {
        error_exit( sprintf "unexpected reference type '%s' supplied",
            $data_ref_type );
    }

    if (    not defined $input_elf_chksum
        and not defined $input_BMW_checksum
        and not Encode::is_utf8( $$data_ref, 1 ) ) {

        my $data_copy = Encode::decode( qw| UTF-8 |, $$data_ref, 8 );
        $data_ref = \$data_copy;
    }

    if ( @elf_modes and @ARG ) {
        warn_err( 'redundant elf mode setting, discarding'
                . ' arguments after hash reference <{C1}>' );
        undef @ARG;
    }

    @elf_modes    ## setting elf-modes ##  [ for truth assertion ]  ##
        = sort ( @ARG ? @ARG : @{ $algorithm_set_up{'elf_truth_modes'} } );

    map {
        error_exit("not a valid elf mode [ $ARG ]")
            if $ARG !~ m|^\d{1,3}$|
    } @elf_modes;

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
    $elf_csum = sprintf qw| %09d |,
        elf_chksum( $$data_ref, $start_elfsum, $chksum_elf_mode, $shift_bits )
        if not defined $elf_csum;
    ##

    $elf_bits = reverse_bin_032($elf_csum);

    ## calculate blue midnight wish checksum [ if not given ] ##
    my $bmw_512b;
    if ( defined $input_BMW_checksum
        and ref $input_BMW_checksum eq qw| SCALAR | ) {

        $bmw_512b = unpack( qw| B512 |, $input_BMW_checksum->$* );

    } elsif ( defined $input_BMW_checksum ) {

        $bmw_512b = unpack( qw| B512 |, $input_BMW_checksum );

    } else {    ##  implement other cases  ##  [LLL]
        my $ctx = Digest::BMW->new(512);
        $ctx->add($$data_ref);
        $bmw_512b = unpack( qw| B512 |, $ctx->digest );
    }
    ##

    my $bmw_512R = join( '', reverse split '', $bmw_512b );

    $bmw_b_R = substr( $bmw_512R, 0,   32 );
    $bmw_b_C = substr( $bmw_512b, 240, 32 );
    $bmw_b_L = substr( $bmw_512b, 0,   32 );

    my $bmw_mod_bits = scalar( '0' x 32 ) . $bmw_512b;

    ## use index !!! ##

    ( $checksum_bits = $elf_bits ) =~ s|^0+|
                                        substr $bmw_b_L, 0, length($MATCH) |e;
    $checksum_bits =~ s|0+$|
                    substr $bmw_b_R, 0, length($MATCH) |e;

    ## numerical ##
    $num_amos_csum = AMOS::BitConv::bit_string_to_num($checksum_bits);

    ## elf checksum protection ##
    $num_amos_csum ^= AMOS::BitConv::bit_string_to_num($bmw_b_L);
    ###

    my $resaturation_offset = 0;

INVERT_TRUTH_STATE:

    if ($bmw_mod_step) {    ##  modifying to requested truth state  ##

        my $cur_mod_bits = reverse split '', substr( $bmw_mod_bits, 0, 32 );

        if ( $cur_mod_bits eq qw| 0 | x 32 ) {    ## skip '0' prefixes ##
            ++$bmw_mod_step and substr( $bmw_mod_bits, 0, 1, '' );
            goto INVERT_TRUTH_STATE;    ##  <--  modify checksum   ##
        }

        ## XOR ##
        $num_amos_csum ^= AMOS::BitConv::bit_string_to_num($cur_mod_bits);

        push( @mod_bits, $cur_mod_bits )
            if $algorithm_set_up{'return_modbits'};
    }

    my $checksum_encoded    ## VAX-B32 ##
        = Crypt::Misc::encode_b32r( pack( qw| V |, $num_amos_csum ) );

    ## ENCODED + VALUE AND STRING HARMONY ##

    if ($algorithm_set_up{'chksum_numerical'}
        and not is_true( $num_amos_csum, 1, 1, @elf_modes )  ##  numerical  ##

        or $algorithm_set_up{'chksum_bits'}    ##  binary [ as string ]  ##
        and not is_true( bin_032($num_amos_csum), 0, 1, @elf_modes )

        or $algorithm_set_up{'chksum_B32'}     ##  encoded result string  ##
        and not is_true( $checksum_encoded, 0, 1, @elf_modes )
    ) {

        ++$bmw_mod_step and substr( $bmw_mod_bits, 0, 1, '' );

        if ( length($bmw_mod_bits) <= 32 ) {    ## resaturate entropy pool ##

            my $bmw_offset = $resaturation_offset += 13;

            while ( $bmw_offset > 512 - 32 ) { $bmw_offset -= ( 512 - 32 ) }

            $bmw_mod_bits .= bin_032(
                AMOS::BitConv::bit_string_to_num(
                    substr( $bmw_512b, $bmw_offset, 32 )
                ) ^ $num_amos_csum
            );
        }
        goto INVERT_TRUTH_STATE;                ##  <--  modify checksum   ##
    }

    ##  true  ##
    return $checksum_encoded;                   ##  VAX AND BASE32 ENCODED  ##
}

return 5;  ###################################################################

#,,..,,.,,,,,,,.,,,,.,,,,,.,,,..,,,,.,.,.,...,..,,...,.,,,,.,,,,,,.,,,,..,,,,,
#AE5QP7SWYWUC3K5SRPUWIJXXRZCX4XOQAURNMSEUVJK52BZHQGQVL67IJLJ5FXAZDG7OIOS2OSI7E
#\\\|MP7ZYHLAU6DGZ4V2CFR47LSMRXQ56OCFZE6GH325VUBUFGGR2PD \ / AMOS7 \ YOURUM ::
#\[7]2NQ74HWLVJ5L7BNVDXUAYYMAEONY73FP6GYQUNKL3PQXOBWVEWAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
