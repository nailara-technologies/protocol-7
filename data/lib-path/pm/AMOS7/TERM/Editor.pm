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
## bracketed paste [ mode 2004 ] is enabled while the editor is open and
## disabled on every exit path, including abort, die and signals. a paste
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
## on_save => sub ( $text ) { ... } } )  returns the edited text, or undef
## when aborted.  editor_normalize_paste( $text )   -> $text with \r\n / \r ->
## \n editor_deinterlace( \@lines, $cursor_line ) -> [ \@lines, $changed ]
## read_editor_event( $reader, \$aborted ) -> $key | { paste => $text }
## editor_make_reader() -> reader hashref bound to STDIN
##
## an optional on_save callback makes ctrl-s [ alias ctrl-o ] a real save : it
## receives the current buffer, normalized exactly like the returned text. a
## true return means saved [ the dirty flag clears ] ; a false return or a die
## shows 'save failed : <reason>' and the buffer stays dirty. without on_save
## the keys only explain that ctrl-x saves + quits -- nothing is ever claimed
## saved.
##
## ctrl-l removes a line onto a kill stack [ per editor session ] and
## ctrl-v brings it back [ LIFO ] -- a simple line undo \ reorder.
## ctrl-. [ \x0e, or CSI-u \e[46;5u ] restores IN ORDER from the same
## stack [ oldest first ], so kills rebuild their original order ;
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
## WHEEL_MAX_PAGES pages. a left mouse press positions the cursor [ content
## geometry mapped from the click, clicks on the frame stay inert, past-EOL
## clamps to the line end ].
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
use constant WHEEL_MAX_PAGES => 2;

use Exporter;
use base qw| Exporter |;
use vars qw| @EXPORT_OK $VERSION |;

our $VERSION = qw| AMOS7::TERM::Editor-VERSION.5AANLBY |;

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

        last if $b =~ m{[A-Za-z~]};
    }

    ## mouse reports [ wheel tracking ] : SGR \e[<btn;x;yM or legacy X10 \e[M
    ## + 3 bytes -- both end the collection above. plain clicks are eaten here
    ## [ never text ] : the wheel becomes a cursor move, a left press becomes
    ## a cursor position [ SGR release 'm' and other buttons stay inert ]
    if ( $seq =~ m{\x1b\[<(\d+);(\d+);(\d+)([Mm])} ) {
        my ( $btn, $cx, $cy, $kind ) = ( $1, $2, $3, $4 );
        return { wheel => qw| up | }   if $btn == 64;
        return { wheel => qw| down | } if $btn == 65;
        return { click => [ $cx, $cy ] }
            if $btn == 0 and $kind eq qw| M |;
        return '';
    }
    if ( $seq eq "\x1b[M" ) {    ## X10 : the 3 coordinate bytes follow ##
        my @coord = map { $reader->{'read'}->(0.1) } 1 .. 3;
        my $btn   = $coord[0];
        return { wheel => qw| up | }
            if defined $btn and $btn eq chr( 32 + 64 );
        return { wheel => qw| down | }
            if defined $btn and $btn eq chr( 32 + 65 );
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

    my ( $cur_line, $cur_col ) = ( 0, 0 );
    my $first_visible = 0;
    my $content_rows  = 1;     ## set by every redraw ; page keys read it ##
    my $drawn_sig     = '';    ## empty forces the first paint           ##
    my $dirty         = 0;
    my $aborted       = 0;
    my $resized       = 0;

    ## the kill stack : ctrl-l pushes the removed line, ctrl-v pops it back ##
    ## in above the cursor [ LIFO ]. per edit_text call on purpose : note   ##
    ## lines are secrets, they must not linger in module state after the    ##
    ## editor closes                                                        ##
    my @kill_stack;

    ## ctrl-v advertises itself only with something to paste : the kill   ##
    ## stack fills as ctrl-l removes lines ; the clipboard counts when it ##
    ## holds text at start [ probing it on every redraw would shell out ] ##
    my $clip_at_start;

    ## ctrl-y clears the registers : the clipboard content at that moment   ##
    ## stays unpasteable until it changes [ the desktop selection itself is ##
    ## never wiped -- other applications may hold it ]                      ##
    my $clip_cleared;

    ## mouse wheel tracking : on unless asked off                       ##
    ## [ 'mouse => 0' or the P7_EDITOR_NO_MOUSE escape hatch ]. no      ##
    ## dependency -- terminals without mouse support ignore the DECSETs ##
    ## wholesale                                                        ##
    my $mouse_on
        = ( $params->{'mouse'} // 1 ) && not $ENV{'P7_EDITOR_NO_MOUSE'};

    ## wheel acceleration state [ per edit_text call, like the kill stack ] :
    ## burst counting with a flush deadline the input wait honors, so a paused
    ## wheel pays out its pages without a keypress
    my ( $wheel_burst, $wheel_dir, $wheel_at, $wheel_accum, $flush_at )
        = ( 0, 0, 0, 0, 0 );

    ## cursor moves shared by the arrow keys and the wheel : the second arg ##
    ## lets arrows grow a line at EOF while the wheel just stops            ##
    my $move_cursor = sub {
        my ( $dir, $extend ) = @ARG;
        if ( $dir < 0 and $cur_line > 0 ) {
            $dirty = 1 if editor_leave_line( \@lines, $cur_line );
            $cur_line--;
            $dirty = 1
                if editor_pad_line_to_col( \@lines, $cur_line, $cur_col );
        } elsif ( $dir > 0 ) {
            if ( $cur_line < $#lines ) {
                $dirty = 1 if editor_leave_line( \@lines, $cur_line );
                $cur_line++;
                $dirty = 1
                    if editor_pad_line_to_col( \@lines, $cur_line, $cur_col );
            } elsif ($extend) {
                $dirty = 1 if editor_leave_line( \@lines, $cur_line );
                push @lines, ' ' x $cur_col;
                $cur_line++;
                $dirty = 1;
            }
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
        $move_cursor->( $wheel_dir, 0 ) for 1 .. $pages * $content_rows;
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
                $dirty = 1;
            }

            ## vertical scroll ##
            if ( $cur_line < $first_visible ) {
                $first_visible = $cur_line;
            } elsif ( $cur_line >= $first_visible + $content_rows ) {
                $first_visible = $cur_line - $content_rows + 1;
            }

            ## redraw gate : repaint only when something visual changed.  a
            ## no-op key [ a wheel tick at EOF, an inert click, a burst that
            ## paid nothing ] otherwise clears and repaints an identical frame
            ## -- pure flicker
            my $frame_sig = join ':', $dirty, $cur_line, $cur_col,
                $first_visible, $cols, $rows, $last_status,
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
                for my $i ( 0 .. $content_rows - 1 ) {
                    my $line_idx = $first_visible + $i;
                    my $line_text
                        = ( $line_idx <= $#lines ) ? $lines[$line_idx] : '';
                    my $is_cursor = ( $line_idx == $cur_line );
                    say detail_editor_draw_line( $line_text, $inner_width,
                        $is_cursor, $cur_col, $C );
                }

                ## bottom padding ##
                say detail_editor_draw_line( '', $inner_width, 0, 0, $C );

                ## footer separator ##
                say frame_border_line(
                    {   width    => $cols,
                        reset    => $C->{R},
                        elements => [
                            {   type  => 'anchor',
                                value => '::.',
                                color => $C->{0}
                            },
                            {   type  => 'anchor',
                                value => ' keys ',
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

                ## help line [ left pad, :: delimiter ]  ctrl-s           ##
                ## [ alias ctrl-o ] is only advertised when on_save gives ##
                ## it a real target                                       ##
                my $save_hint = defined $on_save ? ' · ctrl-s save' : '';
                my $paste_hint
                    = (
                    @kill_stack
                        or ( defined $clip_at_start
                        and not defined $clip_cleared )
                    )
                    ? ' · ctrl-v paste · ctrl+. in-order · ctrl-y clear'
                    : '';
                my $help_text
                    = ' · ctrl-x save+quit · ctrl-c abort'
                    . $save_hint
                    . $paste_hint
                    . ' · ctrl-w del-word · ctrl-l del-line · ctrl-d '
                    . 'de-interlace · arrows · enter · del · pgup \ '
                    . 'pgdn page ·';
                $help_text = ' · ' . $hint . ' ·' . $help_text
                    if length $hint;
                ## show status [ e.g. 'saved' ] on the LEFT so it survives ##
                ## narrow terminals; truncation keeps the leftmost part    ##
                $help_text = "· $last_status · $help_text"
                    if length $last_status;
                $help_text = substr( $help_text, 0, $inner_width - 2 );
                my $help_pad
                    = ' ' x ( $inner_width - length($help_text) - 1 );
                my $help = $help_pad . $help_text . '';
                say $C->{0} . ':'
                    . $C->{dim}
                    . $C->{3}
                    . $help
                    . $C->{0} . '::'
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
                my $cursor_row
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
                my $cursor_col = 4 + $dcol;    ## ':  ' puts text at col 4 ##
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

            $last_status = '';

            ## control keys ##
            if ( $key eq "\x03" ) {    ## Ctrl-C : abort ##
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
                $move_cursor->( -1, 1 );
            } elsif ( $key eq "\e[B" ) {    ## down ##
                $move_cursor->( 1, 1 );
            } elsif ( ref $key eq 'HASH'
                and defined $key->{'wheel'} ) {    ## mouse wheel ##
                ## one line per tick, on the spot -- the burst pays out pages
                ## when it asserts [ the wheel paused for a window ] ; a
                ## direction change cashes the old burst in first
                my $dir = $key->{'wheel'} eq qw| up | ? -1 : 1;
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
                $move_cursor->( $dir, 0 );
            } elsif ( ref $key eq 'HASH'
                and defined $key->{'click'} ) {         ## left press ##
                ## position the cursor : content row 1 is terminal row
                ## header+1, text starts at col 4 [ ':  ' ] ; chrome clicks
                ## stay inert, past-EOL clamps to the line end
                my ( $cx, $cy ) = $key->{'click'}->@*;
                my $line = $first_visible + $cy - 5;    ## header_rows = 4 ##
                if (    $cy >= 5
                    and $line <= $first_visible + $content_rows - 1 ) {
                    $cur_line = $line > $#lines ? $#lines : $line;
                    my $col = $cx - 4;
                    $col = 0 if $col < 0;
                    my $len = length $lines[$cur_line];
                    $cur_col = $col > $len ? $len : $col;
                }
            } elsif ( $key eq "\e[5~" or $key eq "\e[6~" ) {
                ## page up \ down : one visible page per press, wheel
                ## semantics -- the down page stops at the last line instead
                ## of growing one at EOF
                my $dir = $key eq "\e[5~" ? -1 : 1;
                $move_cursor->( $dir, 0 ) for 1 .. $content_rows;
            } elsif ( $key eq "\e[C" ) {    ## right ##
                $cur_col++;
                if ( $cur_col > length( $lines[$cur_line] ) ) {
                    $lines[$cur_line]
                        .= ' ' x ( $cur_col - length( $lines[$cur_line] ) );
                    $dirty = 1;
                }
            } elsif ( $key eq "\e[D" ) {    ## left ##
                if ( $cur_col > 0 ) {
                    $cur_col--;
                } elsif ( $cur_line > 0 ) {
                    $dirty = 1 if editor_leave_line( \@lines, $cur_line );
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
                $dirty = 1 if editor_leave_line( \@lines, $cur_line );
                splice @lines, $cur_line + 1, 0, $rest;
                $cur_line++;
                $cur_col = 0;
                $dirty   = 1;
            } elsif ( $key eq "\x08" or $key eq "\x7f" ) {    ## backspace ##
                if ( $cur_col > 0 ) {
                    substr( $lines[$cur_line], $cur_col - 1, 1, '' );
                    $cur_col--;
                    $dirty = 1;
                } elsif ( $cur_line > 0 ) {
                    $dirty   = 1 if editor_leave_line( \@lines, $cur_line );
                    $cur_col = length( $lines[ $cur_line - 1 ] );
                    $lines[ $cur_line - 1 ] .= $lines[$cur_line];
                    splice @lines, $cur_line, 1;
                    $cur_line--;
                    $dirty = 1;
                }
            } elsif ( $key eq "\e[3~" ) {    ## delete ##
                if ( $cur_col < length( $lines[$cur_line] ) ) {
                    substr( $lines[$cur_line], $cur_col, 1, '' );
                    $dirty = 1;
                } elsif ( $cur_line < $#lines ) {
                    $lines[$cur_line] .= $lines[ $cur_line + 1 ];
                    splice @lines, $cur_line + 1, 1;
                    $dirty = 1;
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
                    $dirty = 1;
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
            ## restore IN ORDER -- the same kill register read from the
            ## bottom, so kills come back oldest-first ; each restore inserts
            ## above the cursor and the cursor follows the restored line down,
            ## repeated presses rebuild the original order. no clipboard
            ## fallback [ that is ctrl-v ]
            elsif ( $key eq "\x0e" or $key eq "\e[46;5u" ) {
                if (@kill_stack) {
                    splice @lines, $cur_line, 0, shift @kill_stack;
                    $cur_line++;
                    $dirty = 1;
                } else {
                    $last_status = 'nothing to restore';
                }
            }

            ## Ctrl-Y : clear the paste registers ##
            elsif ( $key eq "\x19" ) {
                _wipe( map { \$ARG } @kill_stack );
                @kill_stack   = ();
                $clip_cleared = _clipboard_read() // '';
                $last_status  = 'paste buffer cleared';
                $dirty        = 1;
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
                $dirty = 1;
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
    _wipe( map { \$ARG } @kill_stack );
    _wipe( \$clip_at_start, \$clip_cleared );
    _wipe( map { \$ARG } @lines );
    @kill_stack = ();

    Term::ReadKey::ReadMode(0);
    paste_disable();
    mouse_disable() if $mouse_on;
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

#,,,,,,,.,,.,,...,,..,,,,,,..,.,.,,..,,.,,,,,,..,,...,...,..,,.,.,,.,,.,,,.,.,
#3SORHCN5AZRZP62DPCYSXYKSP4FCO3752NBERF2HRJFTPQ6ZU2MZP2LHSWCYLV6HYY6XZ7A762AKY
#\\\|ERHFQSRSX7INUGKO63NVYFOXGCQD3WWL5QABZPVBVSCCG725JEJ \ / AMOS7 \ YOURUM ::
#\[7]WSI2E7OBENFURZICOKKFMYCG2RUAURVYOV62DDQ2S4AXCL5RIEDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
