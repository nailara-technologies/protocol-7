## [:< ##

package AMOS7::TERM::Frame;    #############################################

## core-only terminal frame rendering : the protocol-7 color palette and   ##
## the border \ rule \ content \ bar renderers extracted from AMOS7::TERM  ##
## [ that module needs Event, Term::ReadLine and Crypt::PRNG::Fortuna ].   ##
## this module loads on core perl only [ plus data/lib-path/pm ] so        ##
## bare-host tools like bin/p7-deps can frame their output without pulling ##
## in the full interactive terminal stack. AMOS7::TERM imports these subs  ##
## and aliases its %p7_colors to this hash -- every existing caller keeps  ##
## working unchanged.                                                      ##

use v5.24;
use utf8;
use strict;
use English;
use warnings;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

use AMOS7 qw| warn_err |;

use Exporter;
use base qw| Exporter |;
use vars qw| $VERSION @EXPORT_OK |;

our $VERSION = qw| AMOS7::TERM::Frame-VERSION.0000001 |;

@EXPORT_OK = qw[
    frame_border_line frame_rule_line frame_colorize_content frame_bar
    frame_color_enabled frame_column_line frame_title_banner
    frame_section_header frame_option_list
    frame_status_row frame_error_line frame_error_exit frame_progress_bar
];

##[ PROTOCOL-7 COLOR PALETTE ]################################################

our %p7_colors = (
    'p7_fg_0000' => "\e[38;2;68;39;172m",    ##  purple  ##
    'p7_fg_0001' => "\e[38;2;38;46;153m",    ##    blue  ##
    'p7_fg_0002' => "\e[38;2;170;94;2m",     ##   brown  ##
    'p7_fg_0003' => "\e[38;2;9;170;94m",     ##  phosphor green [ cursor ]  ##
    'p7_fg_0004' => "\e[38;2;6;71;195m",     ##  TRUE blue       [ text ]   ##
    ##  neon amber  [ brighter 0002 ]  ##
    'p7_fg_0005' => "\e[38;2;197;141;7m",
    ##  neon green  [ brighter 0003 ]  ##
    'p7_fg_0006' => "\e[38;2;71;195;6m",
);

##[ ASCII FRAME HELPERS ]#####################################################

## render a border line via anchor/fill/slot elasticity model  parameters:
## elements => [{type=>'anchor',value=>..,color=>..},
## {type=>'fill',char=>..,min=>..,color=>..},
## {type=>'slot',name=>..,color=>..}]  values => {name=>string} for slots
## width => target column count reset => ansi reset sequence
## [ used after every colored segment ]
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
        return warn_err('element type not defined')
            if not defined $el->{'type'};
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

## convenience wrapper : title on the left, fill dashes to the right  colors
## hash uses keys 'title', 'fill', 'reset' [ any missing = no color ]
sub frame_rule_line {
    my $title = shift // '';
    my $width = shift // 0;
    my $C     = shift // {};

    return frame_border_line(
        {   width    => $width,
            reset    => $C->{'reset'} // '',
            elements => [
                {   type  => qw| anchor |,
                    value => $title,
                    color => $C->{'title'} // '',
                },
                {   type  => qw| fill |,
                    char  => $C->{'char'} // '-',
                    min   => 1,
                    color => $C->{'fill'} // '',
                },
            ],
        }
    );
}

## colorize a content line  splits label:/value with leading/trailing pad also
## handles a separator row [ colon-border + = fill + colon-border ] color-hash
## keys used : fill_colon fill_eq label value
sub frame_colorize_content {
    my $line  = shift // '';
    my $A     = shift // {};
    my $reset = shift // '';
    return $line if not length $line;

    ## separator row : left border + run of = + right border ##
    if ( $line =~ m{^([:.])(\s*=+\s*)([:.])$} ) {
        my ( $lb, $mid, $rb ) = ( $1, $2, $3 );
        return
              ( $A->{'fill_colon'} // '' )
            . $lb
            . $reset
            . ( $A->{'fill_eq'} // '' )
            . $mid
            . $reset
            . ( $A->{'fill_colon'} // '' )
            . $rb
            . $reset;
    }

    my $first = substr( $line, 0, 1 );
    my $last  = length($line) > 1 ? substr( $line, -1, 1 ) : '';
    my $body
        = length($line) > 1
        ? substr( $line, 1, length($line) - 2 )
        : '';

    my $left
        = ( $first eq qw| : | )
        ? ( ( $A->{'fill_colon'} // '' ) . $first . $reset )
        : $first;
    my $right
        = ( $last eq qw| : | )
        ? ( ( $A->{'fill_colon'} // '' ) . $last . $reset )
        : $last;

    my $body_colored;
    if ( $body =~ m{^(\s*)([\w][\w\-\.]*:)(\s+)(.*?)(\s*)$} ) {
        my ( $lpad, $lbl, $sp, $val, $rpad ) = ( $1, $2, $3, $4, $5 );
        $body_colored
            = $lpad
            . ( $A->{'label'} // '' )
            . $lbl
            . $reset
            . $sp
            . ( length($val) ? ( $A->{'value'} // '' ) . $val . $reset : '' )
            . $rpad;
    } elsif ( length $body and $body =~ m{\S} ) {
        if ( $body =~ m{^(\s*)(.*?)(\s*)$} ) {
            my ( $lpad, $mid, $rpad ) = ( $1, $2, $3 );
            $body_colored = $lpad
                . (
                length($mid)
                ? ( $A->{'value'} // '' ) . $mid . $reset
                : ''
                ) . $rpad;
        } else {
            $body_colored = $body;
        }
    } else {
        $body_colored = $body;
    }

    return $left . $body_colored . $right;
}

## render fraction [ 0..1 ] as a left-justified space-padded fill bar
sub frame_bar {
    my $frac  = shift // 0;
    my $width = shift // 0;
    my $char  = shift // ':';

    $frac  = 0 if $frac < 0;
    $frac  = 1 if $frac > 1;
    $width = 0 if $width < 0;

    my $fill = int( $width * $frac );
    $fill = $width if $fill > $width;

    return sprintf( '%-*s', $width, $char x $fill );
}

##[ SHARED TERMINAL HELPERS ]#################################################
##
## the look of bin/todo, bin/format-code and bin/amos-chksum as one set of  ##
## helpers. every helper returns a string [ no trailing newline, nothing    ##
## printed ] except frame_error_exit -- frame_section_header and           ##
## frame_option_list return more than one line. colour meanings :          ##
##   ok \ success ................ neon green  [ p7_fg_0006 ] -- only these ##
##   warnings \ errors ........... neon amber  [ p7_fg_0005 ]               ##
##   titles \ labels \ values .... TRUE blue   [ p7_fg_0004 ]               ##
##   structure [ : [ ] . < > ] ... purple      [ p7_fg_0000 ]               ##
## without colours the very same text comes back, no escape sequence in it ##

## backgrounds -- apart from %p7_colors, which holds foregrounds only ##
our %p7_bg = (
    ##  nailara background [ format-code's progress bar ]  ##
    'p7_bg_0002' => "\e[48;2;9;5;42m",
);

our $color_reset = "\e[0m";

## the AMOS7 error exit code [ AMOS7::error_exit : exit( qw| 0110 | ) ] ##
our $exit_error = qw| 0110 |;

## undef : frame_color_enabled decides ; TRUE \ FALSE force colours on \ ##
## off for every helper [ a -nc option, tests ]                          ##
our $color_override;

## the central colour gate : colours on a terminal only, never with a      ##
## non-empty NO_COLOR [ no-color.org : 'present and not an empty string' ] ##
## -- the handle to test is the one the text goes to [ STDERR for errors ] ##
sub frame_color_enabled {
    my $fh = shift // \*STDOUT;
    return $color_override ? TRUE : FALSE if defined $color_override;
    return FALSE                          if length( $ENV{'NO_COLOR'} // '' );
    return -t $fh ? TRUE : FALSE;
}

## per-call option { color => TRUE \ FALSE } wins over the gate ##
sub _color_on {
    my ( $opt, $fh ) = @_;
    return $opt->{'color'} ? TRUE : FALSE
        if defined $opt and defined $opt->{'color'};
    return frame_color_enabled($fh);
}

## one coloured segment [ empty text stays empty, no colour : plain ] ##
sub _paint {
    my ( $on, $key, $text ) = @_;
    return ''    if not length( $text // '' );
    return $text if not $on;
    my $color = $p7_colors{$key} // $p7_bg{$key} // '';
    return $color . $text . $color_reset;
}

## the bare left column between rows : ':' [ or '::' .. ] ##
sub frame_column_line {
    my $column = shift // ':';
    my $opt    = shift // {};
    return _paint( _color_on($opt), qw| p7_fg_0000 |, $column );
}

## main title : ' .: main title :. ' ##
sub frame_title_banner {
    my $title = shift // '';
    my $opt   = shift // {};
    my $on    = _color_on($opt);

    return
          _paint( $on, qw| p7_fg_0000 |, ' .: ' )
        . _paint( $on, qw| p7_fg_0004 |, $title )
        . _paint( $on, qw| p7_fg_0000 |, ' :. ' );
}

## section title continuing a ':' \ '::' column : ':::[ section title ]' ##
## and a '::' line below it, so the rows' '::' column starts right under ##
## the header [ option column : that line, default '::' ]                ##
sub frame_section_header {
    my $title = shift // '';
    my $opt   = shift // {};
    my $on    = _color_on($opt);

    return
          _paint( $on, qw| p7_fg_0000 |, ':::[ ' )
        . _paint( $on, qw| p7_fg_0004 |, $title )
        . _paint( $on, qw| p7_fg_0000 |, ' ]' ) . "\n"
        . _paint( $on, qw| p7_fg_0000 |, $opt->{'column'} // qw| :: | );
}

## an option list after bin/todo and bin/amos-chksum : the text as given, ##
## its words TRUE blue and everything between them purple                 ##
## [ dot leaders, brackets, '.:' ]. the trailing newline is taken off     ##
sub frame_option_list {
    my $text = shift // '';
    my $opt  = shift // {};

    $text =~ s|\n\z||;
    return $text if not _color_on($opt);

    ## spaces stay unpainted : words blue, every other run purple ##
    $text =~ s{(\w+)|([^\w\s]+)}{
        defined $1
            ? _paint( TRUE, qw| p7_fg_0004 |, $1 )
            : _paint( TRUE, qw| p7_fg_0000 |, $2 )
    }ge;
    return $text;
}

## status words and their level : the same split bin/p7-deps' service      ##
## report uses [ 'ok' green, the problem words amber, the rest TRUE blue ] ##
our %status_level = (
    ( map { $ARG => qw| ok | } qw| ok success | ),
    (   map { $ARG => qw| warn | }
            qw| failed missing differs stale older warning error refused |
    ),
);

## dot-leader status row :  '::   label ...... status [ detail ]'  options ##
## : width [ label column, the longest label of the block ], detail, level ##
## [ ok \ warn \ value -- else looked up by the status ], column           ##
## [ default '::' ], color. the leader has three dots at least so the      ##
## longest label still stands apart from its status                        ##
sub frame_status_row {
    my $label  = shift // '';
    my $status = shift // '';
    my $opt    = shift // {};
    my $on     = _color_on($opt);

    my $width  = $opt->{'width'}  // length($label);
    my $column = $opt->{'column'} // qw| :: |;
    my $level  = $opt->{'level'}  // $status_level{$status} // qw| value |;
    my $dots   = '.'
        x ( 3 + ( $width > length($label) ? $width - length($label) : 0 ) );

    my $status_key
        = $level eq qw| ok |   ? qw| p7_fg_0006 |
        : $level eq qw| warn | ? qw| p7_fg_0005 |
        :                        qw| p7_fg_0004 |;

    my $row
        = _paint( $on, qw| p7_fg_0000 |, $column ) . '   '
        . _paint( $on, qw| p7_fg_0004 |, $label ) . ' '
        . _paint( $on, qw| p7_fg_0000 |, $dots ) . ' '
        . _paint( $on, $status_key,      $status );

    my $detail = $opt->{'detail'} // '';
    $row
        .= ' '
        . _paint( $on, qw| p7_fg_0000 |, '[ ' )
        . _paint( $on, qw| p7_fg_0004 |, $detail )
        . _paint( $on, qw| p7_fg_0000 |, ' ]' )
        if length $detail;

    return $row;
}

## error line in the bin/format-code form : ':: < tool > : message'. an    ##
## AMOS7 caller marker at the end [ ' <{NC}>', ' <{C1}>' ] is taken off -- ##
## this line never shows a caller. the tool name is TRUE blue, not         ##
## format-code's green [ green means ok only ] ; colours follow STDERR     ##
sub frame_error_line {
    my $tool    = shift // '';
    my $message = shift // '';
    my $opt     = shift // {};
    my $on      = _color_on( $opt, \*STDERR );

    $message =~ s{ <\{(?:NC|C\d+)\}>$}{};

    return
          _paint( $on, qw| p7_fg_0000 |, ':: < ' )
        . _paint( $on, qw| p7_fg_0004 |, $tool )
        . _paint( $on, qw| p7_fg_0000 |, ' > : ' )
        . _paint( $on, qw| p7_fg_0005 |, $message );
}

## the error line framed by ':' rows on STDERR, then exit 0110 [ option  ##
## exit : another code, for callers whose exit codes are fixed already ] ##
sub frame_error_exit {
    my ( $tool, $message, $opt ) = @ARG;
    my $col = _paint( _color_on( $opt, \*STDERR ), qw| p7_fg_0000 |, ':' );
    STDOUT->flush;    ## what was printed before stays before the error ##
    print STDERR $col, "\n", frame_error_line( $tool, $message, $opt ), "\n",
        $col, "\n";
    exit( $opt->{'exit'} // $exit_error );
}

## progress bar after bin/format-code : ':::[:::::        ]:::[ label ]:.' ##
## [ done of total ]. options : width [ bar columns, default 13 ],         ##
## label_width [ pads the label so a \r redraw overwrites a longer one ],  ##
## color. the caller adds the '\r' or '\n'                                 ##
sub frame_progress_bar {
    my $done  = shift // 0;
    my $total = shift // 0;
    my $label = shift // '';
    my $opt   = shift // {};
    my $on    = _color_on($opt);

    my $width = $opt->{'width'} // 13;
    my $bar   = frame_bar( $total > 0 ? $done / $total : 0, $width, ':' );
    my $bg    = $on ? $p7_bg{'p7_bg_0002'} : '';

    my $line
        = _paint( $on, qw| p7_fg_0000 |, ':::[' )
        . (
        $on ? $bg . $p7_colors{'p7_fg_0004'} . $bar . $color_reset : $bar )
        . _paint( $on, qw| p7_fg_0000 |, ']' );

    if ( length $label ) {
        my $padded = sprintf ' %-*s ',
            $opt->{'label_width'} // length($label),
            $label;
        $line .= _paint( $on, qw| p7_fg_0000 |, ':::[' )
            . (
              $on
            ? $bg . $p7_colors{'p7_fg_0004'} . $padded . $color_reset
            : $padded
            ) . _paint( $on, qw| p7_fg_0000 |, ']' );
    }

    return $line . _paint( $on, qw| p7_fg_0000 |, ':.' );
}

1;

#,,..,.,.,,.,,,.,,.,.,.,.,,,.,.,,,.,.,,.,,,..,..,,...,...,,,.,,.,,,,.,,,,,...,
#ZH3PSIFH7N6GPV2LIJZYNB76UWQKOUTDF2QGJMUHPTXHPOBJZZ4OA62LWLOMQTWKEVKPU6VEJZOD6
#\\\|F5EDOLP7CKMFSD7AYG6MKSB2KT6527IZWS56JHWWK6MSYBLJMTH \ / AMOS7 \ YOURUM ::
#\[7]F44WKCTZFKAJU7ALENSAGLUHC3VG5MKASJHIYBZJEJCBTYE7SACA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
