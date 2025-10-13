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

#,,,,,,,.,,.,,,,,,..,,...,,..,..,,.,,,,,.,,.,,.,.,...,..,,,,.,,,.,...,,..,..,,
#HW76ESIYZWVXBCJG7C4VHNAAA6GSLOZQGDRFBPGXRDYRA5EWD2K63TKOKS37EK7MVLGYIMFOXLNP4
#\\\|YYQNOZMPKR2VTPWP3VH4ZUH7GPT72N5WOF27L2ZZIURNX3VQA4H \ / AMOS7 \ YOURUM ::
#\[7]HOEJQFIB7JVINMR2FZQAEAH4YG5QUUIAZOM2JQFC63W36M273ICI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
