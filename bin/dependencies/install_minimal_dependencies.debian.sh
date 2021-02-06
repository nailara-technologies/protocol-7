#!/bin/bash

script_path=`realpath $0`
bin_path=`dirname $script_path` # ./bin/dependencies/
NAILARA_ROOT=`realpath $bin_path/../..`

( id nailara || useradd -m -r nailara ) 2>&1 >/dev/null
ln -f -s $NAILARA_ROOT/bin/protocol-7 /usr/local/bin/protocol-7
ln -f -s $NAILARA_ROOT/bin/nshell /usr/local/bin/nshell

cp $NAILARA_ROOT/lib/systemd/system/protocol-7.service /lib/systemd/system/

# dependencies for 'nroot','core','config', 'events' agents + nshell

apt-get -y install cpanminus git libevent-perl libproc-processtable-perl \
  libterm-readpassword-perl libterm-readline-gnu-perl libio-aio-perl libc6-dev \
  libclone-perl libhash-flatten-perl libhash-merge-simple-perl libjson-xs-perl \
  libio-socket-multicast-perl libfile-slurper-perl libtimedate-perl gcc make \
  libdigest-crc-perl libclass-accessor-lite-perl libc6-dev libsub-uplevel-perl \
  liburi-perl libbsd-resource-perl libcryptx-perl libtest-exception-perl \
  libdigest-jhash-perl libdigest-elf-perl libhttp-date-perl libnet-dns-perl \
  libtest-requires-perl libtest-sharedfork-perl libhttp-message-perl \
  libfile-which-perl libyaml-libyaml-perl libfile-extattr-perl \
  libbsd-resource-perl liburi-query-perl libconfig-simple-perl \
  libfile-finder-perl libmce-perl libperl-critic-perl libppix-utilities-perl &&

# no longer found: libmodule-build-pluggable-perl

cpanm Crypt::Ed25519 Digest::Skein Digest::BMW Net::IP::Lite \
      File::MimeInfo::Magic Sys::Statistics::Linux::CpuStats URI::QueryParam

# Crypt::Curve25519 no longer compiles as orig., provided fixed copy locally now
#                                                until fmul issue fixed upstream
perl -Mv5.13 -e \
 'my$M="Crypt::Curve25519";eval"require $M";exit(1)if$@;say"$M is installed.,"'||
  cpanm $NAILARA_ROOT/lib/pm-src/crypt-curve25519 &&
    cd $NAILARA_ROOT && git clean -fxd $NAILARA_ROOT/lib/pm-src

# 'c-trade'-agent requirements..,
perl -Mv5.13 -e \
 'my$M="Poloniex::API";eval"require $M";exit(1)if$@;say"$M is installed .,"'||
cpanm --force Poloniex::API
perl -Mv5.13 -e \
 'my$M="Bittrex::API";eval"require $M";exit(1)if$@;say"$M is installed ..,"'||
cpanm https://github.com/jheddings/bittrex.git

# LLL cpan2deb --recursive --build --install-deps --install-build-deps --install
