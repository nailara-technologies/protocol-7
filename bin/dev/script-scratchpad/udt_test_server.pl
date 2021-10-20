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

#,,,,,,,.,,.,,,,,,..,,...,,..,..,,.,,,,,.,,.,,.,.,...,...,,,,,,,,,..,,...,.,.,
#SR6OPEKBJLGDBP6QVV5IAVIGUXV5UVS6BVCJTI5KRALB5WOQYOTN7TF3OZ4IS2I2LSEFK6TSQMJWA
#\\\|SBOVVIFTA2JAVLBQCZEFVPBND5XCV4XPLKE7F7CJ6RGS5H4SFS6 \ / AMOS7 \ YOURUM ::
#\[7]2C3G5LBV4UHNSAQCFJBFPWP555DW6PX4XPYFFJT3SDNUWDLQX6BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
