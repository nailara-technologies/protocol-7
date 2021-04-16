
package AMOS::CHKSUM::ELF;  ##################################################

use vars qw| @EXPORT |;

use Exporter;
use base qw| Exporter |;

use v5.24;
use strict;
use English;
use warnings;

use Digest::Elf;            ## needs checks for overflow .., ##

use AMOS::CHKSUM::ELF::Inline qw| compile_inline_elf_to |;

my $AMOS::CHKSUM::ELF::inline_elf = compile_inline_elf_to(qw| /tmp/ELF |);

@EXPORT = qw| elf_chksum |;

our $use_inline_elf   //= 1;    ## compile and use inline-elf version ? ##
our $use_external_elf //= 1;    ## use /usr/local/bin/elf as fallback ? ##

##[ CHECKSUM CALCULATION ]####################################################

sub elf_chksum {

    ## initializing empty ##
    @ARG = qq|| if not @ARG;

    ## allows passing by reference ##
    my $data_ref = ref( $ARG[0] ) eq 'SCALAR' ? shift : \$ARG[0];

    return '0' x 9 if not length( $$data_ref // '' );

    return $AMOS::CHKSUM::ELF::inline_elf->($$data_ref)
        if defined $AMOS::CHKSUM::ELF::inline_elf
        and ref $AMOS::CHKSUM::ELF::inline_elf eq 'CODE';

    my $elf_checksum = Digest::Elf::elf($$data_ref);

    return $elf_checksum;
}

return 1;  ###################################################################

#.............................................................................
#DX7C2JZJWKGXAFAYCMN45TFSKQ4KPE6ZTAG3RVRN5IV6L5ORZKNHQ6PCXKJTX4XXFYFDGDMTBTVTY
#::: YJE2LPX4GJYGXIRWBLAATPKL4OCLOGNJXD7PGVZHNPFPOMC3HHP :::: NAILARA AMOS :::
# :: LWC2FZ4IYJD6NU5QGQD2MBHRZVUKR7BG6Z3QL2RSMT33E7FZSWBQ :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
