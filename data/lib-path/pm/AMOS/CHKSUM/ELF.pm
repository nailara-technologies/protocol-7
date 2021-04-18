
package AMOS::CHKSUM::ELF;  ##################################################

use vars qw| @EXPORT |;

use Exporter;
use base qw| Exporter |;

use v5.24;
use strict;
use English;
use warnings;

use AMOS::CHKSUM::ELF::Inline qw| compile_inline_elf_to $VERSION |;

### use calculated \ generated paths and caller context awareness ### [LLL]
our $inline_elf_ref = compile_inline_elf_to(qw| /tmp/ELF |);

@EXPORT = qw| elf_chksum |;

our $inline_base_path  //= qw| /var/tmp/inline-elf/<version>/<user> |;
our $use_inline_elf    //= 1;    ## compile and use inline-elf version ? ##
our $use_external_elf  //= 1;    ## use /usr/local/bin/elf as fallback ? ##
our $elf_checksum_mode //= 4;    ## elf-checksum base algorithm setting ##

## install inline_elf() as currently available ##
if ( defined $AMOS::CHKSUM::ELF::inline_elf ) {
    *inline_elf = $AMOS::CHKSUM::ELF::inline_elf;
} elsif ( defined *inline_elf ) {
    *inline_elf = $inline_elf_ref;
} else {
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

    my $elf_checksum
        = length( $$data_ref // '' )
        ? inline_elf( $elf_checksum_mode, $start_checksum, $$data_ref )
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
#EBHYJB7NOHVHNT5RID3E3BPV5HCO3RNNDZGAYZVCZIE7DFUETMY3FPUIYAO2YA5I7E5564O4QFKIE
#::: U22LQMKWJVBZ62MYDSLIFJ2FNB7AB4AIEJG3OSDHFZVNNCJAKSJ :::: NAILARA AMOS :::
# :: EPRSSLIFLCXYZ63A3K4RZNBMF674ALYFFAKFOHIHDTLI33663OCI :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
