
package AMOS::CHKSUM::ELF::Inline;  ##########################################

use vars qw| @EXPORT |;

use Exporter;
use base qw| Exporter |;

use v5.24;
use strict;
use English;
use warnings;
use List::Util;
use File::Path qw| make_path |;

eval qq| require 'Inline/C.pm' |;
die "'Inline::C' is not available [ installed ? ]" if $EVAL_ERROR;

@EXPORT = qw| compile_inline_elf_to inl_elf_src $VERSION |;

## inline elf source code version ##
##
our $VERSION = qw| AMOS-ELF7-SRC-Z6342LQ |;    ##  amos-chksum -VS  ##

##[ COMPILATION TO TARGET PATH ]##############################################

sub compile_inline_elf_to {

    my $inline_directory = shift // '';
    die 'require at least a <path> parameter' if not length $inline_directory;
    my $uid      = shift;           ## optional ##
    my $gid      = shift;           ## optional ##
    my $elf_code = inl_elf_src();

    my @params = ( mode => 0755 );
    push( @params, 'uid'   => $uid ) if defined $uid;
    push( @params, 'group' => $gid ) if defined $gid;

    die "inline elf directory '$inline_directory' not readable [ repair .., ]"
        if -d $inline_directory and !-r $inline_directory;

    if ( !-d $inline_directory ) {

        make_path( $inline_directory, {@params} )
            or die ": \l$OS_ERROR : $inline_directory";

        die "cannot create <inline_elf_directory> '$inline_directory'"
            if !-d $inline_directory;
    }

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
    my $min_indent = List::Util::min map { m|^\s+| ? length($MATCH) : 0 }
        split( "\n", $source_code );
    $source_code =~ s|^\s{$min_indent}||mg;    ## indent to start of source ##
    return $source_code;    ## return cleaned source code version ##
}

## uncondensed inline_elf() c source code [ prefer using above version ] ##

sub return_elf_c_sourcecode {
    return <<~ 'EOL';

    unsigned int inline_elf(
            unsigned int elf_mode,
            unsigned int shift_value,
            unsigned int start_sum,
            unsigned char *str,
            unsigned int len
        ) {

        unsigned int result = start_sum; // 0 if no continuation
        unsigned int carryover;
        int pos_0  = (int) str;
        unsigned int round = 0;

        // algorithm configuration
        unsigned int left  = elf_mode;       // 4 == elf hash [ base setting ]
        unsigned int right = shift_value;   // 24 == elf hash, 13 : AMOS-ELF

        unsigned int z_val = 777;      // special value for "\0" [ instead 0 ]

        while ( len-- ) {
            round = (long) str - pos_0;
            int character = (int) *str++;

            if ( character == 0 )    // ascii 0 characters
                character += z_val;

            result = ( result << left ) + character;

            if ( ( carryover = result & 0xF0000000 ) )
                result ^= carryover >> right;

            result &= ~carryover;
        }

        return result;
    }

    EOL
}

return 1;  ###################################################################

#.............................................................................
#FL5VZ6XCZMDD4EH6CISIQVAF45PNX7ETINOWYPDD6BUDLSTCXHC6ALNO6557BVFOSJII5G33W6JXQ
#::: J7UFSRLUEMWSUDRN563E5VIRLI6MIAI42VQ5ZKIKGAMAKDHH5F2 :::: NAILARA AMOS :::
# :: 5JY2OWWSXY52AS5JRN5MITPLSUMQFMODONEPQD7EULZRRF3CW4BY :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
