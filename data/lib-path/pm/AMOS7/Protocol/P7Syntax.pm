
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

@EXPORT_OK = qw| $VERSION p7_syntax__translate p7_syntax__perl_c
    p7_syntax__floor_perl p7_syntax__sig_fragment_rx |;

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

## every helper below takes the source as a SCALAR REF, never by value :  ##
## 'my ( $str, ... ) = @ARG' copies the whole module source on each call, ##
## and these are called once per quote / regex / keyword in the file      ##

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
    my ( $sref, $pos, $open, $close ) = @ARG;
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
    my ( $sref, $pos, $delim ) = @ARG;
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
    my ( $sref, $pos ) = @ARG;
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
    my ( $sref, $pos, $open1, $close1 ) = @ARG;
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

my %QLIKE = map { $ARG => 1 } qw| q qq qw qr m s tr y |;

## true when $pos sits on a segment of a '<..>' data key chain : directly ##
## after '<' or after a key chain character inside it [ both the 'y' and  ##
## the '-y' remainder of 'qq-y' in <x.qq-y> ]. scans back over key chain  ##
## characters [ word, '-', '.', ':' ] -- reaching '<' means inside a key. ##
## any other left context stops the scan before a '<' can be reached      ##
sub inside_key_chain {
    my ( $sref, $pos ) = @ARG;
    my $p = $pos - 1;
    $p-- while $p >= 0 and substr( $$sref, $p, 1 ) =~ m{[\w.:-]};
    return 0 if $p < 0;
    return substr( $$sref, $p, 1 ) eq qw|<| ? 1 : 0;
}

## $pos must point at the first letter of a candidate keyword. returns ( ##
## $keyword, $delim_pos ) or ()                                          ##
sub match_qlike_op {
    my ( $sref, $pos ) = @ARG;
    return () if $pos > 0 and substr( $$sref, $pos - 1, 1 ) =~ m{[\w\$]};
    ## anything right after '->' is a method name, never an operator ##
    ## keyword [ eg $event->y, $obj->s ] -- real perl's own rule     ##
    return () if $pos >= 2 and substr( $$sref, $pos - 2, 2 ) eq qw|->|;
    ## a '<..>' data key chain segment is key text, not an operator   ##
    return () if inside_key_chain( $sref, $pos );
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
    my ( $kw, $delim ) = @ARG;
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
    my ( $text, $honor_escape ) = @ARG;
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
    my ( $open, $close, $inner, $class ) = @ARG;
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
    my ( $sref, $pos ) = @ARG;
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
    my ( $sref, $pos, $hd ) = @ARG;
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

##[ FLOOR PERL SYNTAX CHECK ]#################################################

##  the oldest perl the project supports is the 'use v5.NN' line of         ##
##  bin/Protocol-7. the syntax checkers [ bin/format-code -c, bin/dev/ptd ] ##
##  compile with the local perl AND with that floor perl when installed :   ##
##  a newer perl accepts code an older one refuses to compile [ {1,65535}  ##
##  : 5.42 compiles it, 5.36 and 5.28 do not -- 2026-10-08 ]                ##
##                                                                          ##
##  floor perl lookup [ first found ] :                                     ##
##    $P7_FLOOR_PERL       path to the binary [ 'none' : local perl only ] ##
##    ~/.local/perl-5.NN.*/bin/perl5.NN.*    [ -Dversiononly install ]     ##
##    perl5.NN.* in PATH                                                   ##

my ( $floor_resolved, $floor_minor, $floor_bin, $floor_noted );

sub floor_perl_minor {    ## minor version from bin/Protocol-7 [ or undef ] ##
    my $root = __FILE__;
    $root =~ s{/data/lib-path/pm/AMOS7/Protocol/P7Syntax\.pm\z}{} or return;
    open( my $fh, qw| < |, "$root/bin/Protocol-7" )               or return;
    while ( my $line = <$fh> ) {
        return $1 if $line =~ m{^\s*use\s+v5\.(\d+)};
        last      if $INPUT_LINE_NUMBER > 42;
    }
    return;
}

sub patch_level { ( $ARG[0] =~ m{perl5\.\d+\.(\d+)\z} )[0] // -1 }

sub local_minor { int( ( $OLD_PERL_VERSION - 5 ) * 1000 + 0.5 ) }

sub p7_syntax__floor_perl {    ## ( binary path or undef, '5.NN' or undef ) ##
    return ( $floor_bin, $floor_minor ? "5.$floor_minor" : undef )
        if $floor_resolved++;

    $floor_minor = floor_perl_minor() // return;
    my $env = $ENV{'P7_FLOOR_PERL'} // '';
    ## the local perl is the floor perl [ or older ] : nothing to add ##
    return ( undef, "5.$floor_minor" )
        if local_minor() <= $floor_minor
        or $env eq qw| none |;

    if ( length $env ) {
        $floor_bin = $env if -x $env;
    } else {
        my $m = $floor_minor;
        my @found
            = grep { -x $ARG and not -d $ARG }
            glob("$ENV{HOME}/.local/perl-5.$m.*/bin/perl5.$m.*"),
            map { glob("$ARG/perl5.$m.*") }
            grep { length and -d } split m{:}, $ENV{'PATH'} // '';
        ($floor_bin) = sort { patch_level($b) <=> patch_level($a) } @found;
    }
    return ( $floor_bin, "5.$floor_minor" );
}

my %floor_module;

sub floor_has_module {    ## cached : can the floor perl load $module ##
    my ( $bin, $module ) = @ARG;
    return $floor_module{$module} //= do {
        system(qq{"$bin" -M$module -e 1 >/dev/null 2>&1}) == 0 ? 1 : 0;
    } if $module =~ m{^\w+$};
    return 1;
}

## run perl -c [ $args : the quoted argument string ] under the local perl ##
## and the floor perl. returns ( \@local_lines, \@floor_only_lines, '5.NN' ##
## when the floor perl ran ). floor lines already in the local output are  ##
## dropped , so the caller reports only what the floor perl alone refuses  ##
sub p7_syntax__perl_c {
    my $args = shift;

    my @local_out = qx{ perl $args 2>&1 };
    my ( $bin, $version ) = p7_syntax__floor_perl();

    if ( not defined $bin ) {
        warn ":\n:: floor perl $version not installed -- syntax checked with "
            . "perl $PERL_VERSION only [ P7_FLOOR_PERL=none : silent "
            . "]\n:\n"
            if defined $version
            and not $floor_noted++
            and local_minor() > ( $floor_minor // 0 )
            and ( $ENV{'P7_FLOOR_PERL'} // '' ) ne qw| none |;
        return ( \@local_out, [], undef );
    }

    ## the floor perl must not see local::lib paths of the local perl : its ##
    ## XS modules are built for another perl version                        ##
    local %ENV = %ENV;
    delete @ENV{qw| PERL5LIB PERL5OPT PERL_LOCAL_LIB_ROOT |};
    my @floor_out = qx{ "$bin" $args 2>&1 };

    my %seen_local = map  { $ARG => 1 } @local_out;
    my @floor_only = grep { not $seen_local{$ARG} } @floor_out;

    ## a module the floor perl lacks [ Gtk3 , .. ] is stubbed -- its        ##
    ## qualified barewords then fail under strict. not a perl version issue ##
    ## : dropped when the floor perl cannot load that module                ##
    @floor_only = grep {
        not m{^Bareword ["'](\w+)(?:::\w+)+["'] not allowed while}
            or floor_has_module( $bin, $1 )
    } @floor_only;
    ## floor 'syntax OK' or the final restatement alone : nothing to add ##
    @floor_only = ()
        if not grep { not m{syntax OK\s*$|had compilation errors\.?$} }
        @floor_only;
    return ( \@local_out, \@floor_only, $version );
}

##[ SIGNATURE FRAGMENT ABOVE THE FOOTER ]#####################################

## a leftover directly ABOVE a file's real signature footer [ found 2026-10-09
## in 56 files, ed8f5e06d ] : a lone separator line, a separator + an agent's
## '#PLACEHOLDER ..' line, a whole placeholder block starting
## '#,,PLACEHOLDER', or a separator + '</content>' -- each followed by a blank
## line and then the real footer.  the sign tool's own stub passes [
## source.extract_sig_body ] only remove complete stub shapes, never these.
##
## deliberately NARROW : only those line kinds, and only when the real footer
## [ separator + checksum line ] follows right after the blank line -- an
## intentional comment or encoding above a footer never matches.  capture 1 =
## the fragment lines [ without the blank line after them ].  used by
## sourcecode.console.update-signatures [ warn, or strip with :strip: ] and
## the pre-commit hook [ warn ]

sub p7_syntax__sig_fragment_rx {
    return qr{^(\#(?:[,\.]{70,}|,,PLACEHOLDER[,\.]*)\n
                (?:(?:\#[^\n]*PLACEHOLDER[^\n]*|\#:{70,}|</content>)\n)*)
              \n(?=\#[,\.]{70,}\n\#[A-Z2-7]{60,}\n)}mx;
}

return 5;  ###################################################################

#,,.,,,,.,.,.,...,.,,,,,.,,,,,...,,..,,,,,,.,,..,,...,..,,.,.,,..,...,.,.,,..,
#V4OPEMPWHL5VRCN5KBYLOOUXF3U2EHZRIVHULEVB4XFOOOCFBD7KXWDB5IY6DIVQEOZRSB6RA2NUG
#\\\|QRYB4G3K46NMI6ULATK5OUKL5BOEERNAF7P6BPHU2FT2LU3TADU \ / AMOS7 \ YOURUM ::
#\[7]RH7TXGMGPHLNXRN47B4UNWDEMUSDYOU34GMVHO6FS5KB6N3ST6CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
