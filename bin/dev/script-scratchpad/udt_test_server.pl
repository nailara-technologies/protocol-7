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

#,,,,,,,.,,.,,,,,,..,,...,,..,..,,.,,,,,.,,.,,.,.,...,...,.,,,,..,,..,.,,,.,,,
#7ARD5L3FRCACH6DBXQENDOHG63SCPECCVP2FFXYSSVILGWDGFFHGXRTZB75YRQZ53H3PBPDLWAQYO
#\\\|AMRNVQQ73VSCP4MFU6SZX7ZTFQKKNRSSTFWVKVXKC7M7QINMFTC \ / AMOS7 \ YOURUM ::
#\[7]KLTGB4NTKOG72XZ6SCRUDNA4RQNJLTUVDA6DHYQVC4PDNRGU7OAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
