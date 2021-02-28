#!/bin/bash

script_path=`realpath $0`
bin_path=`dirname $script_path` # ./bin/dependencies/
NAILARA_ROOT=`realpath $bin_path/../..`

ln -f -s $NAILARA_ROOT/bin/protocol-7 /usr/local/bin/protocol-7
ln -f -s $NAILARA_ROOT/bin/nshell /usr/local/bin/nshell

cp $NAILARA_ROOT/lib/systemd/system/protocol-7.service /lib/systemd/system/

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
            libtest-requires-perl libppix-utilities-perl \
            libtest-exception-perl libtest-sharedfork-perl \
            libhash-merge-simple-perl libproc-processtable-perl \
            libterm-readline-gnu-perl libterm-readpassword-perl \
            liblwp-protocol-https-perl libclass-accessor-lite-perl \
            libio-socket-multicast-perl &&

# no longer found: libmodule-build-pluggable-perl

cpanm Crypt::Ed25519 Digest::Skein Digest::BMW Net::IP::Lite SigAction::SetCallBack \
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
cpanm --force https://github.com/jheddings/bittrex.git

# LLL cpan2deb --recursive --build --install-deps --install-build-deps --install

# ______________________________________________________________________________
#\\D4JBANUQPJYENLXF33EPWKZO26LCH642VAV6KXHEVGNWCJKIOK57Q36KXVYEI4F4RNG6ORSGNL6ZK
# \\ Q7BXEMPMXUD2ORILML5HHKUHTUYQ3SFUQFFZDWFQSHOHHANIEV3L \\// C25519-BASE-32 //
#  \\// ZQQE7SLBVSPNNSRXAWPYVKAX6FWEPSWPGJTLHF42VTA5MNIW2AY \\ CODE SIGNATURE \\
#   ````````````````````````````````````````````````````````````````````````````
