## [:< ##

package AMOS7::CHKSUM::ELF;   ################################################

use v5.24;
use strict;
use English;
use warnings;

##[ global constants ]##
use constant TRUE  => 5;      ##  TRUE.  ##
use constant FALSE => 0;      ##  false  ##

use Digest::Elf;    ##  temporary fallback  [ no longer same algorithm ]  ##

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT $VERSION |;

## INLINE ELF OUTPUT CHECKSUM ##
##
$VERSION = qw| AMOS-13-ELF-7-SQIG7DQ |;    #  amos-chksum -VL7  #

@EXPORT = qw| elf_chksum $VERSION |;

## AMOS-13-ELF-7 SETTINGS ##
##
our $elf_mode   //= 7;                     ##  elf hash setting :   4 ##
our $shift_bits //= 13;                    ##  elf hash setting :  24 ##

our $overflow_threshold //= 0XFE000000;    ##  elf hash : 0XF0000000 ##
##
####

use AMOS7;                                 ##  error handler  ##
use AMOS7::INLINE;                         ## inline_elf compilation ##

## skips compilation when included from AMOS7::INLINE::src::TruthAssertion
if ( defined &AMOS7::INLINE::compile_inline_source ) {

    ## loads when not defined ##
    compile_inline_source( { qw| subroutine-name | => qw| inline_elf | } );
}
###

## will use rudimentary Digest::Elf fallback if not compiled ##
warn_err('compilation of inline_elf subroutine not successful <{C1}>')
    if not defined &inline_elf;    ##  AMOS7::CHKSUM::ELF::inline_elf()  ##

##[ CHECKSUM CALCULATION ]####################################################

sub elf_chksum {

    ## initializing empty ##
    my $data_ref;
    @ARG = qq|| if not @ARG;
    my $start_chksum = 0;

    ## start checksum and mode parameters when passing by reference ##
    if ( not length ref( $ARG[0] ) ) {

        $data_ref = \shift;    ## CREATING REFERENCE TO DATA ##

    } else {
        $data_ref = shift;     ## PASSED BY REFERENCE ##
    }

    ## START CHECKSUM ##
    if ( defined $ARG[0] and $ARG[0] =~ m|^\d{1,9}$| ) {
        $start_chksum = shift @ARG;
    }
    ## ELF MODE ##
    if ( defined $ARG[0] and $ARG[0] =~ m|^\d{1,2}$| ) {
        $elf_mode = shift @ARG if $ARG[0] <= 64;
    }
    ## RIGHT SHIFT VAL ##
    if ( defined $ARG[0] and $ARG[0] =~ m|^\d{1,2}$| ) {
        $shift_bits = shift @ARG if $ARG[0] <= 64;
    }
    ## OVERFLOW THRESHOLD ##
    if ( defined $ARG[0] and $ARG[0] <= 4294967295 ) {    ## 32 bit ##
        $overflow_threshold = shift @ARG;
    }

    ##  temporary fallback to not break __all__ code  ##
    state $warned_elf //= 0;
    if ( not defined &inline_elf ) {
        if ( $start_chksum == 0 ) {

            ++$warned_elf
                and warn_err(
                '<< using Digest::Elf fallback [ incompatible algorithm ] >>')
                if not $warned_elf
                and ( $elf_mode != 4
                or $shift_bits != 24
                or $overflow_threshold != 0XF0000000 );

            ##  Digest::Elf CHKSUM  ##    no elf mode support   ##
            return sprintf qw| %09d |, Digest::Elf::elf($$data_ref);

        } else {
            warn 'start checksum not supported by Digest::Elf fallback';
            return undef;
        }
    }
    ##

    ####                  ####
    ## calculating checksum ##
    ####                  ####

    my $elf_checksum;
    {
        no warnings 'utf8';    ## deal silently with malformed UTF8 ##
        $elf_checksum
            = inline_elf( $$data_ref, $start_chksum, $elf_mode, $shift_bits,
            $overflow_threshold );
    }

    $elf_mode   = 7;     ## resetting to AMOS-13-ELF algorithm settings ##
    $shift_bits = 13;    ## resetting to AMOS-13-ELF algorithm settings ##

    $overflow_threshold //= 0XFE000000;    ##  AMOS-13-ELF algorithm  ##

    return sprintf qw| %09d |, $elf_checksum;    ## AMOS-13 ELF-7 CHKSUM ##
}

return TRUE ##################################################################

#,,..,,.,,,..,.,.,,,,,.,.,,,,,,,.,...,,..,...,..,,...,.,.,,,.,.,,,,..,..,,,.,,
#7LYKXRGXJIR57XCLF26LH4XX26EIYTNBQOJKGF6G75YYWBH7LEKG4RGJCIMGABEJDPY6FRHWPZSWU
#\\\|GTR7WQOHL7QS7VKJM4NPGDL36QCA6IJQL7TVDA6AV466CDFMTN7 \ / AMOS7 \ YOURUM ::
#\[7]DTK6E56TF373NFTZ47ZJVTZT3E3EF7VHEXJ6SY4BHTRA455PPWBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
