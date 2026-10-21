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
## label => 'details', hint => $extra_keys, width => $cols,  colors => \%C } )
## returns the edited text, or undef when aborted.  editor_normalize_paste(
## $text )   -> $text with \r\n / \r -> \n editor_deinterlace( \@lines,
## $cursor_line ) -> [ \@lines, $changed ] read_editor_event( $reader,
## \$aborted ) -> $key | { paste => $text } editor_make_reader() -> reader
## hashref bound to STDIN
##
## a reader is a hashref with two closures :
##   read   => sub ( $timeout ) -> single byte or undef
##   ungetc => sub ( $bytes )   -> push bytes back [ read again in order ]
## and optionally :
##   eof    => sub ()           -> true once the input is gone [ tty closed ]

use v5.32.0;
use utf8;
use strict;
use English;
use warnings;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

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
use POSIX       qw| TCSANOW ICRNL |;
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

sub editor_make_reader {
    ## reader closure pair bound to STDIN [ the live editor input ]
    $stdin_eof = FALSE;
    return {
        read   => \&_stdin_read_byte,
        ungetc => \&_stdin_ungetc,
        eof    => sub {$stdin_eof},
    };
}

sub _read_paste_block {
    ## read until the paste terminator "\e[201~" shows up at the tail
    my ( $reader, $aborted_ref ) = @_;
    ## idle timeout, not a total one : a large or slow paste keeps going as ##
    ## long as bytes keep arriving                                          ##
    my $paste = '';
    while ( !$$aborted_ref ) {
        my $b = $reader->{'read'}->(2);
        last if !defined $b;
        $paste .= $b;
        last if $paste =~ m{\x1b\[201~$};
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
    return $seq;
}

##[ LINE DRAWING ]############################################################

sub detail_editor_draw_line {
    my ( $text, $width, $is_cursor, $cur_col, $C ) = @_;
    $text //= '';

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

##[ BRACKETED PASTE MODE ]####################################################

sub paste_enable {
    print "\e[?2004h";
    return;
}

sub paste_disable {
    print "\e[?2004l";
    return;
}

##[ INTERACTIVE EDITOR ]######################################################

sub edit_text {
    my $params = shift // {};

    require_readkey();

    my $C       = _colors( $params->{'colors'} );
    my $title   = $params->{'title'}   // '';
    my $summary = $params->{'summary'} // '';
    my $label   = $params->{'label'}   // 'details';
    my $hint    = $params->{'hint'}    // '';
    my $width   = $params->{'width'};

    my @lines = split m|\n|, $params->{'text'} // '', -1;
    @lines = ('') if !@lines;

    my ( $cur_line, $cur_col ) = ( 0, 0 );
    my $first_visible = 0;
    my $dirty         = 0;
    my $aborted       = 0;
    my $resized       = 0;

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
        paste_enable();
        print "\e[4 q";
        $resized = 1;         ## full redraw ##
        syswrite( $sig_w, 'c', 1 );
    };

    ## raw mode : ctrl-c is read as the byte \x03, not delivered as SIGINT ##
    Term::ReadKey::ReadMode(4);
    _disable_icrnl();         ## keep pasted "\r\n" from becoming "\n\n" ##

    ## bracketed paste : the terminal wraps pasted text in  "\e[200~" ... ##
    ## "\e[201~" so a multi-line paste arrives as one block               ##
    paste_enable();

    ## use a steady underscore cursor while editing ##
    print "\e[4 q";

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
            my $footer_rows  = 4;
            my $content_rows = $rows - $header_rows - $footer_rows;
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

            ## draw frame : hide cursor during redraw to stop it flickering ##
            ## at 1,1                                                       ##
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

            ## summary line [ left-aligned, 3-space left pad, 1-space right ##
            ## pad, :: delimiter ]                                          ##
            my $max_summary = $inner_width - 4;
            if ( length($summary) > $max_summary ) {
                $summary = substr( $summary, 0, $max_summary - 3 ) . ' .,';
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

            ## help line [ left pad, :: delimiter ] ##
            my $help_text
                = ' · ctrl-x save+quit · ctrl-c abort · ctrl-o save · ctrl-w '
                . 'del-word · ctrl-l del-line · ctrl-d de-interlace · '
                . 'arrows · enter · del ·';
            $help_text = ' · ' . $hint . ' ·' . $help_text
                if length $hint;
            ## show status [ e.g. 'saved' ] on the LEFT so it survives ##
            ## narrow terminals; truncation keeps the leftmost part    ##
            $help_text = "· $last_status · $help_text"
                if length $last_status;
            $help_text = substr( $help_text, 0, $inner_width - 2 );
            my $help_pad = ' ' x ( $inner_width - length($help_text) - 1 );
            my $help     = $help_pad . $help_text . '';
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

            ## wait for input or a signal, then read one event ##
            my $key;
            while ( !defined $key and !$aborted and !$resized ) {
                my $rin = '';
                vec( $rin, fileno(STDIN),  1 ) = 1;
                vec( $rin, fileno($sig_r), 1 ) = 1;

                my $n = select( my $rout = $rin, undef, undef, undef );
                next if !defined $n or $n < 0;

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
            } elsif ( $key eq "\x0f" ) {    ## Ctrl-O : save ##
                $dirty       = 0;
                $last_status = 'saved';
            } elsif ( $key eq "\x18" ) {    ## Ctrl-X : save+quit ##
                $dirty       = 0;
                $last_status = 'saved';
                last;
            }

            ## navigation [ free cursor : lines grow with spaces ] ##
            elsif ( $key eq "\e[A" ) {      ## up ##
                if ( $cur_line > 0 ) {
                    $dirty = 1 if editor_leave_line( \@lines, $cur_line );
                    $cur_line--;
                    $dirty = 1
                        if editor_pad_line_to_col( \@lines, $cur_line,
                        $cur_col );
                }
            } elsif ( $key eq "\e[B" ) {    ## down ##
                if ( $cur_line < $#lines ) {
                    $dirty = 1 if editor_leave_line( \@lines, $cur_line );
                    $cur_line++;
                    $dirty = 1
                        if editor_pad_line_to_col( \@lines, $cur_line,
                        $cur_col );
                } else {
                    ## add a new line at EOF, padded to current column ##
                    $dirty = 1 if editor_leave_line( \@lines, $cur_line );
                    push @lines, ' ' x $cur_col;
                    $cur_line++;
                    $dirty = 1;
                }
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
            } elsif ( $key eq "\x0c" ) {     ## Ctrl-L : delete line ##
                splice @lines, $cur_line, 1;
                @lines    = ('')    if !@lines;
                $cur_line = $#lines if $cur_line > $#lines;
                $cur_col  = 0;
                $dirty    = 1;
            } elsif ( $key eq "\x17" ) {     ## Ctrl-W : del word back ##
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

            ## paste [ one event, one redraw ] ##
            elsif ( ref $key eq 'HASH' and defined $key->{'paste'} ) {
                my $text  = editor_normalize_paste( $key->{'paste'} );
                my @block = split m{\n}, $text, -1;

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

    Term::ReadKey::ReadMode(0);
    paste_disable();
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

    ## leave cursor on a fresh line below the frame, always visible, shape ##
    ## reset                                                               ##
    print "\e[$rows;1H\e[?25h\e[0 q\n\e[0 m";

    return $edit_result;
}

1;

#,,..,.,.,..,,,.,,...,..,,.,,,.,.,...,,..,.,.,..,,...,..,,...,,.,,,.,,,,,,.,,,
#3BCGNFKQF5XHFMOE5AHK5ZC47ISB4BIDYF3PL3EWK3GI4NQD7S6VIMGSVH6GBO2MTVCXWZ4B3CWK2
#\\\|4NCM2IXLWAVA3JZ5ZZ7BGX5P6WIWYUTR44NKE5N2HRDOB6GR265 \ / AMOS7 \ YOURUM ::
#\[7]QQ3SA3IZSXIPB42GYK5TK5NDFSSRVUE5ZQMJ7RHRYPW6MPGUOYCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
