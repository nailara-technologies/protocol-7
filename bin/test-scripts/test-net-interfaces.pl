#!/usr/bin/env perl
use v5.32.0;
use strict;
use warnings;
use English;

use Test::More;
use FindBin    qw| $RealBin |;
use File::Temp qw| tempdir |;

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

sub put {
    my ( $path, $text ) = @ARG;
    ( my $dir = $path ) =~ s|/[^/]+$||;
    system( qw| mkdir -p |, $dir ) == 0 or die "mkdir $dir";
    open my $fh, '>', $path or die "cannot write $path : $OS_ERROR";
    print $fh $text;
    close $fh;
}

my $root = tempdir( CLEANUP => 1 );
my $sys  = "$root/sys/class/net";
my %fake = (
    lo => {
        type      => 772,
        address   => '00:00:00:00:00:00',
        operstate => 'unknown',
        carrier   => 1
    },
    eth0 => {
        type      => 1,
        address   => '52:54:00:aa:bb:01',
        operstate => 'up',
        carrier   => 1,
        speed     => 1000,
        device    => 1
    },
    eth1 => {
        type      => 1,
        address   => '52:54:00:aa:bb:02',
        operstate => 'down',
        carrier   =>  0,
        speed     => -1,
        device    => 1
    },
    wlan0 => {
        type      => 1,
        address   => '52:54:00:aa:bb:03',
        operstate => 'dormant',
        device    => 1,
        wireless  => 1
    },
    br0 => {
        type      => 1,
        address   => '52:54:00:aa:bb:04',
        operstate => 'up',
        carrier   => 1
    },
);
foreach my $name ( keys %fake ) {
    my $f = $fake{$name};
    foreach my $key (qw| type address operstate carrier speed |) {
        put( "$sys/$name/$key", "$f->{$key}\n" ) if defined $f->{$key};
    }
    put( "$sys/$name/device/uevent", '' )           if $f->{'device'};
    system( qw| mkdir -p |, "$sys/$name/wireless" ) if $f->{'wireless'};
}
my $ip_text = <<'IP';
1: lo    inet 127.0.0.1/8 scope host lo\       valid_lft forever preferred_lft forever
1: lo    inet6 ::1/128 scope host noprefixroute \       valid_lft forever preferred_lft forever
2: eth0    inet 192.0.2.7/24 brd 192.0.2.255 scope global dynamic eth0\       valid_lft 85000sec
2: eth0    inet6 2001:db8::7/64 scope global dynamic mngtmpaddr \       valid_lft 86000sec
2: eth0    inet6 fe80::5054:ff:feaa:bb01/64 scope link \       valid_lft forever
5: br0@NONE    inet 198.51.100.1/24 scope global br0\       valid_lft forever
IP
put( "$root/proc/net/route", <<'RT' );
Iface	Destination	Gateway 	Flags	RefCnt	Use	Metric	Mask		MTU	Window	IRTT
eth0	00000000	0102000A	0003	0	0	202	00000000	0	0	0
eth0	0002000A	00000000	0001	0	0	202	00FFFFFF	0	0	0
br0	00000000	FE6433C6	0003	0	0	100	00000000	0	0	0
RT
put( "$root/proc/net/ipv6_route",
    "00000000000000000000000000000000 00 00000000000000000000000000000000 00 "
        . "fe800000000000000000000000000001 00000400 00000001 00000000 "
        . "00000003     eth0\n20010db8000000000000000000000000 40 "
        . "00000000000000000000000000000000 00 "
        . "00000000000000000000000000000000 00000100 00000001 00000000 "
        . "00000001     eth0\n" );
put( "$root/proc/101/comm", "dhcpcd\n" );
put( "$root/proc/102/comm", "wpa_supplicant\n" );
put( "$root/proc/103/comm", "bash\n" );
put( "$root/etc/resolv.conf",
          "# generated\nsearch lan\nnameserver "
        . "192.0.2.1\nnameserver 2001:db8::1\n" );
put( "$root/etc/network/interfaces", "auto lo\niface lo inet loopback\n" );

$data{'network'}{'cfg'} = {
    sys_class_net => $sys,
    proc_root     => "$root/proc",
    resolv_conf   => "$root/etc/resolv.conf",
    ifupdown_conf => "$root/etc/network/interfaces",
};
$code{'network.interfaces.ip_addr_text'} = sub { return $ip_text };
load_src($ARG) for qw| network.read_line network.interfaces.ip_addr_parse
    network.interfaces.collect network.cmd.interfaces
    network.status.default_route network.status.dns_servers
    network.status.backend network.cmd.status |;

my $i = $code{'network.interfaces.collect'}->();
is_deeply [ sort keys %$i ], [qw| br0 eth0 eth1 lo wlan0 |],
    'all interfaces found';
is $i->{'lo'}{'type'},      'loopback',          'lo is loopback';
is $i->{'eth0'}{'type'},    'wired',             'eth0 with device is wired';
is $i->{'wlan0'}{'type'},   'wlan',              'wireless dir means wlan';
is $i->{'br0'}{'type'},     'virtual',           'no device means virtual';
is $i->{'eth0'}{'speed'},   1000,                'speed read';
is $i->{'eth1'}{'speed'},   undef,               'speed -1 is unknown';
is $i->{'wlan0'}{'speed'},  undef,               'missing speed is unknown';
is $i->{'eth1'}{'carrier'}, 0,                   'carrier down';
is $i->{'eth0'}{'mac'},     '52:54:00:aa:bb:01', 'mac read';
is_deeply $i->{'eth0'}{'ipv4'}, ['192.0.2.7/24'], 'eth0 ipv4';
is_deeply $i->{'eth0'}{'ipv6'},
    [ '2001:db8::7/64', 'fe80::5054:ff:feaa:bb01/64' ], 'eth0 ipv6';
is_deeply $i->{'br0'}{'ipv4'}, ['198.51.100.1/24'],
    'iface@peer name stripped';
is_deeply $i->{'lo'}{'ipv6'}, ['::1/128'], 'lo ipv6';

my $t = $code{'network.cmd.interfaces'}->()->{'data'};
like $t, qr|^IFACE\s+TYPE\s+MAC\s+STATE\s+CARRIER\s+SPEED\s+ADDRESSES|,
    'table header';
like $t,
    qr|^eth0\s+wired\s+52:54:00:aa:bb:01\s+up\s+up\s+1000 Mb/s\s+192\.0\.2\.7/24|m,
    'eth0 row';
like $t, qr|^eth1\s+wired\s+\S+\s+down\s+down\s+-\s+-$|m, 'eth1 row unknowns';
my @len = map { index( $ARG, 'TYPE' ) } ( split m|\n|, $t )[0];
ok( ( grep { substr( $ARG, $len[0] - 1, 1 ) eq ' ' } split m|\n|, $t ) == 6,
    'columns aligned' );

my $r = $code{'network.status.default_route'}->();
is $r->{'ipv4'}{'iface'},   'br0',            'lowest metric default wins';
is $r->{'ipv4'}{'gateway'}, '198.51.100.254', 'little endian gateway';
is $r->{'ipv6'}{'iface'},   'eth0',           'ipv6 default iface';
is $r->{'ipv6'}{'gateway'}, 'fe80:0:0:0:0:0:0:1', 'ipv6 gateway';
is_deeply $code{'network.status.dns_servers'}->(),
    [ '192.0.2.1', '2001:db8::1' ], 'dns servers';
my $b = $code{'network.status.backend'}->();
is $b->{'backend'}, 'ifupdown+dhcpcd', 'backend ifupdown + dhcpcd';
is_deeply $b->{'running'}, [qw| dhcpcd wpa_supplicant |], 'running daemons';

put( "$root/proc/104/comm", "systemd-network\n" );
unlink "$root/etc/network/interfaces";
unlink "$root/proc/101/comm";
is $code{'network.status.backend'}->()->{'backend'}, 'networkd',
    'truncated comm finds networkd';
unlink "$root/proc/104/comm";
is $code{'network.status.backend'}->()->{'backend'}, 'none',
    'nothing running is none';

my $s = $code{'network.cmd.status'}->()->{'data'};
like $s, qr|^default ipv4 : br0 via 198\.51\.100\.254$|m,
    'status default route';
like $s, qr|^dns\s+: 192\.0\.2\.1 2001:db8::1$|m, 'status dns';
note $t, $s;

done_testing;

#,,,.,.,,,.,.,,.,,.,.,,..,.,.,..,,..,,,.,,,,,,..,,...,...,,.,,..,,,.,,,..,..,,
#HHHQETXF7BNMSA2P5TNE4BWBBB7XOXHTOPZAQWWC5IXHE3AK7HIYWQK6RXO3FEZQGWC2U44EZEPPI
#\\\|QDEJFC56YXG622MMKGLGZ3F57UHLHT22XCWGAXBWV6DEGTMGO7J \ / AMOS7 \ YOURUM ::
#\[7]T3JEHR6AA4HQKNVXXTJDPIG2OIA2BUVSX3STULMLA7KMJW6M46BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
