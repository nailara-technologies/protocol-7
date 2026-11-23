#!/usr/bin/env perl
use v5.32.0;
use strict;
use warnings;
use English;

## p7-wlan-helper against a fake wpa_supplicant control socket ##
## [ no root, no real wlan ]                                   ##

use Test::More;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;
use IPC::Open2 ();
use File::Spec ();
use Socket     qw| AF_UNIX SOCK_DGRAM pack_sockaddr_un |;
use Encode     ();
use IO::Select ();
use constant { TRUE => 5, FALSE => 0 };

our %data;
our %code;
our $call;

sub translate_code {
    my $code = shift;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>(?=->)}{chr(36).qq|code{'$1'}|}eg;
    $code =~ s{<\[([A-Za-z][-\w.]*)\]>}{chr(36).qq|code{'$1'}->()|}eg;
    $code =~ s{<([a-z][-\w.]*)>}{
        my @keys = split m|\.|, ${^CAPTURE}[0];
        chr(36).qq|data{'| . join( "'}{'", @keys ) . qq|'}|
    }ge;
    return $code;
}

sub load_src {
    my $name = shift;
    my $path = "$RealBin/../../src/$name";
    open my $fh, '<', $path or die "cannot read $path : $OS_ERROR";
    local $INPUT_RECORD_SEPARATOR;
    my $src = <$fh>;
    close $fh;
    my @seg = split m{('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|\#[^\n]*)}x,
        $src, -1;
    for ( my $i = 0; $i < @seg; $i += 2 ) {
        $seg[$i] = translate_code( $seg[$i] );
    }
    my $sub = eval 'sub { ' . join( '', @seg ) . ' }';
    die "compile error in $name : $EVAL_ERROR" if $EVAL_ERROR;
    $code{$name} = $sub;
}

my $root = tempdir( CLEANUP => 1 );
my $ctrl = "$root/ctrl";
mkdir $ctrl or die;
my $log = "$root/wpa.log";

## fake wpa_supplicant : answers, and logs what it received ##
my $fake_pid = fork() // die;
if ( $fake_pid == 0 ) {
    socket( my $s, AF_UNIX, SOCK_DGRAM, 0 )     or die;
    bind( $s, pack_sockaddr_un("$ctrl/wlan0") ) or die;
    my $next_id = 3;
    while (1) {
        my $from = recv( $s, my $cmd, 4096, 0 ) // next;
        open my $fh, '>>', $log or die;
        print $fh "$cmd\n";
        close $fh;
        my $answer
            = $cmd eq 'STATUS'
            ? "bssid=02:00:00:00:01:00\nfreq=2437\nssid=home "
            . "net\nwpa_state=COMPLETED\nip_address=192.0.2.9\n"
            : $cmd eq 'SCAN' ? "OK\n"
            : $cmd eq 'SCAN_RESULTS'
            ? "bssid / frequency / signal level / flags / ssid\n02:00:00:00:01:00\t2437\t-41\t[WPA2-PSK-CCMP][ESS]\thome net\n02:00:00:00:02:00\t5180\t-67\t[ESS]\tcafe\n"
            : $cmd eq 'LIST_NETWORKS' ? "network id / ssid / bssid / "
            . "flags\n0\thome "
            . "net\tany\t[CURRENT]\n"
            : $cmd eq 'ADD_NETWORK' ? ( $next_id++ ) . "\n"
            : $cmd =~ m|^SET_NETWORK \d+ ssid 6261640a| ? "FAIL\n"
            : $cmd
            =~ m{^(SET_NETWORK|SELECT_NETWORK|REMOVE_NETWORK|DISCONNECT) }
            ? "OK\n"
            : $cmd eq 'DISCONNECT' ? "OK\n"
            :                        "UNKNOWN COMMAND\n";
        ## an unsolicited event first, now and then ##
        send( $s, "<3>CTRL-EVENT-SCAN-STARTED", 0, $from ) if $cmd eq 'SCAN';
        send( $s, $answer,                      0, $from );
    }
}

my $helper = "$RealBin/../p7-wlan-helper";
our $hpid;
$hpid = IPC::Open2::open2( my $out, my $in, $^X, $helper, qw| -ctrl-dir |,
    $ctrl, qw| -timeout 2 | );
$in->autoflush(1);

sub ask {
    my @lines = @ARG;
    print $in map {"$ARG\n"} @lines;
    my $head = readline($out) // return ['eof'];
    chomp $head;
    my @body;
    if ( $head =~ m|^ok (\d+)$| ) {
        for ( 1 .. $1 ) { my $l = readline($out); chomp $l; push @body, $l }
    }
    return [ $head, @body ];
}

my $hex = sub { unpack 'H*', shift };

my $r = ask('status wlan0');
is $r->[0], 'ok 5', 'status ok';
ok( ( grep { $ARG eq 'ssid=home net' } @$r ),
    'status passes key=value lines'
);

$r = ask('scan wlan0');
is $r->[0], 'ok 0', 'scan skips the unsolicited event, OK';

$r = ask('scan-results wlan0');
is $r->[0], 'ok 3', 'scan results : header + 2';
like $r->[2], qr|^02:00:00:00:01:00\t2437\t-41\t|, 'scan result line kept';

$r = ask( 'connect wlan0 ' . $hex->('home net'), 'correct horse battery' );
is_deeply $r, [ 'ok 1', 'network 3' ], 'connect with passphrase';

$r = ask( 'connect wlan0 ' . $hex->('cafe'), '' );
is_deeply $r, [ 'ok 1', 'network 4' ], 'connect open network';

$r = ask( 'connect wlan0 ' . $hex->('home net'), 'short' );
like $r->[0], qr|^err secret not valid|, 'short passphrase refused';

$r = ask( 'connect wlan0 ' . $hex->("bad\n"), 'correct horse battery' );
like $r->[0], qr|^err wpa_supplicant refused SET_NETWORK|,
    'refused set reported';

## ssid forms : b32: [ any prefix case, padding optional ], hex:, bare hex ##
my $b32 = sub {
    my $bits = unpack( 'B*', $ARG[0] );
    $bits .= '0' x ( ( 5 - length($bits) % 5 ) % 5 );
    join '', map {
        substr( 'ABCDEFGHIJKLMNOP' . 'QRSTUVWXYZ234567', oct("0b$ARG"), 1 )
    } $bits =~ m|(.{5})|g;
};
$r = ask( 'connect wlan0 b32:' . $b32->('home net'),
    'correct horse battery' );
is_deeply $r, [ 'ok 1', 'network 6' ], 'ssid as b32:';
$r = ask( 'connect wlan0 B32:' . lc( $b32->('cafe') ) . '===', '' );
is_deeply $r, [ 'ok 1', 'network 7' ], 'B32: prefix, lowercase body, padding';
$r = ask( 'connect wlan0 HEX:' . $hex->('cafe'), '' );
is_deeply $r, [ 'ok 1', 'network 8' ], 'HEX: prefix';
$r = ask( 'connect wlan0 b32:189', 'correct horse battery' );
like $r->[0], qr|^err ssid must be|, 'b32 outside the alphabet refused';
$r = ask( 'connect wlan0 b32:' . $b32->( 'x' x 33 ),
    'correct horse battery' );
like $r->[0], qr|^err ssid must be|, 'b32 ssid over 32 bytes refused';

$r = ask('saved wlan0');
is $r->[0], 'ok 2', 'saved networks listed';

$r = ask('disconnect wlan0');
is $r->[0], 'ok 0', 'disconnect';

## validation : nothing of these reaches wpa_supplicant ##
my $before = -s $log;
foreach my $bad (
    ['reboot wlan0'],
    ['status'],
    ['status ../etc'],
    ['status wlan0 extra'],
    ['status wlan0;id'],
    [ 'connect wlan0',                  'secret-line-dropped' ],
    [ 'connect wlan0 ZZ',               'secret-line-dropped' ],
    [ 'connect wlan0 ' . ( 'aa' x 33 ), 'secret-line-dropped' ],
    ['SAVE_CONFIG wlan0'],
) {
    like ask(@$bad)->[0], qr|^err |, "refused : $bad->[0]";
}
is -s $log, $before, 'refused requests never reach wpa_supplicant';

$r = ask('status wlan9');
is $r->[0], 'err no control socket for this interface', 'missing socket';

close $in;
waitpid $hpid, 0;
is $CHILD_ERROR, 0, 'helper ends on eof';

open my $lfh, '<', $log or die;
my @sent = map { chomp; $ARG } <$lfh>;
close $lfh;
ok( !( grep {m|SAVE_CONFIG|} @sent ), 'SAVE_CONFIG never sent' );
ok( ( grep { $ARG eq 'SET_NETWORK 3 psk "correct horse battery"' } @sent ),
    'passphrase quoted' );
ok( ( grep { $ARG eq 'SET_NETWORK 4 key_mgmt NONE' } @sent ),
    'open network key_mgmt' );
ok( ( grep { $ARG eq 'SET_NETWORK 3 ssid ' . $hex->('home net') } @sent ),
    'ssid as hex' );
ok( ( grep {m|^REMOVE_NETWORK 5$|} @sent ),
    'failed connect removes its network'
);
ok( !( grep {m|secret-line-dropped|} @sent ),
    'dropped secret lines never sent'
);
ok( ( grep { $ARG eq 'SET_NETWORK 6 ssid ' . $hex->('home net') } @sent ),
    'b32 ssid sent as hex' );
ok( ( grep { $ARG eq 'SET_NETWORK 7 ssid ' . $hex->('cafe') } @sent ),
    'B32: ssid sent as hex' );

## zenka side : the network.wlan modules through a second helper ##
my @logs;
$code{'base.log'}  = sub { push @logs, $ARG[1]; TRUE };
$code{'base.logs'} = sub { shift; push @logs, sprintf( shift, @ARG ); TRUE };
$code{'base.perlmod.load'} = sub {TRUE};
$code{'base32.encode'}
    = sub { require Crypt::Misc; Crypt::Misc::encode_b32r( $ARG[0] ) };
$code{'network.interfaces.collect'} = sub {
    return { wlan0 => { type => 'wlan' }, eth0 => { type => 'wired' } };
};
load_src($ARG) for qw| network.wlan.request network.wlan.scan_parse
    network.wlan.iface network.wlan.vault_secret network.cmd.wlan-status
    network.cmd.wlan-scan network.cmd.wlan-connect network.cmd.wlan-disconnect |;

## fake p7-vault : 'get wlan:<ssid> password', a locked vault for 'locked' ##
my $vault = "$root/p7-vault";
open my $vfh, '>', $vault or die;
print $vfh <<'V';
#!/bin/sh
[ "$1" = get ] && [ "$3" = password ] || exit 2
case "$2" in
    'wlan:home net') printf 'correct horse battery\n' ;;
    *) echo 'no entry' >&2 ; exit 1 ;;
esac
V
close $vfh;
chmod 0755, $vault;
$data{'network'}{'cfg'}{'vault_bin'} = $vault;

sub cmd {
    my ( $name, $args ) = @ARG;
    our $call = { args => $args };
    return $code{"network.cmd.$name"}->();
}

my $r0 = cmd( 'wlan-status', '' );
like $r0->{'data'}, qr|helper not running|, 'no helper : clean refusal';

{ open( my $truncate, q|>|, $log ) or die; close $truncate; }
$hpid = IPC::Open2::open2( my $o2, my $i2, $^X, $helper, qw| -ctrl-dir |,
    $ctrl );
$i2->autoflush(1);
@{ $data{'network'}{'wlan'}{'helper'} }{qw| pid r_fh w_fh |}
    = ( $hpid, $o2, $i2 );

my $st = cmd( 'wlan-status', '' );
like $st->{'data'}, qr|^ssid\s+: home net$|m,   'status ssid';
like $st->{'data'}, qr|^state\s+: COMPLETED$|m, 'status state';
like $st->{'data'}, qr|^iface\s+: wlan0$|m,     'first wlan iface picked';
like cmd( 'wlan-status', 'eth0' )->{'data'}, qr|not a wlan|,
    'wired iface refused';

my $sc = cmd( 'wlan-scan', 'wlan0' );
like $sc->{'data'}, qr|^scan started|, 'scan started note';
like $sc->{'data'}, qr|^SSID\s+SIGNAL\s+FREQ\s+SECURITY\s+BSSID$|m,
    'scan header';
like $sc->{'data'}, qr|^home net\s+-41\s+2437\s+wpa2\s+02:00:00:00:01:00$|m,
    'scan row strongest first';
like $sc->{'data'}, qr|^cafe\s+-67\s+5180\s+open\s+|m, 'open network row';

my $c = cmd( 'wlan-connect', 'wlan0 home net' );
is $c->{'mode'}, 'true', 'connect from the vault';
like cmd( 'wlan-connect', 'wlan0 locked' )->{'data'},
    qr|^vault locked or no entry wlan:locked|, 'locked vault refused';
like cmd( 'wlan-connect', 'wlan0' )->{'data'}, qr|expected|,
    'missing ssid refused';
like cmd( 'wlan-connect', 'wlan0 ' . ( 'x' x 33 ) )->{'data'},
    qr|longer than 32|, 'long ssid refused';
is cmd( 'wlan-disconnect', '' )->{'mode'}, 'true', 'disconnect';
ok( !( grep {m|correct horse|} @logs ), 'secret never logged' );

close $i2;
waitpid $hpid, 0;
open $lfh, '<', $log or die;
my @sent2 = map { chomp; $ARG } <$lfh>;
close $lfh;
ok( ( grep {m|^SET_NETWORK \d+ psk "correct horse battery"$|} @sent2 ),
    'vault secret reached wpa_supplicant' );
ok( ( grep {m|^SELECT_NETWORK \d+$|} @sent2 ), 'network selected' );
ok( !( grep {m|SAVE_CONFIG|} @sent2 ),         'still no SAVE_CONFIG' );

my @leftover = glob( File::Spec->tmpdir . "/p7-wlan-$hpid-*" );
is scalar @leftover, 0, 'client sockets removed';

kill 9, $fake_pid;
waitpid $fake_pid, 0;

done_testing;

#,,,,,.,,,,,.,,.,,,,,,..,,,,,,,,.,,.,,...,,,.,..,,...,...,.,,,..,,...,,,,,.,.,
#H4WB2I4M6OGK5WV4WMJJOEJR32BMVCH676OCAPB3X2TPY3JZOEGK2C4HJTX5F3BOPPFKI5KLXF2YU
#\\\|HEETZWJIFVO3BMQWRRZB4FWNFYU7MXMLX6BJFGULJPQMBNSQ7LO \ / AMOS7 \ YOURUM ::
#\[7]ASNSMAWEPS4ZPFM325HRXC6ABZCZ3QS3B4TWTXA2HSS4N2NF3KCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
