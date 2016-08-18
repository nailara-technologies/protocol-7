#!/bin/sh

export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none

apt-get update && \
apt-get -fuy \
	--no-allow-insecure-repositories \
	-o Dpkg::Options::="--force-confnew" \
	-o Dpkg::Options::="--force-confdef" \
	-o Dpkg::Options::="--force-overwrite" dist-upgrade && \
	apt-get clean && \
	apt-get -y --purge autoremove && \
	echo done.
