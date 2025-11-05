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

#,,,.,...,,..,...,.,.,.,.,..,,,,.,...,..,,,.,,..,,...,..,,..,,.,,,,..,.,.,,..,
#FT6GU6CKJI2HIYLKP2XDKFGOALGWMPVC6TLQ6SJT3MH6OZYYXCYHSWNX276VJ5TVVENL7ZZDIK3EQ
#\\\|O5WQ2V5UEHMZT5CU7GSZ5RW4LYQZCV2A23S6VDFFETNPA2VJTHP \ / AMOS7 \ YOURUM ::
#\[7]ZRNVX6JWRFDW6PFOT3RIOLIAHKBWY75KU5SDBCTKHEC247JVPSBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
