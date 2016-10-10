#!/usr/bin/perl

use IO::Socket::Multicast;

die "\n usage: $0 <test_message>\n\n" if !@ARGV;

my $msg  = join( ' ', @ARGV );
my $addr = '239.23.5.42';

#my $addr = '239.84.87.67';

my $port = 242;
my $ttl  = 1;

my $sock = IO::Socket::Multicast->new(
    'Proto'     => 'udp',
    'PeerAddr'  => $addr,
    'PeerPort'  => $port,
    'ReuseAddr' => 1
) or die $!;

$sock->mcast_ttl($ttl) or die $!;

$sock->mcast_send( $msg, "$addr:$port" ) or die $!;
