
package AMOS::CHKSUM::ELF;  ##################################################

use vars qw| @EXPORT $VERSION |;

use Exporter;
use base qw| Exporter |;

use v5.24;
use strict;
use English;
use warnings;

# use AMOS::CHKSUM qw| amos_chksum |;

use AMOS::CHKSUM::ELF::Inline
    qw[ compile_inline_elf_to inl_elf_src $VERSION ];

### use calculated \ generated paths and caller context awareness ### [LLL]

@EXPORT = qw| elf_chksum $VERSION |;

our $inline_base_path  //= qw| /var/tmp/inline-elf/<version>/<user> |;
our $use_inline_elf    //= 1;    ## compile and use inline-elf version ? ##
our $use_external_elf  //= 1;    ## use /usr/local/bin/elf as fallback ? ##
our $elf_checksum_mode //= 4;    ## elf-checksum base algorithm setting ##

## install inline_elf() as currently available ## [ trigger in parent module? ]

## load latest version here, recompile in parent with version string available?

if ( defined $AMOS::CHKSUM::ELF::inline_elf ) {
    *inline_elf = $AMOS::CHKSUM::ELF::inline_elf;
} else {
    *inline_elf = compile_inline_elf_to(qw| /tmp/ELF |);
}

if ( not defined &inline_elf ) {
    die 'no inline_elf() code reference available';
}

##[ CHECKSUM CALCULATION ]####################################################

sub elf_chksum {

    ## initializing empty ##
    my $data_ref;
    @ARG = qq|| if not @ARG;
    my $start_checksum = 0;

    ## start checksum and mode parameters when passing by reference ##
    if ( ref( $ARG[0] ) eq 'SCALAR' ) {

        $data_ref = shift;

        if ( @ARG and defined $ARG[0] and $ARG[0] =~ m|^\d{1,9}$| ) {
            $start_checksum = shift;
        }

        if ( @ARG and defined $ARG[0] and $ARG[0] =~ m|^\d{1,2}$| ) {
            $elf_checksum_mode = shift;
        }

    } else {
        $data_ref = \$ARG[0];
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
    my $user = getpwuid($UID);

}

return 1;  ###################################################################

#.............................................................................
#AI5W3SGGMAFTRBMWRT5GUVK7747E2FLMGZQ364VFO2H3MWYEKH2FYQKGIXY4D6BWZPMN2V53YNJLQ
#::: HCAA3A6UJ55REMHBLDPY34WPXV2C3RSFHUC7REJVRMPA76TXRJL :::: NAILARA AMOS :::
# :: UQEJJR2KVJ3LH4RE73XL44OYIT3C6G5KT3GWXLMZFAM3DTIYVUDA :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
