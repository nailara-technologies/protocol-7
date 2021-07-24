
package AMOS7::CHKSUM::ELF::Inline; ##########################################

use vars qw| @EXPORT |;

use Exporter;
use base qw| Exporter |;

use v5.24;
use strict;
use English;
use warnings;
use Cwd qw| abs_path |;
use File::Path qw| make_path |;
use List::MoreUtils qw| minmax |;

eval qq| require 'Inline/C.pm' |;
die "'Inline::C' is not available [ installed ? ]" if $EVAL_ERROR;

@EXPORT = qw| compile_inline_elf_to inl_elf_src $VERSION |;

## inline elf source code version ##
##
our $VERSION = qw| AMOS-13-ELF-7-SRC-VER-MGF4O4Y |;    ##  amos-chksum -VS  ##

our $debug_output_to_console = 0;

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

    $inline_directory = abs_path($inline_directory);

    ### [RE]COMPILING \ LOADING .., ###
    eval {
        no warnings;    # <-- 'redefine' ?
        Inline->bind(
            qw| C |           => $elf_code,
            qw| directory |   => $inline_directory,
            qw| BUILD_NOISY | => $debug_output_to_console
        );
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
    ( undef, my $min_indent ) = minmax map { m|^\s+| ? length($MATCH) : 0 }
        split( "\n", $source_code );
    $source_code =~ s|^\s{$min_indent}||mg;    ## indent to start of source ##
    return $source_code;    ## return cleaned source code version ##
}

## uncondensed inline_elf() c source code [ prefer using above version ] ##

sub return_elf_c_sourcecode {
    return <<~ 'EOL';

    void inline_elf(
            SV * input_str,
            unsigned int start_sum, // make optional [LLL]
            unsigned int  elf_mode, // make optional [LLL]
            ...
        ) {

        inline_stack_vars;

        unsigned int overflow_shift_threshold = 0XFE000000; // <-- 7 bit
        unsigned int result = start_sum;  // start_sum 0 when no continuation
        unsigned int carryover;

        bool utf_8_as_value = true;    // add utf-8 codepoint value, not bytes
        bool ignore_0_bytes = false;  // add 777 for 0 bytes, instead 0

        unsigned int shift_reset = 4;
        unsigned int shift_limit = ~result;
        shift_limit >>= 4; // limiting left shift [ elf mode ] beyond 27 bits

        STRLEN    len = SvCUR( input_str );       // <-- can contain \0 bytes
        U8* str       = sv_2pvutf8_nolen( input_str );
        UV  str_pos_0 = (UV) str;

        STRLEN  c_pos = 0;

        unsigned int shift_value = 13;     //  AMOS-13 : 13  ||  elf-hash : 4

        // overflow threshold value [ up to 32 bit ]
        if( inline_stack_items >= 5 && SvOK(inline_stack_item(4)) ) {
            if( !looks_like_number( inline_stack_item(4) ) )
                croak("overflow threshold parameter not numerical");
                overflow_shift_threshold = POPu; // overflow right shift threshold
            if( overflow_shift_threshold > 0XFFFFFFFF ) // elf hash: 0XF0000000
                croak("overflow threshold out of range [ 32 bit ]");
        }

        // [right] shift bits [ param 4 ]
        if( inline_stack_items >= 4 && SvOK(inline_stack_item(3)) ) {
            if( !looks_like_number( inline_stack_item(3) ) )
                croak("shift_bits is not an integer [1..64]");
                shift_value = POPl; // overflow right shift bits
            if( shift_value < 1 || shift_value > 64 )
                croak("shift_bits out of range [1..64]");
        }

        // algorithm configuration
        unsigned int left  = elf_mode;       // 5 : AMOS-ELF ||  4 : elf hash
        unsigned int right = shift_value;   // 13 : AMOS-ELF || 24 : elf hash

        unsigned int z_val = 777;      // special value for "\0" [ instead 0 ]
        if ( ignore_0_bytes )
            z_val = 0;     // do not treat 0 as special cases

        while ( len > 0 ) {

            if ( left > shift_reset && result >= shift_limit )
                left = shift_reset; // reset to 4 to avoid entropy loss

            c_pos = (long) str - str_pos_0;

            bool is_ascii = is_ascii_string( str, 1 );

            U8 * next_chr;
            STRLEN u8_len;

            UV character;

            if( *str == 0 ) {                                 // ASCII 0

                len--;
                character = z_val;
                str++;

            } else if ( is_ascii || !utf_8_as_value ) { // ASCII 1 .. 127

                len--;
                character = *str;
                str++;

            } else {                            // ASCII 128 .. 255 and UTF-8

                character = utf8_to_uvchr_buf( str, next_chr, &u8_len );

                if ( character < 256 )

                    u8_len = 1;   //   not UTF-8 codepoint, single character

                    len -= u8_len;
                    str += u8_len;
            }

            result = ( result << left ) + character;

            if ( carryover = result & overflow_shift_threshold )
                result ^= carryover >> right;

            result &= ~carryover;
        }

        inline_stack_reset;
        inline_stack_push(sv_2mortal(newSViv( result )));
        inline_stack_done;
    }

    EOL
}

return 1;  ###################################################################

#,,,.,..,,,,,,,..,,.,,,.,,,..,,,.,..,,...,...,..,,...,...,.,.,,,.,,,,,,.,,,,,,
#HIM5DBLMGQSDDEXAMXYXHNKINK72IMO7RICWLA2TI6HUEWUFGF4QUAD24PW7TSJGH7SGEVK6OX35O
#\\\|OYCBP3DYWLWD4QA4YASM7QXMTMSUIHQIZ3IOS5AAPO6JGMCUPJS \ / AMOS7 \ YOURUM ::
#\[7]LSK5AQYZ5FUN776GEJMSKD7CK7HKNQP3PY7A4YYLX2WZQNPHBKCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
