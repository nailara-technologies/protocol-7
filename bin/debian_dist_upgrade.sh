#!/bin/bash

source /etc/os-release

export ACTION=dist-upgrade # upgrade | dist-upgrade

export PATH=/usr/sbin:/usr/bin:/sbin:/bin

export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
export PAGER=/bin/true

echo -e "\n:\n: starting $ID $ACTION ...\n:\n"


dpkg --configure -a ; apt-get -fy install # [automatic recovery, if required]

apt-get update && \
apt-get -fuy \
	-o Dpkg::Options::="--force-confnew" \
	-o Dpkg::Options::="--force-confdef" \
	-o Dpkg::Options::="--force-overwrite" $ACTION && \
	apt-get clean && \
	apt-get -y --purge autoremove && \
	echo -e "\n:\n: done.\n:\n"
