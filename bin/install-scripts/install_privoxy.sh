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
