
package AMOS::CHKSUM::ELF;  ##################################################

use v5.24;
use strict;
use English;
use warnings;

use vars qw| @EXPORT $VERSION |;

use AMOS;

use Exporter;
use base qw| Exporter |;

use AMOS::CHKSUM::ELF::Inline qw| compile_inline_elf_to inl_elf_src |;

## INLINE ELF OUTPUT CHECKSUM ##
##
our $VERSION = qw| AMOS-13-ELF-7-2XQFA4Y |;    #  amos-chksum -VL7  #

@EXPORT = qw| elf_chksum gen_inline_path $VERSION |;

our $inline_base_path //= qw| /var/tmp/inline-elf/<version>/<user> |;
our $use_inline_elf   //= 1;    ## compile and use inline-elf version ? ##
our $use_external_elf //= 0;    ## use /usr/local/bin/elf as fallback ? ##

## ANOS-13-ELF SETTINGS ##
##
our $elf_mode           //= 5;            ##  elf hash setting :   4        ##
our $shift_bits         //= 13;           ##  elf hash setting :  24        ##
our $overflow_threshold //= 0XFE000000;   ##  elf hash : 0XF0000000 ##
##
####

## installing inline_elf() as currently available ##

if ( defined $AMOS::CHKSUM::ELF::inline_elf ) {
    *inline_elf = $AMOS::CHKSUM::ELF::inline_elf;
} else {
    *inline_elf = compile_inline_elf_to( gen_inline_path(qw| /var/tmp/. |) );
}

die 'loading \ compiling of inline_elf() subroutine not successful'
    if not defined &inline_elf;

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

  # $overflow_threshold = shift if @ARG and $ARG[0] <= 4294967295;  #[ 32bit ]

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

    $elf_mode   = 5;     ## resetting to AMOS-13-ELF algorithm settings ##
    $shift_bits = 13;    ## resetting to AMOS-13-ELF algorithm settings ##
    $overflow_threshold //= 0XFE000000;    ##  AMOS-13-ELF algorithm  ##

    return $elf_checksum;
}

##[ STAND ALONE INVOCATION ]##################################################

sub gen_inline_path {
    my $user = getpwuid($UID);
    ( my $base_path = shift // qw| /var/tmp | ) =~ s|//|/|;
    $base_path =~ s|/$||;
    return sprintf( qw| %s/%s/amos-13-elf-%s |, $base_path, $user, $VERSION );
}

return 1;  ###################################################################

#.............................................................................
#32TOLZ5YQXB22FSYNANZQWSYMGTSWCFL7LEVSSVVNKURRAEXE6LCY2GPTIAZCG5JUB7OIHQ4LS3US
#::: TBP7NDPVZSIZFYCAS2EMG2PDQEXF7FM72DVW7GLFDKHH5N5ISDT :::: NAILARA AMOS :::
# :: VXG6FLTJBSXTK45LBYZG2AFIZCEAHXFIOPWGS4UBRES2OHSYSQAQ :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
