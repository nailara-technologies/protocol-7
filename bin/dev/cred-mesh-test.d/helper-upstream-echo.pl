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
use CredMeshTest qw| start_echo_server temp_dir |;

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

#,,,.,,..,...,,,.,,,.,,.,,.,.,.,.,,,,,,..,...,..,,...,...,,,.,..,,,.,,,,,,,.,,
#JDA6JU3Z3V6AI7JZFPAXCDDZFMOQ3WMYZLZPBFSH57N4NS25XD3ZK2RRIN7ULXFPOLMLQBVJFSP7M
#\\\|35USYUOWAOGL7GGMI3CQ5BX4DGQFOZ4CVC62UI4O4GJ6ERYD6M3 \ / AMOS7 \ YOURUM ::
#\[7]FIOIAKFJPKZQLI4VY6YSANHHKNOPDDDT4Y4JIH3OAHGVBMSZLUDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
