#!/bin/sh

NAILARA_ROOT=/usr/local/nailara

useradd -r nailara
ln -v -s $NAILARA_ROOT/bin/nailara /usr/bin/nailara
ln -v -s $NAILARA_ROOT/bin/nshell /usr/bin/nshell

cp -v $NAILARA_ROOT/lib/systemd/system/nailara-root.service /lib/systemd/system/

# dependencies for 'root','core','config', 'events' agents + nshell

apt-get -y install cpanminus libevent-perl libproc-processtable-perl \
  libterm-readpassword-perl libterm-readline-perl-perl libdigest-sha-perl \
  libclone-perl libhash-flatten-perl libhash-merge-simple-perl libjson-xs-perl \
  libio-socket-multicast-perl libfile-slurper-perl libtimedate-perl gcc make \
  libio-all-perl libdigest-crc-perl libclass-accessor-lite-perl libc6-dev \
  libbsd-resource-perl

cpanm CryptX POSIX::1003 Crypt::Curve25519 Crypt::Ed25519 Digest::Skein \
      https://github.com/gitpan/Module-Build-Pluggable-XSUtil.git Digest::BLAKE2 \
      File::MimeInfo::Magic Sys::Statistics::Linux::CpuStats


# XXX cpan2deb --recursive --build --install-deps --install-build-deps --install
