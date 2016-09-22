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
  libtimedate-perl gcc make

cpanm Crypt::PRNG::Fortuna POSIX::1003

# XXX cpan2deb --recursive --build --install-deps --install-build-deps --install
