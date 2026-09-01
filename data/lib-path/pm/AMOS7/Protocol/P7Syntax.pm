
package AMOS7::Protocol::P7Syntax;   #########################################

use v5.24;
use strict;
use English;
use warnings;

our $VERSION = qw| AMOS-Protocol-P7Syntax-XKC91QZ |;

use Exporter;
use base qw| Exporter |;
use vars qw| $VERSION @EXPORT @EXPORT_OK |;

@EXPORT = qw[ ];

@EXPORT_OK = qw| $VERSION p7_syntax__translate |;

## deliberately dependency-free : no 'use AMOS7'/'use AMOS7::CHKSUM' --     ##
## this sub is also called from bin/Protocol-7's own bootstrap, before base ##
## is loaded, so nothing here may pull in a chain that could affect boot    ##
## order                                                                    ##

##[ P7 -> PERL SYNTAX TRANSLATION ]###########################################

##     kept in lockstep with the inline copy in bin/Protocol-7 by hand      ##
##     -- see the comment there. duplicated instead of shared because       ##
##     bin/Protocol-7 needs this before 'use lib' for data/lib-path/pm      ##
##     is safe to rely on that early in boot, and ptd/format-code need      ##
##     a real module they can 'use'                                         ##
##                                                                          ##
##     region-aware : a blind whole-string regex can't tell a string        ##
##     literal from code, so '<key.chain>' inside a single-quoted           ##
##     string used to translate too, corrupting the quoting -- and          ##
##     '\<key.chain>' in bare code [ intending a perl reference ]           ##
##     silently failed to translate at all, since the same backslash is     ##
##     also this translator's own escape marker. region rules mirror        ##
##     real perl's own interpolation semantics : single-quote / qw() /      ##
##     tr/// / y/// / q() / <<'TAG' -- never translate, backslash or        ##
##     not [ no real perl construct here ever interpolates, so there is     ##
##     nothing for a p7-specific escape to do ] double-quote / qq() /       ##
##     m() / s() / qr() [ non-' delim ] / <<TAG -- translate by default     ##
##     ; a backslash immediately before '<' suppresses it, exactly like     ##
##     '\$foo' suppresses variable interpolation in a double-quoted         ##
##     string in real perl comments [ # to end of line ] -- passed          ##
##     through verbatim, untouched bare code -- always translated, no       ##
##     backslash exception, so '\<key.chain>' correctly becomes             ##
##     '\$data{...}' [ a real reference ]                                   ##

my %CLOSE_OF = ( '(' => ')', '{' => '}', '[' => ']', '<' => '>' );

## every helper below takes the source as a SCALAR REF, never by value :    ##
## 'my ( $str, ... ) = @_' copies the whole module source on each call, and ##
## these are called once per quote / regex / keyword in the file            ##

## delimiter patterns are memoized by delimiter char rather than rebuilt by ##
## string interpolation on each call -- interpolating quotemeta() output    ##
## into m{} defeats perl's regex cache and forces a re-parse every time.    ##
## the delimiter alphabet is tiny [ mostly ' " | { } ( ) / ] and repeats    ##
## heavily within a file, so these hashes stay small and hot                ##
my ( %PAIRED_RE, %SAMECHAR_RE );

## regex-scan based [ not a per-character perl loop ] : each iteration      ##
## jumps forward by a full regex match instead of one char at a time, which ##
## matters since this runs on every quote/regex body in every file          ##
sub find_paired_end {    ## $pos just past the opening delim ##
    my ( $sref, $pos, $open, $close ) = @_;
    ## unrolled-loop form [ friedl ] : 'plain* (?: escape plain* )*' lets  ##
    ## the engine scan runs of plain chars with its fast character-class   ##
    ## loop, instead of re-entering an alternation once per character. the ##
    ## two forms are equivalent because the plain class excludes both the  ##
    ## backslash and both delimiters, so there is no ambiguity             ##
    my $re = $PAIRED_RE{ $open . $close } //= do {
        my $qopen  = quotemeta($open);
        my $qclose = quotemeta($close);
        qr{\G[^\\$qopen$qclose]*(?:\\.[^\\$qopen$qclose]*)*([$qopen$qclose])}s;
    };
    my $depth = 1;
    pos($$sref) = $pos;
    while ( $$sref =~ m{$re}gc ) {
        if ( $open ne $close and $1 eq $open ) { $depth++; }
        else { $depth--; return pos($$sref) if $depth == 0; }
    }
    return undef;
}

sub find_samechar_end {    ## $pos just past the opening delim ##
    my ( $sref, $pos, $delim ) = @_;
    my $re = $SAMECHAR_RE{$delim} //= do {
        my $qdelim = quotemeta($delim);
        qr{\G[^\\$qdelim]*(?:\\.[^\\$qdelim]*)*$qdelim}s;
    };
    pos($$sref) = $pos;
    return pos($$sref) if $$sref =~ m{$re}gc;
    return undef;
}

## consume one delimited body : $pos must point AT the opening delim char. ##
## returns ( $open, $close, $inner_text, $pos_after_close ) or ()          ##
sub consume_body {
    my ( $sref, $pos ) = @_;
    my $open  = substr( $$sref, $pos, 1 );
    my $close = $CLOSE_OF{$open};
    my $end;
    if ( defined $close ) {
        $end = find_paired_end( $sref, $pos + 1, $open, $close );
    } else {
        $close = $open;
        $end   = find_samechar_end( $sref, $pos + 1, $open );
    }
    return () unless defined $end;
    return ( $open, $close, substr( $$sref, $pos + 1, $end - $pos - 2 ),
        $end );
}

## second body of s///, tr///, y/// : $pos is right after the first body's  ##
## close delim. for paired delimiters a fresh open char follows [ maybe     ##
## after whitespace ]; for same-char delimiters the same delim continues.   ##
## returns ( $open2, $close2, $inner2, $pos_after, $body2_start,            ##
## $has_own_open_char ). for paired delimiters body2 carries its own        ##
## literal opening char in the source [ needs re-emitting ] ; for same-char ##
## delimiters it does not [ the middle delimiter was already emitted as     ##
## body1's close ]                                                          ##
sub consume_second_body {
    my ( $sref, $pos, $open1, $close1 ) = @_;
    if ( $open1 ne $close1 ) {
        pos($$sref) = $pos;
        $$sref =~ m{\G\s*}gc;
        my $p = pos($$sref);
        my @b = consume_body( $sref, $p );
        return () unless @b;
        my ( $open2, $close2, $inner2, $end2 ) = @b;
        return ( $open2, $close2, $inner2, $end2, $p, 1 );
    }
    my $end = find_samechar_end( $sref, $pos, $open1 );
    return () unless defined $end;
    return ( $open1, $open1, substr( $$sref, $pos, $end - $pos - 1 ),
        $end, $pos, 0 );
}

my %QLIKE = map { $_ => 1 } qw| q qq qw qr m s tr y |;

## $pos must point at the first letter of a candidate keyword. returns ( ##
## $keyword, $delim_pos ) or ()                                          ##
sub match_qlike_op {
    my ( $sref, $pos ) = @_;
    return () if $pos > 0 and substr( $$sref, $pos - 1, 1 ) =~ m{[\w\$]};
    ## anything right after '->' is a method name, never an operator ##
    ## keyword [ eg $event->y, $obj->s ] -- real perl's own rule     ##
    return () if $pos >= 2 and substr( $$sref, $pos - 2, 2 ) eq qw|->|;
    pos($$sref) = $pos;
    return () unless $$sref =~ m|\G([a-z]{1,2})\b|cg;
    my $kw = $1;
    return () unless exists $QLIKE{$kw};
    $$sref =~ m{\G[ \t]*}gc;
    my $p = pos($$sref);
    return () if $p >= length($$sref);
    return () if substr( $$sref, $p, 2 ) eq qw|=>|;  ## autoquoted bareword ##
    my $delim = substr( $$sref, $p, 1 );
    return () if $delim =~ m{[\w\s]};    ## must be a real delimiter char ##
    return ( $kw, $p );
}

## interpolation class of one delimited body, mirroring real perl :         ##
## q()/qw()/tr///y/// never interpolate ; '-delimited bodies never          ##
## interpolate [ m'..' s'..'..' qr'..' ] ; everything else [ qq m s qr with ##
## a non-' delim, plain "..." ] interpolates by default                     ##
sub qlike_class {
    my ( $kw, $delim ) = @_;
    return 'NEVER' if $kw eq qw|q|  or $kw eq qw|qw|;
    return 'NEVER' if $kw eq qw|tr| or $kw eq qw|y|;
    return 'NEVER' if $delim eq qw|'|;
    return 'INTERP';
}

## pre-compiled once [ NOT re-interpolated per call -- string-interpolating ##
## a pattern on every invocation defeats perl's regex caching and forces a  ##
## re-parse each time, which dominates runtime when this is called at every ##
## flush boundary ]                                                         ##
my ($RE_SUB_CALL_ARGS_NOESC, $RE_SUB_CALL_NOESC,   $RE_SUB_VAR_ARGS_NOESC,
    $RE_SUB_VAR_NOESC,       $RE_KEYCHAIN_NOESC,   $RE_SUB_CALL_ARGS_ESC,
    $RE_SUB_CALL_ESC,        $RE_SUB_VAR_ARGS_ESC, $RE_SUB_VAR_ESC,
    $RE_KEYCHAIN_ESC,
);

BEGIN {
    $RE_SUB_CALL_ARGS_NOESC = qr{<\[([\w\-\.]+)\]>\s*->\(};
    $RE_SUB_CALL_NOESC      = qr{<\[([\w\-\.]+)\]>};
    $RE_SUB_VAR_ARGS_NOESC  = qr{<\[(\$\w+)\]>\s*->\(};
    $RE_SUB_VAR_NOESC       = qr{<\[(\$\w+)\]>};
    $RE_KEYCHAIN_NOESC      = qr{<([\w\-:]+\.[\w\-\.:]+)>};
    $RE_SUB_CALL_ARGS_ESC   = qr{(?<!\\)<\[([\w\-\.]+)\]>\s*->\(};
    $RE_SUB_CALL_ESC        = qr{(?<!\\)<\[([\w\-\.]+)\]>};
    $RE_SUB_VAR_ARGS_ESC    = qr{(?<!\\)<\[(\$\w+)\]>\s*->\(};
    $RE_SUB_VAR_ESC         = qr{(?<!\\)<\[(\$\w+)\]>};
    $RE_KEYCHAIN_ESC        = qr{(?<!\\)<([\w\-:]+\.[\w\-\.:]+)>};
}

sub translate_segment {
    my ( $text, $honor_escape ) = @_;
    return $text unless index( $text, '<' ) >= 0;    ## cheap early-out ##
    ## the four sub-call rules all require a literal '<[' -- one index() ##
    ## skips all four passes for a segment that has none                 ##
    my $has_call = index( $text, '<[' ) >= 0;
    my $out      = $text;
    if ($honor_escape) {
        if ($has_call) {
            $out =~ s|$RE_SUB_CALL_ARGS_ESC|\$code{'$1'}->(|g;
            $out =~ s|$RE_SUB_CALL_ESC|\$code{'$1'}->()|g;
            $out =~ s|$RE_SUB_VAR_ARGS_ESC|\$code{$1}->(|g;
            $out =~ s|$RE_SUB_VAR_ESC|\$code{$1}->()|g;
        }
        $out =~ s{$RE_KEYCHAIN_ESC}
                 {do { my $k = "\$data{'$1'}"; $k =~ s<\.><'}{'>g; $k }}ge;
    } else {
        if ($has_call) {
            $out =~ s|$RE_SUB_CALL_ARGS_NOESC|\$code{'$1'}->(|g;
            $out =~ s|$RE_SUB_CALL_NOESC|\$code{'$1'}->()|g;
            $out =~ s|$RE_SUB_VAR_ARGS_NOESC|\$code{$1}->(|g;
            $out =~ s|$RE_SUB_VAR_NOESC|\$code{$1}->()|g;
        }
        $out =~ s{$RE_KEYCHAIN_NOESC}
                 {do { my $k = "\$data{'$1'}"; $k =~ s<\.><'}{'>g; $k }}ge;
    }
    return $out;
}

## emit one quote-like body [ open .. translated-or-raw-inner .. close ]  ##
sub render_body {
    my ( $open, $close, $inner, $class ) = @_;
    return
          $open
        . ( $class eq 'INTERP' ? translate_segment( $inner, 1 ) : $inner )
        . $close;
}

my $RE_HEREDOC_MARKER;

BEGIN {
    $RE_HEREDOC_MARKER
        = qr{\G<<(~?)(?:'([A-Za-z_]\w*)'|"([A-Za-z_]\w*)"|(\\?)([A-Za-z_]\w*))};
}

sub match_heredoc_marker {    ## $pos points at '<<' ##
    my ( $sref, $pos ) = @_;
    pos($$sref) = $pos;
    if ( $$sref =~ m{$RE_HEREDOC_MARKER}gc ) {
        my ( $indent, $sq, $dq, $bs, $bare ) = ( $1, $2, $3, $4, $5 );
        my $tag = $sq // $dq // $bare;
        return (
            {   'tag'    => $tag,
                'interp' => ( defined $sq or length $bs ) ? 0 : 1,
                'indent' => length($indent)               ? 1 : 0,
            },
            pos($$sref)
        );
    }
    return ();
}

## consume a heredoc body : $pos is right after the newline that follows    ##
## the marker line. returns ( $body, $terminator_line_and_newline_verbatim, ##
## $pos_after )                                                             ##
my %HEREDOC_RE;    ## memoized by indent-flag + terminator tag ##

sub extract_heredoc_body {
    my ( $sref, $pos, $hd ) = @_;
    my $tag = $hd->{'tag'};
    my $key = $hd->{'indent'} . $tag;
    %HEREDOC_RE = () if keys %HEREDOC_RE > 512;    ## bound the cache ##
    my $re = $HEREDOC_RE{$key}
        //= $hd->{'indent'}
        ? qr{\G(.*?\n)(^[ \t]*\Q$tag\E\s*$)(\n|\z)}sm
        : qr{\G(.*?\n)(^\Q$tag\E\s*$)(\n|\z)}sm;
    pos($$sref) = $pos;
    if ( $$sref =~ m{$re}gc ) {
        return ( $1, $2 . $3, pos($$sref) );
    }
    my $rest = substr( $$sref, $pos );    ## unterminated : consume to EOF ##
    return ( $rest, '', $pos + length($rest) );
}

## every possible trigger this scanner cares about, in one alternation --   ##
## expressed as 'consume everything that is NOT a trigger', possessively,   ##
## so the engine's fast character-class loop handles the common [ boring ]  ##
## runs, and only reaches the keyword alternation for identifiers that      ##
## actually start with one of its five initial letters                      ##
##                                                                          ##
## a newline is only a trigger while a heredoc marker is waiting for its    ##
## body to start -- otherwise it is just ordinary code text                 ##
##                                                                          ##
## a quoted literal or a comment that contains no '<' is swallowed by the   ##
## skip instead of being dispatched : with no '<' in it, translate_segment  ##
## provably cannot alter it, and it provably cannot be entered from outside ##
## either -- the quote and '#' characters that bracket it appear in none of ##
## the five translation patterns' character classes, so no match can span   ##
## its boundary. the region rules are therefore unchanged, the region       ##
## simply does not have to be isolated to be left alone. these alternatives ##
## are all-or-nothing : the moment a '<' shows up the whole alternative     ##
## fails [ possessive, so it cannot backtrack into a partial match ] and    ##
## the scanner stops and dispatches to the real region handler              ##
my ( $RE_SKIP, $RE_SKIP_NL );

BEGIN {
    my $body = q{ (?:
              [^%%NL%%\#'"<\w]++                                ## punctuation
            | ' [^\\\\'<]*+ (?: \\\\[^<] [^\\\\'<]*+ )*+ '   ## '..' sans '<'
            | " [^\\\\"<]*+ (?: \\\\[^<] [^\\\\"<]*+ )*+ "   ## ".." sans '<'
            | \# [^\n<]*+ (?= \n | \z )                 ## comment sans '<'
            | < (?!<)                                    ## lone '<', not '<<'
            | [^\Wqmsty] \w*+                     ## word, no keyword initial
            | (?! (?<!\w) (?:qq|qw|qr|tr|q|m|s|y) \b ) \w++  ## not a keyword
        )*+ };
    ( my $plain = $body ) =~ s{%%NL%%}{};
    ( my $nl    = $body ) =~ s{%%NL%%}{\\n};
    $RE_SKIP    = qr{\G$plain}sx;
    $RE_SKIP_NL = qr{\G$nl}sx;
}

## the two quoted-literal forms, whole-literal and precompiled : matching   ##
## the opening delimiter as part of the pattern means the scanner never has ##
## to re-seat pos() to step over it                                         ##
my ( $RE_SQ_LITERAL, $RE_DQ_LITERAL );

BEGIN {
    $RE_SQ_LITERAL = qr{\G'[^\\']*(?:\\.[^\\']*)*'}s;
    $RE_DQ_LITERAL = qr{\G"[^\\"]*(?:\\.[^\\"]*)*"}s;
}

sub p7_syntax__scan {
    my $sref = shift;
    my $len  = length $$sref;
    my $pos  = 0;
    my $out  = '';

    ## pending CODE text is tracked as a source offset, not accumulated     ##
    ## into a buffer : it is always contiguous with the last append, so the ##
    ## whole pending region is just [ $code_start .. $pos ) and can be cut  ##
    ## out once, at flush time                                              ##
    my $code_start = 0;
    my @pending_heredocs;

    my $skip_re = $RE_SKIP;

    while ( $pos < $len ) {

        ## consume every byte that cannot begin a trigger, in one engine ##
        ## pass, then dispatch on the single character we stopped at     ##
        pos($$sref) = $pos;
        $$sref =~ m{$skip_re}gc;
        $pos = pos($$sref);
        last if $pos >= $len;

        my $c = substr( $$sref, $pos, 1 );

        ## dispatch is keyed on the stop character. the branches are        ##
        ## mutually exclusive by first character, so ordering them by       ##
        ## frequency [ quotes first ] is behaviour-preserving : a quote can ##
        ## never begin a quote-like operator keyword, and vice versa        ##

        if ( $c eq qw|'| ) {    ## NEVER class : emitted verbatim ##

            if ( $$sref =~ m{$RE_SQ_LITERAL}gc ) {
                my $end = pos($$sref);
                if ( $pos > $code_start ) {
                    my $seg
                        = substr( $$sref, $code_start, $pos - $code_start );
                    $out
                        .= index( $seg, '<' ) < 0
                        ? $seg
                        : translate_segment( $seg, 0 );
                }
                $out .= substr( $$sref, $pos, $end - $pos );
                $pos = $code_start = $end;
                next;
            }
            ## unterminated : fall through to the single-character append ##

        } elsif ( $c eq qw|"| ) {    ## INTERP class : translate the body ##

            if ( $$sref =~ m{$RE_DQ_LITERAL}gc ) {
                my $end = pos($$sref);
                if ( $pos > $code_start ) {
                    my $seg
                        = substr( $$sref, $code_start, $pos - $code_start );
                    $out
                        .= index( $seg, '<' ) < 0
                        ? $seg
                        : translate_segment( $seg, 0 );
                }
                my $inner = substr( $$sref, $pos + 1, $end - $pos - 2 );
                $out .= qw|"|
                    . (
                    index( $inner, '<' ) < 0
                    ? $inner
                    : translate_segment( $inner, 1 )
                    ) . qw|"|;
                $pos = $code_start = $end;
                next;
            }

        } elsif ( $c eq "\n" ) {

            $pos++;    ## the newline itself stays part of the code region ##
            if (@pending_heredocs) {
                if ( $pos > $code_start ) {
                    my $seg
                        = substr( $$sref, $code_start, $pos - $code_start );
                    $out
                        .= index( $seg, '<' ) < 0
                        ? $seg
                        : translate_segment( $seg, 0 );
                }
                for my $hd (@pending_heredocs) {
                    my ( $body, $term, $next )
                        = extract_heredoc_body( $sref, $pos, $hd );
                    $out
                        .= $hd->{'interp'}
                        ? translate_segment( $body, 1 )
                        : $body;
                    $out .= $term;
                    $pos = $next;
                }
                @pending_heredocs = ();
                $code_start       = $pos;
                $skip_re          = $RE_SKIP;
            }
            next;

        } elsif ( $c eq '#' ) {    ## comment : verbatim to end of line ##

            if ( $pos > $code_start ) {
                my $seg = substr( $$sref, $code_start, $pos - $code_start );
                $out
                    .= index( $seg, '<' ) < 0
                    ? $seg
                    : translate_segment( $seg, 0 );
            }
            my $eol = index( $$sref, "\n", $pos );
            $eol = $len if $eol < 0;
            $out .= substr( $$sref, $pos, $eol - $pos );
            $pos = $code_start = $eol;
            next;

        } elsif ( $c eq '<' ) {

            ## the skip pattern only stops on '<' when it is '<<', and     ##
            ## match_heredoc_marker re-checks that itself. the marker text ##
            ## stays part of the code region                               ##
            my ( $hd, $after ) = match_heredoc_marker( $sref, $pos );
            if ($hd) {
                push @pending_heredocs, $hd;
                $skip_re = $RE_SKIP_NL;
                $pos     = $after;
                next;
            }

        } else {    ## a quote-like operator keyword at a word boundary ##

            my ( $kw, $delim_pos ) = match_qlike_op( $sref, $pos );
            my @b1 = defined $kw ? consume_body( $sref, $delim_pos ) : ();
            if (@b1) {
                my ( $open1, $close1, $inner1, $end1 ) = @b1;
                if ( $pos > $code_start ) {
                    my $seg
                        = substr( $$sref, $code_start, $pos - $code_start );
                    $out
                        .= index( $seg, '<' ) < 0
                        ? $seg
                        : translate_segment( $seg, 0 );
                }
                $out .= substr( $$sref, $pos, $delim_pos - $pos );
                $out .= render_body( $open1, $close1, $inner1,
                    qlike_class( $kw, $open1 ) );
                $pos = $end1;

                if ( $kw eq qw|s| or $kw eq qw|tr| or $kw eq qw|y| ) {
                    my @b2
                        = consume_second_body( $sref, $pos, $open1, $close1 );
                    if (@b2) {
                        my ( $open2, $close2, $inner2, $end2, $body2_start,
                            $has_own_open )
                            = @b2;
                        $out .= substr( $$sref, $pos, $body2_start - $pos );
                        my $class2
                            = ( $kw eq qw|s| )
                            ? qlike_class( qw|s|, $open2 )
                            : 'NEVER';
                        if ($has_own_open) {
                            $out .= render_body( $open2, $close2, $inner2,
                                $class2 );
                        } else {
                            $out .= (
                                $class2 eq 'INTERP'
                                ? translate_segment( $inner2, 1 )
                                : $inner2
                            ) . $close2;
                        }
                        $pos = $end2;
                    }
                }
                $code_start = $pos;
                next;
            }
        }

        ## unterminated quote, a '<<' that is not a heredoc, or a keyword   ##
        ## that is not an operator : the character stays in the code region ##
        $pos++;
    }

    if ( $len > $code_start ) {
        my $seg = substr( $$sref, $code_start, $len - $code_start );
        $out
            .= index( $seg, '<' ) < 0
            ? $seg
            : translate_segment( $seg, 0 );
    }
    return $out;
}

## scan in byte mode : every structural character this scanner keys on is   ##
## ascii, and utf-8 is self-synchronizing [ no ascii byte ever occurs       ##
## inside a multi-byte sequence ], so byte-level scanning is equivalent --  ##
## but it avoids perl's character-index arithmetic on utf8-flagged strings, ##
## which the scanner's substr/pos access pattern makes pathological [       ##
## measured 42x slower on a 75k module file ]. every module source reaches  ##
## this translator utf8-flagged [ bin/Protocol-7 opens with                 ##
## :encoding(UTF-8) ], so this is the common path, not an edge case         ##
sub p7_syntax__translate
{    ## p7 syntax -> perl [ becomes base.syntax.translate ]

    my $str      = shift // '';
    my $was_utf8 = utf8::is_utf8($str);
    utf8::encode($str) if $was_utf8;
    my $result = p7_syntax__scan( \$str );
    if ($was_utf8) {
        utf8::decode($result);
        utf8::upgrade($result);    ## keep the caller's flag state intact ##
    }
    return $result;
}

return 5;  ###################################################################

#,,..,..,,.,.,,.,,.,.,,,.,.,,,...,,.,,...,,,,,..,,...,...,..,,,.,,,..,,,.,...,
#53WQZY5HRUDURXHHT2DUQFNK2FLHZC5ZT6JVSUZS5NYE345A5NOTN6RK3PJTLDCXT7YPQJP3G4ZEE
#\\\|65UYG7OG4BGK6QXQNYGBQM3M6SWCGCBHJNU2ZUELJZXU2RFHHXS \ / AMOS7 \ YOURUM ::
#\[7]O2VXA7LMFFDPBRXMSVF27RF47FVIOA753XVZG7NWIXP2VQESRIBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
