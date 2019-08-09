#!/bin/sh

# a crude dependency installation script for browser agent + some infrastructure

apt-get update

apt-get -y install pciutils cpanminus libevent-perl libproc-processtable-perl \
  libterm-readpassword-perl libterm-readline-perl-perl \
  libclone-perl libhash-flatten-perl libhash-merge-simple-perl libjson-xs-perl \
  libio-socket-multicast-perl libfile-slurper-perl libtimedate-perl gcc make \
  libdigest-crc-perl libclass-accessor-lite-perl libc6-dev libglib-perl \
  libgtk3-perl libx11-protocol-perl libx11-protocol-other-perl \
  libx11-keyboard-perl liblinux-inotify2-perl openbox hsetroot xvfb \
  libgtk3-webkit2-perl libtest-needsdisplay-perl libcryptx-perl \
  libextutils-pkgconfig-perl libextutils-depends-perl

cpanm Crypt::Curve25519 Crypt::Ed25519 \
      Digest::Skein Glib::Event

cpanm --force POSIX::1003 # <- temporary! ( localtime test fails.. )

#>-- HTTP::Soup
export PERL5LIB=.
export PERL_USE_UNSAFE_INC=1
cpanm HTTP::Soup
#--<

xvfb-run cpanm Gtk3::WebKit2

useradd -m -r nailara
