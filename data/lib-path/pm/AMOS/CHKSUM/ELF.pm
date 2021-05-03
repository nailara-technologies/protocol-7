
package AMOS::CHKSUM::ELF;  ##################################################

use vars qw| @EXPORT $VERSION |;

use Exporter;
use base qw| Exporter |;

use v5.24;
use strict;
use English;
use warnings;

use AMOS::CHKSUM::ELF::Inline qw| compile_inline_elf_to inl_elf_src |;

## INLINE ELF OUTPUT CHECKSUM ##
##
our $VERSION = qw| AMOS-ELF-7L-R6TXGYI |;    ##  amos-chksum -VL  ##

@EXPORT = qw| elf_chksum gen_inline_path $VERSION |;

our $inline_base_path  //= qw| /var/tmp/inline-elf/<version>/<user> |;
our $use_inline_elf    //= 1;    ## compile and use inline-elf version ? ##
our $use_external_elf  //= 1;    ## use /usr/local/bin/elf as fallback ? ##
our $elf_checksum_mode //= 4;    ## elf-checksum base algorithm setting ##

## installing inline_elf() as currently available ##

if ( defined $AMOS::CHKSUM::ELF::inline_elf ) {
    *inline_elf = $AMOS::CHKSUM::ELF::inline_elf;
} else {
    *inline_elf = compile_inline_elf_to( gen_inline_path('/var/tmp/.') );
}

die 'loading \ compiling of inline_elf() subroutine not successful'
    if not defined &inline_elf;

##[ CHECKSUM CALCULATION ]####################################################

sub elf_chksum {

    ## initializing empty ##
    my $data_ref;
    @ARG = qq|| if not @ARG;
    my $start_checksum = 0;

    ## start checksum and mode parameters when passing by reference ##
    if ( ref( $ARG[0] ) eq '' ) {

        $data_ref = \shift;    ## CREATING REFERENCE TO DATA ##

    } else {
        $data_ref = shift;     ## PASSED BY REFERENCE ##
    }

    ## START CHECKSUM ##
    if ( @ARG and defined $ARG[0] and $ARG[0] =~ m|^\d{1,9}$| ) {
        $start_checksum = shift;
    }
    ## ELF MODE ##
    if ( @ARG and defined $ARG[0] and $ARG[0] =~ m|^\d{1,2}$| ) {
        $elf_checksum_mode = shift;
    }

    ####                  ####
    ## calculating checksum ##
    ####                  ####

    my $len = length( $$data_ref // '' );

    my $elf_checksum
        = $len > 0
        ? inline_elf( $elf_checksum_mode, $start_checksum, $$data_ref, $len )
        : sprintf( "%09d", $start_checksum );    ## start chksum for empty ##

    $elf_checksum_mode = 4;    ## resetting to elf base-algorithm mode ##

    return $elf_checksum;
}

##[ STAND ALONE INVOCATION ]##################################################

sub gen_inline_path {
    my $base_path = shift // qw| /var/tmp/. |;
    my $user      = getpwuid($UID);
    return sprintf( '%sinline_elf.%s.%s', $base_path, $user, $VERSION );
}

return 1;  ###################################################################

#.............................................................................
#4ZPYXJ4QFWDS66IENKVBS5OX34JM3QHDX5AQFGUFUZ36AX6ZJZXZQOP3XRSQXM2XK3MBR6WNRK3KU
#::: ZQNFQEKARGBEO6H4XFVVEJQ2MBPBOQISCN3RMI7G2TEMHITCNPE :::: NAILARA AMOS :::
# :: TOLPT75RKOANY2XADNIY6YFTID57NNR2H623ZC6MTHS5LKLFT6AA :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
