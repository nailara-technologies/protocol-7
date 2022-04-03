#!/bin/bash

script_path=`realpath $0`
bin_path=`dirname $script_path` # ./bin/dependencies
NAILARA_ROOT=`realpath $bin_path/../..`
EXT_LIB_PATH="$NAILARA_ROOT/data/lib-path"

ln -f -s $NAILARA_ROOT/bin/Protocol-7 /usr/local/bin/Protocol-7
ln -f -s $NAILARA_ROOT/bin/nshell /usr/local/bin/nshell

cp $EXT_LIB_PATH/systemd/system/Protocol-7.service /lib/systemd/system/

# dependencies for 'nroot','core','config', 'events' agents + nshell

apt-get -y install gcc git make cpanminus libc6-dev libc6-dev libmce-perl \
            liburi-perl libclone-perl libevent-perl libcryptx-perl \
            libio-aio-perl libjson-xs-perl libnet-dns-perl libtimedate-perl \
            libhttp-date-perl liburi-query-perl libdigest-crc-perl \
            libdigest-elf-perl libfile-which-perl libfile-finder-perl \
            libperl-critic-perl libsub-uplevel-perl libbsd-resource-perl \
            libbsd-resource-perl libdigest-jhash-perl libfile-extattr-perl \
            libfile-slurper-perl libhash-flatten-perl libhttp-message-perl \
            libyaml-libyaml-perl libconfig-simple-perl libio-socket-ssl-perl \
            libtest-requires-perl libppix-utilities-perl shared-mime-info \
            libtest-exception-perl libtest-sharedfork-perl libcurses-perl \
            libhash-merge-simple-perl libproc-processtable-perl \
            libterm-readline-gnu-perl libterm-readpassword-perl \
            liblwp-protocol-https-perl libclass-accessor-lite-perl \
            libio-socket-multicast-perl libinline-c-perl libconst-fast-perl \
            liblwpx-paranoidagent-perl liblinux-inotify2-perl \
            libio-compress-perl libcapture-tiny-perl libfreezethaw-perl &&

# no longer found: libmodule-build-pluggable-perl

## required in bin/dev/..,
#
apt-get -y install libterm-size-perl \
  libunicode-string-perl libunicode-maputf8-perl

cpanm Crypt::Ed25519 Digest::Skein Digest::BMW Net::IP::Lite URI::QueryParam \
  File::MimeInfo::Magic Sys::Statistics::Linux::CpuStats \
  SigAction::SetCallBack Crypt::Twofish2 Config::Hosts

## [ LLL ] ### repair path[?] ###

# Crypt::Curve25519 no longer compiles as orig., provided fixed copy locally now
#                                                until fmul issue fixed upstream
perl -Mv5.13 -e \
'my$M="Crypt::Curve25519";eval"require $M";exit(1)if$@;say"$M is installed.,"'||
  cpanm $EXT_LIB_PATH/pm-src/crypt-curve25519 &&
    cd $NAILARA_ROOT && git clean -fxd $EXT_LIB_PATH/pm-src

# 'c-trade'-agent requirements..,
perl -Mv5.13 -e \
  'my$M="Poloniex::API";eval"require $M";exit(1)if$@;say"$M is installed .,"'||
  cpanm --force Poloniex::API
perl -Mv5.13 -e \
  'my$M="Bittrex::API";eval"require $M";exit(1)if$@;say"$M is installed ..,"'||
  cpanm --force https://github.com/jheddings/bittrex.git

# LLL cpan2deb --recursive --build --install-deps --install-build-deps --install

#,,,.,...,.,,,...,.,,,...,..,,.,.,,.,,.,,,...,..,,...,...,..,,,.,,..,,,..,.,,,
#4JKBEUQGR747YMN53BIZLVRXDIJ6S3ZYQRTV4BCLV5L37JAXOZCT7MVTVXR2E3NCWI3IPH6BYUZF6
#\\\|KLDFYS6HLSPKNJLMVIEWSXTZKEM2R3WSOHBJCDBFOUPSPIHRCNR \ / AMOS7 \ YOURUM ::
#\[7]7NVN7SQDSROBYGHICM3SKBZQBQBNQCRFUH32QUJRKBP3PGZOTMCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
