#!/usr/bin/perl

use IO::Socket::INET;
use UDT::Simple;

my $buf_size = 230000;    # 10x packet size

my $u = UDT::Simple->new( AF_INET, SOCK_DGRAM );
$u->udt_sndbuf($buf_size);
$u->udt_rcvbuf($buf_size);
$u->udp_sndbuf($buf_size);
$u->udp_rcvbuf($buf_size);

$u->connect( "localhost", "12344" );

# if the socket is SOCK_STREAM send() might not send the whole thing
my $message = "another world!\n";
$u->sendmsg($message);

# if it is SOCK_DGRAM the whole message will be sent
# $u->send($message);
$u->close();

#,,,.,...,..,,,..,..,,,,,,,,.,.,,,,,,,.,,,,,.,.,.,...,...,.,,,..,,.,,,,,,,,.,,
#6XFZC6AI2Q7ECK647S4H35JJYY6BHUSG5JBY6TJQWSCQN75SCDFW6F6IZSHYRAYD7CG4OVKUKRTKM
#\\\|UXFJZAOAJLGH4LCQXQLC4KXGXKQDLBDTOIP5OCDMUQHCF2IKCBO \ / AMOS7 \ YOURUM ::
#\[7]EW5UPK5GHKKHPYDPFCHKBGQONM5ANRY4UCGKXRVMUEC3ACZI7GDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
