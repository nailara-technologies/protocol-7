#!/bin/sh

export PATH=/usr/sbin:/usr/bin:/sbin:/bin

export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
export PAGER=/bin/true

echo "\n:\n: starting dist-upgrade ...\n:\n"

apt-get update && \
apt-get -fuy \
	--no-allow-insecure-repositories \
	-o Dpkg::Options::="--force-confnew" \
	-o Dpkg::Options::="--force-confdef" \
	-o Dpkg::Options::="--force-overwrite" dist-upgrade && \
	apt-get clean && \
	apt-get -y --purge autoremove && \
	echo "\n:\n: done.\n:\n"
