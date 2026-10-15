#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## p7-vault's auto-lock through a real pty : the shell locks after the idle
## time [ P7_VAULT_LOCK_SECONDS ], clears screen + scrollback, asks for the
## passphrase again and goes on ; a lock inside a hidden input cancels the
## command ; ':keep-open:' never locks. throwaway vault, cheap kdf also the
## hidden input itself [ one buffer written in place ] : backspace over ascii
## and utf-8, a value past the first buffer size

use FindBin;
use File::Temp qw| tempdir |;
use IO::Pty;
use POSIX ();

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

BEGIN { unshift @INC, "$FindBin::Bin/../../data/lib-path/pm" }

use AMOS7::Vault qw| vault_init |;
use Encode       qw| encode |;

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

## run the shell in a pty : @steps are [ seconds to wait, text to type ] ;
## returns ( everything it printed, exit code )
sub session {
    my ( $env, $args, @steps ) = @ARG;
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
        $ENV{$ARG} = $env->{$ARG} foreach grep { $ARG ne '-d' } keys %{$env};
        ## block : no warning ##
        { exec $^X, $vault_bin, '-d', $env->{'-d'} // $dir, @{$args} }
        POSIX::_exit(1);
    }
    $pty->close_slave;
    my $out   = '';
    my $drain = sub {
        my $until = time + shift;
        while ( ( my $left = $until - time ) > 0 ) {
            my $rin = '';
            vec( $rin, fileno($pty), 1 ) = 1;
            last if not select( my $rout = $rin, undef, undef, $left );
            my $n = sysread( $pty, my $buf, 4096 ) or last;
            $out .= $buf;
        }
    };
    foreach my $step (@steps) {
        $drain->( $step->[0] );
        syswrite( $pty, $step->[1] );
    }
    $drain->(2);
    ## a shell still waiting [ a lock where the test typed too late ] is a
    ## failure, not a hang of the whole suite
    my $rc;
    foreach ( 1 .. 50 ) {
        if ( waitpid( $pid, POSIX::WNOHANG() ) == $pid ) {
            $rc = $? >> 8;
            last;
        }
        select( undef, undef, undef, 0.1 );
    }
    if ( not defined $rc ) {
        kill 'KILL', $pid;
        waitpid $pid, 0;
        $rc = -1;
    }
    close $pty;
    return ( $out, $rc );
}

## 2 s lock : the waits past it are 4 s, the typing after an unlock stays well
## inside it

## idle at the prompt : locked, cleared, unlocked again, a command works ##
my ( $out, $rc ) = session(
    { P7_VAULT_LOCK_SECONDS => 2 },
    [],
    [ 1,   "pass phrase\r" ],
    [ 4,   "pass phrase\r" ],
    [ 0.6, "commands sync\r" ],
    [ 0.6, "quit\r" ]
);
my $plain = $out =~ s|\e\[[0-9;?]*[A-Za-z]||gr;
ok( $plain =~ m|locked after 2 s without input|, 'idle prompt : locked' );
ok( index( $out, "\e[3J" ) >= 0, 'idle prompt : scrollback cleared' );
ok( $plain =~ m|sync <host>| && $rc == 0,
    'idle prompt : unlocked again, the session goes on' );

## idle inside a hidden input : the command is cancelled, nothing changes ##
open( my $kfh, '<:raw', "$dir/vault.key.B32" ) or die $OS_ERROR;
my $key_before = do { local $INPUT_RECORD_SEPARATOR; <$kfh> };
close $kfh;
( $out, $rc ) = session(
    { P7_VAULT_LOCK_SECONDS => 2 },
    [],
    [ 1,   "pass phrase\r" ],
    [ 0.3, "passwd\r" ],
    [ 4,   "pass phrase\r" ],
    [ 0.6, "quit\r" ]
);
$plain = $out =~ s|\e\[[0-9;?]*[A-Za-z]||gr;
open( $kfh, '<:raw', "$dir/vault.key.B32" ) or die $OS_ERROR;
my $key_after = do { local $INPUT_RECORD_SEPARATOR; <$kfh> };
close $kfh;
ok( $plain =~ m|new vault passphrase| && $plain =~ m|locked after|,
    'hidden input : the lock reached it' );
ok( $key_before eq $key_after && $rc == 0,
    'hidden input : passwd cancelled, the old passphrase still opens' );

## esc at the lock prompt ends the session, the screen cleared again ##
( $out, $rc ) = session(
    { P7_VAULT_LOCK_SECONDS => 2 },
    [],
    [ 1, "pass phrase\r" ],
    [ 4, "\e" ]
);
my $clears = () = $out =~ m|\e\[3J|g;
ok( $clears >= 2 && $rc == 0, 'lock prompt : esc ends, cleared again' );

## :keep-open: never locks ##
( $out, $rc ) = session(
    { P7_VAULT_LOCK_SECONDS => 2 },
    [':keep-open:'],
    [ 1, "pass phrase\r" ],
    [ 4, "quit\r" ]
);
$plain = $out =~ s|\e\[[0-9;?]*[A-Za-z]||gr;
ok( $plain =~ m|auto-lock off| && $plain !~ m|locked after| && $rc == 0,
    ':keep-open: : no lock' );

## the hidden input buffer : what was typed, after editing, opens the vault ##
my $unlocked = sub {
    my ( $out, $rc ) = @ARG;
    my $plain = $out =~ s|\e\[[0-9;?]*[A-Za-z]||gr;
    return ( $plain =~ m|sync <host>| and $plain !~ m|wrong| and $rc == 0 );
};
( $out, $rc ) = session(
    {}, [':keep-open:'],
    [ 1,   "pass phrasX\x7fe\r" ],
    [ 0.6, "commands sync\r" ],
    [ 0.6, "quit\r" ]
);
ok( $unlocked->( $out, $rc ), 'hidden input : backspace over ascii' );

my $utf8_dir = "$tmp/vault-utf8";
vault_init(
    $utf8_dir, encode( 'UTF-8', "p\x{e4}ss phrase \x{fc}" ),
    undef,
    t => 1,
    m => 8192,
    p => 1
);
( $out, $rc ) = session(
    { '-d' => $utf8_dir },
    [':keep-open:'],
    ## typed only once raw mode is on : before it, the tty's own line editing
    ## erases one BYTE per backspace, half a utf-8 char
    [ 2.5, encode( 'UTF-8', "p\x{e4}ss phrase \x{fc}\x{fc}" ) . "\x7f\r" ],
    [ 0.6, "commands sync\r" ],
    [ 0.6, "quit\r" ]
);
ok( $unlocked->( $out, $rc ), 'hidden input : backspace over a utf-8 char' );

my $long     = join ' ', map {"word$ARG"} 1 .. 70;    ## ~ 450 bytes ##
my $long_dir = "$tmp/vault-long";
vault_init( $long_dir, $long, undef, t => 1, m => 8192, p => 1 );
( $out, $rc ) = session(
    { '-d' => $long_dir },
    [':keep-open:'],
    [ 1,   "$long\r" ],
    [ 1,   "commands sync\r" ],
    [ 0.6, "quit\r" ]
);
ok( $unlocked->( $out, $rc ),
    'hidden input : past the first buffer [ doubled, nothing lost ]' );

say "\npassed : $pass  failed : $fail";
exit( $fail ? 1 : 0 );

#,,..,.,.,.,,,..,,,..,,,.,,,.,,,,,,,.,.,.,,..,..,,...,...,,..,,,.,,.,,.,.,.,,,
#3VCDKYLDMGCOKW3DRZRYDAPLE4SUJIVBT3R7AWGBWDZIWVJIDJWWRKSYLY65WLQZZKQIETDRPJSP6
#\\\|UQBKXHZ6WZQ5R6UXDEXFWT3RIMDUC5UVSYWJOP2WLXJA2SR6L76 \ / AMOS7 \ YOURUM ::
#\[7]2HPDTQK2RSGMAYATE2ID4MDITJFLOS62P65VH53EMESADIJ27IDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
