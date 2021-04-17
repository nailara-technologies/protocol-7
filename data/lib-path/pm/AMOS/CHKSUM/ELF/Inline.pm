
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

use AMOS::CHKSUM qw| amos_chksum |;

eval qq| require 'Inline/C.pm' |;
die "'Inline::C' is not available [ installed ? ]" if $EVAL_ERROR;

@EXPORT = qw| compile_inline_elf_to $VERSION |;

our $VERSION = amos_chksum( return_c_code() );    ## algorithm code version ##

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

    return \&inline_elf;    ## returning code-ref to compiled routine ##

}

##[ CHECKSUM CALCULATION CODE ]###############################################

sub return_c_code {
    return <<~ 'EOC';

        unsigned int inline_elf( int elf_mode, int start_sum, char *str ) {

            unsigned int result = start_sum; // 0 if no continuation
            unsigned int carryover;
            int pos_0  = (int) str;
            unsigned int round = 0;

            // algorithm configuration
            unsigned int left  = elf_mode; // 4 == elf hash [ base setting ]
            unsigned int right = 24;

            while ( *str ) {
                round = (long) str - pos_0;
                int character = (int) *str++;
                if ( character < 0 ) // characters >= ascii 128
                    character += 256;

                result = ( result << left ) + character;

                if ( ( carryover = result & 0xF0000000 ) )
                    result ^= carryover >> right;

                result &= ~carryover;
            }

            return result;
        }

    EOC
}

return 1;  ###################################################################

#.............................................................................
#TKOTZPJ3MBR7SBULPJZOOAICJ7KGXIB6ORNQJPD3GOFQOGBGSCORFDOSYFKFNTKB37NIMN5LHFBFU
#::: 5C2EM4OK7ZYHLAOEP65BGWHJYVCMGPV6VWLWLNGPHCISE3ARIUY :::: NAILARA AMOS :::
# :: JVEJWBAERLZDMOE2CRQYRG6RI7KUKLMLT6WLNICP6Z75DAF5PCBI :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
