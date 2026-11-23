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
    sys_class_net  => $sys,
    proc_root      => "$root/proc",
    resolv_conf    => "$root/etc/resolv.conf",
    ifupdown_conf  => "$root/etc/network/interfaces",
    ifupdown_state => "$root/run/network/ifstate",
};
$data{'network'}{'lease'} = {};
my @logged;
$code{'base.log'} = sub { push @logged, $ARG[1]; return TRUE };
put( "$root/run/network/ifstate", "lo=lo\neth0=eth0\n" );
$code{'network.interfaces.ip_addr_text'} = sub { return $ip_text };
load_src($ARG) for qw| network.read_line network.interfaces.ip_addr_parse
    network.interfaces.collect network.cmd.interfaces
    network.status.default_route network.status.dns_servers
    network.status.backend network.cmd.status
    network.cmd.event network.cmd.leases network.cmd.macs |;

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

## a debian base ships interfaces with lo only : not ifupdown ##
put( "$root/run/network/ifstate", "lo=lo\n" );
is $code{'network.status.backend'}->()->{'backend'}, 'dhcpcd',
    'lo-only ifstate is not ifupdown';
put( "$root/etc/network/interfaces",
          "auto lo\niface lo inet loopback\nallow-hotplug "
        . "eth0\niface eth0 inet dhcp\n" );
is $code{'network.status.backend'}->()->{'backend'}, 'ifupdown-idle dhcpcd',
    'configured but not up';
put( "$root/etc/network/interfaces", "auto lo\niface lo inet loopback\n" );
put( "$root/proc/104/comm",          "systemd-network\n" );
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

## macs : wired + wlan only ##
is $code{'network.cmd.macs'}->()->{'data'},
    "eth0 52:54:00:aa:bb:01 wired\neth1 52:54:00:aa:bb:02 "
    . "wired\nwlan0 52:54:00:aa:bb:03 wlan\n",
    'macs lists wired and wlan';

## dhcpcd hook : fake env -> fake p7c -> args -> net.event -> leases ##
my $out  = "$root/p7c.args";
my $fake = "$root/bin/p7c";
put( $fake,
          "#!/bin/sh\nprintf '%s\\n' \"\$*\" "
        . "> $out.tmp && mv $out.tmp $out\n" );
chmod 0755, $fake;
my $hook = "$RealBin/../dhcpcd-hook/50-protocol-7-net";
{
    local %ENV = (
        PATH                    => "$root/bin:/usr/bin:/bin",
        P7_NET_P7C              => 'p7c',
        reason                  => 'BOUND',
        interface               => 'eth0',
        new_ip_address          => '192.0.2.7',
        new_subnet_cidr         => '24',
        new_routers             => '192.0.2.1',
        new_domain_name_servers => '192.0.2.1 192.0.2.53',
        new_domain_name         => 'lan',
        new_dhcp_lease_time     => '86400',
    );
    my $rc = system( qw| sh -c |,
        ". '$hook'; echo rest-of-hooks-ran > $root/after" );
    is $rc, 0, 'sourced hook returns 0';
}
ok -e "$root/after", 'hook does not exit the sourcing shell';
for ( 1 .. 50 ) { last if -e $out; select( undef, undef, undef, 0.1 ) }
open my $afh, '<', $out or die "hook never called p7c";
chomp( my $args = <$afh> );
close $afh;
is $args,
    'net.event BOUND eth0 ip=192.0.2.7 prefix=24 routers=192.0.2.1 '
    . 'dns=192.0.2.1,192.0.2.53 domain=lan lease=86400', 'hook args';
{
    local %ENV = (
        PATH       => "/usr/bin:/bin",
        P7_NET_P7C => "p7c-not-installed",
        reason     => 'BOUND',
        interface  => 'eth0'
    );
    is system( qw| sh -c |, ". '$hook'" ), 0, 'missing p7c is quiet';
}
( $call = { args => $args } )->{'args'} =~ s|^net\.event ||;
is $code{'network.cmd.event'}->()->{'mode'}, 'true', 'event accepted';
is_deeply $data{'network'}{'lease'}{'eth0'}{'dns'},
    [ '192.0.2.1', '192.0.2.53' ], 'dns kept as list';
like $logged[-1], qr|net\.event BOUND eth0|, 'event logged';
foreach my $bad (
    'BOUND',
    'bound eth0',
    'BOUND eth0;rm',
    'BOUND eth0 evil=1',
    'BOUND eth0 ip=1.2.3.4;x',
    'BOUND eth0 ip'
) {
    $call = { args => $bad };
    is $code{'network.cmd.event'}->()->{'mode'}, 'false', "refused : $bad";
}
is scalar keys $data{'network'}{'lease'}->%*, 1,
    'refused events store nothing';
my $l = $code{'network.cmd.leases'}->()->{'data'};
like $l, qr|^IFACE\s+REASON\s+AGE\s+ADDRESS\s+ROUTERS\s+DNS|, 'leases header';
like $l,
    qr|^eth0\s+BOUND\s+\d+ s\s+192\.0\.2\.7/24\s+192\.0\.2\.1\s+192\.0\.2\.1 192\.0\.2\.53$|m,
    'leases row';
note $l;

done_testing;

#,,,.,...,,..,.,.,.,.,,..,,..,,,,,,,,,,.,,...,..,,...,..,,..,,...,...,,..,,..,
#L7PLFU3RCU7A2SNJ7C2QUVK5D3JEMKUIDMGRRQPTMM2CTS4VDBMTVS4CSWQHVAOGU2UPSTADEASLW
#\\\|HY2XCST42DMVMCHTVKHWZCHVX5DCJJQ7UIZJKYZVDTACZYUYINO \ / AMOS7 \ YOURUM ::
#\[7]UNQR6SSDEMVLEZHIAA3DXSRIWZQPZCGNHWEIGFA6K37R7725PSDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
