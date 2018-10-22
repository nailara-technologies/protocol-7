#!/bin/sh

NAILARA_ROOT=/usr/local/nailara

useradd -m -r nailara
ln -v -f -s $NAILARA_ROOT/bin/nailara /usr/local/bin/nailara
ln -v -f -s $NAILARA_ROOT/bin/nshell /usr/local/bin/nshell

cp -v $NAILARA_ROOT/lib/systemd/system/nailara-root.service /lib/systemd/system/

# dependencies for 'root','core','config', 'events' agents + nshell

apt-get -y install cpanminus libevent-perl libproc-processtable-perl \
  libterm-readpassword-perl libterm-readline-perl-perl libdigest-sha-perl \
  libclone-perl libhash-flatten-perl libhash-merge-simple-perl libjson-xs-perl \
  libio-socket-multicast-perl libfile-slurper-perl libtimedate-perl gcc make \
  libdigest-crc-perl libclass-accessor-lite-perl libc6-dev \
  liburi-perl libbsd-resource-perl libcryptx-perl \
  libtest-requires-perl libtest-sharedfork-perl libmodule-build-pluggable-perl &&

cpanm POSIX::1003 Crypt::Curve25519 Crypt::Ed25519 Digest::Skein Digest::BLAKE2 \
      File::MimeInfo::Magic Sys::Statistics::Linux::CpuStats URI::QueryParam


# XXX cpan2deb --recursive --build --install-deps --install-build-deps --install
