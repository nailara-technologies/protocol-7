#!/bin/bash

script_path=`realpath $0`
bin_path=`dirname $script_path` # ./bin/dependencies/
NAILARA_ROOT=`realpath $bin_path/../..`

useradd -m -r nailara
ln -v -f -s $NAILARA_ROOT/bin/nailara /usr/local/bin/nailara
ln -v -f -s $NAILARA_ROOT/bin/nshell /usr/local/bin/nshell

cp -v $NAILARA_ROOT/lib/systemd/system/nailara.service /lib/systemd/system/

# dependencies for 'nroot','core','config', 'events' agents + nshell

apt-get -y install cpanminus git libevent-perl libproc-processtable-perl \
  libterm-readpassword-perl libterm-readline-gnu-perl libio-aio-perl libc6-dev \
  libclone-perl libhash-flatten-perl libhash-merge-simple-perl libjson-xs-perl \
  libio-socket-multicast-perl libfile-slurper-perl libtimedate-perl gcc make \
  libdigest-crc-perl libclass-accessor-lite-perl libc6-dev libsub-uplevel-perl \
  liburi-perl libbsd-resource-perl libcryptx-perl libtest-exception-perl \
  libdigest-jhash-perl libdigest-elf-perl libhttp-date-perl libnet-dns-perl \
  libtest-requires-perl libtest-sharedfork-perl libhttp-message-perl \
  libfile-which-perl libyaml-libyaml-perl &&

# no longer found: libmodule-build-pluggable-perl

cpanm Crypt::Ed25519 Digest::Skein Digest::BMW \
      File::MimeInfo::Magic Sys::Statistics::Linux::CpuStats URI::QueryParam &&

# Crypt::Curve25519 no longer compiles as orig., provided fixed copy locally now
cpanm $NAILARA_ROOT/lib/pm-src/crypt-curve25519  # until fmul issue fixed upstr.
cd $NAILARA_ROOT && git clean -fxd $NAILARA_ROOT/lib/pm-src

cpanm --force POSIX::1003 # <- temporary forced (localtime test fails) <<!>>

# LLL cpan2deb --recursive --build --install-deps --install-build-deps --install
