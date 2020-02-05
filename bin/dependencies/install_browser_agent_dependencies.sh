#!/bin/sh

# a crude dependency installation script for browser agent + some infrastructure

script_path=`realpath $0`
bin_path=`dirname $script_path` # ./bin/dependencies/
NAILARA_ROOT=`realpath $bin_path/../..`

apt-get update

apt-get -y install pciutils cpanminus libevent-perl libproc-processtable-perl \
  libterm-readpassword-perl libterm-readline-gnu-perl libio-aio-perl \
  libclone-perl libhash-flatten-perl libhash-merge-simple-perl libjson-xs-perl \
  libio-socket-multicast-perl libfile-slurper-perl libtimedate-perl gcc make \
  libdigest-crc-perl libclass-accessor-lite-perl libc6-dev libglib-perl \
  libx11-protocol-perl libx11-protocol-other-perl \
  libx11-keyboard-perl liblinux-inotify2-perl openbox hsetroot xvfb \
  libgtk3-webkit2-perl libtest-needsdisplay-perl libcryptx-perl \
  libextutils-pkgconfig-perl libextutils-depends-perl libhttp-message-perl \
  libhttp-date-perl libdigest-elf-perl libglib2.0-dev libsoup2.4-dev

cpanm Crypt::Ed25519 Digest::Skein Glib::Event

# Crypt::Curve25519 no longer compiles as orig., provided fixed copy locally now
cpanm $NAILARA_ROOT/lib/pm-src/crypt-curve25519  # until fmul issue fixed upstr.
cd $NAILARA_ROOT && git clean -fxd $NAILARA_ROOT/lib/pm-src

cpanm --force POSIX::1003      # <- temporary <!> ( localtime test fails .. )
cpanm --force XML::RSS::Timing # <- temporary forced [date_conv test fails] <!>

#>-- HTTP::Soup
export PERL5LIB=.
export PERL_USE_UNSAFE_INC=1
cpanm HTTP::Soup
#--<

useradd -m -r nailara
