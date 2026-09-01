
package AMOS7::INLINE::src::AMOS_13_ELF;  ####################################

## target namespace : AMOS7::CHKSUM::ELF ##

use v5.24;
use strict;
use English;
use warnings;

use Exporter;
use vars qw| @EXPORT @EXPORT_OK |;
use base qw| Exporter |;

@EXPORT    = qw[ ];
@EXPORT_OK = qw| $VERSION |;

our $VERSION = qw| AMOS-13-ELF-7-SRC-VER-HQ7GNVQ |;

##[ BITSTRING CONVERSION ]####################################################

sub inline_elf {    ##[ modified \ expanded elf hash algorithm ]##
    my $source = <<~'EOC';

    void inline_elf (
            SV * input_str,
            unsigned int start_sum, // make optional [LLL]
            unsigned int  elf_mode, // make optional [LLL]
            ...
        ) {

        inline_stack_vars;

        if( input_str == &PL_sv_undef )
            croak("input_str is undefined");

        unsigned int overflow_shift_threshold = 0XFE000000; // <-- 7 bit
        unsigned int result = start_sum;  // start_sum 0 when no continuation
        unsigned int carryover;

        bool utf_8_as_value = true;    // add utf-8 codepoint value, not bytes
        bool ignore_0_bytes = false;  // add 777 for 0 bytes, instead 0

        unsigned int shift_reset = 4;
        unsigned int shift_limit = ~result;
        shift_limit >>= 4; // limiting left shift [ elf mode ] beyond 27 bits

        U8* str       = sv_2pvutf8_nolen( input_str );
        STRLEN    len = SvCUR( input_str );       // <-- AFTER utf8 upgrade :
        // upgrading a byte >= 0x80 grows the buffer [ 1 byte -> 2 byte utf8
        // sequence ]. reading SvCUR() before the upgrade [ as this used to ]
        // captures the PRE-upgrade byte count, which is always <= the real
        // [ possibly larger ] upgraded buffer. the loop below decrements
        // `len` by the exact number of bytes it advances `str`, so on a
        // buffer containing >= 0x80 bytes, near the end `len` can drop
        // below the `u8_len` of the next decoded sequence -- `len -= u8_len`
        // on the unsigned STRLEN then WRAPS to a huge value instead of
        // going negative, and the loop reads straight past the end of the
        // buffer into adjacent memory until it happens to stop [ this is
        // what the "Malformed UTF-8 character (empty string)" warnings
        // silenced by `no warnings 'utf8'` in ELF.pm's elf_chksum were :
        // out-of-bounds reads, not the codepoint decode itself being wrong
        // ]. the out-of-bounds content differs across perl versions/builds
        // [ different internal SV allocation slack ], which is why this
        // surfaced as a checksum divergence between perl 5.40 and 5.42
        // rather than a crash. see data/tasks/
        // elf-chksum-c-vs-pure-perl-utf8-divergence.md and
        // c25519-key-decryption-failure-hypothesis-2026-08-25.md
        UV  str_pos_0 = (UV) str;
        STRLEN  c_pos = 0;
        U8* str_end   = str + len;   // true end of buffer, for bounds-
                                      // checked utf8_to_uvchr_buf() calls
                                      // below -- previously an
                                      // uninitialized `next_chr` local was
                                      // passed as the `send` boundary arg,
                                      // giving the decoder no real bound

        unsigned int shift_value = 13;     //  AMOS-13 : 13  ||  elf-hash : 4

        // overflow threshold value [ up to 32 bit ]
        if( inline_stack_items >= 5 && SvOK(inline_stack_item(4)) ) {
            if( !looks_like_number( inline_stack_item(4) ) )
                croak("overflow threshold parameter not numerical");
                overflow_shift_threshold = POPu; // right shift threshold
            if( overflow_shift_threshold > 0XFFFFFFFF ) // elf sum: 0XF0000000
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

            UV character;
            STRLEN u8_len;

            if( *str == 0 ) {                                 // ASCII 0
                len--;
                character = z_val;
                str++;

            } else if ( is_ascii || !utf_8_as_value ) { // ASCII 1 .. 127
                len--;
                character = *str;
                str++;

            } else {                            // ASCII 128 .. 255 and UTF-8

                character = utf8_to_uvchr_buf( str, str_end, &u8_len );

                // `character`'s VALUE may legitimately be < 256 [ e.g. every
                // high byte 0x80..0xFF that sv_2pvutf8_nolen's Latin-1
                // upgrade turned into a 2-byte UTF-8 sequence decodes back
                // to that same < 256 codepoint ] -- but the buffer pointer
                // must always advance by the REAL number of bytes the
                // decoder consumed [ u8_len ], never by 1 regardless of the
                // decoded value. forcing u8_len=1 here [ removed ] advanced
                // `str` past only half of every such 2-byte sequence,
                // landing on its trailing continuation byte and cascading
                // "unexpected continuation byte" errors through the rest of
                // the buffer -- see data/tasks/
                // c25519-key-decryption-failure-hypothesis-2026-08-25.md

                // never allow zero-length advance : some malformed [ e.g.
                // non-text binary input ] byte sequences can otherwise
                // decode with u8_len == 0, which would spin the outer
                // while(len>0) loop forever on the same byte
                if ( u8_len == 0 ) {
                    u8_len = 1;
                }

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

    EOC

    my $fallback_sub = sub {    ## pure-perl AMOS-13-ELF-7 implementation ##
        my ( $input_str, $start_sum, $elf_mode, $shift_bits,
            $overflow_threshold )
            = @ARG;

        return warn_err( 'input_str is undefined', 1 )
            if not defined $input_str;

        ## set defaults matching C implementation ##
        $start_sum //= 0;
        ## AMOS-13 : left shift bits ##
        $elf_mode //= 7;
        ## AMOS-13 : right shift bits ##
        $shift_bits         //= 13;
        $overflow_threshold //= 0xFE000000;    ## 7-bit overflow threshold ##

        return warn_err( 'overflow_threshold out of range', 1 )
            if $overflow_threshold > 0xFFFFFFFF;
        return warn_err( 'shift_bits out of range [1..64]', 1 )
            if $shift_bits < 1 || $shift_bits > 64;

        my $result      = $start_sum & 0xFFFFFFFF;  ## keep 32-bit boundary ##
        my $shift_reset = 4;
        ## special value for null bytes ##
        my $z_val = 777;

        ## entropy-loss-avoidance threshold : computed ONCE from the        ##
        ## starting result [ matching the C implementation's one-time       ##
        ## setup, AMOS_13_ELF.pm lines 44-45 ] -- NOT recomputed per        ##
        ## character. earlier version of this fallback recomputed it inside ##
        ## the loop below, which is a real transcription bug: it made the   ##
        ## threshold track the CURRENT (growing) $result instead of staying ##
        ## fixed, causing the entropy-loss-avoidance branch to fire at a    ##
        ## different point than the C version for any sufficiently long     ##
        ## input, independent of character content                          ##
        my $shift_limit = ~$result >> 4;

        ## iterate through string as UTF-8 codepoints ##
        ##
        ## RESOLVED 2026-08-25 [ was: KNOWN LIMITATION ]: this used to      ##
        ## diverge from the compiled C implementation for any input         ##
        ## containing bytes >= 0x80. A byte-level Encode::decode rewrite    ##
        ## was tried here first and did NOT close the gap -- because the    ##
        ## actual cause was never a decode-model mismatch between this      ##
        ## codepoint-based loop and the C code's byte-level one. It was two ##
        ## real bugs in the C side itself [ this file, ~lines 48-49 and     ##
        ## ~128-134 ]: a stale pre-upgrade `len` that could underflow the   ##
        ## unsigned STRLEN and read past the buffer, and a forced `u8_len = ##
        ## 1` override that misaligned the byte cursor on every upgraded    ##
        ## high byte. With both fixed in the C source, this unpack('U*')    ##
        ## codepoint loop and the compiled C now agree exactly -- verified  ##
        ## across 320+ random binary vectors [ 1..512 bytes ] plus the      ##
        ## fixed UTF-8/malformed/high-entropy test set, zero mismatches.    ##
        ## See data/tasks/  elf-chksum-c-vs-pure-perl-utf8-divergence.md    ##
        ## and data/tasks/                                                  ##
        ## c25519-key-decryption-failure-hypothesis-2026-08-25.md for the   ##
        ## full investigation                                               ##
        foreach my $character ( unpack( 'U*', $input_str ) ) {

            ## reset left shift if approaching entropy loss ##
            if ( $elf_mode > $shift_reset && $result >= $shift_limit ) {
                $elf_mode = $shift_reset;
            }

            ## substitute null with z_val, use character codepoint ##
            ## otherwise                                           ##
            my $chr_val = ( $character == 0 ) ? $z_val : $character;

            ## accumulate with left shift ##
            $result = ( ( $result << $elf_mode ) + $chr_val ) & 0xFFFFFFFF;

            ## handle overflow carryover via XOR ##
            if ( my $carryover = $result & $overflow_threshold ) {
                $result ^= ( $carryover >> $shift_bits );
                $result &= ~$carryover;
            }
            $result &= 0xFFFFFFFF;    ## maintain 32-bit boundary ##
        }

        return $result;
    };

    return {
        qw| source | => $source,

        qw| package | => qw| AMOS7::CHKSUM::ELF |,    ## inline_elf ##

        qw| fallback | => $fallback_sub
    };
}

return 5;    ##  true  ##

#,,,.,.,,,,..,.,.,..,,..,,,,,,,,,,,,,,.,,,,.,,..,,...,...,.,.,.,.,,..,.,.,,,,,
#6LD56F6SVVYVZHAGM7H3TWSWL3TBRMKSVETTLZH2MHQX2HZEMWZUE7F4FAEVKWWCKGVIP47NFNFFO
#\\\|BCVIAGSUR5CTJ7TPVPVUYUYITPXCBETFWFR7TCPSAN2UNUMS5A2 \ / AMOS7 \ YOURUM ::
#\[7]ZLZLLFGNSUHZ72BQSEDAUKADPQ4ASTOJM5LGIRH4FQEYRKLYGODQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
