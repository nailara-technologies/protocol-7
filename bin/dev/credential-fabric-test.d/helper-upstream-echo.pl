#!/usr/bin/perl

# [ helper: start a local upstream echo server for manual exploration ]

use v5.24;
use strict;
use warnings;
use English;

use File::Spec;
use IO::Socket::IP;
use FindBin qw| $RealBin |;
use lib File::Spec->catdir( $RealBin, 'lib' );
use CredFabTest qw| start_echo_server temp_dir |;

my $port     = $ARGV[0] // 0;
my $log_file = $ARGV[1] // File::Spec->catfile( temp_dir(), 'echo.log' );

if ( not $port ) {
    # [ pick a free high port ]
    my $tmp = IO::Socket::IP->new(
        LocalHost => '127.0.0.1',
        LocalPort => 0,
        Type      => SOCK_STREAM(),
        Listen    => 1,
    );
    $port = $tmp->sockport;
    $tmp->close;
}

my $pid = start_echo_server( $port, $log_file );
print "echo server pid=$pid port=$port log=$log_file\n";

# [ keep running until stdin closes or signal ]
$SIG{'TERM'} = $SIG{'INT'} = sub { exit 0 };
sleep 3600;

# [ end ]

#,,,.,.,,,...,,,,,,,.,,.,,,..,...,...,,.,,,.,,..,,...,...,,..,.,,,,..,,,,,...,
#C57FWZIPLIJUQMKQFFME2Q7NDMJKGAVMRBQSZ26NOFDEM3XEU4WGWBAO42ST4XWVZM2WUICWHKMHE
#\\\|5EFK3FSXOYK25XACHQA7VLXME3EAHNEIPBS7VCRO6JY5G675CWF \ / AMOS7 \ YOURUM ::
#\[7]NO2XS2PH6IJAVY7NDPDBJTCKJP5SOFXWN3FOQDJC3KXEUPJEH4BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
