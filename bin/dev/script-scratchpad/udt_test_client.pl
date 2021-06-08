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

#,...,..,,,,,,,.,,,,,,,..,.,.,,,,,,,.,.,,,...,.,,,,,.,.,.,..,,.,.,..,,,,,,,,.,
#I6XBJ4NZXMTAUAI5V55GFWAQF5G3KDWZZZLFZTTWHNSAFZU5QJSQQE2XCJFAK3V6TOMGKEV4GX62A
#\\\|LYWMLKWCKMVZXC3RZJLHMHDELNVIDCQ5ZUBH2UZR7JD46BFBS2N \ / AMOS7 \ YOURUM ::
#\[7]6IVUFYWN4B7PBSLPAQMLQJNJRITM3TSMA73QPT5SYOQVAQ4QZYAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
