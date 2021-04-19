
package AMOS::CHKSUM::ELF::Inline;  ##########################################

use vars qw| @EXPORT |;

use Exporter;
use base qw| Exporter |;

use v5.24;
use strict;
use Inline;
use English;
use warnings;
use List::Util qw| min |;

use AMOS;

# use AMOS::CHKSUM qw| amos_chksum |;

eval qq| require 'Inline/C.pm' |;
die "'Inline::C' is not available [ installed ? ]" if $EVAL_ERROR;

@EXPORT = qw| compile_inline_elf_to inl_elf_src $VERSION |;

our $VERSION;    ## algorithm version ## receive from parent module

##[ COMPILATION TO TARGET PATH ]##############################################

sub compile_inline_elf_to {

    my $inline_directory = shift;
    my $elf_code         = inl_elf_src();

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

    ## inherit parse_error [ $EVAL_ERROR ]

    warn '<< conmilation not successful >> ' and return undef
        if not defined &inline_elf;

    return \&inline_elf;    ## returning code-ref to compiled routine ##

}

##[ CHECKSUM CALCULATION CODE ]###############################################

## return cleaned up code for filtering false-positive change detection ##

sub inl_elf_src {
    my $source_code = return_elf_c_sourcecode();
    $source_code =~ s{\s*/\*(([^\*]|\*(*nla:/))+)\*/\ *}{}sg;   ## comments ##
    $source_code =~ s{\s*//.+$}{}mg;     ## single line comments ##
    $source_code =~ s{\n\s*\n}{\n}sg;    ## empty lines ##
    $source_code =~ s{^\n|\n$}{}sg;      ## empty lines [ first and last ] ##
    $source_code =~ s{\s+$}{}sg;         ## trailing tabs|spaces ##
    my $min_indent = min map { m|^\s+| ? length($MATCH) : 0 }
        split( "\n", $source_code );
    $source_code =~ s|^\s{$min_indent}||mg;    ## indent to start of source ##
    return $source_code;    ## return cleaned source code version ##
}

## uncondensed inline_elf() c source code [ prefer using above version ] ##

sub return_elf_c_sourcecode {
    return <<~ 'EOC';

    unsigned int inline_elf( int elf_mode, int start_sum, char *str, int len ) {

        unsigned int result = start_sum; // 0 if no continuation
        unsigned int carryover;
        int pos_0  = (int) str;
        unsigned int round = 0;

        // algorithm configuration
        unsigned int left  = elf_mode; // 4 == elf hash [ base setting ]
        unsigned int right = 24;
        unsigned int z_val = 777;   // special value for "\0" [ instead 0 ]

        while ( len-- ) {
            round = (long) str - pos_0;
            int character = (int) *str++;

            if ( character == 0 )    // ascii 0 characters
                character += z_val;

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
#YCENU2LUTA6HAEL2FLKQBC5UPZ4TQPLZXSYQEK4SPPK4BL6R5VF66MW6J4G65OPCYQ2ZIHECFU4KE
#::: HG6GPOFJBVMSZ6ZXEW5ZIX455MZKKWQBMTIU4NH2PER57Z6JYK4 :::: NAILARA AMOS :::
# :: RUZKUXKDETDXZDEIZU3JBDG35SIV2CX7CT67I7KIIJEUEDPW7YDA :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
