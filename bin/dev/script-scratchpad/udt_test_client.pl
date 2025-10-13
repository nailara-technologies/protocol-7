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

#,,,.,...,..,,,..,..,,,,,,,,.,.,,,,,,,.,,,,,.,.,.,...,...,...,.,.,,,.,...,.,.,
#NNNCQCKRKLN6UUTV7G6C6EH5CR6Y3VLC32N3P26JRKXI5OGTAJ6IWAIROZNZ5YALDEIKV246ZCA52
#\\\|5WJKOWGQO4FL3H6F3DTNIZ4CCOJTB3CTLN4EZCEHKSZWQO2R3AH \ / AMOS7 \ YOURUM ::
#\[7]KRKEQQDLQT43KOEJLUL4VD7IF4VZLDWVGKZHIHFWSDAMKHSJ2ABY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
