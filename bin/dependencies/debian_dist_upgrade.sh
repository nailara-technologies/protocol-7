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

#.............................................................................
#DBADJ3O2KOFVNF3EKSL2TKVF6Y3ND3ELDKN4X6NHRLIQGZAEJCC7MVYG2ZKYRJ445RZVML542FI2A
#::: GDLAU77RRKH2WKSUYDT7JFKTIIEP7CTYSO6YFRIWFOXNXLDXYYL :::: NAILARA AMOS :::
# :: NC2WYUQZ64HADA76MRVJAYTKGMDEODHENJNVBPGU2PQ3XEAU2ODY :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
