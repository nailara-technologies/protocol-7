#!/bin/bash

script_path=`realpath $0`
bin_path=`dirname $script_path` # ./bin/dependencies
NAILARA_ROOT=`realpath $bin_path/../..`
EXT_LIB_PATH="$NAILARA_ROOT/data/lib-path"

## unit file \ links : bin/p7-deps install-service at the end [ it needs ##
## the perl modules installed below ]                                   ##

### dependencies for 'v7-zenki', 'cube', 'p7-log', 'system', 'httpd',
##                   'events' and some non-X11 zenki agents + nshell

apt-get -y install gcc git make cpanminus libc6-dev libmce-perl \
            liburi-perl libclone-perl libevent-perl libcryptx-perl \
            libcrypt-argon2-perl \
            libio-stringy-perl liblist-moreutils-perl libio-aio-perl \
            libjson-xs-perl libnet-dns-perl libtimedate-perl \
            libhttp-date-perl liburi-query-perl libdigest-crc-perl \
            libdigest-elf-perl libfile-which-perl libfile-finder-perl \
            libperl-critic-perl libsub-uplevel-perl libbsd-resource-perl \
            libdigest-jhash-perl libfile-extattr-perl \
            libfile-slurper-perl libhash-flatten-perl libhttp-message-perl \
            libyaml-libyaml-perl libyaml-tiny-perl libconfig-simple-perl \
            libio-socket-ssl-perl libtest-requires-perl \
            libppix-utilities-perl shared-mime-info libtest-exception-perl \
            libtest-sharedfork-perl libcurses-perl \
            libhash-merge-simple-perl libproc-processtable-perl \
            libterm-readline-gnu-perl libterm-readpassword-perl \
            libterm-readkey-perl liblinux-termios2-perl \
            libterm-clui-perl \
            libcompress-raw-lzma-perl liblwp-protocol-https-perl \
            libanyevent-http-perl libasync-interrupt-perl libguard-perl \
            libclass-accessor-lite-perl libio-socket-multicast-perl \
            libinline-c-perl libconst-fast-perl liblwpx-paranoidagent-perl \
            liblinux-inotify2-perl libio-compress-perl \
            libcapture-tiny-perl libfreezethaw-perl libcrypt-dev \
            libio-compress-lzma-perl libgit-wrapper-perl \
            libconvert-asn1-perl libdata-uuid-perl libnet-ssh2-perl \
            libcrypt-openssl-x509-perl libcrypt-openssl-bignum-perl \
            libcrypt-openssl-random-perl libcrypt-openssl-rsa-perl &&

# no longer found: libmodule-build-pluggable-perl

## required in bin/dev/..,
#
apt-get -y install libterm-size-perl \
  libunicode-string-perl libunicode-maputf8-perl

cpanm Crypt::Ed25519 Digest::Skein Digest::BMW Net::IP::Lite URI::QueryParam \
  File::MimeInfo::Magic Sys::Statistics::Linux::CpuStats \
  SigAction::SetCallBack Config::Hosts Tie::Dir Filesys::Fuse3

## [ LLL ] ### repair path[?] ###

# Crypt::Curve25519 no longer compiles as orig., provided fixed copy locally now
#                                                until fmul issue fixed upstream
perl -Mv5.13 -e \
'my$M="Crypt::Curve25519";eval"require $M";exit(1)if$@;say"$M is installed.,"'||
  cpanm $EXT_LIB_PATH/pm-src/crypt-curve25519 &&
    cd $NAILARA_ROOT && git clean -fxd $EXT_LIB_PATH/pm-src

## the unit [ compared first, written atomically, systemd reloaded after a ##
## change -- a plain cp left 'changed on disk' until a manual reload ],   ##
## /usr/local/protocol-7 + launcher symlinks ; never starts or restarts   ##
$NAILARA_ROOT/bin/p7-deps install-service

# LLL cpan2deb --recursive --build --install-deps --install-build-deps --install

#,,,,,.,,,,,.,,..,,..,..,,,,.,,.,,..,,,.,,,,.,..,,...,..,,...,...,,.,,..,,.,,,
#X4EOCDRMW4UGV6H6YD2PTLB3DO7ZHTIEF77UP7LDCYSLBNGLRROP6FPNYKKPWATZ6F7NYULSUXP5Y
#\\\|ANXH4Q6WR244OJXVYGXNWTVYGAOT6ZOYCAUXMEU46TCO6E3B6RY \ / AMOS7 \ YOURUM ::
#\[7]Y6LTQ53CAH762ETTTG5GCIDSFCRQB7ZKWO7KL27JSSAOZVY7F6CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
