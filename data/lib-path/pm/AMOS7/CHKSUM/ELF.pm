## [:< ##

package AMOS7::CHKSUM::ELF;   ################################################

use v5.24;
use strict;
use English;
use warnings;

##[ global constants ]##
use constant TRUE  => 5;      ##  TRUE.  ##
use constant FALSE => 0;      ##  false  ##

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT $VERSION $ALGORITHM_VERSION |;

## INLINE ELF OUTPUT CHECKSUM ##
##
our $ALGORITHM_VERSION = qw| AMOS-13-ELF-7-MMQNNII |;   #  amos-chksum -VL7  #
##  module source  ##
our $VERSION = qw| AMOS7::CHKSUM::ELF-VERSION.A233HVY |;

@EXPORT = qw| elf_chksum inline_elf |;

## AMOS-13-ELF-7 SETTINGS ##
##
our $elf_mode   //= 7;     ##  elf hash setting :   4 ##
our $shift_bits //= 13;    ##  elf hash setting :  24 ##

our $overflow_threshold //= 0XFE000000;    ##  elf hash : 0XF0000000 ##
##
####

use AMOS7;                                 ##  error handler  ##
## inline_elf compilation [ $VERSION not imported : alias protection ] ##
use AMOS7::INLINE qw| compile_inline_source |;

## skips compilation when included from AMOS7::INLINE::src::TruthAssertion
if ( defined &AMOS7::INLINE::compile_inline_source ) {

    ## loads when not defined ##
    compile_inline_source( { qw| subroutine-name | => qw| inline_elf | } );
}
###

## will _no_longer_ use Digest::Elf fallback if not compiled ##
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

    ####                  ####
    ## calculating checksum ##
    ####                  ####

    my $elf_checksum;
    {
        no warnings 'utf8';    ## deal silently with malformed UTF8 ##
        $elf_checksum
            = inline_elf( $data_ref->$*, $start_chksum, $elf_mode,
            $shift_bits, $overflow_threshold );
    }

    $elf_mode   = 7;     ## resetting to AMOS-13-ELF algorithm settings ##
    $shift_bits = 13;    ## resetting to AMOS-13-ELF algorithm settings ##

    $overflow_threshold //= 0XFE000000;    ##  AMOS-13-ELF algorithm  ##

    return sprintf qw| %09d |, $elf_checksum;    ## AMOS-13 ELF-7 CHKSUM ##
}

return TRUE ##################################################################

#,,,.,..,,..,,,,,,,..,.,,,...,,..,,..,...,.,.,..,,...,...,.,,,.,.,,..,,.,,,,.,
#HD4YV6PDEBOHT62FYHKN27LUUR65FKTHD4R3ISIW2QNX26CGCIDAGLPX5RTRMNRECBNICPQQAFLFQ
#\\\|RHE555BCPMMIIMGPVG4YRAMJYUQC37AM7WYLX2AKNEZCOBOGGP5 \ / AMOS7 \ YOURUM ::
#\[7]XPGCPK2BGRZIYPEO4ZLCUEU2OUJVUCHEMPP6XQZI4RO75LZMVIAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
