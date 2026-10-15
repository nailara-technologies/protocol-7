#!/usr/bin/perl
use v5.32.0;
use strict;
use English;
use warnings;

## an encrypted single-file key [ the .private alone ] through the real
## p7-keys in a pty : enc-key-chksum loads it via crypt.C25519.load_single.
## the same checksum on every load, another key another checksum, a wrong
## password refused [ the clamp bits of the decrypted key : a lone .private
## has no public key to compare with ], never the key's checksum.  [
## load_single stored decrypt_priv_keystr's reference until 2026-10-15 --
## harmless here, base.context.list dereferences it ]  throwaway keys, always
## removed [ END ] ; skips without p7-keys on PATH

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

my $key      = sprintf 'zz-single-%d',   $PID;
my $key_2    = sprintf 'zz-single-%d-2', $PID;
my $password = 'a throwaway single-file key password';

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

say ': encrypted single-file key, live [ real p7-keys in a pty ]';

my $rc;
my $out  = create_key($key);
my $find = sub { return key_file( $key, shift ) };
ok( defined $find->('private') && defined $find->('secret'),
    'a throwaway encrypted key [ .secret .private .public ]'
) or print $out;

## the checksum as a full key set [ load_keypair ] ##
( $out, $rc ) = p7_keys( [ qw| enc-key-chksum |, $key ],
    [ qr|key decryption password|, "$password\r" ] );
my ($full_sum) = $out =~ m|'\Q$key\E' :\s+(<:[A-Z2-7:]+:>)\s+::|;
ok( defined $full_sum, 'checksum as a full key set' ) or print $out;

## .secret and .public gone : the .private alone is a single-file key
## [ crypt.C25519.single_file ], loaded by load_single
foreach my $type (qw| secret public |) {
    my $file = $find->($type);
    unlink $file if defined $file;
}
ok( not( defined $find->('secret') or defined $find->('public') )
        && defined $find->('private'),
    'the .private alone left'
);

my @sums;
foreach my $run ( 1 .. 2 ) {
    ( $out, $rc ) = p7_keys(
        [ qw| enc-key-chksum |,        $key ],
        [ qr|key decryption password|, "$password\r" ],
        [ qr|re-enter|,                "$password\r" ]
    );
    my ($sum) = $out =~ m|'\Q$key\E' :\s+(<:[A-Z2-7:]+:>)\s+::|;
    push @sums, $sum;
    print $out if not defined $sum;
}
ok( defined $sums[0] && defined $sums[1] && $sums[0] eq $sums[1],
    'single-file : the same checksum twice' );
## [ not the full set's : that one covers the public key too ] ##
ok( defined $full_sum && defined $sums[0] && $sums[0] ne $full_sum,
    'single-file : its own checksum [ private key only ]'
);

## a lone .private has no public key to compare with : the clamp bits of the
## decrypted key are the check [ a random decryption keeps them 1 in 32 --
## three wrong passwords, at least one refused ; never the key's sum ]
my ( $refused, $matched ) = ( 0, 0 );
foreach my $wrong (
    'not the right password',
    'another wrong password',
    'and a third wrong one'
) {
    ( $out, $rc ) = p7_keys(
        [ qw| enc-key-chksum |,        $key ],
        [ qr|key decryption password|, "$wrong\r" ],
        [ qr|re-enter|,                "$wrong\r" ]
    );
    my ($wrong_sum) = $out =~ m|'\Q$key\E' :\s+(<:[A-Z2-7:]+:>)\s+::|;
    $refused++
        if $out =~ m|password is not correct| and not defined $wrong_sum;
    $matched++
        if defined $wrong_sum
        and defined $sums[0]
        and $wrong_sum eq $sums[0];
}
ok( $refused >= 1,
    "single-file : a wrong password " . "refused [ $refused of 3 ]" );
ok( not($matched),
    'single-file : a wrong password ' . 'never gives the key\'s checksum' );

## another key, the same password : another checksum ##
create_key($key_2);
my $sum_2 = single_sum( $key_2, $password );
ok( defined $sum_2 && defined $sums[0] && $sum_2 ne $sums[0],
    'single-file : another key, another checksum'
);

say "\npassed : $pass  failed : $fail";
exit( $fail ? 1 : 0 );

#,,,,,,,.,.,.,.,.,,,,,...,.,.,,..,,..,.,,,,,,,..,,...,...,..,,...,...,..,,,,.,
#BF26KDAV7WIB4CQBJVTH4TIAQFOSPH66SV546MQSIE5H7LQQDPPROYHGZRVDIJ5XLADFQNHYA5VLG
#\\\|L3462LEGUYYBOK34QQOCBG7B2PBJNR7CT7KGQR2Q27N5VHSTD5M \ / AMOS7 \ YOURUM ::
#\[7]DQ2TORV46NPCFF4YFDFKG23UI52RDMNUNMWMRRAPCJITUE5RMICI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
