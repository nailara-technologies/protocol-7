#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## AMOS7::TERM's password reader through a real pty : the bytes it returns for
## every editing form [ backspace kinds, utf-8, ctrl-u, escape sequences,
## control bytes, the 64-byte xor folding, paste vs typed, aborts, timeout,
## min length, repeated entry ]. the expected values are what decrypts the
## existing keys -- a change here locks people out of them, so a differing
## value is a failure, never an update of the table without a reason.  a key
## is typed one byte at a time [ 20 ms ], an escape sequence in one write
## [ as a terminal sends it ]. P7_TERM_TEST_PRINT=1 prints the table, a
## pattern argument runs the matching cases only

use FindBin;
use File::Temp qw| tempdir |;
use IO::Pty;
use POSIX       ();
use Time::HiRes qw| time sleep |;
use Encode      qw| encode |;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

## P7_TERM_TEST_LIB : another lib dir [ an older TERM.pm to compare with ]
my $lib = $ENV{'P7_TERM_TEST_LIB'} // "$FindBin::Bin/../../data/lib-path/pm";
my $tmp = tempdir( CLEANUP => 1 );
my ( $pass, $fail ) = ( 0, 0 );

## one read in the pty : the result as hex + abort mode into a file ##
my $driver = <<'DRIVER';
use v5.32.0;
use strict;
use warnings;
BEGIN { unshift @INC, $ENV{P7_TERM_LIB} }
use AMOS7::TERM;
my ( $mode, $timeout ) = @ARGV;
my ( $pw, $abort );
if ( $mode eq 'repeated' ) {
    $pw = AMOS7::TERM::read_password_repeated( 'test password', '', 1,
        $timeout );
    $abort = '-';
} else {
    ( $pw, $abort )
        = AMOS7::TERM::read_password_single( 'test password', '', 1,
        $timeout );
}
my $result = ( defined $pw ? unpack( 'H*', $pw ) : 'undef' ) . ' '
    . ( $abort // 'undef' );
if ( $mode =~ m|^scan| ) {
    ## the returned value wiped [ not in the control ], then this process's
    ## writable memory searched for the pattern -- given masked, the search
    ## holds no plain copy of it
    AMOS7::TERM::wipe_secret( \$pw ) if $mode eq 'scan';
    undef $pw;
    my $masked = pack 'H*', $ENV{P7_TERM_MASKED};
    my $hits   = 0;
    open my $maps, '<',     "/proc/$$/maps" or die $!;
    open my $mem,  '<:raw', "/proc/$$/mem"  or die $!;
    while ( my $line = <$maps> ) {
        my ( $from, $to, $perm, $name )
            = $line =~ m|^(\w+)-(\w+) (\S+) \S+ \S+ \S+\s*(.*)$|;
        next if not defined $perm or $perm !~ m|^rw| or $name =~ m|^\[v|;
        sysseek( $mem, hex $from, 0 ) or next;
        my $chunk = '';
        sysread( $mem, $chunk, hex($to) - hex($from) ) or next;
        $chunk ^.= "\x55" x length $chunk;
        my $at = 0;
        while ( ( $at = index( $chunk, $masked, $at ) ) >= 0 ) {
            $hits++;
            $at++;
        }
    }
    $result = "hits=$hits";
}
open my $out, '>', $ENV{P7_TERM_RESULT} or die $!;
print {$out} $result;
close $out;
DRIVER

## @steps : [ wait seconds or [ regex to wait for ], bytes, one at a time ]
sub read_case {
    my ( $mode, $timeout, @steps ) = @ARG;
    my $result = "$tmp/result";
    unlink $result;
    my $pty = IO::Pty->new;
    my $pid = fork // die "fork : $OS_ERROR";
    if ( not $pid ) {
        ## make_slave_controlling_terminal setsid()s ##
        my $tty = $pty->slave;
        $pty->make_slave_controlling_terminal;
        close $pty;
        open( STDIN,  '<&', $tty ) or POSIX::_exit(1);
        open( STDOUT, '>&', $tty ) or POSIX::_exit(1);
        open( STDERR, '>&', $tty ) or POSIX::_exit(1);
        $ENV{'P7_TERM_LIB'}    = $lib;
        $ENV{'P7_TERM_RESULT'} = $result;
        ## block : no warning ##
        { exec $^X, '-e', $driver, $mode, $timeout }
        POSIX::_exit(1);
    }
    $pty->close_slave;

    my $out      = '';
    my $read_for = sub {
        my ( $seconds, $until ) = @ARG;
        my $end = time + $seconds;
        while ( ( my $left = $end - time ) > 0 ) {
            return TRUE if defined $until and $out =~ $until;
            my $rin = '';
            vec( $rin, fileno($pty), 1 ) = 1;
            last if not select( my $rout = $rin, undef, undef, $left );
            sysread( $pty, my $buf, 4096 ) or last;
            $out .= $buf;
        }
        return ( not defined $until or $out =~ $until ) ? TRUE : FALSE;
    };

    ## typed only once the prompt is there : before it, the tty's own line
    ## editing would handle the keys
    $read_for->( 10, qr|test password| ) or return 'no prompt';
    sleep 0.3;
    foreach my $step (@steps) {
        my ( $wait, $bytes, $one_at_a_time ) = @{$step};
        if ( ref $wait ) { $read_for->( 10, $wait->[0] ) }
        else             { $read_for->($wait) }
        if ($one_at_a_time) {
            foreach my $byte ( split m||, $bytes ) {
                syswrite $pty, $byte;
                sleep 0.02;
            }
        } else {
            syswrite $pty, $bytes;
        }
    }

    my $rc;
    my $end = time + 20;
    while ( time < $end ) {
        $read_for->(0.2);
        if ( waitpid( $pid, POSIX::WNOHANG() ) == $pid ) {
            $rc = $CHILD_ERROR >> 8;
            last;
        }
    }
    if ( not defined $rc ) {    ## a hung read is a failure, not a hang ##
        kill 'KILL', $pid;
        waitpid $pid, 0;
        $rc = 'hung';
    }
    close $pty;
    my $value = 'none';
    if ( open my $fh, '<', $result ) {
        $value = <$fh> // 'none';
        close $fh;
    }
    return "rc=$rc $value";
}

my $pw   = 'correct horse battery';
my $u8   = encode( 'UTF-8', "p\x{e4}ssw\x{f6}rd l\x{e4}ng\x{e9}r" );
my $l100 = join '', map { chr( 33 + $ARG % 90 ) } 1 .. 100;
my $hpw  = unpack( 'H*', $pw );
my $ok   = "rc=0 $hpw 0";

## no copy of a typed value stays in memory once the caller wiped the one it
## got back : bytes 16..23 of it searched
## [ a free() overwrites the first 16 ]. the control keeps the value -- the
## search must find it
my $scan_pw = 'Kx9vQ2mWp8Lr4Tz7Hd3Ng6Bs1Yc5Fj';
$ENV{'P7_TERM_MASKED'}
    = unpack( 'H*', substr( $scan_pw, 16, 8 ) ^. ( "\x55" x 8 ) );
my $scan_typed
    = substr( $scan_pw, 0, 10 )
    . "ab\x7f\x7f"
    . substr( $scan_pw, 10 ) . "\r";

my @cases = (
    [ 'plain paste', $ok, 'single', 13, [ 0, "$pw\r" ] ],
    [ 'plain typed', $ok, 'single', 13, [ 0, "$pw\r", 1 ] ],
    [   'utf-8 typed', 'rc=0 70c3a4737377c3b67264206cc3a46e67c3a972 0',
        'single', 13, [ 0, "$u8\r", 1 ]
    ],
    [   'DEL typed', $ok, 'single', 13,
        [ 0, "correct horsX\x7fe " . "battery\r", 1 ]
    ],
    [ 'DEL paste', $ok, 'single', 13, [ 0, "correct horsX\x7fe battery\r" ] ],
    [   'BS typed', $ok, 'single', 13,
        [ 0, "correct horsX\x08e " . "battery\r", 1 ]
    ],
    [   'ESC[3~ typed', $ok, 'single', 13,
        [ 0,   'correct horsX', 1 ],
        [ 0,   "\e[3~" ],
        [ 0.1, "e battery\r", 1 ]
    ],
    [   'ESC[3~ paste', $ok, 'single', 13,
        [ 0, "correct horsX\e[3~e " . "battery\r" ]
    ],
    [   'ESC[D typed', $ok, 'single', 13,
        [ 0,   'correct horsX', 1 ],
        [ 0,   "\e[D" ],
        [ 0.1, "e battery\r", 1 ]
    ],
    ## one DEL removes one BYTE : half of a two-byte character stays ##
    [   'utf-8 + two DEL typed',
        'rc=0 70c3a4737377c3b67264206cc3a46e67c3 0',
        'single', 13, [ 0, "$u8\x7f\x7f\r", 1 ]
    ],
    [ 'leading DEL typed', $ok, 'single', 13, [ 0, "\x7f$pw\r", 1 ] ],
    [   'two DEL in one paste', $ok,
        'single',               13,
        [ 0, "correct horsXY\x7f\x7fe battery\r" ]
    ],
    [   'ctrl-u typed', $ok, 'single', 13,
        [ 0,   "garbage\x15", 1 ],
        [ 1.5, "$pw\r",       1 ]
    ],
    ## what follows a ctrl-u in the same read stays [ fast typing, paste ] ##
    [ 'ctrl-u paste', $ok, 'single', 13, [ 0, "garbage\x15$pw\r" ] ],
    [   'ctrl-u, typing on at once',
        $ok, 'single', 13,
        [ 0,   'garbage', 1 ],
        [ 0.3, "\x15co" ],
        [ 0,   "rrect horse " . "battery\r", 1 ]
    ],
    [   'unknown csi typed',
        $ok, 'single', 13,
        [ 0,   'correct ', 1 ],
        [ 0,   "\e[5~" ],
        [ 0.1, "horse battery\r", 1 ]
    ],
    [   'unknown csi paste', $ok,
        'single',            13,
        [ 0, "correct \e[5~horse battery\r" ]
    ],
    [   'ctrl bytes 1-9 typed',
        $ok, 'single', 13, [ 0, "correct\x01\x02\x05\x09 horse battery\r", 1 ]
    ],
    ## pasted control bytes stay in the value ##
    [   'ctrl bytes paste',
        'rc=0 636f72726563740102050920686f7273652062617474657279 0',
        'single',
        13,
        [ 0, "correct\x01\x02\x05\x09 horse battery\r" ]
    ],
    [   'cr alone, then ' . 'the value',
        $ok, 'single', 13,
        [ 0,   "\r" ],
        [ 0.5, "$pw\r" ]
    ],
    ## 63 characters + the line break : 64 bytes, xor folded ##
    [   'length 63 paste',
        'rc=0 ' . ( '1e' x 63 ) . '7f 0',
        'single', 13, [ 0, ( 'a' x 63 ) . "\r" ]
    ],
    [   'length 63 typed',
        'rc=0 ' . ( '1e' x 63 ) . '7f 0',
        'single', 13, [ 0, ( 'a' x 63 ) . "\r", 1 ]
    ],
    [   'length 64 paste',
        'rc=0 ' . ( '1d' x 64 ) . ' 0',
        'single', 13, [ 0, ( 'b' x 64 ) . "\r" ]
    ],
    [   'length 64 typed',
        'rc=0 ' . ( '1d' x 64 ) . ' 0',
        'single',
        13,
        [ 0, ( 'b' x 64 ) . "\r", 1 ]
    ],
    [   'length 65 paste',
        'rc=0 7f' . ( '1c' x 63 ) . ' 0',
        'single', 13, [ 0, ( 'c' x 65 ) . "\r" ]
    ],
    [   'length 65 typed',
        'rc=0 7f' . ( '1c' x 63 ) . ' 0',
        'single', 13, [ 0, ( 'c' x 65 ) . "\r", 1 ]
    ],
    ## a paste past 64 bytes is folded unedited : its DEL is folded in ##
    [   'length 100 paste + DEL',
        'rc=0 '
            . '3c3e383e3c3e303e3c3e383e3c3e203e3c3e383e3c3e303e3c3e6260626425'
            . '19'
            . '1915151111393837363534333231302f2e2d2c2b2a292827262524232221201f 0',
        'single',
        13,
        [ 0, substr( $l100, 0, 30 ) . "\x7f" . substr( $l100, 30 ) . "\r" ]
    ],
    [   'length 100 typed + DEL',
        'rc=0 '
            . '3e383e3c3e303e3c3e383e3c3e203e3c3e383e3c3e303e3c64666066641919'
            . '15'
            . '151111393837363534333231302f2e2d2c2b2a292827262524232221201f1e1d 0',
        'single', 13,
        [   0, substr( $l100, 0, 30 ) . "\x7f" . substr( $l100, 30 ) . "\r",
            1
        ]
    ],
    [   'length 100 typed, DEL past 64',
        'rc=0 '
            . '3f3f3f3f3f3f283e3c3e383e3c3e203e3c3e383e3c3e303e3c3e626062641a'
            . '18'
            . '1a141210123837363534333231302f2e2d2c2b2a292827262524232221201f1e 0',
        'single', 13,
        [   0, substr( $l100, 0, 70 ) . "\x7f" . substr( $l100, 70 ) . "\r",
            1
        ]
    ],
    [   'paste 40, then paste 40',
        'rc=0 '
            . '3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f4d4c4b4a494847464544434241403f'
            . '3e'
            . '3d3c3b3a393837363534333231302f2e2d2c2b2a292827262524232221201f1e 0',
        'single',
        13,
        [ 0,   substr( $l100, 0,  40 ) ],
        [ 0.5, substr( $l100, 40, 40 ) . "\r" ]
    ],
    [ 'esc aborts',    'rc=110 none', 'single', 13, [ 0, "abc\e",   1 ] ],
    [ 'ctrl-c aborts', 'rc=110 none', 'single', 13, [ 0, "abc\x03", 1 ] ],
    [ 'ctrl-d aborts', 'rc=110 none', 'single', 13, [ 0, "abc\x04", 1 ] ],
    [ 'timeout',       'rc=110 none', 'single', 2 ],
    [   'min length, then again',
        $ok,
        'single',
        13,
        [ 0,             "short\r", 1 ],
        [ [qr|min len|], '' ],
        [ 2.5,           "$pw\r", 1 ]
    ],
    [   'memory : typed, ' . 'wiped',
        'rc=0 hits=0', 'scan', 13, [ 0, $scan_typed, 1 ]
    ],
    [   'memory : ' . 'pasted, wiped',
        'rc=0 hits=0', 'scan', 13, [ 0, $scan_typed ]
    ],
    [   'memory : ' . 'control, not wiped',
        qr|^rc=0 hits=[1-9]|,
        'scan-control', 13, [ 0, $scan_typed, 1 ]
    ],
    [   'repeated : match',
        "rc=0 $hpw -", 'repeated', 13,
        [ 0,              "$pw\r", 1 ],
        [ [qr|re-enter|], "$pw\r", 1 ]
    ],
    [   'repeated : mismatch, then match',
        "rc=0 $hpw -",
        'repeated',
        13,
        [ 0,                                     "$pw\r",    1 ],
        [ [qr|re-enter|],                        "${pw}x\r", 1 ],
        [ [qr|(?s)differ.*enter test password|], "$pw\r",    1 ],
        [ [qr|(?s)differ.*re-enter|],            "$pw\r",    1 ]
    ],
);

my $only  = shift;
my $print = $ENV{'P7_TERM_TEST_PRINT'};
foreach my $case (@cases) {
    my ( $name, $expect, $mode, $timeout, @steps ) = @{$case};
    next if defined $only and $name !~ m|$only|;
    my $got = read_case( $mode, $timeout, @steps );
    if ($print) { printf "  %-34s %s\n", $name, $got; next }
    if ( ref $expect ? $got =~ $expect : $got eq $expect ) {
        $pass++;
        say "  ok    $name";
    } else {
        $fail++;
        say "  FAIL  $name\n          expected "
            . "$expect\n          got      $got";
    }
}

say "\npassed : $pass  failed : $fail";
exit( $fail ? 1 : 0 );

#,,.,,,,,,,,.,,.,,.,,,.,.,,..,..,,,,.,,,.,.,,,..,,...,...,..,,...,,..,,,,,..,,
#QLYEPSFDUCUGQYCHXM46TCDK3UDD5OXWPWDAM3GZEBCR4TSAMMIVQZJISQTN4D42NEB4C72325LFS
#\\\|FSR4STQ36TSCZ3WFI6OJTYGK4ZQEWUPAW7HZVTJYKUGYLPGNWAT \ / AMOS7 \ YOURUM ::
#\[7]2ESKP43DEYWHASHSALMDAJ4U5QPLGLJ5PBQOZUMX7DEIIBRHMCDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
