#!/bin/sh

# installs cpanm and some basic (packaged) cpan modules
apt-get install cpanminus libevent-perl libdigest-sha-perl\
  libio-all-perl libcrypt-cbc-perl libcrypt-openssl-random-perl\
  libcrypt-openssl-rsa-perl libproc-processtable-perl perl-tk\
  libsdl-perl libtext-lorem-perl libevent-perl\
  libcrypt-openssl-random-perl libproc-processtable-perl\
  libglib-perl libgtk2-perl libterm-readpassword-perl\
  libterm-readline-perl-perl libx11-protocol-perl\
  libx11-protocol-other-perl\ # <- not in ubuntu!
  libwebkitgtk-dev # <- Gtk2::WebKit
  #libtext-unidecode-perl
  #libconvert-uu-perl

# installs the rest from cpan
cpanm Crypt::Twofish2 X11::Tops Gtk2::WebKit XML::RSS::TimingBot\
      XML::RSS::Parser # X11::Protocol::Other # <- ubuntu!
