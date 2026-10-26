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
## fast = one collapsed page ] and a no-op tick at EOF repaints nothing.
## skipped when IO::Pty is not installed

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

say '';
say "=== $tests_passed / $tests_run tests passed ===";
exit( $tests_passed == $tests_run ? 0 : 1 );

#,,.,,.,.,,,.,.,,,.,.,.,,,,,.,,..,.,.,.,.,,,.,..,,...,...,,.,,,..,..,,,.,,.,,,
#4ITQMQDX3QAETFFQFEUBQBGMAHJEY7ETJ7VXGJ5RTGSWM5WAGB4FZRVTDEKDUMZ54S2AH6GFQRIHG
#\\\|AK7LNIHICCHNN3YWP4EWI2OS5CCQCWIMFU6PYIB3CK5PNY7KFFN \ / AMOS7 \ YOURUM ::
#\[7]EME2MEV6FI75BDYS7VPV3XJXPVGWLY6QY27UW2LLGCCJBHN42SAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
