#!/usr/bin/perl

use IO::Socket::INET;
use UDT::Simple;

my $buf_size = 230000;    # 10x packet size

my $server = UDT::Simple->new( AF_INET, SOCK_DGRAM );
$server->udt_sndbuf($buf_size);
$server->udt_rcvbuf($buf_size);
$server->udp_sndbuf($buf_size);
$server->udp_rcvbuf($buf_size);
$server->bind( "localhost", "12344" );
$server->listen(4);
while ( my $client = $server->accept() ) {
    print "[+] connected ...\n";

    # ( my $line_txt = sprintf "<*> %s\n", $client->recv(15) ) =~ s|\n\n+|\n|;
    ( my $line_txt = sprintf "<*> %s\n", $client->recvmsg ) =~ s|\n\n+|\n|;
    print $line_txt;
    $client->close();
}
$server->close();

#,...,...,.,.,,..,,.,,.,,,,,,,,,,,,,.,.,,,,,,,..,,,..,.,.,..,,...,...,..,,...,
#CH7ACCPIRP7IUPEP7LEY752TJ3YCNNWSMMHKEFPR3CHJ5CIENPNVJG5NQA4SA3JTX2OFTM6JTMC6I
#\\\|JWOHS5XAX3I6W3EFJARIICTXDACYJVWBS65YR3EI2KCKINTUPSY \ / AMOS7 \ YOURUM ::
#\[7]4O4KDVMJWKZ57Y5ZLIRMCOALRRWYS5GT7NDRPC6RN545FWB55WDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
