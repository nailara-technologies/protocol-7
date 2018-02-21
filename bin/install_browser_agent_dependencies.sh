#!/bin/sh

# a crude dependency installation script for browser agent + some infrastructure

apt-get update

apt-get -y install pciutils cpanminus libevent-perl libproc-processtable-perl \
  libterm-readpassword-perl libterm-readline-perl-perl libdigest-sha-perl \
  libclone-perl libhash-flatten-perl libhash-merge-simple-perl libjson-xs-perl \
  libio-socket-multicast-perl libfile-slurper-perl libtimedate-perl gcc make \
  libdigest-crc-perl libclass-accessor-lite-perl libc6-dev \
  libgtk3-perl libx11-protocol-perl libx11-protocol-other-perl \
  libx11-keyboard-perl liblinux-inotify2-perl openbox hsetroot xvfb \
  libwebkitgtk-3.0-dev libtest-needsdisplay-perl

cpanm CryptX POSIX::1003 \
      Crypt::Curve25519 Crypt::Ed25519 \
      Digest::Skein Glib::Event

#>-- HTTP::Soup
export PERL5LIB=.
export PERL_USE_UNSAFE_INC=1
cpanm HTTP::Soup
#--<

xvfb-run cpanm Gtk3::WebKit

useradd -m -r nailara
