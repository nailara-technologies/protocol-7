## [:< ##

package AMOS7::TERM::Editor;    #############################################

## standalone interactive multi-line text editor for terminals.
##
## extracted from bin/todo [ keep behaviour and look in step ] so both todo
## and the standalone vault script can use it. this module must stay
## lightweight : it never loads AMOS7::TERM
## [ that pulls in Event and Crypt::PRNG::Fortuna ], it only needs
## Term::ReadKey, Time::HiRes and core modules. it never writes temp files
## [ secrets pass through it ].
##
## bracketed paste [ mode 2004 ], mouse wheel tracking
## [ DECSET 1000 + SGR 1006 ] and modifyOtherKeys=1 [ XTMODKEYS ] are enabled
## while the editor is open and disabled on every exit path, including abort,
## die and signals. modifyOtherKeys=1 makes only the keys without a legacy
## ctrl byte [ ctrl-. ctrl-, .. ] arrive as CSI-u sequences -- every legacy
## byte is untouched ; terminals without support ignore the mode.  a paste
## arrives as one event : a hashref { paste => $text } holding the decoded
## block. line endings are normalised on insert
## [ "\r\n" and lone "\r" become "\n" ]. without bracketed paste, a "\r"
## immediately followed by "\n" still counts as a single enter.
##
## character contract : text, summary, title, label and hint are character
## strings [ decoded ], and the edited result is returned as characters.  all
## cursor and width math counts characters -- multibyte input is read as utf-8
## and assembled into single characters. wide [ east-asian ] glyphs still
## count as one, same as any other character. output goes to STDOUT, which
## callers are expected to have a utf-8 layer on.
##
## api :  edit_text( { text => $initial, title => $label, summary => $line,
## label => 'details', hint => $extra_keys, width => $cols,  colors => \%C,
## wrap => 1, on_save => sub ( $text ) { ... } } )  returns the edited text,
## or undef when aborted.  editor_normalize_paste( $text )   -> $text with
## \r\n / \r -> \n editor_deinterlace( \@lines, $cursor_line ) ->
## [ \@lines, $changed ]  read_editor_event( $reader, \$aborted ) -> $key | {
## paste => $text } editor_make_reader() -> reader hashref bound to STDIN
##
## 'wrap => 1' turns long lines into full-width visual rows instead of
## scrolling them sideways [ the historical default ] : the wrap is view-only
## -- the buffer keeps the raw lines and the saved file is never re-flowed.
## the fold is WORD-AWARE by default
## [ 'wrap_words => 0' for the historical fixed-width character fold ] : rows
## break after eligible whitespace and the break is bracket-aware in the
## bin/format-code sense -- a space touching a bracket counts the bracket into
## the word, so bracketed groups move as one. the cursor's whole block
## [ head row + continuation rows ] darkens as one selected unit ; other lines
## keep their bright text, continuation rows carry a dim wrap marker under the
## ':', and a wrapped block is followed by a dim dotted separator row
## [ 'wrap_sep => 0' opts out ] -- a visual blank line between blocks, except
## before a blank line of the buffer itself : that empty line renders AS the
## separator, one gap row instead of two. the separator counts as a visual
## row, so scrolling, the hardware cursor, clicks and the page keys all
## account for it.
##
## an optional on_save callback makes ctrl-s [ alias ctrl-o ] a real save : it
## receives the current buffer, normalized exactly like the returned text. a
## true return means saved [ the dirty flag clears ] ; a false return or a die
## shows 'save failed : <reason>' and the buffer stays dirty. without on_save
## the keys only explain that ctrl-x saves + quits -- nothing is ever claimed
## saved.
##
## ctrl-l removes a line onto a kill stack [ per editor session ] and
## ctrl-v brings it back [ LIFO ] -- a simple line undo \ reorder ;
## empty lines never enter this stack [ they have nothing to restore,
## so they never bury a real kill ]. ctrl-. [ \x0e, or CSI-u \e[46;5u ]
## restores IN ORDER and IN PLACE from a second register that keeps
## EVERY line [ blanks are file content ] : an entry prepends when its
## kill landed above the previous one [ bottom-up truncation ], so the
## run rebuilds at the kill position in the ORIGINAL file order however
## the kills were made ;
## terminals that give ctrl-, its own byte [ \x1c legacy, \e[44;5u
## CSI-u ] kill with it. a literal ',' \ '.' can never be bound --
## the terminal must send a distinguishable encoding. with an empty
## stack ctrl-v pastes the system clipboard
## [ wl-paste, xsel, xclip, powershell on wsl ] as lines above the cursor ;
## the hint line only advertises ctrl-v when something can actually be pasted.
## ctrl-y clears the registers -- the clipboard content stays unpasteable
## until it changes, the desktop selection itself is never touched. the
## mouse wheel scrolls like the arrow keys [ wheel tracking DECSET 1000 +
## SGR 1006 -- no dependency, terminals without mouse support ignore it ;
## 'mouse => 0' or P7_EDITOR_NO_MOUSE opts out ]. pgup \ pgdn
## [ \e[5~ \ \e[6~ ] move a visible page per press with wheel semantics :
## the down page stops at the last line instead of growing one at EOF
## [ the arrow keys still grow ] ; the page size is the current content
## height, so it follows terminal resizes.
##
## the wheel accelerates on a NON-LINEAR curve : every tick still moves one
## line on the spot, and ticks arriving closer together than WHEEL_WINDOW form
## a burst. a fast burst [ avg gap under WHEEL_FAST ] collapses to exactly one
## page once the wheel pauses and the window asserts ; a medium burst pays
## nothing for its first  WHEEL_MIN_TICKS - 1 ticks
## [ short rolls stay relative navigation ], then ramps to up to
## WHEEL_MAX_PAGES pages. a left mouse press positions the cursor
## [ content geometry mapped from the click, past-EOL clamps to the line end ].
## the keys bar packs whole cells, pages from its border markers \ wheel and
## runs action clicks through their key bindings. f1 cycles keys \ hybrid \
## hidden and remembers the mode in ~/.7/editor-keys-bar-mode [ best-effort ].
##
## secrets hygiene [ keep in step with AMOS7::Vault ] : note lines are mlocked
## best-effort when IO::AIO is available [ optional -- a standalone copy
## without it runs unlocked, past the memlock limit the rest does too ] and
## every register \ scratch \ buffer copy is overwritten with random bytes
## before it is dropped -- the registers never survive the editor.
##
## a reader is a hashref with two closures :
##   read   => sub ( $timeout ) -> single byte or undef
##   ungetc => sub ( $bytes )   -> push bytes back [ read again in order ]
## and optionally :
##   eof    => sub ()           -> true once the input is gone [ tty closed ]
##   pending => sub ()          -> true when a byte is already waiting

use v5.32.0;
use utf8;
use strict;
use English;
use warnings;
use Digest::SHA ();

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

## wheel acceleration [ all in seconds ] : ticks arriving closer than
## WHEEL_WINDOW form a burst -- every tick still moves one line on the spot,
## and when the burst asserts [ the wheel paused for a window ] the
## accumulated roll pays out as page jumps. a fast burst collapses to exactly
## one page no matter its length ; a medium burst only pays past
## WHEEL_MIN_TICKS [ the first lines of a roll stay relative navigation ],
## then min( burst - threshold, WHEEL_MAX_PAGES ) pages
use constant WHEEL_WINDOW    => 0.18;
use constant WHEEL_FAST      => 0.07;
use constant WHEEL_MIN_TICKS => 5;
## seconds : one click, not a double ##
use constant CLICK_BOUNCE    => 0.25;
use constant WHEEL_MAX_PAGES => 2;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK $VERSION |;

our $VERSION = qw| AMOS7::TERM::Editor-VERSION.LYHOEGI |;

@EXPORT_OK = qw|
    edit_text
    editor_normalize_paste
    editor_deinterlace
    read_editor_event
    editor_make_reader
    |;

##[ DEPENDENCIES ]############################################################

use Fcntl       qw| F_SETFL O_NONBLOCK |;
use Errno       qw| EAGAIN EINTR |;
use POSIX       qw| TCSANOW ICRNL IXON |;
use Time::HiRes qw| time |;

sub _disable_icrnl {
    ## ReadMode(4) leaves the icrnl input flag on : clear it so pasted "\r\n"
    ## reaches the editor un-translated [ POSIX::Termios is core ]
    my $term = POSIX::Termios->new;
    return if not defined $term;
    return if $term->getattr( fileno(STDIN) ) != 0;
    $term->setiflag( $term->getiflag & ~ICRNL );
    $term->setattr( fileno(STDIN), TCSANOW );
    return TRUE;
}

sub _disable_ixon {
    ## ctrl-s must reach the editor as "\x13", never be swallowed as an xoff
    ## flow-control byte. the ReadKey builds in use already clear ixon in
    ## ReadMode(4), this makes it explicit
    ## [ and safe against ReadKey changes ]. ReadMode(0) restores the saved
    ## settings on every exit path, same as icrnl above
    my $term = POSIX::Termios->new;
    return if not defined $term;
    return if $term->getattr( fileno(STDIN) ) != 0;
    $term->setiflag( $term->getiflag & ~IXON );
    $term->setattr( fileno(STDIN), TCSANOW );
    return TRUE;
}

our $readkey_loaded = 0;

sub require_readkey {
    return if $readkey_loaded;
    eval { require Term::ReadKey; 1 }
        or die "AMOS7::TERM::Editor : Term::ReadKey is required\n";
    $readkey_loaded = 1;
    return TRUE;
}

##[ DEFAULT COLOR MAP ]#######################################################

our %default_colors = (
    T   => '',    ## TRUE blue [ titles ]     ##
    0   => '',    ## purple [ frame ]         ##
    3   => '',    ## phosphor green [ hints ] ##
    B   => '',    ## bold                     ##
    R   => '',    ## reset                    ##
    dim => '',    ## dim                      ##
);

sub _colors {
    my $given = shift // {};
    my %C     = %default_colors;
    for my $k ( keys %{$given} ) {
        $C{$k} = $given->{$k} // '';
    }
    return \%C;
}

##[ FRAME BORDER LINE ]#######################################################
## local copy of AMOS7::TERM::frame_border_line [ keep in step ] so this ##
## module never loads AMOS7::TERM. render a border line via the          ##
## anchor/fill/slot elasticity model.                                    ##

sub frame_border_line {
    my $params = shift // {};

    my $elements = $params->{'elements'} // [];
    my $values   = $params->{'values'}   // {};
    my $width    = $params->{'width'}    // 0;
    my $reset    = $params->{'reset'}    // '';

    return '' if not @{$elements};

    ## sum fixed-width parts and locate fill slots ##
    my $fixed_width = 0;
    my @fill_idx;
    for my $i ( 0 .. $#{$elements} ) {
        my $el = $elements->[$i];
        if ( not defined $el->{'type'} ) {
            warn 'frame_border_line : element type not defined';
            return '';
        }
        if ( $el->{'type'} eq qw| anchor | ) {
            $fixed_width += length( $el->{'value'} // '' );
        } elsif ( $el->{'type'} eq qw| slot | ) {
            $fixed_width += length( $values->{ $el->{'name'} } // '' );
        } elsif ( $el->{'type'} eq qw| fill | ) {
            push @fill_idx, $i;
        }
    }

    my $available = $width - $fixed_width;
    $available = 0 if $available < 0;

    ## distribute available column budget across fill elements ##
    my %alloc;
    if (@fill_idx) {
        if ( @fill_idx == 1 ) {
            $alloc{ $fill_idx[0] } = $available;
        } else {
            my $sum_min = 0;
            $sum_min += ( $elements->[$_]->{'min'} // 1 ) for @fill_idx;
            my $used = 0;
            for my $idx (@fill_idx) {
                my $min = $elements->[$idx]->{'min'} // 1;
                my $a   = int( $available * $min / $sum_min );
                $a = 0 if $a < 0;
                $alloc{$idx} = $a;
                $used += $a;
            }
            my $rem = $available - $used;
            $alloc{ $fill_idx[-1] } += $rem if $rem != 0;
        }
    }

    ## assemble line with per-element color wrap ##
    my $line = '';
    for my $i ( 0 .. $#{$elements} ) {
        my $el    = $elements->[$i];
        my $color = $el->{'color'} // '';
        my $r     = length($color) ? $reset : '';
        if ( $el->{'type'} eq qw| anchor | ) {
            my $v = $el->{'value'} // '';
            $line .= $color . $v . $r if length $v;
        } elsif ( $el->{'type'} eq qw| slot | ) {
            my $v = $values->{ $el->{'name'} } // '';
            $line .= $color . $v . $r if length $v;
        } elsif ( $el->{'type'} eq qw| fill | ) {
            my $n = $alloc{$i} // 0;
            $line .= $color . ( $el->{'char'} x $n ) . $r if $n > 0;
        }
    }

    return $line;
}

##[ PURE TRANSFORMS ]#########################################################

sub editor_normalize_paste {
    ## normalise line endings of a pasted block : "\r\n" and lone "\r" both
    ## become "\n"
    my $text = shift // '';
    $text =~ s|\r\n|\n|g;
    $text =~ s|\r|\n|g;
    return $text;
}

sub _line_is_blank {
    my $line = shift // '';
    return $line =~ m{^\s*$} ? 1 : 0;
}

sub editor_deinterlace {
    ## collapse doubled line breaks below the cursor line.
    ##
    ## with every line break doubled, a text line is followed by a run of e
    ## empty lines where e is odd ; the original had [ e - 1 ] / 2 empty
    ## lines. walk down from the cursor line : skip to the first text line,
    ## then for each following run of empty lines : when e is odd, replace the
    ## run with [ e - 1 ] / 2 empty lines and continue after the next text
    ## line ; stop at the first run with even e
    ## [ including e = 0, i.e. two text lines in a row ] or at the end of the
    ## buffer.  lines above the cursor line are untouched. whitespace-only
    ## lines count as empty.
    ##
    ## returns [ \@lines, $changed ] ; the input array is not modified.
    my ( $lines_ref, $cursor_line ) = @_;

    my @lines = @{ $lines_ref // [] };
    my $n     = scalar @lines;
    return ( \@lines, 0 ) if $n == 0;

    $cursor_line = 0      if $cursor_line < 0;
    $cursor_line = $n - 1 if $cursor_line > $n - 1;

    my $changed = 0;
    my $i       = $cursor_line;

    ## skip to the first text line at or below the cursor ##
    $i++ while $i < $n and _line_is_blank( $lines[$i] );

    while ( $i < $n ) {
        ## count the run of empty lines after this text line ##
        my $j = $i + 1;
        $j++ while $j < $n and _line_is_blank( $lines[$j] );
        my $e = $j - $i - 1;

        ## even run [ incl. two text lines in a row ] : stop ##
        last if $e % 2 == 0;

        my $original_empty = ( $e - 1 ) / 2;
        splice( @lines, $i + 1, $e, ('') x $original_empty );
        $n       = scalar @lines;
        $changed = 1;

        ## continue after the next text line ##
        $i = $i + 1 + $original_empty;
    }

    return ( \@lines, $changed );
}

##[ KEY READER ]##############################################################

our $stdin_pushback;
our $stdin_eof;

sub _stdin_read_byte {
    my $timeout = shift // 0;
    if ( defined $stdin_pushback and length $stdin_pushback ) {
        return substr( $stdin_pushback, 0, 1, '' );
    }

    ## a handled signal [ WINCH, CONT ] interrupts select and sysread :    ##
    ## retry for the time left. taking EINTR as a timeout cut pastes short ##
    ## and ran the rest as editing keys [ resize during a paste ]          ##
    my $deadline = time() + $timeout;
    my $r        = '';
    vec( $r, fileno(STDIN), 1 ) = 1;
    my $ready;
    while (1) {
        my $remain = $deadline - time();
        $remain = 0 if $remain < 0;
        $ready  = select( my $rout = $r, undef, undef, $remain );
        last if $ready >= 0 or $ERRNO != EINTR or $remain == 0;
    }
    return undef if $ready <= 0;

    my $b;
    my $n;
    do { $n = sysread( STDIN, $b, 1 ) } while !defined $n and $ERRNO == EINTR;
    ## eof or a read error [ EIO once the tty is gone ] : input is over ##
    $stdin_eof = TRUE
        if ( defined $n and $n == 0 )
        or ( !defined $n and $ERRNO != EAGAIN );
    return undef if !defined $n or $n == 0;
    return $b;
}

sub _stdin_ungetc {
    $stdin_pushback = $_[0] . ( $stdin_pushback // '' );
    return;
}

sub _stdin_pending {
    ## true when a byte is already waiting : pushed back, or on STDIN ##
    ## [ select timeout 0 ]                                           ##
    return TRUE if defined $stdin_pushback and length $stdin_pushback;
    my $r = '';
    vec( $r, fileno(STDIN), 1 ) = 1;
    my $ready = select( $r, undef, undef, 0 );
    return $ready > 0 ? TRUE : FALSE;
}

sub editor_make_reader {
    ## reader closure pair bound to STDIN [ the live editor input ]
    $stdin_eof = FALSE;
    return {
        read    => \&_stdin_read_byte,
        ungetc  => \&_stdin_ungetc,
        eof     => sub {$stdin_eof},
        pending => \&_stdin_pending,
    };
}

sub _read_paste_block {
    ## read until the paste terminator "\e[201~" shows up at the tail
    my ( $reader, $aborted_ref ) = @_;
    ## idle timeout, not a total one : a large or slow paste keeps going as ##
    ## long as bytes keep arriving  a terminator with more bytes already    ##
    ## pending is content, not the end : the paste arrives as one burst, so ##
    ## a real end is a terminator followed by an idle line. without this, a ##
    ## literal "\e[201~" inside pasted text                                 ##
    ## [ foot, urxvt and xterm with allowPasteControls let it through ]     ##
    ## ends the paste early and the rest runs as editing keys               ##
    my $paste = '';
    while ( !$$aborted_ref ) {
        my $b = $reader->{'read'}->(2);
        last if !defined $b;
        $paste .= $b;
        next if $paste !~ m{\x1b\[201~$};
        ## candidate end : accept only when nothing else is pending       ##
        ## [ a reader without 'pending' keeps the first-terminator rule ] ##
        last if !$reader->{'pending'} or !$reader->{'pending'}->();
    }
    $paste =~ s|\x1b\[201~$||;    ## strip terminator when complete ##
    return $paste;
}

sub read_editor_event {
    ## reads one event from the reader : a plain key string
    ## [ single character or collected escape sequence ], a hashref  { paste
    ## => $text } holding the decoded paste block, or undef on eof / abort.
    my ( $reader, $aborted_ref ) = @_;

    my $first = $reader->{'read'}->(0);
    return undef if !defined $first;

    ## enter : "\r" with an immediately available "\n" counts as one ##
    ## [ crlf paste without bracketed paste support ]                ##
    if ( $first eq "\r" ) {
        my $next = $reader->{'read'}->(0);    ## zero-timeout probe ##
        $reader->{'ungetc'}->($next)
            if defined $next and $next ne "\n";
        return "\n";
    }

    ## utf-8 lead byte : collect the continuation bytes                   ##
    ## [ same short timeout pattern as escape sequences ] and decode to a ##
    ## character                                                          ##
    if ( $first =~ m{^[\xC2-\xF4]$} ) {
        my $extra
            = $first =~ m{^[\xC2-\xDF]$} ? 1
            : $first =~ m{^[\xE0-\xEF]$} ? 2
            :                              3;
        my $bytes    = $first;
        my $deadline = time() + 0.1;
        while ( length($bytes) < $extra + 1 and time() < $deadline ) {
            my $remain = $deadline - time();
            $remain = 0.001 if $remain < 0.001;
            my $next = $reader->{'read'}->($remain);
            last if !defined $next;
            ## not a continuation byte : it is the next key, not ours ##
            if ( $next !~ m{^[\x80-\xBF]$} ) {
                $reader->{'ungetc'}->($next);
                last;
            }
            $bytes .= $next;
        }
        return $bytes
            if length($bytes) == $extra + 1 and utf8::decode($bytes);

        ## incomplete or invalid sequence : push the tail back, keep the ##
        ## lead byte [ reads as its latin-1 character ]                  ##
        $reader->{'ungetc'}->( substr( $bytes, 1 ) ) if length($bytes) > 1;
        return $first;
    }

    return $first if $first ne "\e";

    ## escape sequence : collect the rest with a short timeout so a lone  ##
    ## ESC key still returns control [ sysread is interrupted by signals, ##
    ## so SIGWINCH / SIGINT reach the caller ]                            ##
    my $seq      = $first;
    my $deadline = time() + 0.1;
    while ( time() < $deadline and !$$aborted_ref ) {
        my $remain = $deadline - time();
        $remain = 0.001 if $remain < 0.001;
        my $b = $reader->{'read'}->($remain);
        last if !defined $b;

        if ( $seq eq "\e" and $b eq "\e" ) {
            ## two bare ESC in a row : treat the first as the escape key ##
            $reader->{'ungetc'}->($b);
            return $seq;
        }

        $seq .= $b;

        ## bracketed paste start "\e[200~" : swallow the whole block ##
        if ( $seq =~ m{\x1b\[200~$} ) {
            my $paste = _read_paste_block( $reader, $aborted_ref );
            utf8::decode($paste);    ## invalid content stays byte-wise ##
            return { paste => $paste };
        }

        ## SS3 keys [ f1 is ESC O P ] have a letter in their introducer ##
        last if $b =~ m{[A-Za-z~]} and $seq ne "\eO";

        ## an in-flight CSI parameter sequence
        ## [ ctrl-, \ ctrl+. as CSI-u, modified arrows .. ] may arrive
        ## byte-wise over a loaded line : a short cut here returns the prefix
        ## as an inert key and the lagging tail then TYPES into the text. once
        ## the prefix is unambiguous, keep collecting far longer
        $deadline = time() + 1 if $seq =~ m{^\x1b\[[0-9;]+$};
    }

    ## mouse reports [ wheel tracking ] : SGR \e[<btn;x;yM or legacy X10 \e[M
    ## + 3 bytes -- both end the collection above. plain clicks are eaten here
    ## [ never text ] : wheel \ click events keep their coordinates so the
    ## caller can route content and keys-bar input [ releases stay inert ]
    if ( $seq =~ m{\x1b\[<(\d+);(\d+);(\d+)([Mm])} ) {
        my ( $btn, $cx, $cy, $kind ) = ( $1, $2, $3, $4 );
        return { wheel => qw| up |,   at => [ $cx, $cy ] } if $btn == 64;
        return { wheel => qw| down |, at => [ $cx, $cy ] } if $btn == 65;
        return { click => [ $cx, $cy ] }
            if $btn == 0 and $kind eq qw| M |;
        return '';
    }
    if ( $seq eq "\x1b[M" ) {    ## X10 : the 3 coordinate bytes follow ##
        my @coord = map { $reader->{'read'}->(0.1) } 1 .. 3;
        my $btn   = $coord[0];
        return {
            wheel => qw| up |,
            at    => [ ord( $coord[1] ) - 32, ord( $coord[2] ) - 32 ]
            }
            if defined $btn
            and $btn eq chr( 32 + 64 )
            and defined $coord[1]
            and defined $coord[2];
        return {
            wheel => qw| down |,
            at    => [ ord( $coord[1] ) - 32, ord( $coord[2] ) - 32 ]
            }
            if defined $btn
            and $btn eq chr( 32 + 65 )
            and defined $coord[1]
            and defined $coord[2];
        return { click => [ ord( $coord[1] ) - 32, ord( $coord[2] ) - 32 ] }
            if defined $btn
            and $btn eq chr(32)
            and defined $coord[1]
            and defined $coord[2];
        return '';
    }
    return $seq;
}

##[ LINE DRAWING ]############################################################

sub detail_editor_draw_line {
    my ( $text, $width, $is_cursor, $cur_col, $C ) = @_;
    $text //= '';
    $text = _display_sanitize($text);

    my $vw = $width - 4;    ## room for ':  ' ... '  :' ##
    $vw = 4 if $vw < 4;

    my $display;
    if ( length($text) <= $vw ) {
        $display = $text;
    } elsif ( $cur_col < $vw - 1 ) {
        $display = substr( $text, 0, $vw - 1 ) . '<';
    } else {
        my $start = $cur_col - $vw + 3;
        ## every visible row receives the CURSOR's column : a shorter row
        ## [ still longer than the window ] would start past its own end
        ## [ substr outside of string ] -- clamp to the tail window
        my $max_start = length($text) - $vw + 2;
        $start   = $max_start if $start > $max_start;
        $start   = 0          if $start < 0;
        $display = '<' . substr( $text, $start, $vw - 2 );
        if ( $start + $vw - 2 < length($text) ) {
            substr( $display, -1, 1, '>' );
        }
    }

    $display .= ' ' x ( $vw - length($display) ) if length($display) < $vw;
    $display = substr( $display, 0, $vw );

    # Cursor line ':' markers use bold TRUE blue for highlighting; other
    # lines keep the purple frame color.
    my $border_color = $is_cursor ? $C->{T} . $C->{B} : $C->{0};
    return
          $border_color . ':'
        . $C->{T}
        . $C->{B} . '  '
        . $display . '  '
        . $border_color . ':'
        . $C->{R};
}

sub detail_editor_wrap_segments {
    ## the visual segments one logical line folds into
    ## [ view-only -- the buffer keeps the raw line ]. WORD-AWARE
    ## [ the wrap default ] breaks after the LAST ELIGIBLE whitespace inside
    ## the window : words stay whole, rows go ragged right. eligibility
    ## follows the bin/format-code rule -- a space TOUCHING a bracket counts
    ## the bracket into the word, so '[ ' and ' ]' groups move as one instead
    ## of orphaning a bracket at the row edge ; a space followed by a space is
    ## also skipped [ runs break at their last space ]. no eligible space, or
    ## a word longer than the window, still splits [ hard floor ]. FIXED-WIDTH
    ## [ 'wrap_words => 0' ] packs characters full-width the historical way
    my ( $text, $vw, $wordwise ) = @_;
    $text = _display_sanitize( $text // '' );
    ## headless callers can hand in a zero or negative width
    ## [ no tty -> terminal size 0 ] : the hard floor below would then strip
    ## ZERO characters and spin forever
    ## [ witnessed 2026-10-27 : wrap test at 99% cpu for 9h ]
    $vw = 1                            if not defined $vw or $vw < 1;
    return ('')                        if not length $text;
    return ( $text =~ m|(.{1,$vw})|g ) if not $wordwise;
    my @seg;
    while ( length $text ) {
        if ( length $text <= $vw ) {
            push @seg, $text;
            last;
        }
        ## the last ELIGIBLE whitespace in the window : search positions BELOW
        ## vw -- a space sitting exactly AT the window edge would break AFTER
        ## it into vw + 1 characters, one column over the frame, and the
        ## terminal's own wrap then tears every row below
        ## [ the 'scrolling glitch' ]. a space touching a bracket is not a
        ## break opportunity
        ## [ bin/format-code rule -- the brackets count into the word ], so
        ## '[ ' and ' ]' groups move as one instead of orphaning a bracket at
        ## the row edge ; a space followed by a space is skipped too
        ## [ runs break at their last space ]
        my ( $cut, $pos ) = ( -1, $vw - 1 );
        while ( ( my $c = rindex( $text, ' ', $pos ) ) > 0 ) {
            my $prev = substr( $text, $c - 1, 1 );
            my $next = substr( $text, $c + 1, 1 );
            if (    $prev !~ m![\[\{\(<]!
                and $next !~ m![\]\}\)>]!
                and $next ne ' ' ) {
                $cut = $c;
                last;
            }
            $pos = $c - 1;
        }
        if ( $cut <= 0 ) {    ## no eligible space : hard floor
            push @seg, substr( $text, 0, $vw, '' );
            next;
        }
        push @seg, substr( $text, 0, $cut + 1, '' );
    }
    return @seg;
}

sub detail_editor_wrap_rows {
    ## visual rows one logical line occupies when soft-wrapped -- the segment
    ## count. the SANITIZED form is what wraps [ control characters expand ],
    ## and an empty line still takes one row
    my ( $text, $vw, $wordwise ) = @_;
    return scalar detail_editor_wrap_segments( $text, $vw, $wordwise );
}

sub detail_editor_draw_wrapped {
    ## soft-wrap rendering : one logical line becomes as many rows as its
    ## segments need [ never scrolled sideways ]. the buffer keeps the raw
    ## line -- wrapping is view-only, the file is untouched. the cursor's
    ## whole block [ head row + continuation rows ] darkens as ONE selected
    ## unit ; other lines keep their bright text, continuation rows carry a
    ## dim wrap marker where the head row has its left pad. a BLANK line [
    ## whitespace-only counts -- the free cursor pads a visited blank with
    ## spaces, and the rule must stay stable while it does ] that directly
    ## follows a wrapped block renders AS the dotted separator row [ $as_sep ]
    ## : the author's own blank line is the paragraph break, so it doubles as
    ## the block separator instead of stacking an empty row behind a drawn
    ## one. ANY other whitespace-only line is just one plain empty row -- it
    ## never renders its padding as a wrapped run of space rows [ the free
    ## cursor pads a visited blank so the column survives, and the layout must
    ## not grow when it does ]
    my ( $text, $width, $is_cursor, $cur_col, $C, $as_sep, $wordwise ) = @_;
    $text = _display_sanitize( $text // '' );

    my $vw = $width - 4;    ## room for ':  ' ... '  :' ##
    $vw = 4 if $vw < 4;

    if ( $as_sep and _line_is_blank($text) ) {
        my $b = $is_cursor ? $C->{T} . $C->{B} : $C->{0};
        ## full inner run -- the content rows carry ':  ' ... '  :' around the
        ## segment, so the dotted rule spans the same width
        return
              $b . ':'
            . $C->{dim}
            . $C->{0}
            . ( '┄' x $width )
            . $b . ':'
            . $C->{R};
    }
    $text = '' if _line_is_blank($text);

    my $border_color = $is_cursor ? $C->{T} . $C->{B} : $C->{0};
    my @segments     = detail_editor_wrap_segments( $text, $vw, $wordwise );
    @segments = ('') if !@segments;

    my @rows;
    for my $i ( 0 .. $#segments ) {
        my $seg = $segments[$i];
        $seg .= ' ' x ( $vw - length($seg) ) if length($seg) < $vw;
        if ($is_cursor) {
            ## the selected block darkens together : dim wraps the whole row
            ## content [ segment AND ┊ ], so the folded line still reads as
            ## one selected unit ; the ':' borders keep the bold TRUE-blue
            ## selection chrome and the ┊ inherits the row dim -- colored like
            ## the content it decorates, which is what is being dimmed.  the
            ## dim resets BEFORE the trailing border so the frame keeps full
            ## strength [ the bleed lesson ]
            my $pad = $i > 0 ? $C->{T} . '┊ ' : $C->{T} . '  ';
            push @rows,
                  $border_color . ':'
                . $C->{dim}
                . $pad
                . $seg . '  '
                . $C->{R}
                . $border_color . ':'
                . $C->{R};
        } else {
            my $left = $C->{T} . $C->{B} . '  ';
            if ( $i > 0 ) {
                ## the dotted vertical under the ':' reads as "this row
                ## continues the line" [ the same ┊ family todo list draws in
                ## its right-hand state column, colored like the content it
                ## decorates -- dim TRUE blue here ; the editor speaks utf-8
                ## end to end, so box glyphs are safe wherever it runs ]. dim
                ## is SCOPED to the glyph : it resets before the segment text,
                ## else the whole continuation row would render dimmed against
                ## the bright head row
                $left
                    = $C->{dim}
                    . $C->{T} . '┊'
                    . $C->{R}
                    . $C->{T}
                    . $C->{B} . ' ';
            }
            push @rows,
                  $border_color . ':'
                . $left
                . $seg . '  '
                . $border_color . ':'
                . $C->{R};
        }
    }
    return @rows;
}

sub _display_sanitize {
    ## control characters in the payload [ a paste, an import ] would reach ##
    ## the terminal as its own commands and break the frame -- render them  ##
    ## visible and inert : ^K for VT, ^[ for ESC, ^? for DEL, <XX> for the  ##
    ## C1 range. the buffer itself keeps the bytes                          ##
    my $text = shift // '';
    $text =~ s{\x7f}{^?}g;
    $text =~ s{([\x00-\x09\x0b-\x1f])}{ '^' . chr( ord($1) + 64 ) }ge;
    $text =~ s|([\x{80}-\x{9f}])| sprintf '<%02X>', ord($1) |eg;
    return $text;
}

sub _on_wsl {
    state $cached = do {
        my $rel = '';
        if ( open my $fh, '<', '/proc/sys/kernel/osrelease' ) {
            local $INPUT_RECORD_SEPARATOR;
            $rel = <$fh> // '';
        }
        $rel =~ m{WSL} ? TRUE : FALSE;
    };
    return $cached;
}

sub _clipboard_read {
    ## read-only clipboard access                                           ##
    ## [ keep in step with bin/p7-vault's clipboard_tool ] : the first tool ##
    ## that answers wins. returns the decoded text, undef when no tool      ##
    ## answers or the selection is empty. P7_EDITOR_NO_CLIP is the test \   ##
    ## escape hatch                                                         ##
    return undef if $ENV{'P7_EDITOR_NO_CLIP'};
    my @readers = (
        $ENV{'WAYLAND_DISPLAY'} ? 'wl-paste -n 2>/dev/null' : (),
        $ENV{'DISPLAY'}         ? 'xsel -bo 2>/dev/null' : (),
        $ENV{'DISPLAY'}         ? 'xclip -selection clipboard -o 2>/dev/null'
        : (),
        _on_wsl()
        ? 'powershell.exe -NoProfile -Command Get-Clipboard 2>/dev/null'
        : (),
    );
    foreach my $cmd (@readers) {
        my $out = qx|$cmd|;
        next if $CHILD_ERROR or not defined $out or not length $out;
        utf8::decode($out);
        return $out;
    }
    return undef;
}

## secrets hygiene [ keep in step with AMOS7::Vault ] : the note lines      ##
## never reach swap -- their pages pinned best-effort when IO::AIO is there ##
## [ optional : a standalone copy without it runs unlocked, and past the    ##
## memlock limit the rest runs unlocked too ]. copies the editor is done    ##
## with are overwritten before they are dropped                             ##

sub _mlock {
    my $sref = shift;
    state $have_aio = eval { require IO::AIO; 1 };
    return FALSE if not $have_aio or not length( ${$sref} // '' );
    ## best effort : wide [ character ] strings make IO::AIO die, those stay
    ## unlocked. no event loop here : flush waits for the request.  IO::AIO
    ## takes a set $@ as a callback error and dies with it -- an earlier
    ## failed eval must not surface here
    my $locked = eval {
        IO::AIO::aio_mlock( ${$sref}, 0, length ${$sref} );
        local $EVAL_ERROR;
        IO::AIO::flush();
        1;
    };
    return $locked ? TRUE : FALSE;
}

## overwrite secrets in place twice with random bytes, then truncate
## [ base.buffer.erase_secure ] -- the same length keeps the same buffer
sub _wipe {
    foreach my $sref (@ARG) {
        next if not defined $sref or not ref $sref;
        my $len = length( ${$sref} // '' );
        next if not $len;
        substr( ${$sref}, 0, $len,
            pack q{C*}, map { int rand 256 } 1 .. $len )
            for 1 .. 2;
        ${$sref} = '';
    }
    return;
}

sub editor_leave_line {
    my ( $lines_ref, $line_idx ) = @_;
    return 0 if $line_idx < 0 or $line_idx > $#$lines_ref;
    my $old = $lines_ref->[$line_idx];
    $lines_ref->[$line_idx] =~ s| +$||;
    return $old ne $lines_ref->[$line_idx];
}

sub editor_pad_line_to_col {
    my ( $lines_ref, $line_idx, $col ) = @_;
    return 0 if $line_idx < 0 or $line_idx > $#$lines_ref;
    my $len = length( $lines_ref->[$line_idx] );
    return 0 if $col <= $len;
    $lines_ref->[$line_idx] .= ' ' x ( $col - $len );
    return 1;
}

sub editor_normalize_details {
    my @lines = @_;
    s| +$|| for @lines;
    pop @lines while @lines and $lines[-1] eq '';
    return @lines;
}

sub _save_error_reason {
    ## one short line out of an on_save failure : first line, width-capped ##
    my $reason = shift // 'unknown error';
    $reason =~ s|\s+$||;
    ($reason) = split m|\n|, $reason;
    $reason = substr( $reason, 0, 40 ) . ' ..' if length($reason) > 40;
    return $reason;
}

##[ BRACKETED PASTE MODE ]####################################################

sub paste_enable {
    print "\e[?2004h";
    return;
}

sub paste_disable {
    print "\e[?2004l";
    return;
}

##[ MOUSE WHEEL ]#############################################################

sub mouse_enable {
    ## button-event reporting in SGR form : wheel arrives as \e[<64/65;x;yM.
    ## press-only [ 1000h ] keeps terminal text selection working ; the
    ## DECSETs are ignored wholesale by terminals without mouse support
    print "\e[?1000h\e[?1006h";
    return;
}

sub mouse_disable {
    print "\e[?1000l\e[?1006l";
    return;
}

## XTMODKEYS modifyOtherKeys=1 : keys that have no legacy ctrl byte
## [ ctrl-. ctrl-, ctrl+; .. ] arrive as CSI-u sequences, e.g. \e[46;5u, which
## the dispatch binds ; level 1 leaves every legacy byte [ ctrl-a .. ]
## untouched ; terminals without support ignore the mode
sub modify_other_keys_enable {
    print "\e[>4;1m";
    return;
}

sub modify_other_keys_disable {
    print "\e[>4;0m";
    return;
}

##[ INTERACTIVE EDITOR ]######################################################

sub edit_text {
    my $params = shift // {};

    require_readkey();

    my $C       = _colors( $params->{'colors'} );
    my $title   = _display_sanitize( $params->{'title'}   // '' );
    my $summary = _display_sanitize( $params->{'summary'} // '' );
    my $label   = $params->{'label'} // 'details';
    my $hint    = $params->{'hint'}  // '';
    my $width   = $params->{'width'};
    my $on_save = $params->{'on_save'};

    my @lines = split m|\n|, $params->{'text'} // '', -1;
    @lines = ('') if !@lines;
    _mlock( \$ARG ) foreach @lines;    ## the note never reaches swap ##

    ## modified = the content differs from the saved state ; $dirty is only ##
    ## a revision counter [ the free-cursor pad + strip bump it twice while ##
    ## the text stays the same ] -- a checksum, no second plain copy        ##
    my $content_sum = sub {
        my $text = join "\n", editor_normalize_details(@lines);
        utf8::encode($text);
        my $sum = Digest::SHA::sha256($text);
        _wipe( \$text );
        return $sum;
    };
    my $saved_sum = $content_sum->();

    my ( $cur_line, $cur_col ) = ( 0, 0 );
    my $first_visible = 0;
    my $content_rows  = 1;     ## set by every redraw ; page keys read it ##
    my $drawn_sig     = '';    ## empty forces the first paint           ##
    my $dirty = 0;    ## buffer revision : ++ at every mutation, 0 on save --
    ## the redraw gate keys on it, so EVERY edit repaints [ a boolean misses
    ## same-cursor mutations : delete never moved the cursor, so the second
    ## press repeated the frame signature and skipped the redraw while the
    ## buffer DID change ]
    my $aborted = 0;
    my $resized = 0;

    ## the kill stack : ctrl-l pushes the removed line, ctrl-v pops it back ##
    ## in above the cursor [ LIFO ]. per edit_text call on purpose : note   ##
    ## lines are secrets, they must not linger in module state after the    ##
    ## editor closes                                                        ##
    my @kill_stack;

    ## the ordered view of the same kills, for ctrl+. : an entry prepends when
    ## its kill landed above the previous one [ bottom-up  truncation ], so
    ## the run always rebuilds the ORIGINAL file order regardless of kill
    ## direction ; $fifo_from is the run's insertion point, $fifo_last_idx
    ## tracks the direction
    my @fifo_run;
    my $fifo_from;
    my $fifo_last_idx;

    ## ctrl-v advertises itself only with something to paste : the kill   ##
    ## stack fills as ctrl-l removes lines ; the clipboard counts when it ##
    ## holds text at start [ probing it on every redraw would shell out ] ##
    my $clip_at_start;

    ## ctrl-y clears the registers : the clipboard content at that moment   ##
    ## stays unpasteable until it changes [ the desktop selection itself is ##
    ## never wiped -- other applications may hold it ]                      ##
    my $clip_cleared;

    ## the keys bar scrolls by whole cells ; the offset belongs to this editor
    ## session and the hit map is rebuilt from the visible plain-text geometry
    my $keys_bar_offset = 0;
    my $keys_bar_page   = 1;
    my $keys_bar_count  = 0;
    my @keys_bar_hits;

    ## one small mode file is shared by ned and every details editor. all io
    ## is best-effort : an absent or unreadable file means the hybrid default
    my $keys_bar_mode     = qw| hybrid |;
    my $keys_bar_mode_dir = defined $ENV{'HOME'} ? "$ENV{'HOME'}/.7" : '';
    my $keys_bar_mode_file
        = length $keys_bar_mode_dir
        ? "$keys_bar_mode_dir/editor-keys-bar-mode"
        : '';
    if ( length $keys_bar_mode_file ) {
        eval {
            open my $fh, '<', $keys_bar_mode_file or die;
            my $saved_mode = <$fh> // '';
            close $fh;
            chomp $saved_mode;
            $keys_bar_mode = $saved_mode
                if $saved_mode =~ m{^(?:keys|hybrid|hidden)$};
            1;
        };
    }
    my $save_keys_bar_mode = sub {
        return if not length $keys_bar_mode_file;
        eval {
            mkdir $keys_bar_mode_dir if not -d $keys_bar_mode_dir;
            open my $fh, '>', $keys_bar_mode_file or die;
            print {$fh} "$keys_bar_mode\n";
            close $fh or die;
            1;
        };
        return;
    };
    my ( $keys_bar_started, $keys_bar_events ) = ( 0,   0 );
    my ( $last_click_sig,   $last_click_at )   = ( q||, 0 );
    ## the drawn footer title, the mouse f1 span ##
    my $bar_title_width = 6;

    ## mouse wheel tracking : on unless asked off                       ##
    ## [ 'mouse => 0' or the P7_EDITOR_NO_MOUSE escape hatch ]. no      ##
    ## dependency -- terminals without mouse support ignore the DECSETs ##
    ## wholesale                                                        ##
    my $mouse_on
        = ( $params->{'mouse'} // 1 ) && not $ENV{'P7_EDITOR_NO_MOUSE'};

    ## soft-wrap mode : 'wrap => 1'. off by default -- long lines then ##
    ## scroll sideways the historical way. wrapping is view-only : the ##
    ## buffer keeps the raw lines, the file on disk is never re-flowed ##
    my $wrap = ( $params->{'wrap'} // 0 ) ? 1 : 0;

    ## 'wrap_sep' [ default on with wrap ] : a logical line that folds onto
    ## more than one row is followed by a dim dotted separator row -- a visual
    ## blank line between wrapped blocks. view-only like the wrap itself ; the
    ## separator counts as a visual row, so the scroll, the hardware cursor,
    ## clicks and the page keys all account for it. none after the buffer's
    ## last line [ the bottom padding is gap enough ] and none before a blank
    ## line [ whitespace-only counts ] -- a blank right after a wrapped block
    ## renders AS the separator row : the author's own paragraph break doubles
    ## as the block separator, one gap row instead of two. the whitespace
    ## tolerance matters : the free cursor pads a blank it visits with spaces
    ## so the column survives, and the layout must not flip when it does
    my $wrap_sep = $wrap ? ( $params->{'wrap_sep'} // 1 ) ? 1 : 0 : 0;

    ## 'wrap_words' [ default ON with wrap ] : the fold is WORD-AWARE -- rows
    ## break after eligible whitespace, words stay whole, ragged right ;
    ## eligibility follows the bin/format-code rule -- a space touching a
    ## bracket counts the bracket into the word, so  '[ like this ]' and 'f(
    ## a, b )' move as one instead of  orphaning a bracket at the row edge.
    ## words longer than the window, or a window with no eligible space, still
    ## split [ hard floor ]. 'wrap_words => 0' selects the historical
    ## fixed-width character fold
    my $wordwise = $wrap ? ( $params->{'wrap_words'} // 1 ) ? 1 : 0 : 0;

    ## wheel acceleration state [ per edit_text call, like the kill stack ] :
    ## burst counting with a flush deadline the input wait honors, so a paused
    ## wheel pays out its pages without a keypress
    my ( $wheel_burst, $wheel_dir, $wheel_at, $wheel_accum, $flush_at )
        = ( 0, 0, 0, 0, 0 );

    my $page_keys_bar = sub {
        my $dir = shift;
        $keys_bar_offset += $dir * $keys_bar_page;
        $keys_bar_offset = 0 if $keys_bar_offset < 0;
        $keys_bar_offset = $keys_bar_count - 1
            if $keys_bar_count and $keys_bar_offset >= $keys_bar_count;
        return;
    };

    ## cursor moves shared by the arrow keys and the wheel : the second arg ##
    ## lets arrows grow a line at EOF while the wheel just stops            ##
    my $move_cursor = sub {
        my $dir = shift;
        ## vertical moves CLAMP the column to the entered line -- the
        ## horizontal offset never propagates : padding every crossed line
        ## with spaces used to grow phantom wrapped blocks
        ## [ 'variable boxes' ] while scrolling, and arrow-down on the last
        ## line used to append whitespace lines outright. the free cursor
        ## stays for horizontal moves on the line being edited [ the main loop
        ## still grows the CURRENT line past its end, and editor_leave_line
        ## strips that pad when the cursor leaves ]
        if (   ( $dir < 0 and $cur_line > 0 )
            or ( $dir > 0 and $cur_line < $#lines ) ) {
            $dirty++ if editor_leave_line( \@lines, $cur_line );
            $cur_line += $dir < 0 ? -1 : 1;
            my $len = length $lines[$cur_line];
            $cur_col = $len if $cur_col > $len;
        }
        return;
    };

    ## wheel burst payout : deliberately NON-LINEAR -- a fast burst
    ## [ avg gap under WHEEL_FAST ] collapses to exactly one page no matter
    ## its length ; a medium burst pays nothing for the first  WHEEL_MIN_TICKS
    ## - 1 ticks [ short rolls stay relative  navigation ], then min( burst -
    ## threshold, WHEEL_MAX_PAGES ) pages on a steep ramp
    my $flush_wheel = sub {
        return if $wheel_burst < 2 or not $wheel_dir;
        my $avg   = $wheel_accum / ( $wheel_burst - 1 );
        my $pages = 0;
        if ( $avg < WHEEL_FAST ) {
            $pages = 1;
        } elsif ( $wheel_burst >= WHEEL_MIN_TICKS ) {
            $pages = $wheel_burst - ( WHEEL_MIN_TICKS - 1 );
            $pages = WHEEL_MAX_PAGES if $pages > WHEEL_MAX_PAGES;
        }
        $move_cursor->($wheel_dir) for 1 .. $pages * $content_rows;
        ( $wheel_burst, $wheel_dir, $wheel_accum, $flush_at )
            = ( 0, 0, 0, 0 );
        return;
    };

    ## self-pipe : signal handlers write a byte here so select() wakes up, ##
    ## giving us event-driven resize/abort handling instead of polling.    ##
    pipe( my $sig_r, my $sig_w );
    $sig_w->autoflush(1);
    fcntl( $sig_w, F_SETFL, O_NONBLOCK )
        or die "editor: fcntl sig_w: $!";
    fcntl( $sig_r, F_SETFL, O_NONBLOCK )
        or die "editor: fcntl sig_r: $!";

    local $SIG{'INT'}
        = sub { $aborted = 1; syswrite( $sig_w, 'i', 1 ); };
    local $SIG{'WINCH'}
        = sub { $resized = 1; syswrite( $sig_w, 'w', 1 ); };

    ## restore tty + bracketed paste even when a signal kills us ##
    my $sig_cleanup = sub {
        paste_disable();
        mouse_disable() if $mouse_on;
        modify_other_keys_disable();
        eval { Term::ReadKey::ReadMode(0) };
        print "\e[0 m\e[?25h\e[0 q";
    };
    local $SIG{'TERM'} = sub {
        $sig_cleanup->();
        $SIG{'TERM'} = 'DEFAULT';
        kill 'TERM', $PID;
    };
    local $SIG{'HUP'} = sub {
        $sig_cleanup->();
        $SIG{'HUP'} = 'DEFAULT';
        kill 'HUP', $PID;
    };
    local $SIG{'QUIT'} = sub {
        $sig_cleanup->();
        $SIG{'QUIT'} = 'DEFAULT';
        kill 'QUIT', $PID;
    };

    ## job control : hand the shell a sane tty while stopped, take raw mode ##
    ## back on continue [ the shell resets the tty meanwhile ]              ##
    local $SIG{'TSTP'} = sub {
        $sig_cleanup->();
        ## perl blocks TSTP while its handler runs : a re-raised TSTP only ##
        ## re-enters this handler. STOP cannot be blocked                  ##
        kill 'STOP', $PID;    ## stops here until SIGCONT ##
    };
    local $SIG{'CONT'} = sub {
        Term::ReadKey::ReadMode(4);
        _disable_icrnl();
        _disable_ixon();
        paste_enable();
        mouse_enable() if $mouse_on;
        modify_other_keys_enable();
        print "\e[4 q";
        $resized   = 1;       ## full redraw ##
        $drawn_sig = '';      ## the shell may have repainted -- paint ##
        syswrite( $sig_w, 'c', 1 );
    };

    ## raw mode : ctrl-c is read as the byte \x03, not delivered as SIGINT ##
    Term::ReadKey::ReadMode(4);
    _disable_icrnl();    ## keep pasted "\r\n" from becoming "\n\n" ##
    _disable_ixon();     ## keep ctrl-s from being eaten as xoff ##

    ## bracketed paste : the terminal wraps pasted text in  "\e[200~" ... ##
    ## "\e[201~" so a multi-line paste arrives as one block               ##
    paste_enable();
    mouse_enable() if $mouse_on;
    modify_other_keys_enable();

    ## use a steady underscore cursor while editing ##
    print "\e[4 q";

    ## the clipboard probe happens only now : shelling out before the     ##
    ## signal handlers \ raw mode above would leave an arriving ctrl-c to ##
    ## the default die during the fork \ exec latency                     ##
    $clip_at_start = _clipboard_read();

    ## make sure the drawn frame is visible before blocking for input ##
    my $old_autoflush = $OUTPUT_AUTOFLUSH;
    STDOUT->autoflush(1);

    my $reader      = editor_make_reader();
    my $last_status = '';
    my $did_abort   = 0;

    my $edit_result = eval {
        while ( !$aborted ) {
            $resized = 0;    ## resize consumed [ or none ] this redraw ##

            ## terminal size may change while editing ##
            my ( $cols, $rows ) = Term::ReadKey::GetTerminalSize();
            $cols //= 80;
            $rows //= 24;
            $cols = 40     if $cols < 40;
            $rows = 10     if $rows < 10;
            $cols = $width if defined $width and $width > 0;

            ## top border / summary / separator / top padding ##
            my $header_rows = 4;
            ## bottom padding / separator / help / bottom border ##
            my $footer_rows = 4;
            $content_rows = $rows - $header_rows - $footer_rows;
            $content_rows = 1 if $content_rows < 1;

            my $inner_width = $cols - 2;
            $inner_width = 20 if $inner_width < 20;

            ## keep cursor inside buffer ##
            $cur_line = 0       if $cur_line < 0;
            $cur_line = $#lines if $cur_line > $#lines;
            $cur_col  = 0       if $cur_col < 0;

            ## free-cursor : current line grows with spaces when cursor is ##
            ## past its end; trailing spaces are stripped on leaving       ##
            if ( $cur_col > length( $lines[$cur_line] ) ) {
                $lines[$cur_line]
                    .= ' ' x ( $cur_col - length( $lines[$cur_line] ) );
                $dirty++;
            }

            ## vertical scroll : scroll mode tracks the first visible LINE,
            ## wrap mode the first visible visual ROW [ one logical line spans
            ## as many rows as its soft-wrapped segments ]
            my $vw_wrap = $inner_width - 4;
            $vw_wrap = 4 if $vw_wrap < 4;
            ## block rows : a line's wrapped rows plus its separator row.
            ## EVERY visual-row walk
            ## [ scroll fixup, drawing, the hardware cursor, clicks, paging ]
            ## runs through this, so a separator never shifts a position.
            ## blank-as-separator predicate : a BLANK line
            ## [ whitespace-only counts ] right after a wrapped block renders
            ## as the ONE dotted separator row [ see the draw below ] instead
            ## of its own wrapped run. the free cursor pads a blank it visits
            ## with spaces [ the column survives the move ], so the test must
            ## stay true for whitespace-only -- the layout does not flip when
            ## arrows pass through, and the padded blank never grows into a
            ## wrapped run of space rows
            my $blank_as_sep = sub {
                my $idx = shift;
                return
                       $wrap_sep
                    && $idx > 0
                    && _line_is_blank( $lines[$idx] )
                    && detail_editor_wrap_rows( $lines[ $idx - 1 ],
                    $vw_wrap, $wordwise ) > 1 ? 1 : 0;
            };
            ## block rows : a line's rendered rows [ its own wrapped rows, or
            ## the ONE separator row for a blank-as-sep ], plus its separator
            ## row. EVERY visual-row walk
            ## [ scroll fixup, drawing, the hardware cursor, clicks, paging ]
            ## runs through this, so a separator never shifts a position.  a
            ## whitespace-only line is ALWAYS one rendered row
            ## [ never a wrapped run of padding spaces ] ; no separator row
            ## after a block whose NEXT line is blank
            ## [ that blank renders AS the separator ], one gap row instead of
            ## two
            my $block_rows = sub {
                my $idx = shift;
                return 1 if _line_is_blank( $lines[$idx] );
                my $rows = detail_editor_wrap_rows( $lines[$idx], $vw_wrap,
                    $wordwise );
                return $rows
                    if not $wrap_sep
                    or $rows <= 1
                    or $idx >= $#lines
                    or _line_is_blank( $lines[ $idx + 1 ] );
                return $rows + 1;
            };
            ## segment geometry for the cursor + click math : word-aware
            ## segments are RAGGED, so the col -> segment map is a cumulative
            ## walk, not division -- the segment index and start column
            ## holding a buffer column, and the start column of a segment
            ## index. a whitespace-only line is one empty segment
            ## [ offset 0, start 0 ], matching the draw
            my $seg_at_col = sub {
                my ( $idx, $col ) = @_;
                my @seg
                    = detail_editor_wrap_segments( $lines[$idx], $vw_wrap,
                    $wordwise );
                my ( $which, $pos ) = ( 0, 0 );
                for my $s (@seg) {
                    last if $col < $pos + length $s;
                    $pos += length $s;
                    $which++;
                }
                if ( $which > $#seg ) {    ## at / past EOL : the cursor
                    $which = $#seg;             ## sits ON the last segment,
                    $pos -= length $seg[-1];    ## at its end
                }
                return ( $which, $pos );
            };
            my $seg_start_at = sub {
                my ( $idx, $which ) = @_;
                my ( $n,   $pos )   = ( 0, 0 );
                for my $seg (
                    detail_editor_wrap_segments(
                        $lines[$idx], $vw_wrap, $wordwise
                    )
                ) {
                    last if $n >= $which;
                    $pos += length $seg;
                    $n++;
                }
                return $pos;
            };
            if ( not $wrap ) {
                if ( $cur_line < $first_visible ) {
                    $first_visible = $cur_line;
                } elsif ( $cur_line >= $first_visible + $content_rows ) {
                    $first_visible = $cur_line - $content_rows + 1;
                }
            } else {
                my $cursor_vrow = 0;
                $cursor_vrow += $block_rows->($_) for 0 .. $cur_line - 1;
                ## which segment holds the cursor [ ragged segments : a
                ## cumulative walk, not division ; a blank line is one empty
                ## segment -> offset 0 ]
                my ($seg_off) = $seg_at_col->( $cur_line, $cur_col );
                $cursor_vrow += $seg_off;
                if ( $cursor_vrow < $first_visible ) {
                    $first_visible = $cursor_vrow;
                } elsif ( $cursor_vrow >= $first_visible + $content_rows ) {
                    $first_visible = $cursor_vrow - $content_rows + 1;
                }
                $first_visible = 0 if $first_visible < 0;
            }

            ## redraw gate : repaint only when something visual changed.  a
            ## no-op key [ a wheel tick at EOF, an inert click, a burst that
            ## paid nothing ] otherwise clears and repaints an identical frame
            ## -- pure flicker
            my $frame_sig = join ':', $dirty, $cur_line, $cur_col,
                $first_visible, $cols, $rows, $last_status, $keys_bar_offset,
                $keys_bar_mode, $keys_bar_started, $keys_bar_events,
                scalar @kill_stack,
                ( defined $clip_at_start ? 1 : 0 ),
                ( defined $clip_cleared  ? 1 : 0 );
            if ( $frame_sig ne $drawn_sig ) {
                $drawn_sig = $frame_sig;

                ## draw frame : hide cursor during redraw to stop it ##
                ## flickering at 1,1                                 ##
                print "\e[?25l\e[H\e[2J";    ## hide cursor, clear ##

                ## top border : .::[ .:. title .:. ]:::::::::::::::. ##
                say frame_border_line(
                    {   width    => $cols,
                        reset    => $C->{R},
                        elements => [
                            {   type  => 'anchor',
                                value => '.:[ ',
                                color => $C->{0}
                            },
                            {   type  => 'anchor',
                                value => '.:. ' . $title . ' .:.',
                                color => $C->{T} . $C->{B},
                            },
                            {   type  => 'anchor',
                                value => ' ]',
                                color => $C->{0}
                            },
                            {   type  => 'fill',
                                char  => ':',
                                min   => 1,
                                color => $C->{0}
                            },
                            {   type  => 'anchor',
                                value => ':.',
                                color => $C->{0}
                            },
                        ],
                    }
                );

                ## summary line [ left-aligned, 3-space left pad, 1-space ##
                ## right pad, :: delimiter ]                              ##
                my $max_summary = $inner_width - 4;
                if ( length($summary) > $max_summary ) {
                    $summary
                        = substr( $summary, 0, $max_summary - 3 ) . ' .,';
                }
                my $sum_pad  = ' ' x ( $inner_width - length($summary) - 3 );
                my $sum_line = $sum_pad . $summary . ' ';
                say $C->{0} . ': '
                    . $C->{T}
                    . $C->{B}
                    . $sum_line
                    . $C->{0} . '::'
                    . $C->{R};

                ## separator [ :. label: .: ] ##
                say frame_border_line(
                    {   width    => $cols,
                        reset    => $C->{R},
                        elements => [
                            {   type  => 'anchor',
                                value => ':.',
                                color => $C->{0}
                            },
                            {   type  => 'anchor',
                                value => ' ' . $label . ': ',
                                color => $C->{T}
                            },
                            {   type  => 'anchor',
                                value => '.::',
                                color => $C->{0}
                            },
                            {   type  => 'fill',
                                char  => ':',
                                min   => 1,
                                color => $C->{0}
                            },
                            {   type  => 'anchor',
                                value => ':',
                                color => $C->{0}
                            },
                        ],
                    }
                );

                ## top padding ##
                say detail_editor_draw_line( '', $inner_width, 0, 0, $C );

                ## content area ##
                if ( not $wrap ) {
                    for my $i ( 0 .. $content_rows - 1 ) {
                        my $line_idx = $first_visible + $i;
                        my $line_text
                            = ( $line_idx <= $#lines )
                            ? $lines[$line_idx]
                            : '';
                        my $is_cursor = ( $line_idx == $cur_line );
                        say detail_editor_draw_line( $line_text,
                            $inner_width, $is_cursor, $cur_col, $C );
                    }
                } else {
                    ## walk visual rows from $first_visible : each logical
                    ## line contributes its wrapped segments, the tail of an
                    ## over-tall line straddles the window alone
                    my $row = 0;
                    my $li  = 0;
                    while ( $li <= $#lines
                        and $row + $block_rows->($li) <= $first_visible ) {
                        $row += $block_rows->($li);
                        $li++;
                    }
                    ## a wrapped block is followed by a dim dotted separator
                    ## row [ view-only -- never after the buffer's last line,
                    ## the bottom padding is gap enough ; and never before a
                    ## BLANK line [ whitespace-only counts ], that blank
                    ## renders AS the separator ].  purple like the frame :
                    ## the separator is structure between blocks, the dim blue
                    ## ┊ stays the content-continuation guide [ todo's state
                    ## column colors the same glyph family like its content ]
                    ## ; green stays reserved for selection modes. the
                    ## horizontal quadruple dash is ┊'s sibling
                    my $sep_row
                        = $C->{0} . ':'
                        . $C->{dim}
                        . $C->{0}
                        . ( '┄' x $inner_width )
                        . $C->{0} . ':'
                        . $C->{R};
                    my $drawn = 0;
                    while ( $drawn < $content_rows and $li <= $#lines ) {
                        ## a blank line right after a wrapped block renders as
                        ## the separator row itself
                        ## [ $block_rows counts it as that one row too ]
                        my @wrows
                            = detail_editor_draw_wrapped( $lines[$li],
                            $inner_width, ( $li == $cur_line ),
                            $cur_col, $C, $blank_as_sep->($li), $wordwise );
                        for my $r ( 0 .. $#wrows ) {
                            next if $row + $r < $first_visible;
                            last if $drawn >= $content_rows;
                            say $wrows[$r];
                            $drawn++;
                        }
                        $row += scalar @wrows;
                        if (    $wrap_sep
                            and @wrows > 1
                            and $li < $#lines
                            and not _line_is_blank( $lines[ $li + 1 ] ) ) {
                            if (    $row >= $first_visible
                                and $drawn < $content_rows ) {
                                say $sep_row;
                                $drawn++;
                            }
                            $row++;
                        }
                        $li++;
                    }
                    while ( $drawn < $content_rows ) {
                        say detail_editor_draw_line( '', $inner_width, 0, 0,
                            $C );
                        $drawn++;
                    }
                }

                ## bottom padding ##
                say detail_editor_draw_line( '', $inner_width, 0, 0, $C );

                ## footer separator : hidden mode keeps the f1 hint here ##
                my $bar_title
                    = $keys_bar_mode eq qw| hidden | ? ' F1=Keys '
                    : (     $keys_bar_mode eq qw| hybrid |
                        and $keys_bar_started ) ? ' status '
                    : $keys_bar_mode eq qw| hybrid | ? ' hybrid '
                    :                                  ' keys ';
                ## the mouse f1 span ##
                $bar_title_width = length $bar_title;
                say frame_border_line(
                    {   width    => $cols,
                        reset    => $C->{R},
                        elements => [
                            {   type  => 'anchor',
                                value => '::.',
                                color => $C->{0}
                            },
                            {   type  => 'anchor',
                                value => $bar_title,
                                color => $C->{T}
                            },
                            {   type  => 'anchor',
                                value => '.::',
                                color => $C->{0}
                            },
                            {   type  => 'fill',
                                char  => ':',
                                min   => 1,
                                color => $C->{0}
                            },
                            {   type  => 'anchor',
                                value => '::',
                                color => $C->{0}
                            },
                        ],
                    }
                );

                ## help line : stable action name, key and label per cell.  ##
                ## ctrl-s [ alias ctrl-o ] only appears with a save target. ##
                ## the later usage-count ordering plugs in at session       ##
                ## startup                                                  ##
                my @keys_bar_cells = (
                    [ 'control',   'CTRL', '' ],
                    [ 'save_quit', 'x',    'save + quit' ],
                    [ 'abort',     'c',    'abort' ],
                );
                push @keys_bar_cells, [ 'save', 's', 'save' ]
                    if defined $on_save;
                if (@kill_stack
                    or ( defined $clip_at_start
                        and not defined $clip_cleared )
                ) {
                    push @keys_bar_cells,
                        [ 'paste',   'v', 'paste' ],
                        [ 'restore', '.', 'in-order' ],
                        [ 'clear',   'y', 'clear' ];
                }
                push @keys_bar_cells,
                    [ 'del_word',    'w',           'del-word' ],
                    [ 'del_line',    'l',           'del-line' ],
                    [ 'deinterlace', 'd',           'de-interlace' ],
                    [ 'arrows',      'arrows',      '' ],
                    [ 'enter',       'enter',       '' ],
                    [ 'delete',      'del',         '' ],
                    [ 'page',        'pgup \ pgdn', 'page' ];
                push @keys_bar_cells, [ 'wrap', 'wrap', '' ] if $wrap;
                unshift @keys_bar_cells, [ '', " $hint", '' ] if length $hint;
                unshift @keys_bar_cells, [ '', " $last_status", '' ]
                    if length $last_status;
                ## hidden : the status line from the start                 ##
                ## [ an empty row says nothing ] ; hybrid : the same after ##
                ## the first key                                           ##
                if ($keys_bar_mode eq qw| hidden |
                    or (    $keys_bar_mode eq qw| hybrid |
                        and $keys_bar_started )
                ) {
                    my $bar_status = (
                        length $last_status ? $last_status
                        : ( $dirty and $content_sum->() ne $saved_sum )
                        ? 'modified'
                        : 'saved'
                        )
                        . ' · line '
                        . ( $cur_line + 1 )
                        . ' · col '
                        . ( $cur_col + 1 );
                    ## the f1 hint stays at the end                        ##
                    ## [ a periodic swap read as a state change ] ; hidden ##
                    ## has it in its title                                 ##
                    $bar_status .= ' · F1=Keys'
                        if $keys_bar_mode eq qw| hybrid |;
                    @keys_bar_cells = ( [ '', $bar_status, '' ] );
                }
                $keys_bar_count = scalar @keys_bar_cells;

                my $cell_text = sub {
                    my $cell = shift;
                    return '.:CTRL:.' if $cell->[0] eq qw| control |;
                    return "[$cell->[1]] $cell->[2]"
                        if length $cell->[2] and length( $cell->[1] ) == 1;
                    return $cell->[1]
                        . ( length $cell->[2] ? " $cell->[2]" : '' );
                };

                ## pack whole cells into the plain-text body ; colors are only
                ## applied after the cut, so escapes never count as width
                my $bar_width = $inner_width - 3;
                $keys_bar_offset = $#keys_bar_cells
                    if $keys_bar_offset > $#keys_bar_cells;
                $keys_bar_offset = 0 if $keys_bar_offset < 0;
                my @keys_bar_visible;
                my $help_text   = '';
                my %action_keys = (
                    save_quit   => "\x18",
                    abort       => "\x03",
                    save        => "\x13",
                    paste       => "\x16",
                    restore     => "\x0e",
                    clear       => "\x19",
                    del_word    => "\x17",
                    del_line    => "\x0c",
                    deinterlace => "\x04",
                );
                @keys_bar_hits = ();

                for my $idx ( $keys_bar_offset .. $#keys_bar_cells ) {
                    my $cell = $keys_bar_cells[$idx];
                    my $text = $cell_text->($cell);
                    my $sep
                        = !@keys_bar_visible ? ''
                        : (
                        $keys_bar_cells[ $idx - 1 ]->[0] eq qw| control |
                            or (length( $cell->[1] ) == 1
                            and length $cell->[2] )
                        ) ? ' '
                        : ' · ';
                    last
                        if length($help_text) + length($sep) + length($text)
                        > $bar_width;
                    my $cell_start = length($help_text) + length($sep);
                    if ( length $cell->[2]
                        and exists $action_keys{ $cell->[0] } ) {
                        push @keys_bar_hits,
                            {
                            action => $cell->[0],
                            key    => $action_keys{ $cell->[0] },
                            start  => $cell_start + 3,
                            end    => $cell_start + 5,
                            },
                            {
                            action => $cell->[0],
                            key    => $action_keys{ $cell->[0] },
                            start  => $cell_start + 7,
                            end    => $cell_start + 6 + length $cell->[2],
                            };
                    }
                    $help_text .= $sep . $text;
                    push @keys_bar_visible, $idx;
                }
                $help_text .= ' ·'
                    if @keys_bar_visible
                    and $keys_bar_visible[-1] == $#keys_bar_cells;
                $keys_bar_page = @keys_bar_visible ? @keys_bar_visible : 1;
                my $help = $help_text
                    . ( ' ' x ( $bar_width - length($help_text) ) );

                ## key chips : TRUE blue on the dark violet background   ##
                ## [ update-version's version string ] -- lights up, yet ##
                ## less contrast to a black terminal, calm on a beamer.  ##
                ## colored after the cut + pad : escapes add no width    ##
                my $chip_on
                    = !length $C->{R}
                    ? ''
                    : $C->{R}
                    . ( $C->{'K'} // "\e[48;2;9;5;42m"
                        . ( $C->{T} || "\e[38;2;6;71;195m" ) );
                my $chip_off = $C->{R} . $C->{dim} . $C->{3};
                ## brackets \ the .: :. pair in the violet frame color ##
                my $punct = $C->{R} . $C->{dim} . $C->{0};
                if ( length $C->{R} ) {    ##  no colors, no chips  ##
                    $help =~ s{\.:CTRL:\.}
                        {${punct}.:${chip_on}CTRL${punct}:.${chip_off}};
                    $help =~ s{\[(\S)\]}
                        {${punct}[${chip_on}$1${punct}]${chip_off}}g;
                    ## named keys [ arrows, enter .. ] chip as a whole word ##
                    ## -- anchored on the · cells so 'del-word' never       ##
                    ## matches                                              ##
                    $help
                        =~ s{(?:^ ?|[·\\] )\K(arrows|enter|del|pgup|pgdn)(?=[ ·])}
                        {${chip_on}$1${chip_off}}g;
                    ## green marks clickable action words only -- the plain ##
                    ## page \ wrap labels take the violet frame color       ##
                    $help =~ s{(?:^ ?| )\K(page)(?= ·| *$)}
                        {${punct}$1${chip_off}};
                    $help =~ s{(?:^ ?|· )\K(wrap)(?= ·| *$)}
                        {${punct}$1${chip_off}};
                }

                ## hidden cells replace the border's outer padding with chip
                ## blue scroll markers ; both remain three columns wide
                my $bar_more_right = (
                    @keys_bar_cells and ( !@keys_bar_visible
                        or $keys_bar_visible[-1] < $#keys_bar_cells )
                );
                my $left_marker
                    = $keys_bar_offset ? $chip_on . '< ' : $C->{0} . ': ';
                my $right_marker
                    = $bar_more_right ? $chip_on . ' >:' : $C->{0} . ' ::';
                say $left_marker
                    . $C->{dim}
                    . $C->{3}
                    . $help
                    . $right_marker
                    . $C->{R};

                ## bottom border [ no trailing newline to avoid scrolling ] ##
                print frame_border_line(
                    {   width    => $cols,
                        reset    => $C->{R},
                        elements => [
                            {   type  => 'anchor',
                                value => ':',
                                color => $C->{0}
                            },
                            {   type  => 'fill',
                                char  => ':',
                                min   => 1,
                                color => $C->{0}
                            },
                            {   type  => 'anchor',
                                value => ':',
                                color => $C->{0}
                            },
                        ],
                    }
                );

                ## position hardware cursor on the cursor line ##
                my ( $cursor_row, $cursor_col );
                if ( not $wrap ) {
                    $cursor_row
                        = $header_rows + ( $cur_line - $first_visible ) + 1;
                    my $vw = $inner_width - 6;
                    my $dcol;
                    if ( length( $lines[$cur_line] ) <= $vw ) {
                        $dcol = $cur_col;
                    } elsif ( $cur_col < $vw - 1 ) {
                        $dcol = $cur_col;
                    } else {
                        $dcol = $vw - 2;
                    }
                    $cursor_col = 4 + $dcol;    ## ':  ' puts text at col 4 ##
                } else {
                    ## the cursor's visual row holds the segment with the
                    ## cursor; the column is the in-segment offset. the walk
                    ## counts separator rows through $block_rows
                    my $cursor_vrow = 0;
                    $cursor_vrow += $block_rows->($_) for 0 .. $cur_line - 1;
                    ## the in-block segment offset + its start column [ ragged
                    ## segments : a cumulative walk, not division ; a blank
                    ## line is one empty segment ]
                    my ( $seg_off, $seg_start )
                        = $seg_at_col->( $cur_line, $cur_col );
                    $cursor_vrow += $seg_off;
                    $cursor_row
                        = $header_rows
                        + ( $cursor_vrow - $first_visible )
                        + 1;
                    $cursor_col = 4 + ( $cur_col - $seg_start );
                }
                $cursor_col = $cols - 2 if $cursor_col > $cols - 2;
                ## position and show cursor at the real edit point ##
                print "\e[$cursor_row;${cursor_col}H\e[?25h";
            }    ## redraw gate ##

            ## wait for input or a signal, then read one event ; a pending
            ## wheel burst turns the wait into a deadline so the payout lands
            ## without a keypress once the window asserts
            my $key;
            while ( !defined $key and !$aborted and !$resized ) {
                my $rin = '';
                vec( $rin, fileno(STDIN),  1 ) = 1;
                vec( $rin, fileno($sig_r), 1 ) = 1;

                my $wait;
                if ($flush_at) {
                    $wait = $flush_at - time();
                    $wait = 0.001 if $wait < 0.001;
                }

                my $n = select( my $rout = $rin, undef, undef, $wait );
                next if !defined $n or $n < 0;
                if ( $n == 0 ) {    ## burst window asserted ##
                    $flush_wheel->();
                    last;
                }

                if ( vec( $rout, fileno($sig_r), 1 ) ) {
                    my $sigbuf;
                    1 while sysread( $sig_r, $sigbuf, 256 );    ## drain ##
                }
                if ( vec( $rout, fileno(STDIN), 1 ) ) {
                    $key = read_editor_event( $reader, \$aborted );

                    ## readable but nothing to read : the tty is gone. ##
                    ## abort like a hangup instead of spinning on eof  ##
                    $aborted = 1
                        if !defined $key
                        and $reader->{'eof'}
                        and $reader->{'eof'}->();
                }
            }

            if ( not defined $key ) {
                last if $aborted;
                next;    ## resized : redraw with new dimensions ##
            }
            ## inert events [ mouse releases ] are no key press : they must ##
            ## not start the hybrid status or tick the f1 hint counter      ##
            next if not ref $key and not length $key;
            ## some mice bounce : a second press on the same cell within   ##
            ## CLICK_BOUNCE is the same click [ a toggle would run twice ] ##
            if ( ref $key eq 'HASH' and defined $key->{'click'} ) {
                my $click_sig = join ':', $key->{'click'}->@*;
                my $click_now = time;
                next
                    if $click_sig eq $last_click_sig
                    and $click_now - $last_click_at < CLICK_BOUNCE;
                ( $last_click_sig, $last_click_at )
                    = ( $click_sig, $click_now );
            }

            ## an action click becomes its key before dispatch : editing, save
            ## handling and the later usage counters share this one code path
            if ( ref $key eq 'HASH' and defined $key->{'click'} ) {
                my ( $click_x, $click_y ) = $key->{'click'}->@*;
                if ( $click_y == $rows - 1 ) {
                    for my $hit (@keys_bar_hits) {
                        next
                            if $click_x < $hit->{'start'}
                            or $click_x > $hit->{'end'};
                        $key = $hit->{'key'};
                        last;
                    }
                }
                ## the footer title [ '::. keys .::' ] is the mouse f1 ##
                if ( ref $key eq 'HASH' and $click_y == $rows - 2 ) {
                    $key = "\eOP" if $click_x <= $bar_title_width + 6;
                }
                ## a click on the status line or its border                ##
                ## [ ' status ' \ ' F1=Keys ' ] brings the key labels back ##
                $key = qw| show-keys |
                    if ref $key eq 'HASH'
                    and $click_y >= $rows - 2
                    and $keys_bar_mode ne qw| keys |;
            }
            if ( $key eq qw| show-keys | ) {
                if ( $keys_bar_mode eq qw| hidden | ) {
                    $keys_bar_mode = qw| hybrid |;
                    $save_keys_bar_mode->();
                }
                $keys_bar_started = 0;
                $keys_bar_offset  = 0;
                $keys_bar_events++;
                next;
            }

            $last_status = '';
            $keys_bar_events++;
            $keys_bar_started = 1
                if $keys_bar_mode eq qw| hybrid |
                and $key ne "\eOP"
                and $key ne "\e[11~";

            ## control keys ##
            if ( $key eq "\eOP" or $key eq "\e[11~" ) {    ## f1 ##
                $keys_bar_mode
                    = $keys_bar_mode eq qw| keys |   ? 'hybrid'
                    : $keys_bar_mode eq qw| hybrid | ? 'hidden'
                    :                                  'keys';
                $keys_bar_started = 0;
                $keys_bar_offset  = 0;
                $save_keys_bar_mode->();
            } elsif ( $key eq "\x03" ) {    ## Ctrl-C : abort ##
                ## the later unsaved-changes confirm window plugs in here ##
                $aborted = 1;
                last;
            } elsif ( $key eq "\x13" or $key eq "\x0f" ) {
                ## Ctrl-S / Ctrl-O : save -- hand on_save a snapshot     ##
                ## normalized exactly like the ctrl-x return value below ##
                my $snapshot = join "\n", editor_normalize_details(@lines);
                if ( defined $on_save ) {
                    my $saved = eval { $on_save->($snapshot) };
                    my $err   = $@;
                    _wipe( \$snapshot );
                    if ( $err or not $saved ) {
                        $last_status
                            = 'save failed : '
                            . _save_error_reason( $err
                                || 'save callback returned false' );
                    } else {
                        $dirty       = 0;
                        $last_status = 'saved';
                        $saved_sum   = $content_sum->();
                    }
                } else {
                    _wipe( \$snapshot );
                    $last_status = 'no save target -- ctrl-x saves + quits';
                }
            } elsif ( $key eq "\x18" ) {    ## Ctrl-X : save+quit ##
                $dirty       = 0;
                $last_status = 'saved';
                last;
            }

            ## navigation [ free cursor : lines grow with spaces ] ##
            elsif ( $key eq "\e[A" ) {      ## up ##
                $move_cursor->(-1);
            } elsif ( $key eq "\e[B" ) {    ## down ##
                $move_cursor->(1);
            } elsif ( ref $key eq 'HASH'
                and defined $key->{'wheel'} ) {    ## mouse wheel ##
                ## one line per tick, on the spot -- the burst pays out pages
                ## when it asserts [ the wheel paused for a window ] ; a
                ## direction change cashes the old burst in first
                my $dir = $key->{'wheel'} eq qw| up | ? -1 : 1;
                my ( $wheel_x, $wheel_y ) = ( $key->{'at'} // [] )->@*;
                if ( defined $wheel_y and $wheel_y == $rows - 1 ) {
                    $page_keys_bar->($dir);
                } else {
                    ## one line per tick, on the spot -- the burst pays out
                    ## pages when it asserts [ the wheel paused for a window ]
                    ## ; a direction change cashes the old burst in first
                    my $now = time();
                    $flush_wheel->()
                        if $wheel_burst and $dir != $wheel_dir;
                    if ( not $wheel_burst
                        or $now - $wheel_at > WHEEL_WINDOW ) {
                        ( $wheel_burst, $wheel_accum, $wheel_dir )
                            = ( 0, 0, $dir );
                    }
                    $wheel_accum += $now - $wheel_at if $wheel_burst;
                    $wheel_burst++;
                    $wheel_at = $now;
                    $flush_at = $now + WHEEL_WINDOW;
                    $move_cursor->($dir);
                }
            } elsif ( ref $key eq 'HASH'
                and defined $key->{'click'} ) {    ## left press ##
                ## position the cursor : content row 1 is terminal row
                ## header+1, text starts at col 4 [ ':  ' ] ; chrome clicks
                ## stay inert, past-EOL clamps to the line end. in wrap mode
                ## the clicked content row is a visual row : find the logical
                ## line and the segment it carries
                my ( $cx, $cy ) = $key->{'click'}->@*;
                if ( $cy == $rows - 1 ) {
                    $page_keys_bar->(-1)
                        if $cx <= 2 and $keys_bar_offset;
                    $page_keys_bar->(1) if $cx >= $cols - 2;
                } elsif ( $cy >= 5 ) {
                    my $vrow      = $first_visible + $cy - 5;
                    my $prev_line = $cur_line;
                    if ( $vrow <= $first_visible + $content_rows - 1 ) {
                        my $col = $cx - 4;
                        $col = 0 if $col < 0;
                        if ( not $wrap ) {
                            my $line = $vrow;
                            $cur_line = $line > $#lines ? $#lines : $line;
                        } else {
                            my ( $row, $li ) = ( 0, 0 );
                            while ( $li < $#lines
                                and $row + $block_rows->($li) <= $vrow ) {
                                $row += $block_rows->($li);
                                $li++;
                            }
                            $cur_line = $li;
                            ## the clicked segment's start column + the x
                            ## offset [ ragged : cumulative walk ]
                            $col
                                = $seg_start_at->( $li, $vrow - $row ) + $col;
                        }
                        ## leaving the previous line strips its pad
                        $dirty++
                            if $prev_line != $cur_line
                            and editor_leave_line( \@lines, $prev_line );
                        my $len = length $lines[$cur_line];
                        $cur_col = $col > $len ? $len : $col;
                    }
                }
            } elsif ( $key eq "\e[5~" or $key eq "\e[6~" ) {
                ## page up \ down : one visible page per press, wheel
                ## semantics -- the down page stops at the last line instead
                ## of growing one at EOF. in wrap mode a page is a screenful
                ## of visual rows : land on the line holding the target row
                my $dir = $key eq "\e[5~" ? -1 : 1;
                if ( not $wrap ) {
                    $move_cursor->($dir) for 1 .. $content_rows;
                } else {
                    my $vrow = 0;
                    $vrow += $block_rows->($_) for 0 .. $cur_line - 1;
                    ## which segment holds the cursor [ cumulative walk ; a
                    ## blank line is one empty segment -> offset 0 ]
                    my ($seg_off) = $seg_at_col->( $cur_line, $cur_col );
                    $vrow += $seg_off;
                    my $target = $vrow + $dir * $content_rows;
                    $target = 0 if $target < 0;
                    my ( $row, $li ) = ( 0, 0 );
                    while ( $li < $#lines
                        and $row + $block_rows->($li) <= $target ) {
                        $row += $block_rows->($li);
                        $li++;
                    }
                    ## leaving the current line strips its free-cursor pad
                    $dirty    = 1 if editor_leave_line( \@lines, $cur_line );
                    $cur_line = $li;
                    ## the landing segment's start column
                    ## [ ragged : cumulative walk, not segment x vw ]
                    my $col = $seg_start_at->( $li, $target - $row );
                    my $len = length $lines[$cur_line];
                    $cur_col = $col > $len ? $len : $col;
                }
            } elsif ( $key eq "\e[C" ) {    ## right ##
                $cur_col++;
                if ( $cur_col > length( $lines[$cur_line] ) ) {
                    $lines[$cur_line]
                        .= ' ' x ( $cur_col - length( $lines[$cur_line] ) );
                    $dirty++;
                }
            } elsif ( $key eq "\e[D" ) {    ## left ##
                if ( $cur_col > 0 ) {
                    $cur_col--;
                } elsif ( $cur_line > 0 ) {
                    $dirty++ if editor_leave_line( \@lines, $cur_line );
                    $cur_line--;
                    $cur_col = length( $lines[$cur_line] );
                }
            } elsif ( $key eq "\e[H" or $key eq "\x01" ) {    ## home ##
                $cur_col = 0;
            } elsif ( $key eq "\e[F" or $key eq "\x05" ) {    ## end ##
                $cur_col = length( $lines[$cur_line] );
            }

            ## editing ##
            elsif ( $key eq "\n" ) {                          ## enter ##
                my $rest = substr( $lines[$cur_line], $cur_col );
                $lines[$cur_line] = substr( $lines[$cur_line], 0, $cur_col );
                $dirty++ if editor_leave_line( \@lines, $cur_line );
                splice @lines, $cur_line + 1, 0, $rest;
                $cur_line++;
                $cur_col = 0;
                $dirty   = 1;
            } elsif ( $key eq "\x08" or $key eq "\x7f" ) {    ## backspace ##
                if ( $cur_col > 0 ) {
                    substr( $lines[$cur_line], $cur_col - 1, 1, '' );
                    $cur_col--;
                    $dirty++;
                } elsif ( $cur_line > 0 ) {
                    $dirty   = 1 if editor_leave_line( \@lines, $cur_line );
                    $cur_col = length( $lines[ $cur_line - 1 ] );
                    $lines[ $cur_line - 1 ] .= $lines[$cur_line];
                    splice @lines, $cur_line, 1;
                    $cur_line--;
                    $dirty++;
                }
            } elsif ( $key eq "\e[3~" ) {    ## delete ##
                if ( $cur_col < length( $lines[$cur_line] ) ) {
                    substr( $lines[$cur_line], $cur_col, 1, '' );
                    $dirty++;
                } elsif ( $cur_line < $#lines ) {
                    $lines[$cur_line] .= $lines[ $cur_line + 1 ];
                    splice @lines, $cur_line + 1, 1;
                    $dirty++;
                }
            } elsif ( $key eq "\x0c"
                or $key eq "\x1c"
                or $key eq "\e[44;5u" ) {
                ## Ctrl-L [ and ctrl-, on terminals that give it a distinct
                ## byte : \x1c legacy on kitty \ foot,
                ## \e[44;5u with the CSI-u protocol ] : delete line onto the
                ## kill stack -- an empty line has nothing to restore, so it
                ## never buries a real kill
                my $killed = $lines[$cur_line];
                $killed =~ s| +$||;
                if ( length $killed ) {
                    _mlock( \$killed );
                    push @kill_stack, $killed;
                }
                ## the ordered register for ctrl+. keeps EVERY line [ blanks
                ## are file content : dropping them collapses the gap and the
                ## next restore lands one line early, which reads as a reorder
                ## ] ; an entry PREPENDS when its kill landed above the
                ## previous one [ bottom-up truncation ], so the run always
                ## holds the ORIGINAL file order ; a fresh copy -- the
                ## registers and the buffer never share a scalar
                my $ordered = q{} . $killed;
                _mlock( \$ordered );
                if ( @fifo_run and $cur_line < $fifo_last_idx ) {
                    unshift @fifo_run, $ordered;
                } else {
                    push @fifo_run, $ordered;
                }
                $fifo_from = $cur_line
                    if not defined $fifo_from
                    or $cur_line < $fifo_from;
                $fifo_last_idx = $cur_line;
                splice @lines, $cur_line, 1;
                @lines    = ('')    if !@lines;
                $cur_line = $#lines if $cur_line > $#lines;
                $cur_col  = 0;
                $dirty    = 1;
            } elsif ( $key eq "\x17" ) {    ## Ctrl-W : del word back ##
                if ( $cur_col > 0 ) {
                    my $start = $cur_col;
                    ## skip trailing whitespace ##
                    while ( $start > 0
                        and substr( $lines[$cur_line], $start - 1, 1 )
                        =~ m{\s} ) {
                        $start--;
                    }
                    ## skip word characters ##
                    while ( $start > 0
                        and substr( $lines[$cur_line], $start - 1, 1 )
                        !~ m{\s} ) {
                        $start--;
                    }
                    if ( $start < $cur_col ) {
                        substr(
                            $lines[$cur_line], $start,
                            $cur_col - $start, ''
                        );
                        $cur_col = $start;
                        $dirty   = 1;
                    }
                }
            } elsif ( $key eq "\x04" ) {    ## Ctrl-D : de-interlace ##
                my ( $new_ref, $changed )
                    = editor_deinterlace( \@lines, $cur_line );
                if ($changed) {
                    @lines    = @{$new_ref};
                    $cur_line = $#lines if $cur_line > $#lines;
                    $dirty    = 1;
                }
            }

            ## Ctrl-V : paste lines above ##
            elsif ( $key eq "\x16" ) {
                ## the kill stack first                                    ##
                ## [ LIFO : the last ctrl-l comes back first ], the system ##
                ## clipboard when the stack is empty                       ##
                if (@kill_stack) {
                    splice @lines, $cur_line, 0, pop @kill_stack;
                    $cur_line++;    ## stay on the text the cursor held ##
                    $dirty++;
                } else {
                    my $clip = _clipboard_read();
                    ## a cleared clipboard stays cleared until its content ##
                    ## changes : the desktop selection itself is never     ##
                    ## touched                                             ##
                    if (    defined $clip
                        and length $clip
                        and ( not defined $clip_cleared
                            or $clip ne $clip_cleared )
                    ) {
                        _mlock( \$clip );
                        my @clip_lines = split m{\n},
                            editor_normalize_paste($clip), -1;
                        pop @clip_lines
                            if @clip_lines > 1 and $clip_lines[-1] eq '';
                        splice @lines, $cur_line, 0, @clip_lines;
                        $cur_line += scalar @clip_lines;
                        $dirty       = 1;
                        $last_status = 'pasted from clipboard';
                        ## the pasted content is known again : the hint ##
                        ## comes back and repeated ctrl-v stays live    ##
                        $clip_at_start = $clip;
                        $clip_cleared  = undef;
                    } else {
                        $last_status = 'nothing to paste';
                    }
                    _wipe( \$clip );
                }
            }

            ## Ctrl+. [ \x0e, or CSI-u \e[46;5u from protocol terminals ] :
            ## restore IN ORDER and IN PLACE -- the ordered register rebuilds
            ## at the kill position in the ORIGINAL file order, so a truncated
            ## tail appends after the line it followed [ never prefixes it,
            ## never upside down however the kills were made ] ; the cursor
            ## follows the restored line. no clipboard fallback
            ## [ that is ctrl-v ]
            elsif ( $key eq "\x0e" or $key eq "\e[46;5u" ) {
                if (@fifo_run) {
                    my $at = defined $fifo_from ? $fifo_from : $cur_line;
                    splice @lines, $at, 0, shift @fifo_run;
                    $cur_line  = $at;
                    $fifo_from = $at + 1;
                    if ( !@fifo_run ) {
                        $fifo_from     = undef;
                        $fifo_last_idx = undef;
                    }
                    $dirty++;
                } else {
                    $last_status = 'nothing to restore';
                }
            }

            ## Ctrl-Y : clear the paste registers ##
            elsif ( $key eq "\x19" ) {
                ## the later clear-registers confirm window plugs in here ##
                _wipe( map { \$ARG } @kill_stack, @fifo_run );
                @kill_stack    = ();
                @fifo_run      = ();
                $fifo_from     = undef;
                $fifo_last_idx = undef;
                $clip_cleared  = _clipboard_read() // '';
                ## no text change : not dirty ##
                $last_status = 'paste buffer cleared';
            }

            ## paste [ one event, one redraw ] ##
            elsif ( ref $key eq 'HASH' and defined $key->{'paste'} ) {
                my $text  = editor_normalize_paste( $key->{'paste'} );
                my @block = split m{\n}, $text, -1;
                _wipe( \$text );    ## the normalized copy is done : the ##
                ## block lines carry the content now ##

                ## splice the block into the current line at the cursor ##
                my $rest = substr( $lines[$cur_line], $cur_col );
                my $head = substr( $lines[$cur_line], 0, $cur_col );
                my @new  = ( $head . shift(@block) );
                push @new, @block;
                $new[-1] .= $rest;
                splice( @lines, $cur_line, 1, @new );

                ## land the cursor right after the pasted content ##
                $cur_line += $#new;
                $cur_col = length( $new[-1] ) - length($rest);
                $dirty   = 1;
            }

            ## printable [ single byte, not control, not ESC ] ##
            elsif ( length($key) == 1
                and ord($key) >= 32
                and $key ne "\e" ) {
                substr( $lines[$cur_line], $cur_col, 0, $key );
                $cur_col++;
                $dirty++;
            }
        }

        if ($aborted) {
            $did_abort = 1;
            return undef;
        }

        ## strip trailing spaces per line and trailing empty lines ##
        return join( "\n", editor_normalize_details(@lines) );
    };

    my $eval_error = $@;

    ## secrets hygiene : the registers and the buffer copies never survive ##
    ## the editor -- the returned text is a join-made copy, it lives on as ##
    ## the caller's own [ pinned, so it stays swap-free as well ]          ##
    _wipe( map { \$ARG } @kill_stack, @fifo_run );
    _wipe( \$clip_at_start,           \$clip_cleared );
    _wipe( map { \$ARG } @lines );
    @kill_stack = ();
    @fifo_run   = ();

    Term::ReadKey::ReadMode(0);
    paste_disable();
    mouse_disable() if $mouse_on;
    modify_other_keys_disable();
    print "\e[0 q";    ## cursor shape back on every exit path ##
    STDOUT->autoflush($old_autoflush);

    if ($eval_error) {    ## restore tty, then rethrow ##
        die $eval_error;
    }

    if ($did_abort) {
        my ( undef, $rows ) = Term::ReadKey::GetTerminalSize();
        $rows //= 24;
        print "\e[?25l\e[H\e[2J\e[H\e[?25h";
        STDOUT->flush();
        print "\e[0 m";
        return undef;    ## abort: caller knows nothing was saved ##
    }

    my ( undef, $rows ) = Term::ReadKey::GetTerminalSize();
    $rows //= 24;

    ## the frame fills the terminal : park the cursor on the last row,     ##
    ## shape reset -- no trailing newline, printing \n on the bottom row   ##
    ## would scroll the whole frame up one line. callers are expected to   ##
    ## clear \ scroll the screen right after [ both todo and p7-vault do ] ##
    print "\e[$rows;1H\e[?25h\e[0 q\e[0 m";

    _mlock( \$edit_result ) if defined $edit_result;
    return $edit_result;
}

1;

#,,,,,,.,,,,.,..,,,,.,,,,,,..,...,.,.,,,.,..,,..,,...,.,.,,.,,..,,,.,,.,.,,,.,
#CZV3STQMQNRWK6VV7XSZHM4IS2F6KQBOLJ3FDI5VQ2WGQNWRCIVI4CXMZYY2X3GNKFP6PUM6HZKD6
#\\\|MNCJCDF25LI6ERAMQVHNJYAEM7NVSQMZCE64NGS4HGHOK6YIQE7 \ / AMOS7 \ YOURUM ::
#\[7]5B4SAQWZ6BK3WNC4REP44IWQR36EIFPTZZWGFIZB2RJS26B7IUBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
