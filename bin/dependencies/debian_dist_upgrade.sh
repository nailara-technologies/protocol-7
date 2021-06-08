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

#,,.,,,..,..,,,,.,..,,,,,,...,.,.,,,,,,.,,,..,..,,...,...,,..,,..,..,,,.,,.,,,
#KDVHXB2FFRQXYJQ5NVGWIUJT4I77UXGEKVMGR6S7FSP46FV56CHXKN36TDZJE3PDIYZDKQT2WXT6A
#\\\|E3HOBQCGYTFINZXOMAUVFKPBECMTTLY6G7V2DWFLY4XTIXH7AWG \ / AMOS7 \ YOURUM ::
#\[7]WSWXROEEBPEBZ7I5GJUB3VCSIXT5BQMDSW7WZOGA3KYXEYZMFICA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
