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

#.............................................................................
#2XWZNR5URUUUGWVW3G3CDNLYN2PX7CKL4JX7PPNBYB7WU56P7K4HGN3KYS43S2BMNY7VZSJKJICDI
#::: WHARPIOQU65LDJXNI55UXXW5SUVM4XTD7EB3YMC7EKUTRZVZC2J :::: NAILARA AMOS :::
# :: PKEQNAQ5IDYFOE7I6OM5DV7VZ7A4KYWAOEUW3ZQHODJPLBYD6GCA :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
