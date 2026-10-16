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

1;

#,,.,,,,.,...,.,,,.,,,...,,,.,...,.,.,..,,,,,,..,,...,...,.,.,.,.,.,,,.,,,.,.,
#JPFFGZUZSKFGA7KY73GJ4FMMHKVJS5SBXYHN2D56K4UD5OQ4MR7EDKBYF3PBLMLWNNLLSUCESNVKS
#\\\|2L7KAIFEL3LFWBV2EJKDKVZRBMCC7KQ446X6JHGMYLAXHE65HUK \ / AMOS7 \ YOURUM ::
#\[7]URLBFTE2U37OW7A3OTEYUPZSZLP2JU6SULPKCH4THN5TNRUNWICA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
