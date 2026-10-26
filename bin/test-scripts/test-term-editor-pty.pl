#!/usr/bin/perl
use v5.32.0;
use strict;
use warnings;
use English;

## Test AMOS7::TERM::Editor on a real pty [ IO::Pty ] : the live edit_text
## loop, its signals and its tty state. Tests : a resize storm during a
## bracketed paste keeps the whole paste as data
## [ control bytes inside do not abort ], a closed tty ends the editor instead
## of spinning, suspend hands back a cooked tty and continue takes raw mode
## back, the cursor shape is reset after a ctrl-c abort, typed utf-8 arrives
## as characters. save tests : ctrl-s [ and its ctrl-o alias ] calls on_save
## with the normalized buffer and the editor keeps running, a false return or
## a die shows the failure and the editor keeps running, without on_save no
## 'saved' is ever claimed. page keys : pgdn moves a visible page and stops at
## the last line instead of growing one, pgup walks a page back and stays at
## the top. mouse : a left press positions the cursor, chrome clicks and
## releases stay inert, the wheel accelerates on a NON-LINEAR curve [ slow =
## line-per-tick, short medium rolls stay relative, a full roll pays pages,
## fast = one collapsed page ] and a no-op tick at EOF repaints nothing.  kill
## register : ctrl+. [ \x0e or CSI-u \e[46;5u ] restores oldest-first so kills
## rebuild their original order, \x1c \ \e[44;5u kill where the terminal gives
## ctrl-, its own byte, an empty register says so ; a truncated tail restores
## in place at the kill position ; modifyOtherKeys=1 is enabled while open and
## disabled on exit. wrap mode [ wrap => 1 ] folds long lines into full-width
## rows with a continuation marker instead of scrolling them sideways -- the
## buffer roundtrips untouched, the hardware cursor lands on the continuation
## row, pgdn pages by visual rows ; a wrapped block is followed by a dim
## dotted separator row [ wrap_sep => 0 opts out ] that every visual-row walk
## counts ; a CSI-u sequence arriving byte-wise with a lagging final byte
## still kills [ never types its tail into the text ] ; scroll mode clamps the
## tail window -- a shorter long line under a far-right cursor never trips
## substr outside of string. skipped when IO::Pty is not installed

##[ LOCAL PM LIB PATH ]#######################################################

my $local_lib_path;

BEGIN {
    use File::Spec;
    use Cwd     qw| abs_path |;
    use FindBin qw| $RealBin |;
    my $up_dir       = File::Spec->updir;
    my $data_pm_path = qw| data/lib-path/pm |;
    my $root_path    = abs_path(
        File::Spec->rel2abs(
            File::Spec->catdir( $RealBin, $up_dir, $up_dir )
        )
    );
    $local_lib_path
        = abs_path( File::Spec->catdir( $root_path, $data_pm_path ) );
    $local_lib_path //= $data_pm_path;
    die "\n:\n:: not found : $local_lib_path\n:\n" if !-d $local_lib_path;
}

use POSIX       qw| WNOHANG setsid |;
use File::Temp  qw| tempdir |;
use Time::HiRes qw| time |;

if ( !eval { require IO::Pty; 1 } ) {
    say '=== skipped : IO::Pty not installed ===';
    exit 0;
}

say '=== testing AMOS7::TERM::Editor on a pty ===';

my $tests_run    = 0;
my $tests_passed = 0;

sub check {
    my ( $label, $ok ) = @ARG;
    $tests_run++;
    $tests_passed++ if $ok;
    say sprintf '[ %s ] %s', ( $ok ? 'ok' : 'FAIL' ), $label;
    return;
}

my $tmp_dir = tempdir( CLEANUP => 1 );

## the editor child : writes its pid, edits, writes the result ##
my $child_code = <<~'CHILD';
    use strict;
    use warnings;
    use AMOS7::TERM::Editor qw| edit_text |;
    binmode STDOUT, ':utf8';
    my $out = shift;
    { open my $pid_fh, '>', "$out.pid" or die; print $pid_fh $$; }
    my $result = eval {
        edit_text( { text => 'seed', title => 'T', summary => 's',
            label => 'l' } );
    };
    open my $fh, '>:utf8', $out or die;
    print $fh defined $result ? "RESULT=<$result>" : 'RESULT=<UNDEF>';
    close $fh;
    CHILD

## a child with an on_save hook : every save appends the received text to
## <result>.saves ; FAILME makes the callback return false, DIEME dies -- both
## must surface as 'save failed' without ending the editor
my $child_code_save = <<~'CHILD';
    use strict;
    use warnings;
    use AMOS7::TERM::Editor qw| edit_text |;
    binmode STDOUT, ':utf8';
    my $out      = shift;
    my $save_log = "$out.saves";
    { open my $pid_fh, '>', "$out.pid" or die; print $pid_fh $$; }
    my $result = eval {
        edit_text( { text => 'seed', title => 'T', summary => 's',
            label => 'l',
            on_save => sub {
                my $text = shift;
                open my $fh, '>>:utf8', $save_log or die "save log : $!";
                print $fh "SAVE=<$text>\n";
                close $fh;
                die "boom : refused\n" if $text =~ m{DIEME};
                return $text =~ m{FAILME} ? 0 : 1;
            },
        } );
    };
    open my $fh, '>:utf8', $out or die;
    print $fh defined $result ? "RESULT=<$result>" : 'RESULT=<UNDEF>';
    close $fh;
    CHILD

## a child seeded with control characters in the payload
## [ VT \x0b and a lone ESC ] : the buffer must keep the raw bytes, the drawn
## frame must show them in caret notation -- raw they would act as terminal
## commands and break the frame
my $child_code_controls = <<~'CHILD';
    use strict;
    use warnings;
    use AMOS7::TERM::Editor qw| edit_text |;
    binmode STDOUT, ':utf8';
    my $out = shift;
    { open my $pid_fh, '>', "$out.pid" or die; print $pid_fh $$; }
    my $result = eval {
        edit_text( { text => "a\x0bb\x1bc", title => 'T', label => 'l' } );
    };
    open my $fh, '>:utf8', $out or die;
    print $fh defined $result ? "RESULT=<$result>" : 'RESULT=<UNDEF>';
    close $fh;
    CHILD

sub read_file {
    my $path = shift;
    my $text = '';
    if ( open my $fh, '<:utf8', $path ) {
        local $INPUT_RECORD_SEPARATOR;
        $text = <$fh>;
    }
    return $text;
}

sub run_case {
    my ( $name, $script, $code ) = @ARG;
    $code //= $child_code;
    my $result_file = "$tmp_dir/result.$name";
    my $pty         = IO::Pty->new;
    $pty->set_winsize( 30, 100 ) if $pty->can('set_winsize');

    my $pid = fork // die "fork : $OS_ERROR";
    if ( !$pid ) {
        setsid();
        my $slave = $pty->slave;
        close $pty;
        open STDIN,  '<&', $slave;
        open STDOUT, '>&', $slave;
        open STDERR, '>&', $slave;
        {
            exec $EXECUTABLE_NAME, "-I$local_lib_path", '-e', $code,
                $result_file;
        }
        POSIX::_exit(127);
    }
    $pty->close_slave;

    ## drain the master for $seconds [ the editor blocks on a full pty ] ; ##
    ## once a case closed the master this just waits                       ##
    my $output = '';
    my $drain  = sub {
        my $until = time() + shift;
        while ( time() < $until ) {
            if ( !defined fileno($pty) ) {
                select( undef, undef, undef, $until - time() );
                last;
            }
            my $rin = '';
            vec( $rin, fileno($pty), 1 ) = 1;
            next if !select( $rin, undef, undef, 0.05 );
            my $n = sysread( $pty, my $buf, 65536 );
            last if !$n;
            $output .= $buf;
        }
    };

    $drain->(0.8);
    $script->( $pty, $pid, $drain );
    $drain->(1.0);

    my $exited = 0;
    for ( 1 .. 30 ) {
        if ( waitpid( $pid, WNOHANG ) > 0 ) { $exited = 1; last }
        $drain->(0.1);
    }
    if ( !$exited ) { kill 'KILL', $pid; waitpid( $pid, 0 ) }

    my $result = '';
    if ( open my $fh, '<:utf8', $result_file ) {
        local $INPUT_RECORD_SEPARATOR;
        $result = <$fh>;
    }
    return ( $result, $exited, $output );
}

sub tty_flags {
    my $tty      = shift;
    my $stty     = qx|stty -a < $tty 2>/dev/null|;
    my ($icanon) = $stty =~ m{(-?icanon)};
    return $icanon // '?';
}

## a resize storm during a paste : signals must not cut the paste short ##
my ( $result, $exited, $output ) = run_case(
    qw| paste |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        syswrite $pty, "\e[200~PART-A";
        $drain->(0.15);
        for ( 1 .. 5 ) { kill 'WINCH', $pid; $drain->(0.05) }
        syswrite $pty, "PART-B\x03\x0cTAIL\e[201~";
        $drain->(0.5);
        syswrite $pty, "\x18";
    }
);
check(
    'resize during paste : whole paste kept, ctrl bytes are data',
    $result eq "RESULT=<PART-APART-B\x03\x0cTAILseed>" && $exited
);

## one burst holding a literal terminator in the middle, then the real one :
## the whole burst is paste content, the real terminator ends it
( $result, $exited ) = run_case(
    qw| pasteterm |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        syswrite $pty, "\e[200~ONE\e[201~TWO\e[201~";
        $drain->(0.5);
        syswrite $pty, "\x18";
    }
);
check( 'literal terminator mid-burst : content kept, real end ends the paste',
    $result eq "RESULT=<ONE\e[201~TWOseed>" && $exited );

## a paste followed by typed keys after a pause : the keys stay editing ##
## keys, they are not swallowed into the paste                          ##
( $result, $exited ) = run_case(
    qw| pastekeys |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        syswrite $pty, "\e[200~ab\e[201~";
        $drain->(0.6);
        syswrite $pty, 'QZ';
        $drain->(0.3);
        syswrite $pty, "\x18";
    }
);
check(
    'keys typed after a paste are not swallowed',
    $result eq 'RESULT=<abQZseed>' && $exited
);

## typed utf-8 : multibyte keys arrive as characters, a lone latin-1 byte ##
## does not swallow the keys after it                                     ##
( $result, $exited ) = run_case(
    qw| utf8 |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        syswrite $pty, "h\xC3\xA9llo \xE2\x80\x94 w\xC3\xB6rld \xE9ab";
        $drain->(0.4);
        syswrite $pty, "\x18";
    }
);
check(
    'typed utf-8 : characters in, characters out',
    $result eq "RESULT=<h\x{e9}llo \x{2014} w\x{f6}rld \x{e9}abseed>"
        && $exited
);

## control characters in the payload : the frame shows them in caret notation,
## never raw -- raw \x0b or ESC+c would act as terminal commands and break the
## frame ; the buffer and the result keep the bytes as they are
( $result, $exited, $output ) = run_case(
    qw| controls |,
    sub {
        my ($pty) = @ARG;
        syswrite $pty, "\x18";
    },
    $child_code_controls
);
check(
    'controls : frame shows caret notation, the result keeps the bytes',
    $result eq "RESULT=<a\x0bb\x1bc>"
        && $exited
        && index( $output, 'a^Kb^[c' ) >= 0
        && $output !~ m{\x0b}
        && $output !~ m{\x1bc}
);

## a child seeded with three lines and no clipboard [ hermetic ] : ctrl-l
## pushes onto the kill stack, ctrl-v pops back above the cursor
my $child_code_lines = <<~'CHILD';
    use strict;
    use warnings;
    use AMOS7::TERM::Editor qw| edit_text |;
    binmode STDOUT, ':utf8';
    $ENV{'P7_EDITOR_NO_CLIP'} = 1;
    my $out = shift;
    { open my $pid_fh, '>', "$out.pid" or die; print $pid_fh $$; }
    my $result = eval {
        edit_text( { text => "one\ntwo\nthree", title => 'T',
            label => 'l' } );
    };
    open my $fh, '>:utf8', $out or die;
    print $fh defined $result ? "RESULT=<$result>" : 'RESULT=<UNDEF>';
    close $fh;
    CHILD

## ctrl-l twice then ctrl-v twice : the last removed line comes back first,
## the earlier one lands below it -- LIFO, and the hint shows once the stack
## holds something
( $result, $exited, $output ) = run_case(
    qw| killstack |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        syswrite $pty, "\x0c";    ## ctrl-l : 'one' onto the stack ##
        $drain->(0.3);
        syswrite $pty, "\x0c";    ## ctrl-l : 'two' onto the stack ##
        $drain->(0.3);
        syswrite $pty, "\x16";    ## ctrl-v : 'two' back above      ##
        $drain->(0.3);
        syswrite $pty, "\x16";    ## ctrl-v : 'one' below it        ##
        $drain->(0.3);
        syswrite $pty, "\x18";
    },
    $child_code_lines
);
check(
    'ctrl-l \ ctrl-v : LIFO kill stack, the hint appears with content',
    $result eq "RESULT=<two\none\nthree>"
        && $exited
        && $output =~ m{ctrl-v paste}
        && $output =~ m{ctrl-y clear}
);

## ctrl-y with an empty stack and no clipboard : nothing moves, the status
## line explains
( $result, $exited, $output ) = run_case(
    qw| ctrlvempty |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        syswrite $pty, "\x16";
        $drain->(0.3);
        syswrite $pty, "\x18";
    },
    $child_code_lines
);
check(
    'ctrl-v with nothing to paste : buffer unchanged, status explains',
    $result eq "RESULT=<one\ntwo\nthree>"
        && $exited
        && $output =~ m{nothing to paste}
);

## ctrl-y empties the kill stack : a later ctrl-v finds nothing to restore
( $result, $exited, $output ) = run_case(
    qw| clearystack |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        syswrite $pty, "\x0c";    ## ctrl-l : 'one' onto the stack ##
        $drain->(0.3);
        syswrite $pty, "\x19";    ## ctrl-y : stack cleared         ##
        $drain->(0.3);
        syswrite $pty, "\x16";    ## ctrl-v : nothing to restore    ##
        $drain->(0.3);
        syswrite $pty, "\x18";
    },
    $child_code_lines
);
my $cleared_at = rindex( $output, 'paste buffer cleared' );
check(
    'ctrl-y empties the kill stack : ctrl-v finds nothing',
    $result eq "RESULT=<two\nthree>"
        && $exited
        && $output                        =~ m{paste buffer cleared}
        && $output                        =~ m{nothing to paste}
        && substr( $output, $cleared_at ) !~ m{ctrl-v paste}
);

## a child with a fake xsel on PATH [ DISPLAY set ] : ctrl-v pastes the
## clipboard as lines above the cursor
my $child_code_clip = <<~'CHILD';
    use strict;
    use warnings;
    use AMOS7::TERM::Editor qw| edit_text |;
    binmode STDOUT, ':utf8';
    my $out     = shift;
    my $fakebin = "$out.fakebin";
    mkdir $fakebin;
    open( my $xf, '>', "$fakebin/xsel" ) or die;
    print $xf "#!/bin/sh\nprintf 'clip1\\nclip2\\n'\n";
    close $xf;
    chmod 0755, "$fakebin/xsel";
    $ENV{'PATH'}    = "$fakebin:$ENV{PATH}";
    $ENV{'DISPLAY'} = ':0';
    { open my $pid_fh, '>', "$out.pid" or die; print $pid_fh $$; }
    my $result = eval {
        edit_text( { text => 'X', title => 'T', label => 'l' } );
    };
    open my $fh, '>:utf8', $out or die;
    print $fh defined $result ? "RESULT=<$result>" : 'RESULT=<UNDEF>';
    close $fh;
    CHILD

( $result, $exited, $output ) = run_case(
    qw| clippaste |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        syswrite $pty, "\x16";
        $drain->(0.5);
        syswrite $pty, "\x18";
    },
    $child_code_clip
);
check(
    'ctrl-v with an empty stack : the clipboard pastes as lines above',
    $result eq "RESULT=<clip1\nclip2\nX>"
        && $exited
        && $output =~ m{pasted from clipboard}
);

## a child whose fake xsel reads a file the parent rewrites mid-run : ctrl-y
## clears the registers -- the cleared clipboard content stays unpasteable,
## changed content re-arms ctrl-v
my $child_code_cleary = <<~'CHILD';
    use strict;
    use warnings;
    use AMOS7::TERM::Editor qw| edit_text |;
    binmode STDOUT, ':utf8';
    my $out     = shift;
    my $fakebin = "$out.fakebin";
    mkdir $fakebin;
    open( my $xf, '>', "$fakebin/xsel" ) or die;
    print $xf "#!/bin/sh\ncat \"\$P7_FAKE_CLIP\"\n";
    close $xf;
    chmod 0755, "$fakebin/xsel";
    $ENV{'P7_FAKE_CLIP'} = "$out.clipcontent";
    open( my $cf, '>', $ENV{'P7_FAKE_CLIP'} ) or die;
    print $cf "v1a\nv1b\n";
    close $cf;
    $ENV{'PATH'}    = "$fakebin:$ENV{PATH}";
    $ENV{'DISPLAY'} = ':0';
    { open my $pid_fh, '>', "$out.pid" or die; print $pid_fh $$; }
    my $result = eval {
        edit_text( { text => 'X', title => 'T', label => 'l' } );
    };
    open my $fh, '>:utf8', $out or die;
    print $fh defined $result ? "RESULT=<$result>" : 'RESULT=<UNDEF>';
    close $fh;
    CHILD

my $clip_file = "$tmp_dir/result.cleary.clipcontent";
( $result, $exited, $output ) = run_case(
    qw| cleary |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        syswrite $pty, "\x16";    ## ctrl-v : clipboard v1 pastes  ##
        $drain->(0.4);
        syswrite $pty, "\x19";    ## ctrl-y : registers cleared    ##
        $drain->(0.4);
        syswrite $pty, "\x16";    ## ctrl-v : same content, no     ##
        $drain->(0.4);
        open( my $cf, '>', $clip_file );
        print {$cf} "v2a\nv2b\n";    ## clipboard content changes     ##
        close $cf;
        syswrite $pty, "\x16";       ## ctrl-v : v2 pastes            ##
        $drain->(0.4);
        syswrite $pty, "\x18";
    },
    $child_code_cleary
);
my $cleared_pos = rindex( $output, 'paste buffer cleared' );
my $v2_pos      = rindex( $output, 'pasted from clipboard' );
check(
    'ctrl-y clears the registers ; a changed clipboard re-arms ctrl-v',
    $result eq "RESULT=<v1a\nv1b\nv2a\nv2b\nX>"
        && $exited
        && $output =~ m{paste buffer cleared}
        && $output =~ m{nothing to paste}
        && $output =~ m{pasted from clipboard}
        && $v2_pos > $cleared_pos
        ## the hint hides after the clear, while the cleared clipboard   ##
        ## content stays unpasteable ; it returns once a new paste lands ##
        && substr( $output, $cleared_pos, $v2_pos - $cleared_pos )
        !~ m{ctrl-v paste}
        && substr( $output, $v2_pos ) =~ m{ctrl-v paste}
);

## the mouse wheel scrolls like the arrow keys : SGR wheel reports move the
## cursor [ down, down, up -> the typed char lands on 'two' ] and the tracking
## DECSETs come on at start, off at exit
( $result, $exited, $output ) = run_case(
    qw| wheel |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        syswrite $pty, "\e[<65;10;5M";    ## wheel down ##
        $drain->(0.3);
        syswrite $pty, "\e[<65;10;5M";    ## wheel down ##
        $drain->(0.3);
        syswrite $pty, "\e[<64;10;5M";    ## wheel up   ##
        $drain->(0.3);
        syswrite $pty, 'X';
        $drain->(0.3);
        syswrite $pty, "\x18";
    },
    $child_code_lines
);
check(
    'mouse wheel : scrolls like the arrows, '
        . 'tracking on at start / off at exit',
    $result eq "RESULT=<one\nXtwo\nthree>"
        && $exited
        && index( $output, "\e[?1000h" ) >= 0
        && rindex( $output, "\e[?1000l" ) > index( $output, "\e[?1000h" )
);

## legacy X10 wheel [ \e[M + 3 bytes ] moves the cursor the same way
( $result, $exited, $output ) = run_case(
    qw| wheelx10 |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        syswrite $pty, "\e[M" . chr( 32 + 65 ) . chr(42) . chr(37);
        $drain->(0.3);
        syswrite $pty, 'X';
        $drain->(0.3);
        syswrite $pty, "\x18";
    },
    $child_code_lines
);
check(
    'mouse wheel : legacy X10 reports scroll too',
    $result eq "RESULT=<one\nXtwo\nthree>" && $exited
);

## plain clicks never become text : an SGR press+release pair and an X10 click
## land on the chrome here [ header rows ], stay inert, and typing right after
## stays clean -- real positioning is covered by clickpos \ clickinert below
( $result, $exited, $output ) = run_case(
    qw| click |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        syswrite $pty, "\e[<0;5;3M";    ## SGR press   ##
        $drain->(0.3);
        syswrite $pty, "\e[<0;5;3m";    ## SGR release ##
        $drain->(0.3);
        syswrite $pty, "\e[M" . chr(32) . chr(42) . chr(36);   ## X10 click ##
        $drain->(0.3);
        syswrite $pty, 'Z';
        $drain->(0.3);
        syswrite $pty, "\x18";
    }
);
check( 'mouse clicks on the chrome : eaten, never become text',
    $result eq "RESULT=<Zseed>" && $exited );

## the tty goes away : the editor must end, not spin ##
( $result, $exited ) = run_case(
    qw| eof |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        syswrite $pty, 'x';
        $drain->(0.3);
        close $pty;
    }
);
check(
    'closed tty : editor aborts instead of spinning',
    $exited && $result eq 'RESULT=<UNDEF>'
);

## suspend \ continue : the shell gets a cooked tty, raw mode comes back ##
my ( $state_stopped, $flags_stopped, $flags_continued ) = ( '', '', '' );
( $result, $exited ) = run_case(
    qw| tstp |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        my $tty = $pty->ttyname;
        kill 'TSTP', $pid;
        $drain->(0.4);
        ( $state_stopped = qx|ps -o stat= -p $pid| ) =~ s{\s}{}g;
        system("stty sane < $tty");    ## a shell takes the tty back ##
        $flags_stopped = tty_flags($tty);
        kill 'CONT', $pid;
        $drain->(0.6);
        $flags_continued = tty_flags($tty);
        syswrite $pty, 'Z';
        $drain->(0.3);
        syswrite $pty, "\x18";
    }
);
check( 'suspend : editor stops',         $state_stopped =~ m{^T} );
check( 'continue : raw mode taken back', $flags_continued eq '-icanon' );
check(
    'continue : typing lands, save works',
    $result eq 'RESULT=<Zseed>' && $exited
);

## ctrl-c abort : the cursor shape set on entry is reset  the ctrl-c only ##
## once the editor's frame is up : sent earlier it may arrive while the   ##
## child still compiles [ cooked tty, ISIG on ] and the default SIGINT    ##
## would kill perl before the editor's handlers exist                     ##
( $result, $exited, $output ) = run_case(
    qw| abort |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        $drain->( 5, qr|ctrl-x save\+quit| );
        syswrite $pty, "\x03";
    }
);
check( 'ctrl-c abort : returns undef', $result eq 'RESULT=<UNDEF>' );
check( 'ctrl-c abort : cursor shape reset',
    rindex( $output, "\e[0 q" ) > rindex( $output, "\e[4 q" ) );

## ctrl-s [ alias ctrl-o ] : on_save gets the normalized buffer, the editor ##
## keeps running and advertises the save key                                ##
( $result, $exited, $output ) = run_case(
    qw| save |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        syswrite $pty, 'abc';
        $drain->(0.3);
        syswrite $pty, "\x13";    ## ctrl-s save ##
        $drain->(0.5);
        syswrite $pty, 'def';
        $drain->(0.3);
        syswrite $pty, "\x0f";    ## ctrl-o alias ##
        $drain->(0.5);
        syswrite $pty, "\x18";    ## ctrl-x quit ##
    },
    $child_code_save
);
my $saves = read_file("$tmp_dir/result.save.saves");
check(
    'ctrl-s + ctrl-o : on_save got each snapshot, editor kept running',
    $result eq 'RESULT=<abcdefseed>'
        && $exited
        && $saves eq "SAVE=<abcseed>\nSAVE=<abcdefseed>\n"
        && $output =~ m{· saved ·}
        && $output =~ m{ctrl-s save}
);

## a failing on_save : the failure shows [ false return and die ], the ##
## editor keeps running and ctrl-x still returns the buffer            ##
( $result, $exited, $output ) = run_case(
    qw| savefail |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        syswrite $pty, 'FAILME';
        $drain->(0.3);
        syswrite $pty, "\x13";    ## callback returns false ##
        $drain->(0.5);
        syswrite $pty, 'DIEME';
        $drain->(0.3);
        syswrite $pty, "\x13";    ## callback dies ##
        $drain->(0.5);
        syswrite $pty, 'X';
        $drain->(0.3);
        syswrite $pty, "\x18";
    },
    $child_code_save
);
$saves = read_file("$tmp_dir/result.savefail.saves");
check(
    'failing on_save : failure shown, editor kept running',
    $result eq 'RESULT=<FAILMEDIEMEXseed>'
        && $exited
        && $saves eq "SAVE=<FAILMEseed>\nSAVE=<FAILMEDIEMEseed>\n"
        && $output =~ m{save failed : save callback returned false}
        && $output =~ m{save failed : boom : refused}
        && $output !~ m{· saved ·}
);

## without on_save : the save keys never claim 'saved', the hint points at ##
## ctrl-x                                                                  ##
( $result, $exited, $output ) = run_case(
    qw| nosave |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        syswrite $pty, "\x13";
        $drain->(0.5);
        syswrite $pty, "\x0f";
        $drain->(0.5);
        syswrite $pty, "\x18";
    }
);
check(
    'no on_save : no saved claim, hint points at ctrl-x',
    $result eq 'RESULT=<seed>'
        && $exited
        && $output =~ m{no save target -- ctrl-x saves \+ quits}
        && $output !~ m{· saved ·}
        && $output !~ m{ctrl-s save}
        && $output !~ m{ctrl-o save}
);

## pgup \ pgdn : a 30-line seed on a 30x100 pty shows 22 content rows, so one
## page-down lands the cursor on line 22 [ 0-based ] ; the down page stops at
## the last line instead of growing one ; page-up walks a page back, from the
## top it stays
my $thirty_lines = join( "\n", map { sprintf 'l%02d', $_ } 1 .. 30 );

my $child_code_pages = <<~"CHILD";
    use strict;
    use warnings;
    use AMOS7::TERM::Editor qw| edit_text |;
    binmode STDOUT, ':utf8';
    my \$out = shift;
    { open my \$pid_fh, '>', "\$out.pid" or die; print \$pid_fh \$\$; }
    my \$result = eval {
        edit_text( { text => '$thirty_lines', title => 'T', label => 'l' } );
    };
    open my \$fh, '>:utf8', \$out or die;
    print \$fh defined \$result ? "RESULT=<\$result>" : 'RESULT=<UNDEF>';
    close \$fh;
    CHILD

my @paged = split "\n", $thirty_lines;

( $result, $exited ) = run_case(
    qw| pgdn |,
    sub {
        my ($pty) = @ARG;
        syswrite $pty, "\e[6~";    ## page down ##
        select( undef, undef, undef, 0.3 );
        syswrite $pty, 'X';
        select( undef, undef, undef, 0.3 );
        syswrite $pty, "\x18";
    },
    $child_code_pages
);
$paged[22] = 'X' . $paged[22];
my $expected = 'RESULT=<' . ( join "\n", @paged ) . '>';
check( 'pgdn : one page down lands the cursor a content-height away',
    $result eq $expected && $exited );

( $result, $exited ) = run_case(
    qw| pgstop |,
    sub {
        my ($pty) = @ARG;
        syswrite $pty, "\e[6~";    ## page down twice : clamps at EOF ##
        select( undef, undef, undef, 0.3 );
        syswrite $pty, "\e[6~";
        select( undef, undef, undef, 0.3 );
        syswrite $pty, "\e[5~";    ## page back up one page ##
        select( undef, undef, undef, 0.3 );
        syswrite $pty, 'X';
        select( undef, undef, undef, 0.3 );
        syswrite $pty, "\x18";
    },
    $child_code_pages
);
@paged    = split "\n", $thirty_lines;
$paged[7] = 'X' . $paged[7];
$expected = 'RESULT=<' . ( join "\n", @paged ) . '>';
check( 'pgdn stops at the last line, pgup walks a page back [ 29 - 22 = 7 ]',
    $result eq $expected && $exited );

( $result, $exited ) = run_case(
    qw| pguphome |,
    sub {
        my ($pty) = @ARG;
        syswrite $pty, "\e[5~";    ## page up from home stays at home ##
        select( undef, undef, undef, 0.3 );
        syswrite $pty, 'X';
        select( undef, undef, undef, 0.3 );
        syswrite $pty, "\x18";
    },
    $child_code_pages
);
$expected = 'RESULT=<X' . $thirty_lines . '>';
check( 'pgup from the top stays', $result eq $expected && $exited );

## left click : a press positions the cursor by the content geometry
## [ text starts at terminal col 4, content row 1 is row 5 ] ; chrome clicks
## and release events stay inert
( $result, $exited ) = run_case(
    qw| clickpos |,
    sub {
        my ($pty) = @ARG;
        syswrite $pty, "\e[<0;6;16M";    ## press col 6, row 16 ##
        select( undef, undef, undef, 0.3 );
        syswrite $pty, 'X';
        select( undef, undef, undef, 0.3 );
        syswrite $pty, "\x18";
    },
    $child_code_pages
);
@paged = split "\n", $thirty_lines;
substr( $paged[11], 2, 0, 'X' );    ## line 11, col 2 ##
$expected = 'RESULT=<' . ( join "\n", @paged ) . '>';
check( 'left click positions the cursor [ line 11, col 2 ]',
    $result eq $expected && $exited );

( $result, $exited ) = run_case(
    qw| clickinert |,
    sub {
        my ($pty) = @ARG;
        syswrite $pty, "\e[<0;3;1M";     ## press on the header ##
        select( undef, undef, undef, 0.2 );
        syswrite $pty, "\e[<0;6;16m";    ## release elsewhere  ##
        select( undef, undef, undef, 0.2 );
        syswrite $pty, 'X';
        select( undef, undef, undef, 0.3 );
        syswrite $pty, "\x18";
    },
    $child_code_pages
);
$expected = 'RESULT=<X' . $thirty_lines . '>';
check( 'clicks on the chrome and release events change nothing',
    $result eq $expected && $exited );

## wheel acceleration on a 30x100 pty [ content height 22 ] on a NON-LINEAR
## curve : spaced ticks stay line-per-tick ; a medium roll pays nothing for
## its first four ticks [ short rolls stay relative ], the fifth tick ramps to
## a page ; a fast burst collapses to one page.  the payout lands after the
## wheel pauses, so every case waits out the window before typing
( $result, $exited ) = run_case(
    qw| wheelslow |,
    sub {
        my ($pty) = @ARG;
        for ( 1 .. 3 ) {
            syswrite $pty, "\e[<65;10;10M";         ## wheel down ##
            select( undef, undef, undef, 0.26 );    ## > window ##
        }
        select( undef, undef, undef, 0.35 );
        syswrite $pty, 'X';
        select( undef, undef, undef, 0.3 );
        syswrite $pty, "\x18";
    },
    $child_code_pages
);
@paged = split "\n", $thirty_lines;
substr( $paged[3], 0, 0, 'X' );
$expected = 'RESULT=<' . ( join "\n", @paged ) . '>';
check( 'wheel slow : three spaced ticks stay line-per-tick',
    $result eq $expected && $exited );

( $result, $exited ) = run_case(
    qw| wheelsmall |,
    sub {
        my ($pty) = @ARG;
        for ( 1 .. 4 ) {
            syswrite $pty, "\e[<65;10;10M";
            select( undef, undef, undef, 0.13 );    ## inside the window ##
        }
        select( undef, undef, undef, 0.35 );        ## window asserts    ##
        syswrite $pty, 'X';
        select( undef, undef, undef, 0.3 );
        syswrite $pty, "\x18";
    },
    $child_code_pages
);
@paged = split "\n", $thirty_lines;
substr( $paged[4], 0, 0, 'X' );    ## four ticks : relative, no page ##
$expected = 'RESULT=<' . ( join "\n", @paged ) . '>';
check( 'wheel medium, short roll : four ticks stay relative [ no page ]',
    $result eq $expected && $exited );

( $result, $exited ) = run_case(
    qw| wheelmedium |,
    sub {
        my ($pty) = @ARG;
        for ( 1 .. 5 ) {
            syswrite $pty, "\e[<65;10;10M";
            select( undef, undef, undef, 0.13 );    ## inside the window ##
        }
        select( undef, undef, undef, 0.35 );        ## window asserts    ##
        syswrite $pty, 'X';
        select( undef, undef, undef, 0.3 );
        syswrite $pty, "\x18";
    },
    $child_code_pages
);
@paged = split "\n", $thirty_lines;
substr( $paged[27], 0, 0, 'X' );    ## 5 lines + 1 page of 22 ##
$expected = 'RESULT=<' . ( join "\n", @paged ) . '>';
check( 'wheel medium, full roll : five ticks pay one page on assert',
    $result eq $expected && $exited );

( $result, $exited ) = run_case(
    qw| wheelfast |,
    sub {
        my ($pty) = @ARG;
        for ( 1 .. 6 ) {
            syswrite $pty, "\e[<65;10;10M";
            select( undef, undef, undef, 0.04 );    ## fast gaps ##
        }
        select( undef, undef, undef, 0.35 );
        syswrite $pty, 'X';
        select( undef, undef, undef, 0.3 );
        syswrite $pty, "\x18";
    },
    $child_code_pages
);
@paged = split "\n", $thirty_lines;
substr( $paged[28], 0, 0, 'X' );    ## 6 lines + 1 collapsed page ##
$expected = 'RESULT=<' . ( join "\n", @paged ) . '>';
check( 'wheel fast : a six-tick burst collapses to one page',
    $result eq $expected && $exited );

## a wheel tick at EOF moves nothing : the redraw gate must skip the repaint,
## so the whole session carries exactly one clear-screen
( $result, $exited, $output ) = run_case(
    qw| wheeleof |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        $drain->(0.3);
        syswrite $pty, "\e[<65;10;10M";    ## wheel down at the last line ##
        $drain->(0.6);
        syswrite $pty, "\x18";
    }
);
my $clears = () = $output =~ m{\e\[2J}g;
check(
    'wheel at EOF : no movement, no repaint [ one clear total ]',
    $result eq 'RESULT=<seed>' && $exited && $clears == 1
);

## the kill register restores in two disciplines : ctrl-v LIFO, ctrl+.
## [ \x0e or CSI-u ] oldest-first so kills rebuild their original order ; \x1c
## \ \e[44;5u kill where the terminal gives ctrl-, its own byte ; an empty
## register says so
( $result, $exited, $output ) = run_case(
    qw| restoreorder |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        syswrite $pty, "\x0c";    ## kill one ##
        $drain->(0.3);
        syswrite $pty, "\x0c";    ## kill two ##
        $drain->(0.3);
        syswrite $pty, "\x0e";    ## restore in order : one ##
        $drain->(0.3);
        syswrite $pty, "\x0e";    ## then two : original order ##
        $drain->(0.3);
        syswrite $pty, 'X';
        $drain->(0.3);
        syswrite $pty, "\x18";
    },
    $child_code_lines
);
check( 'ctrl+. restores oldest-first : kills rebuild the original order',
    $result eq "RESULT=<one\nXtwo\nthree>" && $exited );

## the user's scenario : truncate a tail
## [ click to line 3, kill three lines to EOF ] then ctrl+. the tail back --
## the run appends after the line it followed, nothing reorders
( $result, $exited ) = run_case(
    qw| tailrestore |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        syswrite $pty, "\e[<0;4;8M";    ## click line 3, col 0 ##
        $drain->(0.3);
        syswrite $pty, "\x1c" for 1 .. 3;    ## truncate to EOF ##
        $drain->(0.4);
        syswrite $pty, "\x0e" for 1 .. 3;    ## restore the tail ##
        $drain->(0.4);
        syswrite $pty, 'X';
        $drain->(0.3);
        syswrite $pty, "\x18";
    },
    $child_code_pages
);
@paged = split "\n", $thirty_lines;
substr( $paged[5], 0, 0, 'X' );    ## cursor follows onto the tail ##
$expected = 'RESULT=<' . ( join "\n", @paged ) . '>';
check( 'truncated tail restores in place : no line reorders',
    $result eq $expected && $exited );

## bottom-up truncation : click the LAST line, kill up the file, then restore
## -- the tail rebuilds in the ORIGINAL order, not the kill order
## [ no upside-down tail ]
my $six_lines      = "a\nb\nc\nd\ne\nf";
my $child_code_six = <<~"CHILD";
    use strict;
    use warnings;
    use AMOS7::TERM::Editor qw| edit_text |;
    binmode STDOUT, ':utf8';
    my \$out = shift;
    { open my \$pid_fh, '>', "\$out.pid" or die; print \$pid_fh \$\$; }
    my \$result = eval {
        edit_text( { text => '$six_lines', title => 'T', label => 'l' } );
    };
    open my \$fh, '>:utf8', \$out or die;
    print \$fh defined \$result ? "RESULT=<\$result>" : 'RESULT=<UNDEF>';
    close \$fh;
    CHILD

( $result, $exited ) = run_case(
    qw| bottomup |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        syswrite $pty, "\e[<0;4;10M";    ## click line 5, col 0 ##
        $drain->(0.3);
        syswrite $pty, "\x1c" for 1 .. 3;    ## kills f, e, d ##
        $drain->(0.4);
        syswrite $pty, "\x0e" for 1 .. 3;    ## restore d, e, f ##
        $drain->(0.4);
        syswrite $pty, 'X';
        $drain->(0.3);
        syswrite $pty, "\x18";
    },
    $child_code_six
);
check(
    'bottom-up truncated tail restores in the original order',
    $result eq "RESULT=<a\nb\nc\nd\ne\nXf>" && $exited
);

## blank lines are file content : the ordered register keeps them, so a kill
## run over a blank rebuilds the exact text -- dropping the blank collapsed
## the gap and the next restore landed one line early
my $child_code_blank = <<~'CHILD';
    use strict;
    use warnings;
    use AMOS7::TERM::Editor qw| edit_text |;
    binmode STDOUT, ':utf8';
    my $out = shift;
    { open my $pid_fh, '>', "$out.pid" or die; print $pid_fh $$; }
    my $result = eval {
        edit_text( { text => "a\nb\nc\nd\n\ne\nf", title => 'T',
            label => 'l' } );
    };
    open my $fh, '>:utf8', $out or die;
    print $fh defined $result ? "RESULT=<$result>" : 'RESULT=<UNDEF>';
    close $fh;
    CHILD

( $result, $exited ) = run_case(
    qw| blankup |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        syswrite $pty, "\e[<0;4;11M";    ## click line 6 [ f ], col 0 ##
        $drain->(0.3);
        syswrite $pty, "\x1c" for 1 .. 3;    ## kills f, blank, e ##
        $drain->(0.4);
        syswrite $pty, "\x0e" for 1 .. 3;
        $drain->(0.4);
        syswrite $pty, 'X';
        $drain->(0.3);
        syswrite $pty, "\x18";
    },
    $child_code_blank
);
check(
    'bottom-up kill over a blank restores the exact text',
    $result eq "RESULT=<a\nb\nc\nd\n\ne\nXf>" && $exited
);

( $result, $exited ) = run_case(
    qw| blankdown |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        syswrite $pty, "\e[<0;4;8M";    ## click line 3 [ d ], col 0 ##
        $drain->(0.3);
        syswrite $pty, "\x1c" for 1 .. 3;    ## kills d, blank, e ##
        $drain->(0.4);
        syswrite $pty, "\x0e" for 1 .. 3;
        $drain->(0.4);
        syswrite $pty, 'X';
        $drain->(0.3);
        syswrite $pty, "\x18";
    },
    $child_code_blank
);
check(
    'top-down kill over a blank restores the exact text',
    $result eq "RESULT=<a\nb\nc\nd\n\nXe\nf>" && $exited
);

( $result, $exited ) = run_case(
    qw| legacykill |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        syswrite $pty, "\x1c";    ## legacy ctrl-, byte ##
        $drain->(0.3);
        syswrite $pty, "\x0e";
        $drain->(0.3);
        syswrite $pty, 'X';
        $drain->(0.3);
        syswrite $pty, "\x18";
    },
    $child_code_lines
);
check(
    'ctrl-, legacy \x1c kills into the same register',
    $result eq "RESULT=<Xone\ntwo\nthree>" && $exited
);

( $result, $exited ) = run_case(
    qw| csiukill |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        syswrite $pty, "\e[44;5u";    ## CSI-u ctrl-, ##
        $drain->(0.3);
        syswrite $pty, "\e[46;5u";    ## CSI-u ctrl+. ##
        $drain->(0.3);
        syswrite $pty, 'X';
        $drain->(0.3);
        syswrite $pty, "\x18";
    },
    $child_code_lines
);
check(
    'CSI-u ctrl-, \ ctrl+. kill and restore',
    $result eq "RESULT=<Xone\ntwo\nthree>" && $exited
);

( $result, $exited, $output ) = run_case(
    qw| restoreempty |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        syswrite $pty, "\x0e";    ## nothing to restore ##
        $drain->(0.4);
        syswrite $pty, 'X';
        $drain->(0.3);
        syswrite $pty, "\x18";
    },
    $child_code_lines
);
check(
    'ctrl+. on an empty register restores nothing and says so',
    $result eq "RESULT=<Xone\ntwo\nthree>"
        && $exited
        && $output =~ m{nothing to restore}
);

## modifyOtherKeys=1 [ XTMODKEYS ] : the editor enables it while open
## [ ctrl-. ctrl-, arrive as CSI-u ] and disables it on every exit
( $result, $exited, $output ) = run_case(
    qw| modkeys |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        $drain->(0.3);
        syswrite $pty, "\x18";
    }
);
check(
    'modifyOtherKeys enabled while open, disabled on exit',
    $exited
        && index( $output, "\e[>4;1m" ) >= 0
        && index( $output, "\e[>4;0m" ) >= 0
);

## an env-seeded child [ hermetic ] : the seed text and the wrap flag come
## from the environment so each case drives its own geometry
my $child_code_seed = <<~'CHILD';
    use strict;
    use warnings;
    use AMOS7::TERM::Editor qw| edit_text |;
    binmode STDOUT, ':utf8';
    $ENV{'P7_EDITOR_NO_CLIP'} = 1;
    my $out = shift;
    { open my $pid_fh, '>', "$out.pid" or die; print $pid_fh $$; }
    my $result = eval {
        edit_text( { text => $ENV{'SEED'} // 'seed', title => 'T',
            label => 'l', wrap => $ENV{'WRAP'} ? 1 : 0,
            wrap_sep   => ( $ENV{'WRAP_SEP'}   // 1 ),
            wrap_words => ( $ENV{'WRAP_WORDS'} // 1 ) } );
    };
    open my $fh, '>:utf8', $out or die;
    print $fh defined $result ? "RESULT=<$result>" : 'RESULT=<UNDEF>';
    close $fh;
    CHILD

## wrap mode [ 100-col pty -> vw 94 ] : a 150-char line folds into a head row
## and a continuation row carrying the dim wrap marker, the shorter lines
## render normally and the buffer roundtrips untouched [ view-only wrap ]
{
    local $ENV{'SEED'} = "head\n" . ( 'a' x 150 ) . "\ntail";
    local $ENV{'WRAP'} = 1;
    ( $result, $exited, $output ) = run_case(
        qw| wraprender |,
        sub {
            my ( $pty, $pid, $drain ) = @ARG;
            $drain->(0.3);
            syswrite $pty, "\x18";
        },
        $child_code_seed
    );
}
my $visible = $output;
$visible =~ s{\e\[[0-9;?]*[A-Za-z]}{}g;
check(
    'wrap mode : long line folds, continuation marker under the colon',
    $result eq "RESULT=<head\n" . ( 'a' x 150 ) . "\ntail>"
        && $exited
        && $visible =~ m|^:\xe2\x94\x8a a{20}|m
);

## wrap mode : end-of-line on a 150-char line puts the cursor on the second
## visual row at in-segment offset 56 [ row 6, col 60 on the 100-col pty ]
{
    local $ENV{'SEED'} = 'a' x 150;
    local $ENV{'WRAP'} = 1;
    ( $result, $exited, $output ) = run_case(
        qw| wrapcursor |,
        sub {
            my ( $pty, $pid, $drain ) = @ARG;
            $drain->(0.3);
            syswrite $pty, "\e[F";    ## end ##
            $drain->(0.4);
            syswrite $pty, "\x18";
        },
        $child_code_seed
    );
}
my @cursor_pos = $output =~ m{\e\[([0-9]+);([0-9]+)H\e\[\?25h}g;
check(
    'wrap mode : hardware cursor lands on the continuation row',
    $exited
        && grep( $cursor_pos[ $_ * 2 ] == 6
            && $cursor_pos[ $_ * 2 + 1 ] == 60,
        0 .. ( $#cursor_pos / 2 ) )
);

## wrap mode : pgdn pages by visual rows -- 30 lines of 150 chars fold into 60
## rows ; one page lands on line 11 [ row 26, col 4 ] and the buffer
## roundtrips
{
    local $ENV{'SEED'} = join( "\n", ( 'a' x 150 ) x 30 );
    local $ENV{'WRAP'} = 1;
    ( $result, $exited, $output ) = run_case(
        qw| wrappgdn |,
        sub {
            my ( $pty, $pid, $drain ) = @ARG;
            $drain->(0.3);
            syswrite $pty, "\e[6~";    ## pgdn ##
            $drain->(0.4);
            syswrite $pty, "\x18";
        },
        $child_code_seed
    );
}
@cursor_pos = $output =~ m{\e\[([0-9]+);([0-9]+)H\e\[\?25h}g;
check(
    'wrap mode : pgdn pages by visual rows, buffer roundtrips',
    $result eq 'RESULT=<'
        . join( "\n", ( 'a' x 150 ) x 30 )
        . '>'
        && $exited
        && grep( $cursor_pos[ $_ * 2 ] == 26
            && $cursor_pos[ $_ * 2 + 1 ] == 4,
        0 .. ( $#cursor_pos / 2 ) )
);

## wrap mode : a wrapped block is followed by a dim dotted separator row, and
## the separator counts as a visual row -- the cursor on the line after a
## wrapped block lands one row lower than the bare fold math
## [ pin 9,60 with separators, 8,60 without ] ; the buffer roundtrips
{
    local $ENV{'SEED'} = ( 'a' x 150 ) . "\n" . ( 'b' x 150 );
    local $ENV{'WRAP'} = 1;
    ( $result, $exited, $output ) = run_case(
        qw| wrapsep |,
        sub {
            my ( $pty, $pid, $drain ) = @ARG;
            $drain->(0.3);
            syswrite $pty, "\e[B";    ## down to line 2 ##
            $drain->(0.3);
            syswrite $pty, "\e[F";    ## end ##
            $drain->(0.4);
            syswrite $pty, "\x18";
        },
        $child_code_seed
    );
}
my $vis_sep = $output;
$vis_sep =~ s{\e\[[0-9;?]*[A-Za-z]}{}g;
@cursor_pos = $output =~ m{\e\[([0-9]+);([0-9]+)H\e\[\?25h}g;
check(
    'wrap mode : dotted separator row '
        . 'after a wrapped block, cursor counts it',
    $result eq 'RESULT=<'
        . ( 'a' x 150 ) . "\n"
        . ( 'b' x 150 )
        . '>'
        && $exited
        && $vis_sep =~ m|^:(?:\xe2\x94\x84){20}|m
        && grep( $cursor_pos[ $_ * 2 ] == 9
            && $cursor_pos[ $_ * 2 + 1 ] == 60,
        0 .. ( $#cursor_pos / 2 ) )
);

## wrap mode : a wrapped block followed by a BLANK line collapses the pair
## into ONE gap row -- the blank renders AS the dotted separator
## [ trailing the prior box ], not an empty row stacked behind a drawn one ;
## the hardware cursor on the line after the blank walks the same accounting
## [ row 8 with the collapse, 9 with a drawn separator + empty row ]
{
    local $ENV{'SEED'} = ( 'a' x 150 ) . "\n\ntail";
    local $ENV{'WRAP'} = 1;
    ( $result, $exited, $output ) = run_case(
        qw| wrapblank |,
        sub {
            my ( $pty, $pid, $drain ) = @ARG;
            $drain->(0.3);
            syswrite $pty, "\e[B";    ## onto the blank ##
            $drain->(0.2);
            syswrite $pty, "\e[B";    ## onto 'tail'  ##
            $drain->(0.3);
            syswrite $pty, "\x18";
        },
        $child_code_seed
    );
}
my $vis_blank = $output;
$vis_blank =~ s{\e\[[0-9;?]*[A-Za-z]}{}g;
@cursor_pos = $output =~ m{\e\[([0-9]+);([0-9]+)H\e\[\?25h}g;
check(
    'wrap mode : a blank after a wrapped '
        . 'block IS the separator, not a second gap',
    $result eq 'RESULT=<'
        . ( 'a' x 150 )
        . "\n\ntail>"
        && $exited
        && $vis_blank =~ m|^:(?:\xe2\x94\x84){20}[^\n]*\n:  tail|m
        && grep( $cursor_pos[ $_ * 2 ] == 8 && $cursor_pos[ $_ * 2 + 1 ] == 4,
        0 .. ( $#cursor_pos / 2 ) )
);

## wrap mode : the blank-as-separator rule plus the CLAMPED vertical cursor --
## arrowing onto the blank from a far column now clamps the column to the
## blank's length [ the horizontal offset never  propagates ], so the blank
## stays the single dotted row, the hardware cursor sits at 7;4
## [ 7;60 while padding still propagated the offset ], nothing phantom ever
## renders, and the collapse restores on leave
{
    local $ENV{'SEED'} = ( 'a' x 150 ) . "\n\ntail";
    local $ENV{'WRAP'} = 1;
    ( $result, $exited, $output ) = run_case(
        qw| wrapblankpad |,
        sub {
            my ( $pty, $pid, $drain ) = @ARG;
            $drain->(0.3);
            syswrite $pty, "\e[F";    ## end of the long line [ 150 ] ##
            $drain->(0.2);
            syswrite $pty, "\e[B";    ## down onto the blank         ##
            $drain->(0.3);
            syswrite $pty, "\e[B\e[H";    ## 'tail', home [ col 0 ]     ##
            $drain->(0.3);
            syswrite $pty, "\x18";
        },
        $child_code_seed
    );
}
my @pad_frames = split m{\e\[H\e\[2J}, $output, -1;
my $mid_frame  = $pad_frames[-2] // '';
$mid_frame =~ s{\e\[[0-9;?]*[A-Za-z]}{}g;
my $end_frame = $pad_frames[-1] // '';
$end_frame =~ s{\e\[[0-9;?]*[A-Za-z]}{}g;
my $mid_seps = () = $mid_frame =~ m|^:(?:\xe2\x94\x84){20}|mg;
@cursor_pos = $output =~ m{\e\[([0-9]+);([0-9]+)H\e\[\?25h}g;
check(
    'wrap mode : a blank the cursor passes through stays '
        . 'the separator [ column clamps, nothing phantom ]',
    $result eq 'RESULT=<' . ( 'a' x 150 ) . "\n\ntail>"
        && $exited
        && $mid_seps == 1
        ## the pass clamps the column : 7;4 lands, 7;60 must not
        && grep( $cursor_pos[ $_ * 2 ] == 7 && $cursor_pos[ $_ * 2 + 1 ] == 4,
        0 .. ( $#cursor_pos / 2 ) )
        && !
        grep( $cursor_pos[ $_ * 2 ] == 7 && $cursor_pos[ $_ * 2 + 1 ] == 60,
        0 .. ( $#cursor_pos / 2 ) )
        && grep( $cursor_pos[ $_ * 2 ] == 8 && $cursor_pos[ $_ * 2 + 1 ] == 4,
        0 .. ( $#cursor_pos / 2 ) )
        && $output    !~ m|^:\xe2\x94\x8a[ ]+:$|m
        && $end_frame =~ m|^:(?:\xe2\x94\x84){20}[^\n]*\n:  tail|m
);

## wrap mode : trailing blanks + the clamped cursor + NO growth at EOF.
## Arrowing onto the trailing blanks clamps the column to their length
## [ no phantom wrapped runs of padding, no 'variable box' ], and arrow-down
## ON THE LAST LINE is a no-op [ it used to append a whitespace line per press
## -- a final section growing past the file ].  The cursor stops at 9;4 ; a
## fourth \e[B adds no frame at all, the roundtrip is untouched, and exactly
## the one dotted row renders.
{
    local $ENV{'SEED'} = ( 'a' x 150 ) . "\n\n\n";
    local $ENV{'WRAP'} = 1;
    ( $result, $exited, $output ) = run_case(
        qw| wraptailpad |,
        sub {
            my ( $pty, $pid, $drain ) = @ARG;
            $drain->(0.3);
            syswrite $pty, "\e[F";    ## end of the long line [ 150 ] ##
            $drain->(0.2);
            syswrite $pty, "\e[B" x 4;    ## across the blanks + past EOF ##
            $drain->(0.4);
            syswrite $pty, "\x18";
        },
        $child_code_seed
    );
}
my @tail_frames = split m{\e\[H\e\[2J}, $output, -1;
my $tail_frame  = $tail_frames[-1] // '';
$tail_frame =~ s{\e\[[0-9;?]*[A-Za-z]}{}g;
my $tail_seps = () = $tail_frame =~ m|^:(?:\xe2\x94\x84){20}|mg;
@cursor_pos = $output =~ m{\e\[([0-9]+);([0-9]+)H\e\[\?25h}g;
check(
    'wrap mode : trailing blanks stay single rows, '
        . 'down at EOF does not grow a final section',
    $result eq 'RESULT=<' . ( 'a' x 150 ) . '>'
        && $exited
        ## no phantom continuation row [ ┊ then only spaces ] anywhere
        && $output !~ m|^:\xe2\x94\x8a[ ]+:$|m
        ## exactly the ONE separator [ the first trailing blank's ] in the
        ## final frame
        && $tail_seps == 1
        ## the cursor walks the blanks clamped and STOPS : exactly five
        ## movement pairs [ initial, end, three downs ] -- the fourth \e[B
        ## moved nothing [ the exit cursor reposition is row 30 ]
        && scalar(
        grep { $cursor_pos[ $_ * 2 ] < 30 } 0 .. ( $#cursor_pos / 2 )
        ) == 5
        && grep( $cursor_pos[ $_ * 2 ] == 9 && $cursor_pos[ $_ * 2 + 1 ] == 4,
        0 .. ( $#cursor_pos / 2 ) )
);

## WINCH reflow : the user confirmed this by eye at miniature sizes -- a
## 150-char line on a 100-col pty folds into 2 rows with the cursor on the
## second [ 6;60 ] ; shrink the pty to 60 cols mid-edit and the SAME buffer
## refolds into 3 rows [ vw 54 : 54+54+42 ] with the cursor on the third at
## in-segment col 42 -> 7;46 ; the frame redraws at the new width and the
## buffer roundtrips raw [ wrapping is view-only ].  the harness delivers
## WINCH explicitly : a setsid'd child has no controlling tty, so the kernel
## would not generate it for the pty -- on a real terminal the resize delivers
## it [ user-verified ]
{
    local $ENV{'SEED'} = 'a' x 150;
    local $ENV{'WRAP'} = 1;
    ( $result, $exited, $output ) = run_case(
        qw| wrapwinch |,
        sub {
            my ( $pty, $pid, $drain ) = @ARG;
            $drain->(0.3);
            syswrite $pty, "\e[F";    ## end, col 150 ##
            $drain->(0.3);
            $pty->set_winsize( 30, 60 ) if $pty->can('set_winsize');
            kill 'WINCH', $pid;
            $drain->(0.8);
            syswrite $pty, "\x18";
        },
        $child_code_seed
    );
}
my @winch_frames = split m{\e\[H\e\[2J}, $output, -1;
my $winch_frame  = $winch_frames[-1] // '';
## normalize to display columns : strip every SGR form incl. the '>' private
## sequences and the space-separated DECSCUSR / cleanup forms, drop CR, and
## swap 1-byte stand-ins for the multibyte glyphs and the middle dot
## [ byte-string regexes ]
$winch_frame =~ s{\e\[[0-9;?>]* ?[A-Za-z]}{}g;
$winch_frame =~ s{\r}{}g;
$winch_frame =~ s{\xe2\x94\x8a}{|}g;
$winch_frame =~ s{\xe2\x94\x84}{-}g;
$winch_frame =~ s{\xc2\xb7}{.}g;
@cursor_pos = $output =~ m{\e\[([0-9]+);([0-9]+)H\e\[\?25h}g;
check(
    'wrap mode : WINCH reflows the fold, cursor follows the segment',
    $result eq 'RESULT=<' . ( 'a' x 150 ) . '>'
        && $exited
        ## the resized frame is exactly 60 columns wide, never wider
        && $winch_frame !~ m|^.{61,}$|m
        && $winch_frame =~ m|^.{60}$|m
        ## before : cursor on the 2nd row of 2 [ 6;60 ]
        && grep( $cursor_pos[ $_ * 2 ] == 6
            && $cursor_pos[ $_ * 2 + 1 ] == 60,
        0 .. ( $#cursor_pos / 2 ) )
        ## after : cursor on the 3rd row of 3 at col 46
        && grep( $cursor_pos[ $_ * 2 ] == 7
            && $cursor_pos[ $_ * 2 + 1 ] == 46,
        0 .. ( $#cursor_pos / 2 ) )
);

## delete repaints EVERY press : the redraw gate used to key on a boolean
## dirty flag plus the cursor position -- delete never moves the cursor, so
## the second press repeated the frame signature and skipped the redraw while
## the buffer DID change. '$dirty' is now a buffer revision
## [ ++ at every mutation, 0 on save ], so every edit repaints : three deletes
## on 'abc' from home paint three frames and leave an empty buffer
{
    local $ENV{'SEED'} = 'abc';
    local $ENV{'WRAP'} = 0;
    ( $result, $exited, $output ) = run_case(
        qw| delredraw |,
        sub {
            my ( $pty, $pid, $drain ) = @ARG;
            $drain->(0.3);
            syswrite $pty, "\e[H";    ## home [ col 0 ] ##
            $drain->(0.2);
            syswrite $pty, "\e[3~" x 3;    ## delete x 3   ##
            $drain->(0.5);
            syswrite $pty, "\x18";
        },
        $child_code_seed
    );
}
my $del_clears = () = $output =~ m{\e\[H\e\[2J}g;
check(
    'delete : every press repaints [ buffer revision in the gate ]',
    $result eq 'RESULT=<>'
        && $exited
        ## initial paint + one clear per delete [ the boolean gate painted the
        ## initial frame + the FIRST delete only ]
        && $del_clears >= 4
);

## word-aware fold [ the wrap default ] : rows break at ELIGIBLE whitespace
## and words stay whole. bracket-awareness follows the bin/format-code rule --
## a space touching a bracket counts the bracket into the word : here the '['
## starts 6 columns before the window edge [ vw 94 ], so a naive fold orphans
## it on the head row ; the eligible-space walk moves the WHOLE "[ 'x' ]"
## group onto the continuation row instead
{
    local $ENV{'SEED'} = ( '1234567890 ' x 8 ) . "[ 'x' ] end";
    local $ENV{'WRAP'} = 1;
    ( $result, $exited, $output ) = run_case(
        qw| wrapwords |,
        sub {
            my ( $pty, $pid, $drain ) = @ARG;
            $drain->(0.3);
            syswrite $pty, "\x18";
        },
        $child_code_seed
    );
}
my $ww_vis = ( split m{\e\[H\e\[2J}, $output, -1 )[-1] // '';
$ww_vis =~ s{\e\[[0-9;?>]* ?[A-Za-z]}{}g;
check(
    'wrap mode : word-aware fold keeps words and bracket groups whole',
    $result eq 'RESULT=<' . ( '1234567890 ' x 8 ) . "[ 'x' ] end>"
        && $exited
        ## the whole bracket group sits on the continuation row
        && $ww_vis =~ m|^:\xe2\x94\x8a \[ 'x' \] end|m
        ## the head row carries no bracket at all [ no orphan ]
        && $ww_vis !~ m|^:  .*\[|m
        ## and no word is split : the continuation starts with the group,
        ## never a bare word fragment
        && $ww_vis !~ m|^:\xe2\x94\x8a \d|m
);

## 'wrap_words => 0' keeps the historical fixed-width character fold : the
## same seed splits at the window edge [ continuation starts with the "] end"
## remainder ], and End lands by the arithmetic position [ 6;9 ]
{
    local $ENV{'SEED'}       = ( '1234567890 ' x 8 ) . "[ 'x' ] end";
    local $ENV{'WRAP'}       = 1;
    local $ENV{'WRAP_WORDS'} = 0;
    ( $result, $exited, $output ) = run_case(
        qw| wrapwordsfixed |,
        sub {
            my ( $pty, $pid, $drain ) = @ARG;
            $drain->(0.3);
            syswrite $pty, "\e[F";    ## end ##
            $drain->(0.4);
            syswrite $pty, "\x18";
        },
        $child_code_seed
    );
}
my $wf_vis = ( split m{\e\[H\e\[2J}, $output, -1 )[-1] // '';
$wf_vis =~ s{\e\[[0-9;?>]* ?[A-Za-z]}{}g;
@cursor_pos = $output =~ m{\e\[([0-9]+);([0-9]+)H\e\[\?25h}g;
check(
    "wrap mode : 'wrap_words => 0' keeps the fixed-width fold",
    $result eq 'RESULT=<' . ( '1234567890 ' x 8 ) . "[ 'x' ] end>"
        && $exited
        ## fixed-width splits at the edge : the continuation starts with the
        ## remainder, not the whole group
        && $wf_vis =~ m|^:\xe2\x94\x8a \] end|m
        && grep( $cursor_pos[ $_ * 2 ] == 6 && $cursor_pos[ $_ * 2 + 1 ] == 9,
        0 .. ( $#cursor_pos / 2 ) )
);

## the window-edge trap : a space sitting EXACTLY at vw
## [ 94 on the 100-col pty ] used to be a legal break target -- 'break after
## it' made a vw + 1 character segment, one column PAST the frame, and the
## terminal's own wrap ate the overflow and tore every row below
## [ the user-reported 'scrolling glitch' on a real item ]. the break now
## searches below vw ; every frame row is exactly 100 columns
{
    local $ENV{'SEED'} = ( 'a' x 94 ) . ' bbb';
    local $ENV{'WRAP'} = 1;
    ( $result, $exited, $output ) = run_case(
        qw| wrapedge |,
        sub {
            my ( $pty, $pid, $drain ) = @ARG;
            $drain->(0.3);
            syswrite $pty, "\x18";
        },
        $child_code_seed
    );
}
my $edge_vis = ( split m{\e\[H\e\[2J}, $output, -1 )[-1] // '';
$edge_vis =~ s{\e\[[0-9;?>]* ?[A-Za-z]}{}g;
$edge_vis =~ s{\r}{}g;
$edge_vis =~ s{\xe2\x94\x8a}{|}g;
$edge_vis =~ s{\xe2\x94\x84}{-}g;
$edge_vis =~ s{\xc2\xb7}{.}g;
check(
    'wrap mode : a space at the window edge never overruns the frame',
    $result eq 'RESULT=<' . ( 'a' x 94 ) . ' bbb>'
        && $exited
        && $edge_vis !~ m|^.{101,}$|m
        && $edge_vis =~ m|^.{100}$|m
);

## the selected block darkens as ONE unit : with colors, the cursor's head row
## AND its continuation row render dimmed [ segment and ┊ alike ] while the
## ':' borders keep the bold-blue chrome ; the other line stays bright with
## its purple border ; the dim resets before the trailing border
my $child_code_wrapcolor = <<~'CHILD';
    use strict;
    use warnings;
    use AMOS7::TERM::Editor qw| edit_text |;
    binmode STDOUT, ':utf8';
    $ENV{'P7_EDITOR_NO_CLIP'} = 1;
    my %C = ( T=>"\e[34m", 0=>"\e[35m", 3=>"\e[32m",
        B=>"\e[1m", R=>"\e[0m", dim=>"\e[2m" );
    my $out = shift;
    { open my $pid_fh, '>', "$out.pid" or die; print $pid_fh $$; }
    my $result = eval {
        edit_text( { text => 'a' x 150 . "\n" . 'bb', title => 'T',
            label => 'l', colors => \%C, wrap => 1 } );
    };
    open my $fh, '>:utf8', $out or die;
    print $fh defined $result ? "RESULT=<$result>" : 'RESULT=<UNDEF>';
    close $fh;
    CHILD

( $result, $exited, $output ) = run_case(
    qw| wrapdarken |,
    sub {
        my ( $pty, $pid, $drain ) = @ARG;
        $drain->(0.3);
        syswrite $pty, "\e[F";    ## cursor onto the continuation row ##
        $drain->(0.4);
        syswrite $pty, "\x18";
    },
    $child_code_wrapcolor
);
my @frames      = split m{\e\[H\e\[2J}, $output, -1;
my $final_frame = $frames[-1] // '';
check(
    'wrap mode : the selected block darkens as one unit, others stay bright',
    $result eq 'RESULT=<' . ( 'a' x 150 ) . "\nbb>"
        && $exited
        ## head row of the cursor's block : dim content, bold-blue border
        && index( $final_frame, "\e[34m\e[1m:\e[2m\e[34m  aaaa" ) >= 0
        ## continuation row : dim ┊ AND dim segment text
        && index( $final_frame, "\e[34m\e[1m:\e[2m\e[34m\xe2\x94\x8a aaaa" )
        >= 0
        ## dim scoped : it resets before the trailing border
        && index( $final_frame, "\e[0m\e[34m\e[1m:" ) >= 0
        ## the other line keeps its purple border and bright text
        && index( $final_frame, "\e[35m:\e[34m\e[1m  bb" ) >= 0
);

## 'wrap_sep => 0' opts out : the historical plain fold, no dotted row
{
    local $ENV{'SEED'}     = "head\n" . ( 'a' x 150 ) . "\ntail";
    local $ENV{'WRAP'}     = 1;
    local $ENV{'WRAP_SEP'} = 0;
    ( $result, $exited, $output ) = run_case(
        qw| wrapnosep |,
        sub {
            my ( $pty, $pid, $drain ) = @ARG;
            $drain->(0.3);
            syswrite $pty, "\x18";
        },
        $child_code_seed
    );
}
my $vis_nosep = $output;
$vis_nosep =~ s{\e\[[0-9;?]*[A-Za-z]}{}g;
check(
    "wrap mode : 'wrap_sep => 0' opts out of the separator row",
    $exited && $vis_nosep !~ m|^:(?:\xe2\x94\x84){20}|m
);

## a CSI-u ctrl-, arriving byte-wise with the final byte lagging past the
## short escape deadline still kills -- the prefix stays in flight and the
## tail never TYPES into the text
{
    local $ENV{'SEED'} = "one\ntwo\nthree";
    local $ENV{'WRAP'} = 0;
    ( $result, $exited, $output ) = run_case(
        qw| splitcsi |,
        sub {
            my ( $pty, $pid, $drain ) = @ARG;
            $drain->(0.3);
            syswrite $pty, "\e[44;5";
            $drain->(0.25);        ## past the 0.1 s first deadline ##
            syswrite $pty, "u";    ## the lagging final byte       ##
            $drain->(0.4);
            syswrite $pty, "\x18";
        },
        $child_code_seed
    );
}
check( 'split CSI-u delivery : the lagging byte completes the kill, not text',
    $result eq "RESULT=<two\nthree>" && $exited );

## scroll mode : the cursor far past a shorter long line
## [ 100 chars under a 200-column cursor ] clamps the tail window instead of
## tripping substr outside of string
{
    local $ENV{'SEED'} = ( 'a' x 200 ) . "\n" . ( 'b' x 100 );
    local $ENV{'WRAP'} = 0;
    ( $result, $exited, $output ) = run_case(
        qw| scrollclamp |,
        sub {
            my ( $pty, $pid, $drain ) = @ARG;
            $drain->(0.3);
            syswrite $pty, "\e[F";    ## end of the 200-char line ##
            $drain->(0.4);
            syswrite $pty, "\x18";
        },
        $child_code_seed
    );
}
check(
    'scroll mode : a far-right cursor over a shorter long line stays silent',
    $result eq 'RESULT=<' . ( 'a' x 200 ) . "\n" . ( 'b' x 100 ) . '>'
        && $exited
        && index( $output, 'substr outside of string' ) < 0
);

say '';
say "=== $tests_passed / $tests_run tests passed ===";
exit( $tests_passed == $tests_run ? 0 : 1 );

#,,,,,,..,.,.,,..,.,.,,,.,,.,,,.,,,.,,,.,,,..,..,,...,..,,,.,,.,.,,,.,...,.,.,
#NSG3NQN4L3X4BQLR4Z45MHDG46KI7LV3DLMH7VZYKTVFHO4TU4KXDXRVDCXRAUD6LKJRR7UEOQUIS
#\\\|TMGH6D7D2VK3VUW2TI34YULP26MOWFZPZJOIZ2XFRW3W6LLXEDY \ / AMOS7 \ YOURUM ::
#\[7]R4VH24NBIRXXEMDOC4H7J2YO3TQTFPCQ4MSTG2AFT5HYBB5BNMBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
