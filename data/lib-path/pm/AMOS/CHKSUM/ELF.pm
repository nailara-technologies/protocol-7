
package AMOS::CHKSUM::ELF;  ##################################################

use vars qw| @EXPORT |;

use Exporter;
use base qw| Exporter |;

use v5.24;
use strict;
use English;
use warnings;

use Digest::Elf;            ## needs checks for overflow .., ##

use AMOS::CHKSUM::ELF::Inline qw| compile_inline_elf_to $VERSION |;

my $AMOS::CHKSUM::ELF::inline_elf = compile_inline_elf_to(qw| /tmp/ELF |);

@EXPORT = qw| elf_chksum |;

our $inline_base_path  //= qw| /var/tmp/inline-elf/<version>/<user> |;
our $use_inline_elf    //= 1;    ## compile and use inline-elf version ? ##
our $use_external_elf  //= 1;    ## use /usr/local/bin/elf as fallback ? ##
our $elf_checksum_mode //= 4;    ## elf-checksum base algorithm setting ##

##[ CHECKSUM CALCULATION ]####################################################

## unsigned int inline_elf( int mode, int start_sum, char *sval ) {

sub elf_chksum {

    ## initializing empty ##
    @ARG = qq|| if not @ARG;
    my $start_checksum = 0;
    ## allows passing by reference [ with start checksum parameter ] ##
    if ( ref( $ARG[0] ) eq 'SCALAR' ) {

        my $data_ref = shift;

        $start_checksum = shift
            if @ARG
            and defined $ARG[0]
            and $ARG[0] =~ m|^\d{1,9}$|;    ## allow for negative values ? ##

    } else {
        my $data_ref = \$ARG[0];
    }

    my $elf_checksum;

    $elf_checksum = sprintf( "%09d", $start_checksum )
        if not length( $$data_ref // '' );

    if ( not defined $elf_checksum ) {
        if ( defined $AMOS::CHKSUM::ELF::inline_elf
            and ref $AMOS::CHKSUM::ELF::inline_elf eq 'CODE' ) {

            $elf_checksum = $AMOS::CHKSUM::ELF::inline_elf->(
                $elf_checksum_mode, $start_checksum, $$data_ref
            );

        } elsif ( $start_checksum > 0 ) {
            warn 'Digest::Elf::elf does not support a start checksum <{C1}>';

        } else {
            $elf_checksum = Digest::Elf::elf($$data_ref);
        }
    }

    $elf_checksum_mode = 4;    ## reset to elf base-algorithm ##

    return $elf_checksum;
}

##[ STAND ALONE INVOCATION ]##################################################

sub gen_inline_path {
    my $user = getpwuid($UID);

}

return 1;  ###################################################################

#.............................................................................
#W5RRAKZ6XECY6QRENZPZ5QZHDGOJKJF5CNKCXQRCGLOPGSAPUJ4HUHKMZMUIK2GOTVIMKEVUNPYW2
#::: IDVWMG2HSNU2PKMOFNLUKSJXPDJQGJSKHGXAXGKCA7IAIOI2OWR :::: NAILARA AMOS :::
# :: 5BQYZ76VFQJDA7W7ZETFOD2EXFAEG3FYA4CB2M6DBEHNGC5YUSCY :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
