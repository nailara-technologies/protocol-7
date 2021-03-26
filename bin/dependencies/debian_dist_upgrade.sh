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
#GFTLYACCDZJGEJUJXS6AKIILWLJBZ4CE3ASAK2H6J6O3U624HM7QB2PK2U44FG5EKFCE2BYQXK46I
#::: 75CROPF3SXIYYRA5EOYBQK4IGHM5MPVWO4MCA7HA65XGCUTCU6Y :::: NAILARA AMOS :::
# :: OB5AQSAAXSIKKPX6ZY5EZIVN5G3WD5XKBW4HZDVBDL5A4X6M5MCI :: CODE SIGNATURE ::
# ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
