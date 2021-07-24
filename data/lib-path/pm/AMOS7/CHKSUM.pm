
package AMOS7::CHKSUM; #######################################################

use v5.24;
use strict;
use English;
use warnings;

use Encode;
use Time::HiRes;
use Digest::BMW;
use Crypt::Misc;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT $VERSION %algorithm_set_up |;

@EXPORT = qw| amos_chksum amos_template_chksum $VERSION |;

our $VERSION = qw| AMOS7::CHKSUM-VERSION.UXA5BUI |;   ##  amos-chksum -VCS  ##

##[ AMOS MODULE ]#############################################################

use AMOS7;                                            ##  error handler  ##
use AMOS7::13;

use AMOS7::INLINE;           ## compile_inline_source ##
use AMOS7::TEMPLATE;         ##  truth templates  ##
use AMOS7::CHKSUM::ELF;      ## elf_chksum ##
use AMOS7::Assert::Truth;    ## is_true ##

##  AMOS7::BitConv::bit_string_to_num  ##
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
    qw| elf_shift_bits   | => $AMOS7::Assert::Truth::elf_shift_bits,    ## 13
    qw| elf_truth_modes  | => [@AMOS7::Assert::Truth::assertion_modes]  ## 4 7
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
our $sstr_start = 0;
our $str_length = 7;

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

        @elf_modes = $data_ref->{'elf-modes'}->@*
            if defined $data_ref->{'elf-modes'}
            and ref( $data_ref->{'elf-modes'} ) eq qw| ARRAY |;

        AMOS7::TEMPLATE::assign_truth_templates(
            $data_ref->{'sprintf-test-template'} )
            if defined $data_ref->{'sprintf-test-template'};

        if ( AMOS7::TEMPLATE::template_count() > 0 ) {
            AMOS7::TEMPLATE::set_ELF7_modes(@elf_modes);
        }

    } elsif ( $data_ref_type ne qw| SCALAR | ) {
        return error_exit( sprintf "unexpected reference type '%s' supplied",
            $data_ref_type );
    }

    if (    not defined $input_elf_chksum
        and not defined $input_BMW_checksum
        and not Encode::is_utf8( $$data_ref, 1 ) ) {

        if ( not defined $data_ref->$* ) {
            my $caller_lvl
                = index( caller_str(), qw| AMOS7/CHKSUM.pm | ) == -1 ? 1 : 3;

            warn_err( 'input not defined', $caller_lvl );
            return undef;
        }

        my $data_copy = Encode::decode( qw| UTF-8 |, $data_ref->$*, 8 );
        $data_ref = \$data_copy;
    }

    if ( @elf_modes and @ARG ) {
        warn_err( 'redundant elf mode setting, discarding'
                . ' arguments after hash reference <{C1}>' );
        undef @ARG;
    }

    @elf_modes    ## setting elf-modes ##  [ for truth assertion ]  ##
        = sort ( @ARG ? @ARG : $algorithm_set_up{'elf_truth_modes'}->@* );

    map {
        return error_exit( 'not a valid elf mode [ %s ] <{C3}>', $ARG )
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
        $ctx->add( $data_ref->$* );
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
    $num_amos_csum = AMOS7::BitConv::bit_string_to_num($checksum_bits);

    ## elf checksum protection ##
    $num_amos_csum ^= AMOS7::BitConv::bit_string_to_num($bmw_b_L);
    ###

    my $time_start;
    $time_start = sprintf qw| %.1f |, Time::HiRes::time
        if AMOS7::TEMPLATE::template_count() > 0;

    my $resaturation_offset = 0;

INVERT_TRUTH_STATE:

    if ($bmw_mod_step) {    ##  modifying to requested truth state  ##

        if ( AMOS7::TEMPLATE::template_count()
            and sprintf( qw| %.1f |, Time::HiRes::time ) - $time_start
            > AMOS7::TEMPLATE::template_timeout() ) {
            my $caller_level_str
                = defined $main::PROTOCOL_SEVEN ? qw| <{C3}> | : qw| <{NC}> |;
            error_exit(
                'truth template validation timeout exceeded [%.2f] '
                    . $caller_level_str,
                AMOS7::TEMPLATE::template_timeout()
            );
            return undef;
        }

        my $cur_mod_bits = reverse split '', substr( $bmw_mod_bits, 0, 32 );

        if ( $cur_mod_bits eq qw| 0 | x 32 ) {    ## skip '0' prefixes ##
            ++$bmw_mod_step and substr( $bmw_mod_bits, 0, 1, '' );
            goto INVERT_TRUTH_STATE;    ##  <--  modify checksum   ##
        }

        ## XOR ##
        $num_amos_csum ^= AMOS7::BitConv::bit_string_to_num($cur_mod_bits);

        push( @mod_bits, $cur_mod_bits )
            if $algorithm_set_up{'return_modbits'};
    }

    my $checksum_encoded    ## VAX-B32 ##
        = Crypt::Misc::encode_b32r( pack( qw| V |, $num_amos_csum ) );

    ## ENCODED + VALUE AND STRING HARMONY ##

    ##  substring  ##
    if ( $str_length != 7 or $sstr_start != 0 ) {
        return error_exit('substring values are out of range [ 1..7 ] <{C2}>')
            if $str_length < 1
            or $str_length + $sstr_start > 7;
        $checksum_encoded    ##  truncating as specified in template case  ##
            = substr( $checksum_encoded, $sstr_start, $str_length );
    }

    if ($algorithm_set_up{'chksum_numerical'}
        and not is_true( $num_amos_csum, 1, 1, @elf_modes )  ##  numerical  ##

        or $algorithm_set_up{'chksum_bits'}    ##  binary [ as string ]  ##
        and not is_true( bin_032($num_amos_csum), 0, 1, @elf_modes )

        or $algorithm_set_up{'chksum_B32'}     ##  encoded result string  ##
        and not is_true( $checksum_encoded, 0, 1, @elf_modes )

        or AMOS7::TEMPLATE::template_count() > 0
        and not AMOS7::TEMPLATE::template_is_true(
            $checksum_encoded,
            $num_amos_csum,
            ## optional data parameters ##
            [ $bmw_mod_step, $elf_csum, \$bmw_512b, $data_ref ]
        )

        ) {    ##  if not all true, modify  ##

        ++$bmw_mod_step and substr( $bmw_mod_bits, 0, 1, '' );

        if ( length($bmw_mod_bits) <= 32 ) {    ## resaturate entropy pool ##

            my $bmw_offset = $resaturation_offset += 13;

            while ( $bmw_offset > 512 - 32 ) { $bmw_offset -= ( 512 - 32 ) }

            $bmw_mod_bits .= bin_032(
                AMOS7::BitConv::bit_string_to_num(
                    substr( $bmw_512b, $bmw_offset, 32 )
                ) ^ $num_amos_csum
            );
        }
        goto INVERT_TRUTH_STATE;                ##  <--  modify checksum   ##
    }

    ##  all criteria true, checksum valid  ##

    AMOS7::TEMPLATE::reset_truth_templates()    ##  reset truth template  ##
        if AMOS7::TEMPLATE::template_count();

    if ( $str_length < 7 ) {   ##  resetting substring template parameters  ##
        $sstr_start = 0;
        $str_length = 7;
    }

    ##  also return numerical checksum in list context  ##
    return ( $checksum_encoded, $num_amos_csum ) if wantarray;

    ##  true  ##
    return $checksum_encoded;    ##  VAX AND BASE32 ENCODED  ##
}

sub amos_template_chksum {

    my $template = shift;

    return undef
        if not defined AMOS7::TEMPLATE::assign_truth_templates($template);

    if ( @ARG == 0 ) {
        warn_err('expected input parameters');
        return undef;
    }

    return scalar amos_chksum(@ARG);
}

return 5;  ###################################################################

#,,.,,,..,.,.,.,.,,.,,,.,,,..,..,,...,,,.,,.,,..,,...,..,,.,.,,,,,,..,,..,,,,,
#25W3MOV4HMUWS7S33AVCGCUAKAXYCYJERZGLCN5N6IXRDEDTFHGQ3LJDXFJ3NWUGLV6RKLFTNB3A6
#\\\|LEYALSGAHCQ5FTRZ4ZSOHWQT5H5AZIGRMEANOI67WNL4JLGJLYR \ / AMOS7 \ YOURUM ::
#\[7]ZFRDEG5HILYYOIPL7425T7EO5JU4SBTXW2K6UJ2XI37UIOOATEDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
