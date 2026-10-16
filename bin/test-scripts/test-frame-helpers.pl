#!/usr/bin/env perl
use v5.32;
use strict;
use English;
use warnings;

## AMOS7::TERM::Frame's shared terminal helpers : the exact plain text of   ##
## every helper, the coloured text being that same plain text once the      ##
## escapes are taken out, and each colour on the part it belongs to [ ok \  ##
## success neon green only, warnings \ errors neon amber, titles \ labels \ ##
## values TRUE blue, structure purple ]. the colour gate : the override,    ##
## NO_COLOR, a pipe being no terminal. frame_error_exit runs in a child     ##
## [ STDERR text, exit 0110 ].                                              ##

use File::Spec;
use Cwd     qw| abs_path |;
use FindBin qw| $RealBin |;

use constant { TRUE => 5, FALSE => 0 };

BEGIN {
    my $root_path = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir(
                $RealBin, File::Spec->updir, File::Spec->updir
            )
        )
    );
    $main::lib_path
        = File::Spec->catdir( $root_path, qw| data lib-path pm | );
    unshift( @INC, $main::lib_path );
}

use AMOS7::TERM::Frame qw|
    frame_color_enabled frame_column_line frame_title_banner
    frame_section_header frame_status_row frame_error_line
    frame_progress_bar frame_option_list
    frame_terminal_width frame_fit_width
    |;

my $pass_count = 0;
my $fail_count = 0;

sub check {
    my ( $label, $cond ) = @_;
    if ($cond) {
        $pass_count++;
        printf "ok   : %s\n", $label;
    } else {
        $fail_count++;
        printf "FAIL : %s\n", $label;
    }
    return $cond;
}

## colour literals [ the palette test in test-deps-core-perl.pl pins them ] ##

my $R  = "\e[0m";
my $pu = "\e[38;2;68;39;172m";    ## p7_fg_0000 structure ##
my $bl = "\e[38;2;6;71;195m";     ## p7_fg_0004 TRUE blue ##
my $am = "\e[38;2;197;141;7m";    ## p7_fg_0005 neon amber ##
my $gr = "\e[38;2;71;195;6m";     ## p7_fg_0006 neon green ##
my $bg = "\e[48;2;9;5;42m";       ## p7_bg_0002 nailara background ##

sub strip_ansi { return $_[0] =~ s|\e\[[0-9;]*m||gr }

my $OFF = { color => FALSE };
my $ON  = { color => TRUE };

## every helper : plain text exact, coloured text = plain once stripped ##

my @cases = (
    [ 'column line', sub { frame_column_line( '::', $_[0] ) }, '::' ],
    [   'title banner',
        sub { frame_title_banner( 'protocol-7 install', $_[0] ) },
        ' .: protocol-7 install :. '
    ],
    [   'section header',
        sub { frame_section_header( 'base packages', $_[0] ) },
        ":::[ base packages ]\n::"
    ],
    [   'section header, other column',
        sub {
            frame_section_header( 'state', { %{ $_[0] }, column => ':' } );
        },
        ":::[ state ]\n:"
    ],
    [   'option list',
        sub {
            frame_option_list(
                "\n    .: tool options :.\n\n    list "
                    . "<name>.. ...  the [ named ] lists\n\n",
                $_[0]
            );
        },
        "\n    .: tool options :.\n\n    list "
            . "<name>.. ...  the [ named ] lists\n"
    ],
    [   'status row ok',
        sub { frame_status_row( 'git', 'ok', { %{ $_[0] }, width => 15 } ) },
        '::   git ............... ok'
    ],
    [   'status row warn + detail',
        sub {
            frame_status_row( 'build-essential', 'missing',
                { %{ $_[0] }, width => 15, detail => 'would install' } );
        },
        '::   build-essential ... missing [ would install ]'
    ],
    [   'status row label longer than width',
        sub {
            frame_status_row( 'a-very-long-label', 'set',
                { %{ $_[0] }, width => 4, column => ':' } );
        },
        ':   a-very-long-label ... set'
    ],
    [   'error line',
        sub { frame_error_line( 'p7-install', 'needs root <{NC}>', $_[0] ) },
        ':: < p7-install > : needs root'
    ],
    [   'error line caller marker',
        sub { frame_error_line( 'tool', 'bad input <{C2}>', $_[0] ) },
        ':: < tool > : bad input'
    ],
    [   'progress bar with label',
        sub {
            frame_progress_bar( 7, 13, 'bin/p7-deps',
                { %{ $_[0] }, label_width => 14 } );
        },
        ':::[:::::::      ]:::[ bin/p7-deps    ]:.'
    ],
    [   'progress bar done, no label',
        sub { frame_progress_bar( 4, 4, '', { %{ $_[0] }, width => 6 } ) },
        ':::[::::::]:.'
    ],
    [   'progress bar empty total',
        sub { frame_progress_bar( 0, 0, '', { %{ $_[0] }, width => 4 } ) },
        ':::[    ]:.'
    ],
);

for my $case (@cases) {
    my ( $name, $render, $expected ) = @{$case};
    my $plain   = $render->($OFF);
    my $colored = $render->($ON);
    check "$name : plain text exact", $plain eq $expected;
    printf "       : got [%s]\n", $plain if $plain ne $expected;
    check "$name : plain has no escape", index( $plain,   "\e" ) < 0;
    check "$name : coloured has colour", index( $colored, "\e[" ) >= 0;
    check "$name : coloured = plain once stripped",
        strip_ansi($colored) eq $plain;
}

## each colour on its part ##

my $c;

$c = frame_status_row( 'git', 'ok', { %$ON, width => 3 } );
check 'status ok : label blue, leader purple, ok green',
    $c eq "${pu}::$R   $bl" . "git$R $pu...$R $gr" . "ok$R";

$c = frame_status_row( 'x', 'success', $ON );
check 'status success : green', index( $c, "${gr}success$R" ) >= 0;

for my $word (qw| failed missing differs stale older warning error refused |)
{
    $c = frame_status_row( 'x', $word, $ON );
    check "status $word : amber, no green",
        index( $c, "$am$word$R" ) >= 0 && index( $c, $gr ) < 0;
}

for my $word ( 'set', 'changed', 'would run', 'enabled' ) {
    $c = frame_status_row( 'x', $word, $ON );
    check "status $word : blue value, no green",
        index( $c, "$bl$word$R" ) >= 0 && index( $c, $gr ) < 0;
}

$c = frame_status_row( 'x', 'installed', { %$ON, level => 'ok' } );
check 'status level ok overrides the word : green',
    index( $c, "${gr}installed$R" ) >= 0;
$c = frame_status_row( 'x', 'ok', { %$ON, level => 'warn' } );
check 'status level warn overrides the word : amber',
    index( $c, "${am}ok$R" ) >= 0;

$c = frame_status_row( 'x', 'ok', { %$ON, detail => 'd' } );
check 'status detail : blue in purple brackets',
    $c =~ m|\Q$pu\E\[ \Q$R$bl\Ed\Q$R$pu\E \]\Q$R\E$|;

$c = frame_title_banner( 'title', $ON );
check 'banner : title blue, frame purple, no green',
    $c eq "$pu .: $R${bl}title$R$pu :. $R";

$c = frame_section_header( 'section', $ON );
check 'section : title blue, frame purple, \'::\' line below, no green',
    $c eq "${pu}:::[ $R${bl}section$R$pu ]$R\n${pu}::$R";

$c = frame_option_list( "  -nc ..  no [ colours ]\n", $ON );
check 'option list : words blue, the rest purple, spaces bare, no green',
    $c eq "  $pu-$R${bl}nc$R $pu..$R  ${bl}no$R "
    . "$pu\[$R ${bl}colours$R $pu]$R";

$c = frame_error_line( 'tool', 'message', $ON );
check 'error : tool blue [ not green ], message amber, frame purple',
    $c eq "${pu}:: < $R${bl}tool$R$pu > : $R${am}message$R";

$c = frame_progress_bar( 1, 2, 'f', { %$ON, width => 2 } );
check 'progress : bar and label blue on the nailara background',
    $c eq "${pu}:::[$R$bg$bl: $R$pu]$R${pu}:::[$R$bg$bl f $R$pu]$R${pu}:.$R";

## the colour gate ##

{
    local $AMOS7::TERM::Frame::color_override;
    local $ENV{'NO_COLOR'};

    $ENV{'NO_COLOR'} = '1';
    check 'gate : NO_COLOR set -> off', not frame_color_enabled();
    check 'gate : NO_COLOR set -> helpers plain',
        index( frame_section_header('s'), "\e" ) < 0;

    $ENV{'NO_COLOR'} = '';
    open( my $pipe_out, '-|', $EXECUTABLE_NAME, '-e', 'print 1' )
        or die "pipe : $OS_ERROR";
    check 'gate : a pipe is no terminal -> off',
        not frame_color_enabled($pipe_out);
    close $pipe_out;

    ## a pty master is a terminal : the gate opens, NO_COLOR closes it ##
    my $tty;
    if ( open( $tty, '+<', '/dev/ptmx' ) and -t $tty ) {
        $ENV{'NO_COLOR'} = '';
        check 'gate : terminal, empty NO_COLOR -> on',
            frame_color_enabled($tty);
        $ENV{'NO_COLOR'} = '1';
        check 'gate : terminal, NO_COLOR set -> off',
            not frame_color_enabled($tty);
        delete $ENV{'NO_COLOR'};
        check 'gate : terminal, no NO_COLOR -> on', frame_color_enabled($tty);
        close $tty;
    } else {
        print "skip : no /dev/ptmx terminal -- "
            . "NO_COLOR on a terminal not checked\n";
    }

    $AMOS7::TERM::Frame::color_override = TRUE;
    $ENV{'NO_COLOR'} = '1';
    check 'gate : override TRUE wins over NO_COLOR', frame_color_enabled();
    check 'gate : override TRUE colours the helpers',
        index( frame_section_header('s'), "\e[" ) >= 0;

    $AMOS7::TERM::Frame::color_override = FALSE;
    check 'gate : override FALSE -> off', not frame_color_enabled();
    check 'gate : per-call color wins over the override',
        index( frame_section_header( 's', $ON ), "\e[" ) >= 0;
}

## frame_fit_width : the bin/todo center cut ##

check 'fit width : shorter text unchanged',
    frame_fit_width( 'short', 10 ) eq 'short';
check 'fit width : no width means no limit',
    frame_fit_width( 'a much longer line', undef ) eq 'a much longer line';
my $fitted = frame_fit_width( 'abcdefghijklmnopqrstuvwxyz', 10 );
check 'fit width : center ellipse keeps the total length',
    length($fitted) == 10;
check 'fit width : the mark is spliced into the middle',
    $fitted eq 'abc.,.wxyz';
check 'fit width : exact width stays untouched',
    frame_fit_width( '1234567890', 10 ) eq '1234567890';
check 'fit width : a tiny budget gets a plain cut',
    frame_fit_width( 'abcdefghijklmnopqrstuvwxyz', 3 ) eq 'abc';

## frame_terminal_width : 0 without a terminal, the pty size with one ##

{
    open( my $pipe_out, '-|', $EXECUTABLE_NAME, '-e', 'print 1' )
        or die "pipe : $OS_ERROR";
    check 'terminal width : a pipe is no terminal -> 0',
        frame_terminal_width($pipe_out) == 0;
    close $pipe_out;

    my $tty;
    if ( open( $tty, '+<', '/dev/ptmx' ) and -t $tty ) {
        local $ENV{'TERM'}    = 'xterm';
        local $ENV{'COLUMNS'} = undef;
        my $winsize = pack( 'S4', 24, 66, 0, 0 );
        ioctl( $tty, 0x5414, $winsize ) or die "TIOCSWINSZ : $OS_ERROR";
        check 'terminal width ' . ': the pty size',
            frame_terminal_width($tty) == 66;
        my $zero = pack( 'S4', 0, 0, 0, 0 );
        ioctl( $tty, 0x5414, $zero ) or die "TIOCSWINSZ : $OS_ERROR";
        check 'terminal width : size 0 falls back to 80',
            frame_terminal_width($tty) == 80;
        close $tty;
    } else {
        print "skip : no /dev/ptmx terminal -- the width not checked\n";
    }
}

## frame_error_exit : framed error line on STDERR, exit 0110 ##

{
    my $child = <<'EOF';
use AMOS7::TERM::Frame qw| frame_error_exit |;
open( STDERR, '>&', \*STDOUT );
print 'before|';
frame_error_exit( 'tool', 'it broke <{NC}>' );
print 'not reached';
EOF
    local $ENV{'NO_COLOR'} = '1';
    my $pid = open( my $pipe, '-|' ) // die "fork : $OS_ERROR";
    if ( $pid == 0 ) {
        exec( $EXECUTABLE_NAME, '-I', $main::lib_path, '-e', $child )
            or exit 127;
    }
    local $INPUT_RECORD_SEPARATOR = undef;
    my $out = <$pipe> // '';
    close $pipe;
    my $exit = $CHILD_ERROR >> 8;
    check 'error exit : exit 0110 [ 110 ]', $exit == 110;
    check 'error exit : framed line, nothing after it',
        $out eq "before|:\n:: < tool > : it broke\n:\n";
}

## the exit option : another code, the same framed line ##

{
    local $ENV{'NO_COLOR'} = '1';
    my $pid = open( my $pipe, '-|' ) // die "fork : $OS_ERROR";
    if ( $pid == 0 ) {
        open( STDERR, '>&', \*STDOUT );
        exec( $EXECUTABLE_NAME, '-I', $main::lib_path, '-e',
            'use AMOS7::TERM::Frame qw| frame_error_exit |;frame_error_exit( '
                . '"tool", "no such thing", { exit => 1 } )' )
            or exit 127;
    }
    local $INPUT_RECORD_SEPARATOR = undef;
    my $out = <$pipe> // '';
    close $pipe;
    check 'error exit, exit option : exit 1', ( $CHILD_ERROR >> 8 ) == 1;
    check 'error exit, exit option : the same framed line',
        $out eq ":\n:: < tool > : no such thing\n:\n";
}

printf "\n: %d checks passed, %d failed\n", $pass_count, $fail_count;
exit( $fail_count ? 1 : 0 );

#,,.,,,.,,,,,,..,,,.,,,,,,,,,,,,,,,,,,,,.,...,..,,...,...,.,.,...,,.,,,,,,...,
#MDBGLZITM2DJUYNVKZHFAHHN42UJOPT63EX2EGVV3PEN3OQPZVFQFFOVYKMTEBY5FXELT5VQZJ2Z4
#\\\|LWNM6JCJVQQNY5CACKYT6RMS5R5AHNFBGGQUV62VXPVJYSJSCJI \ / AMOS7 \ YOURUM ::
#\[7]YLNFXFQKTWFRQPZ4FLFTRR3ZCCF66EU77MK7X6YF776237ZEGAAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
