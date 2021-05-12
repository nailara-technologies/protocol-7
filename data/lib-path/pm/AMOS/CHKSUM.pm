
package AMOS::CHKSUM;  #######################################################

use v5.24;
use strict;
use English;
use warnings;

use Encode;
use Crypt::Misc;
use Digest::BMW;

use vars qw| @EXPORT $VERSION %algorithm_set_up |;

use Exporter;
use base qw| Exporter |;

##[ AMOS MODULE ]#############################################################

use AMOS;
use AMOS::13;
use AMOS::Assert::Truth qw| is_true |;
use AMOS::CHKSUM::ELF qw| elf_chksum |;

our $VERSION = qw| AMOS-CHKSUM-V-SDTO47I |;    ##  amos-chksum -VCS  ##

@EXPORT = qw| amos_chksum $VERSION |;

##[ SET-UP \ INIT ]###########################################################

## algorithm configuration ##
%algorithm_set_up = (
    ## permanent switches ##
    qw| return_modbits   | => 0,
    qw| chksum_numerical | => 1,
    qw| chksum_bits      | => 1,
    qw| chksum_B32       | => 1,
    qw| elf_truth_modes  | => [@AMOS::Assert::Truth::assertion_modes]
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

    my @elf_modes;
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
    $elf_csum = sprintf qw| %09d |, elf_chksum( $$data_ref, 0, 7 )
        if not defined $elf_csum;
    ##

    $elf_bits = reverse_bin_032($elf_csum);

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

    ##  replace eval calls with bit_to_num()  ##                         [LLL]
    ##
    $num_amos_csum = eval "0b$checksum_bits";    ## numerical ##
    $num_amos_csum ^= eval "0b$bmw_b_L";         ## elf checksum protection ##
    ###

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

            $bmw_mod_bits .= bin_032( ## replace with inline version ##  [LLL]
                eval( join '', qw| 0b |,
                    substr( $bmw_512b, $bmw_offset, 32 ) ) ^ $num_amos_csum
            );
        }
        goto INVERT_TRUTH_STATE;      ##  <--  modify checksum   ##
    }

    return $checksum_encoded;         ##  VAX AND BASE32 ENCODED  ##
}

return 1;  ###################################################################

#.............................................................................
#WSCBTMECUWQZZQPNNWLYSHSIFANNQEUG523G7BJO3VR2U4JLFNW6EC5UR54IAK3DR6RSRB2NKYHCW
#::: PICWSCV4R6D7PJVWIPPLIJUFKLCYZRLUADDSJZ3SWBK3RLJ5Y4F :::: NAILARA AMOS :::
# :: A76ICPKBL6QPIXU3TXI5PY2W4T2OXZVFPSOHGQLENNUCRIGAACBI :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
