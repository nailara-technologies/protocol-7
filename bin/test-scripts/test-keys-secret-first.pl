#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## crypt.C25519.load_keypair takes .secret first : ONE unlock derives both
## halves, .private is the fallback for an unusable .secret. every file set
## gives the same checksum with exactly one password prompt ; a wrong password
## is refused. throwaway keys, always removed [ END ] ; skips without p7-keys
## on PATH

use IO::Pty;
use POSIX       ();
use Time::HiRes qw| time sleep |;

##[ global constants ]##
use constant TRUE  => 5;    ##  TRUE.  ##
use constant FALSE => 0;    ##  false  ##

my ( $pass, $fail ) = ( 0, 0 );

sub ok {
    my ( $cond, $name ) = @ARG;
    if   ($cond) { $pass++; say "  ok    $name" }
    else         { $fail++; say "  FAIL  $name" }
    return $cond;
}

my ($p7_keys) = grep { -x "$ARG/p7-keys" } split m|:|, $ENV{'PATH'} // '';
if ( not defined $p7_keys ) {
    say '  skip : no p7-keys on PATH';
    exit 0;
}
$p7_keys .= '/p7-keys';

my $key      = sprintf 'zz-secret-first-%d',   $PID;
my $key_2    = sprintf 'zz-secret-first-%d-2', $PID;
my $password = 'a throwaway secret-first key password';

## p7-keys in a pty : @steps are [ text to wait for, keys to type ] ; returns
## ( everything it printed, colors removed, exit code )
sub p7_keys {
    my ( $args, @steps ) = @ARG;
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
        ## block : no warning ##
        { exec $p7_keys, @{$args} }
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
    my $seen = 0;    ## each wait looks past the text matched before ##
    foreach my $step (@steps) {
        my ( $wait, $keys ) = @{$step};
        my $found = FALSE;
        my $end   = time + 60;
        while ( time < $end ) {
            my $plain = substr( $out, $seen ) =~ s|\e\[[0-9;?]*[A-Za-z]||gr;
            if ( $plain =~ $wait ) {
                $found = TRUE;
                $seen  = length $out;
                last;
            }
            $read_for->(0.2);
        }
        last if not $found;
        sleep 0.3;
        foreach my $byte ( split m||, $keys ) {
            syswrite $pty, $byte;
            sleep 0.02;
        }
    }
    my $rc;
    my $end = time + 90;
    while ( time < $end ) {
        $read_for->(0.2);
        if ( waitpid( $pid, POSIX::WNOHANG() ) == $pid ) {
            $rc = $CHILD_ERROR >> 8;
            last;
        }
    }
    if ( not defined $rc ) {    ## a hung command is a failure, not a hang ##
        kill 'KILL', $pid;
        waitpid $pid, 0;
        $rc = 'hung';
    }
    $read_for->(0.5);
    close $pty;
    return ( $out =~ s|\e\[[0-9;?]*[A-Za-z]||gr, $rc );
}

my %created;

END {    ## the throwaway keys go, whatever happened ##
    p7_keys( [ qw| remove |, $ARG ], [ qr|\[\s*y/N\s*\]|i, "y\r" ] )
        foreach sort keys %created;
}

## an encrypted key : created, returns the create output ##
sub create_key {
    my $name = shift;
    my ($out) = p7_keys(
        [ qw| create |,                               $name ],
        [ qr|enter C25119 key encryption passphrase|, "$password\r" ],
        [ qr|re-enter|,                               "$password\r" ]
    );
    $created{$name} = TRUE;
    return $out;
}

## a key's file of one type, or undef ##
sub key_file {
    my ( $name, $type ) = @ARG;
    my @hits = grep {-f} glob "$ENV{HOME}/.n/user-keys/$name.$type";
    return $hits[0];
}

## its single-file checksum [ the .secret and .public removed first ] ##
sub single_sum {
    my ( $name, $typed ) = @ARG;
    foreach my $type (qw| secret public |) {
        my $file = key_file( $name, $type );
        unlink $file if defined $file;
    }
    my ($out) = p7_keys(
        [ qw| enc-key-chksum |,        $name ],
        [ qr|key decryption password|, "$typed\r" ],
        [ qr|re-enter|,                "$typed\r" ]
    );
    return ( $out =~ m|'\Q$name\E' :\s+(<:[A-Z2-7:]+:>)\s+::| )[0];
}

## the checksum and the number of password prompts ##
sub load_sum {
    my ( $name, $typed ) = @ARG;
    my ( $out,  $rc )    = p7_keys( [ qw| enc-key-chksum |, $name ],
        [ qr|key decryption password|, "$typed\r" ] );
    my ($sum) = $out =~ m|'\Q$name\E' :\s+(<:[A-Z2-7:]+:>)\s+::|;
    ## masked input redraws the prompt on its own line : count line starts ##
    my $prompts = ()
        = $out =~ m{(?:\A|\n)[:\s]*enter [^\n]*?key decryption password}g;
    return ( $sum, $prompts, $out );
}

## files of a key : saved \ restored around each variant ##
sub save_files {
    my $name = shift;
    my %saved;
    foreach my $type (qw| secret private public |) {
        my $file = key_file( $name, $type ) // next;
        open( my $fh, '<:raw', $file ) or die "$file : $OS_ERROR";
        local $INPUT_RECORD_SEPARATOR;
        $saved{$type} = [ $file, scalar <$fh> ];
    }
    return \%saved;
}

sub restore_files {
    my $saved = shift;
    foreach my $entry ( values $saved->%* ) {
        my ( $file, $data ) = $entry->@*;
        open( my $fh, '>:raw', $file ) or die "$file : $OS_ERROR";
        print {$fh} $data;
        close $fh;
        chmod 0600, $file;
    }
}

say ': .secret first, .private fallback, live [ real p7-keys in a pty ]';
my $out = create_key($key);
ok( defined key_file( $key, 'secret' ) && defined key_file( $key, 'private' ),
    'a throwaway encrypted key [ .secret .private .public ]'
) or print $out;
my $saved = save_files($key);

my ( $full_sum, $prompts, $o ) = load_sum( $key, $password );
ok( defined $full_sum, 'full key set : checksum' )                or print $o;
ok( $prompts == 1,     "full key set : one prompt [ $prompts ]" ) or print $o;

unlink key_file( $key, 'private' );
my ($sum) = load_sum( $key, $password );
ok( defined $sum && $sum eq ( $full_sum // '' ),
    '.secret + .public : same checksum'
);
restore_files($saved);

unlink key_file( $key, 'secret' );
( $sum, $prompts, $o ) = load_sum( $key, $password );
ok( defined $sum && $sum eq ( $full_sum // '' ),
    '.private + .public : same checksum'
) or print $o;
restore_files($saved);

## an unusable .secret [ wrong length ] : .private takes over ##
{
    open( my $fh, '>', key_file( $key, 'secret' ) ) or die $OS_ERROR;
    print {$fh} "AAAA\n";
    close $fh;
}
( $sum, $prompts, $o ) = load_sum( $key, $password );
ok( defined $sum && $sum eq ( $full_sum // '' ),
    'unusable .secret : .private fallback, same checksum'
) or print $o;
ok( $prompts == 1, "unusable .secret : one prompt [ $prompts ]" ) or print $o;
restore_files($saved);

( $sum, undef, $o ) = load_sum( $key, 'not the password' );
ok( not( defined $sum and $sum eq ( $full_sum // '' ) ),
    'wrong password : refused' )
    or print $o;

say sprintf ': %d passed, %d failed', $pass, $fail;
exit( $fail ? 1 : 0 );

#,,,,,,,.,,..,,..,.,.,,,.,,,.,,..,,.,,,..,,,,,..,,...,..,,,..,...,,,.,,.,,,..,
#5IVFL4S33AFUYK3C2SW7YLH6E6D44EFINW5CL44YEUK5TJ7VNVUH2BXZKCWNNTZTIIVWZ2MQW5B4M
#\\\|E2W63RBCOI7FOKWR6Z3VVEBMWQBGFGPF6JV4D5RQRX2FYIME7XD \ / AMOS7 \ YOURUM ::
#\[7]SZXYCF3PTOUEWE65FGEJM3TJIKQALUFOKR7SSEULFAKXRGBARWBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
