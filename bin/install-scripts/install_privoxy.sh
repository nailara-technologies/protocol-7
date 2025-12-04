#!/bin/sh

SCRIPT=$(readlink -f $0)
BINDIR=$(echo $SCRIPT|sed 's/\/[^\/]*$//')
PBLSH="$BINDIR/privoxy-blocklist.sh"

set -x

apt-get -y install privoxy

sed 's/^listen-address\s*localhost/listen-address  127.0.0.1/' -i /etc/privoxy/config
sed 's/^keep-alive-timeout/#keep-alive-timeout/' -i /etc/privoxy/config # speeding up

echo y | $PBLSH -r # remove old blocklists
$PBLSH            # download adblock lists

systemctl restart privoxy

#,,..,.,,,.,.,.,,,,,.,...,.,.,,.,,...,...,...,..,,...,...,,.,,,,,,...,,..,,..,
#3QGB42LGNPSXNGBC72HPGL322RJLF6F35TLLULQDESLVPFWRKSP6TFVX6KBKJEPAJ6TVTY4A2B2GO
#\\\|THIPQL2V3J2GQIC5CZ36ELGNYJJQ5OURXSGHGCCRXHCL2252LIE \ / AMOS7 \ YOURUM ::
#\[7]OQUF6OH5R327CBNP6P5KCEQ4I7I4A7QUAHVYGVJ6O3VKQHBJF6CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
