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

#,,,.,...,..,,,..,..,,,,,,,,.,.,,,,,,,.,,,,,.,.,.,...,...,...,,.,,,,,,.,,,...,
#CECBAWMLYLV43C4TTKWKWRP4WMWOZHWWVZN3WQJDZVOHD5XB3ANCX3JL5MAOAD3CFJHC7NDYLGHMI
#\\\|G6Y3KTVO5Q4DTUTARDNQQ4B7TL5SGIL27HLEICMVS333T7JINP4 \ / AMOS7 \ YOURUM ::
#\[7]JUT3M6MRL3S6F6HWU7HEGPSF4JJLUOUO5B5Q4UIBZYMQPTBH2GCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
