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

#.............................................................................
#ILPR34TAD4IF65ZU3DCYJT6FRISX4BFAQGHBK4IFAQDHZMEJWBH7RYNDYTEYTZ3SPFPGQKG6MN5JQ
#::: TC2DAGAB7KGWV2327TB52KJRB43TXIJUMHCFSTS45X6GOX3BWYK :::: NAILARA AMOS :::
# :: 72KY255DRWFBPEZL7LPSNHMOX5OURLKEG32UPEQHCLFBDBSWPABA :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
