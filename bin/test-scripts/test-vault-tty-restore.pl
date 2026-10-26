#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## p7-vault's terminal hygiene on a real pty [ IO::Pty ] :
##
## editor : 'scratchpad' saves through the shared full-screen editor. the
## editor's exit scrolls once and leaves its frame on screen -- note_editor
## must clear it [ the way bin/todo's details editor keeps in step ], or every
## line the shell prints next scrolls the leftover frame further
## [ the frame sits one line too high for what follows ]
##
## signals : INT \ TERM during the shell end it through cursor_shell's
## handlers -- those must restore the console mode
## [ readline's own mode, ReadKey's raw ] before exiting. END only resets the
## cursor shape, not the tty : without the restore the console  stays with
## echo off \ raw after ctrl-c at the prompt
##
## throwaway vaults, cheap kdf ; skipped when IO::Pty is not installed

use FindBin;
use File::Temp qw| tempdir |;
use POSIX      ();

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }

use AMOS7::Vault qw| vault_init |;

if ( !eval { require IO::Pty; 1 } ) {
    say '=== skipped : IO::Pty not installed ===';
    exit 0;
}

my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    my ( $cond, $name ) = @ARG;
    if   ($cond) { $pass++; say "  ok    $name" }
    else         { $fail++; say "  FAIL  $name" }
}

my $tmp       = tempdir( CLEANUP => 1 );
my $dir       = "$tmp/vault";
my $vault_bin = "$FindBin::Bin/../p7-vault";
vault_init( $dir, 'pass phrase', undef, t => 1, m => 8192, p => 1 );

## run the shell in a pty, keep the slave's tty name : the tty flag checks
## after a signal exit need the master still open. returns a handle hash
sub spawn {
    my $pty = IO::Pty->new;
    $pty->set_winsize( 24, 80 ) if $pty->can('set_winsize');
    my $tty = $pty->ttyname;
    my $pid = fork // die "fork : $OS_ERROR";
    if ( not $pid ) {
        ## make_slave_controlling_terminal setsid()s ##
        my $slave = $pty->slave;
        $pty->make_slave_controlling_terminal;
        close $pty;
        open( STDIN,  '<&', $slave ) or POSIX::_exit(1);
        open( STDOUT, '>&', $slave ) or POSIX::_exit(1);
        open( STDERR, '>&', $slave ) or POSIX::_exit(1);
        $ENV{'P7_VAULT_LOCK_SECONDS'} = 0;         ## no auto-lock in tests ##
        $ENV{'TERM'}                  = 'xterm';
        { exec $^X, $vault_bin, '-d', $dir }
        POSIX::_exit(1);
    }
    $pty->close_slave;
    my $out = '';
    my $h;
    $h = {
        pty  => $pty,
        pid  => $pid,
        tty  => $tty,
        out  => \$out,
        wait => sub {    ## drain seconds [ or until a regex appeared ] ##
            my ( $seconds, $text ) = @ARG;
            my $until = time + $seconds;
            while ( ( my $left = $until - time ) > 0 ) {
                last if defined $text and $out =~ $text;
                my $rin = '';
                vec( $rin, fileno($pty), 1 ) = 1;
                last if not select( my $rout = $rin, undef, undef, $left );
                my $n = sysread( $pty, my $buf, 4096 ) or last;
                $out .= $buf;
            }
        },
        send => sub {    ## type, then drain ##
            my ( $text, $seconds ) = @ARG;
            syswrite( $pty, $text );
            $h->{'wait'}->( $seconds // 0.5 );
        },
        reap => sub {    ## up to 5 s, then KILL ; returns the exit code ##
            ## the master stays open : the tty flag checks read the slave ##
            my $rc;
            foreach ( 1 .. 50 ) {
                if ( waitpid( $pid, POSIX::WNOHANG() ) == $pid ) {
                    $rc = $? >> 8;
                    last;
                }
                $h->{'wait'}->(0.1);
            }
            if ( not defined $rc ) {
                kill 'KILL', $pid;
                waitpid $pid, 0;
                $rc = -1;
            }
            return $rc;
        },
        done => sub { close $pty; return },
    };
    return $h;
}

sub tty_flag {
    my ( $tty, $flag ) = @ARG;
    my $st = qx|stty -a < $tty 2>/dev/null|;
    return $st =~ m{(-?$flag)} ? $1 : undef;
}

## one flag check pair after a signal exit ##
sub ok_tty_restored {
    my ( $h, $name ) = @ARG;
    my $echo   = tty_flag( $h->{'tty'}, 'echo' );
    my $icanon = tty_flag( $h->{'tty'}, 'icanon' );
    ok( ( defined $echo   && $echo eq 'echo' ), "$name : echo restored" );
    ok( ( defined $icanon && $icanon eq 'icanon' ),
        "$name : icanon restored" );
}

##[ the editor's leftover frame ]#############################################

my $h = spawn();
$h->{'wait'}->( 15,              qr|passphrase| );
$h->{'send'}->( "pass phrase\r", 1 );
$h->{'wait'}->( 12,              qr|:: vault ::| );
$h->{'send'}->( "scratchpad\r",  1.5 );               ## the editor opens ##
$h->{'wait'}->( 12,              qr|ctrl-x save\+quit| );
my $out        = ${ $h->{'out'} };
my $frame_seen = $out =~ m|ctrl-x save\+quit| ? TRUE : FALSE;
$h->{'send'}->( 'X',    0.5 );
$h->{'send'}->( "\x18", 1 );                          ## ctrl-x save ##
$h->{'wait'}->( 12,     qr|stored 'scratchpad'| );
$out = ${ $h->{'out'} };
my $stored = $out =~ m|stored 'scratchpad'| ? TRUE : FALSE;

## the clear must sit between the editor's exit-position report and the ##
## message : the frame may not linger for the shell's next lines        ##
my $exit_pos   = rindex( $out, "\e[24;1H" );
my $clear_at   = rindex( $out, "\e[H\e[2J" );
my $stored_pos = index( $out, "stored 'scratchpad'" );
ok( $frame_seen, 'editor : the scratchpad frame came up' );
ok( $stored,     'editor : ctrl-x stored the note' );
ok( $stored && $clear_at > $exit_pos && $clear_at < $stored_pos,
    'editor : the leftover frame is cleared before the stored message'
);
ok( index( $out, "\e[24;1H\e[?25h\e[0 q\n" ) < 0,
    'editor : the exit does not print a newline on the '
        . 'last row [ no scroll, no empty line under the frame ]'
);

## and the editor still comes back up with the saved body ##
my $mark = length $out;
$h->{'send'}->( "scratchpad\r", 1.5 );
$h->{'wait'}->( 12,             qr|ctrl-x save\+quit| );
my $tail     = substr( ${ $h->{'out'} }, $mark );
my $reopened = $tail =~ m|:  X\s+:| ? TRUE : FALSE;
$h->{'send'}->( "\x18",   0.5 );                      ## leave it as it was ##
$h->{'wait'}->( 3,        qr|stored 'scratchpad'| );
$h->{'send'}->( "quit\r", 0.5 );
my $rc = $h->{'reap'}->();
$h->{'done'}->();
ok( $reopened && $rc == 0,
    'editor : reopens with the saved body, the session goes on' );

##[ signals : the console mode on the way out ]###############################

## ctrl-c at the shell prompt : the tty's echo + icanon come back ##
$h = spawn();
$h->{'wait'}->( 15,              qr|passphrase| );
$h->{'send'}->( "pass phrase\r", 1 );
$h->{'wait'}->( 12,              qr|:: vault ::| );
kill 'INT', $h->{'pid'};
$rc = $h->{'reap'}->();
ok( $rc == 130, 'ctrl-c at the prompt : exit 130' );
ok_tty_restored( $h, 'ctrl-c at the prompt' );
$h->{'done'}->();

## SIGTERM at the shell prompt : same ##
$h = spawn();
$h->{'wait'}->( 15,              qr|passphrase| );
$h->{'send'}->( "pass phrase\r", 1 );
$h->{'wait'}->( 12,              qr|:: vault ::| );
kill 'TERM', $h->{'pid'};
$rc = $h->{'reap'}->();
ok_tty_restored( $h, 'SIGTERM at the prompt' );
$h->{'done'}->();

## ctrl-c while the unlock prompt holds the tty in raw mode ##
$h = spawn();
$h->{'wait'}->( 15, qr|passphrase| );
kill 'INT', $h->{'pid'};
$rc = $h->{'reap'}->();
ok( $rc == 130, 'ctrl-c at the unlock prompt : exit 130' );
ok_tty_restored( $h, 'ctrl-c at the unlock prompt' );
$h->{'done'}->();

say "\npassed : $pass  failed : $fail";
exit( $fail ? 1 : 0 );

#,,,,,...,...,,,.,.,,,,.,,,.,,,..,...,.,,,,..,..,,...,...,,..,,,,,...,.,,,...,
#VTDPSG4YDI6PZH5ZZL7XSTC3U7CA3VGKEVNTSLS2TV7RNTISBCTYKSFQL5ASM5AHXFXY6W2POQFRW
#\\\|JULGHZ34GJMOVAZ7YKRLVHLFCFSEHAOMP2UIK34DMKE2ZGF67MQ \ / AMOS7 \ YOURUM ::
#\[7]7Z26ZZP22N7OB3IFZZKZNTHDZXD7JCPGXOQJNSPY453JLDWX2SBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
