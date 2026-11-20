#!/usr/bin/perl

use v5.32.0;
use strict;
use warnings;
use Getopt::Long qw| GetOptions |;
use IO::Select;
use IO::Socket::INET;
use Time::HiRes qw| time |;

my $listen_port = 0;
my $target_port = 0;
my $loss        = 0;
my $burst       = 1;
my $delay_ms    = 40;
GetOptions(
    'listen-port=i' => \$listen_port,
    'target-port=i' => \$target_port,
    'loss=f'        => \$loss,
    'burst=i'       => \$burst,
    'delay-ms=f'    => \$delay_ms,
) or die "invalid options\n";
die "ports, loss 0..100 and burst >= 1 required\n"
    if $listen_port < 1
    or $target_port < 1
    or $loss < 0
    or $loss > 100
    or $burst < 1;

my $incoming = IO::Socket::INET->new(
    LocalAddr => '127.0.0.1',
    LocalPort => $listen_port,
    Proto     => 'udp',
) or die "relay listen failed : $!\n";
my $outgoing = IO::Socket::INET->new(
    PeerAddr => '127.0.0.1',
    PeerPort => $target_port,
    Proto    => 'udp',
) or die "relay target failed : $!\n";

my $running = 1;
local $SIG{'TERM'} = sub { $running = 0 };
local $SIG{'INT'}  = sub { $running = 0 };
my $readers = IO::Select->new( $incoming, $outgoing );
my @queue   = ( [], [] );
my @peers   = ( undef, undef );
my @bursts  = ( 0,     0 );

sub drop_datagram {
    my $direction = shift;
    return 1 if $bursts[$direction]-- > 0;
    if ( $burst > 1 ) {
        return 0 if rand(100) >= $loss / $burst;
        $bursts[$direction] = $burst - 1;
        return 1;
    }
    return rand(100) < $loss;
}

while ($running) {
    my $writers = IO::Select->new;
    for my $direction ( 0, 1 ) {
        my $front = $queue[$direction][0];
        $writers->add( $direction == 0 ? $outgoing : $incoming )
            if defined $front and $front->[1] <= time;
    }
    my ( $readable, $writable )
        = IO::Select->select( $readers, $writers, undef, 0.01 );
    for my $socket ( $readable->@* ) {
        my $direction = $socket == $incoming ? 0 : 1;
        next if $direction == 1 and not defined $peers[1];
        $socket->recv( my $payload, 65535 );
        next                          if not length $payload;
        $peers[1] = $socket->peername if $direction == 0;
        next                          if drop_datagram($direction);
        my $due = time + $delay_ms / 1000;
        push $queue[$direction]->@*, [ $payload, $due ];
    }
    for my $socket ( $writable->@* ) {
        my $direction = $socket == $outgoing ? 0 : 1;
        my $packet    = shift $queue[$direction]->@*;
        if ( $direction == 0 ) {
            $socket->send( $packet->[0] );
        } else {
            $socket->send( $packet->[0], 0, $peers[1] );
        }
    }
}

#,,..,.,,,,,.,.,,,,.,,,,,,,.,,,.,,.,,,...,.,.,..,,...,...,...,..,,.,,,,,,,,,.,
#T3TOPRJD7ZSEES4DEB6DF6XS2VVIASQZTTSS4RNMU3RRAZRXFNYB5IZQD4G2UMM7LQGKL6ZMNFXPQ
#\\\|TLAQQG7BIXA5UYCVFFG5YVTITVKVJWMHPVNPUULYXSI26EDZO5U \ / AMOS7 \ YOURUM ::
#\[7]QU5ECVCCU5JAXZOGTBVWQ4PJ7BNAN2X6IC24AMKZLSBRZWOROKBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
