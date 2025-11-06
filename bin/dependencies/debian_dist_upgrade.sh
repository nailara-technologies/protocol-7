#!/bin/bash

source /etc/os-release

export ACTION=dist-upgrade # upgrade | dist-upgrade

export PATH=/usr/sbin:/usr/bin:/sbin:/bin

export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
export UCF_FORCE_CONFMISS=true
export UCF_FORCE_CONFOLD=true
export PAGER=/bin/true

echo -e "\n:\n: starting $ID $ACTION ...\n:\n"

dpkg --force-confold --force-confdef --force-confmiss --force-overwrite \
    --configure -a ; apt-get -fy install # [automatic recovery, if required]

apt-get -y $ACTION

pam-auth-update --force

rm -rf /var/cache/apt/mediainfo_tmp*

apt-get update && \
apt-get -fy \
	-o Dpkg::Options::="--force-confold" \
	-o Dpkg::Options::="--force-confdef" \
	-o Dpkg::Options::="--force-confmiss" \
	-o Dpkg::Options::="--force-overwrite" $ACTION && \
	apt-get clean && apt-get -y --purge autoremove && \
	echo -e "\n:\n: done.\n:\n"

rm -rf /var/cache/apt/mediainfo_tmp*
rm -rf /root/.cpanm

# dpkg -l | grep '^rc' | awk '{print $2}' | xargs dpkg --purge 2>/dev/null

#,,,.,..,,,,.,,.,,.,,,.,,,.,,,.,,,,,.,.,,,,.,,..,,...,...,...,..,,,.,,..,,..,,
#LQLGBUZY6OWLURJZQKZ7A2UOBUINGXSHGL6W7GWFSVK37M4FJECBQIK5DTS5GOQZMJDAOZ6FP67L2
#\\\|TKSR5SBDYKLPW5B2EP5QPWWZRSKHD2Q4HCUUCSQE7X2IXWYZFQO \ / AMOS7 \ YOURUM ::
#\[7]LHWD3VTYUNKZC6SERBA2XIX5CVG4FLSV7G34MFCFY6YYLDPE6YDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
