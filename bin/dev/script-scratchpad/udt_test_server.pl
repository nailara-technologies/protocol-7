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

#,,,.,..,,.,.,,.,,..,,,,,,.,,,..,,,,.,,.,,,,.,..,,...,..,,,,.,...,,,.,,,,,,,,,
#2JZKSG2DKN6EUD2WKR5TXXNUNQLMITVAXKLAPCMBXLB3UX7D72LDDA46DR52ASZ5WGCNYFHT5RKDY
#\\\|CREVH5PMS4ITMVFNT45WKIR2JB344ZYI7OWUVX2PJPGUG3HKJ4Q \ / AMOS7 \ YOURUM ::
#\[7]VQDLH35DI3YOLLL4PLDAYUS7U2AL4KYWERULWGGI7GKUQQNBDCBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
