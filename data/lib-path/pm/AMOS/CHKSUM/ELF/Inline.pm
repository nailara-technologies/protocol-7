
package AMOS::CHKSUM::ELF::Inline;  ##########################################

use vars qw| @EXPORT |;

use Exporter;
use base qw| Exporter |;

use v5.24;
use strict;
use Inline;
use English;
use warnings;

use AMOS;

# use AMOS::Assert::Truth qw| |;

eval qq| require 'Inline/C.pm' |;
die "'Inline::C' is not available [ installed ? ]" if $EVAL_ERROR;

@EXPORT = qw| compile_inline_elf_to |;

##[ COMPILATION TO TARGET PATH ]##############################################

sub compile_inline_elf_to {

    my $inline_directory = shift;
    my $elf_code         = return_c_code();

    die "<inline_directory> '$inline_directory' not found"
        if !-d $inline_directory;

### [RE]COMPILING \ LOADING .., ###
    eval {
        no warnings;     # <-- 'redefine' ?
        Inline->bind( 'C' => $elf_code, 'directory' => $inline_directory );
        use warnings;    # <-- 'redefine' ?
    };

## removing ,./lib/ from @INC again ., ##
    shift @INC if $INC[0] =~ m|^$inline_directory/lib|;

    return undef if not defined &inline_elf;

    say ' <<< SUCCESS >>>';

    return \&inline_elf;    ## returning code-ref to compiled routine ##

}

##[ CHECKSUM CALCULATION CODE ]###############################################

sub return_c_code {
    return << 'EOT';

void inline_elf(char *sval)
{
    unsigned int h = 0; // <-- repaired overflow [ broken in Digest::Elf ]
    unsigned long g;
    Inline_Stack_Vars;

    while ( *sval ) {

        h = ( h << 4 ) + *sval++;

        if ( g = h & 0xF0000000 )
            h ^= g >> 24;

        h &= ~g;
    }

    Inline_Stack_Reset;
    Inline_Stack_Push(sv_2mortal(newSViv( h )));
    Inline_Stack_Done;
}
EOT
}

return 1;  ###################################################################

#.............................................................................
#DX7C2JZJWKGXAFAYCMN45TFSKQ4KPE6ZTAG3RVRN5IV6L5ORZKNHQ6PCXKJTX4XXFYFDGDMTBTVTY
#::: YJE2LPX4GJYGXIRWBLAATPKL4OCLOGNJXD7PGVZHNPFPOMC3HHP :::: NAILARA AMOS :::
# :: LWC2FZ4IYJD6NU5QGQD2MBHRZVUKR7BG6Z3QL2RSMT33E7FZSWBQ :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
