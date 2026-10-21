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
## as characters.  skipped when IO::Pty is not installed

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

sub run_case {
    my ( $name, $script ) = @ARG;
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
            exec $EXECUTABLE_NAME, "-I$local_lib_path", '-e', $child_code,
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

## ctrl-c abort : the cursor shape set on entry is reset ##
( $result, $exited, $output ) = run_case(
    qw| abort |,
    sub {
        my ($pty) = @ARG;
        syswrite $pty, "\x03";
    }
);
check( 'ctrl-c abort : returns undef', $result eq 'RESULT=<UNDEF>' );
check( 'ctrl-c abort : cursor shape reset',
    rindex( $output, "\e[0 q" ) > rindex( $output, "\e[4 q" ) );

say '';
say "=== $tests_passed / $tests_run tests passed ===";
exit( $tests_passed == $tests_run ? 0 : 1 );

#,,,.,,,,,,,.,...,.,.,...,.,.,..,,,..,,,,,...,..,,...,...,...,.,.,,,,,,,,,,..,
#4ILESMRAESMYDCY6VE7X3VFG65ZEXULU6WEJOWXLPEERBMID2FOXUL5ZZSDBIX2R7DMNXGX5WK44C
#\\\|BA3QXZCW6HJWRNEL27CZMUG2A7PP7YHIA7FYCT7GEJI5WAUNCQE \ / AMOS7 \ YOURUM ::
#\[7]3JSG7PGAAF3FW3IJLIHTSNOURXLE6PTAJ7CWXWSJFN66CLB3VWAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
