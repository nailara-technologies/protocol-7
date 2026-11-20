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
my $delay_ms    = 40;
my $stall_ms    = 120;
GetOptions(
    'listen-port=i' => \$listen_port,
    'target-port=i' => \$target_port,
    'loss=f'        => \$loss,
    'delay-ms=f'    => \$delay_ms,
    'stall-ms=f'    => \$stall_ms,
) or die "invalid options\n";
die "ports and loss 0..100 required\n"
    if $listen_port < 1
    or $target_port < 1
    or $loss < 0
    or $loss > 100;

my $listener = IO::Socket::INET->new(
    LocalAddr => '127.0.0.1',
    LocalPort => $listen_port,
    Proto     => 'tcp',
    Listen    => 1,
    ReuseAddr => 1,
) or die "relay listen failed : $!\n";
my $client = $listener->accept or die "relay accept failed : $!\n";
my $server = IO::Socket::INET->new(
    PeerAddr => '127.0.0.1',
    PeerPort => $target_port,
    Proto    => 'tcp',
) or die "relay target failed : $!\n";
$listener->close;
$client->blocking(0);
$server->blocking(0);

my $running = 1;
local $SIG{'TERM'} = sub { $running = 0 };
local $SIG{'INT'}  = sub { $running = 0 };
my @sockets       = ( $client, $server );
my $readers       = IO::Select->new(@sockets);
my @queue         = ( [], [] );
my @blocked_until = ( 0, 0 );

while ($running) {
    my $writers = IO::Select->new;
    for my $direction ( 0, 1 ) {
        my $front = $queue[$direction][0];
        $writers->add( $sockets[$direction] )
            if defined $front and $front->[1] <= time;
    }
    my ( $readable, $writable )
        = IO::Select->select( $readers, $writers, undef, 0.005 );
    for my $socket ( $readable->@* ) {
        my $source = $socket == $client ? 0 : 1;
        my $target = 1 - $source;
        my $read   = sysread( $socket, my $payload, 65536 );
        next if not defined $read or $read == 0;
        my $due = time + $delay_ms / 1000;
        if ( rand(100) < $loss ) {
            $due = $blocked_until[$target]
                if $blocked_until[$target] > $due;
            $due += $stall_ms / 1000;
            $blocked_until[$target] = $due;
        } elsif ( $blocked_until[$target] > $due ) {
            $due = $blocked_until[$target] + $delay_ms / 1000;
        }
        push $queue[$target]->@*, [ $payload, $due ];
    }
    for my $socket ( $writable->@* ) {
        my $direction = $socket == $client ? 0 : 1;
        my $chunk     = $queue[$direction][0];
        my $written   = syswrite( $socket, $chunk->[0] );
        if ( defined $written ) {
            if ( $written == length $chunk->[0] ) {
                shift $queue[$direction]->@*;
            } else {
                substr( $chunk->[0], 0, $written, '' );
            }
        }
    }
}

#,,,,,,.,,,,,,.,.,.,,,,,.,...,..,,.,.,,,,,..,,..,,...,...,...,.,,,.,,,.,.,.,,,
#WKM5Z6SPULYGXV32RTP6YCOLERM7IHBKEEGV6FNJYQL55V3JMYDOWBZK35TARFTYRQU5BPROGPOYQ
#\\\|7PYSOSELBAUTSWM36M4WKHTPVE2RVFMECF7AFZ3WYIX3LIX7K3I \ / AMOS7 \ YOURUM ::
#\[7]COOHB57KHH4FATBBNV5LIT7YDUPOTT2Z2RYSIFV4T5WM6HJKQWCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
