#!/bin/sh

# installs cpanm and some basic (packaged) cpan modules
apt-get install xvfb cpanminus libevent-perl libdigest-sha-perl\
  libio-all-perl libcrypt-cbc-perl libproc-processtable-perl libdigest-crc-perl\
  libsdl-perl libtext-lorem-perl libevent-perl liblwpx-paranoidagent-perl\
  libproc-processtable-perl libglib-perl libterm-readpassword-perl\
  libterm-readline-perl-perl libx11-protocol-perl libhash-flatten-perl\
  libx11-protocol-other-perl libx11-keyboard-perl\
  libfreezethaw-perl libclone-perl libtimedate-perl\
  libhash-merge-simple-perl libwebkitgtk-dev libjson-xs-perl\
  libpoppler-glib-dev libgraphics-magick-perl libimage-exif-perl\
  libfile-mimeinfo-perl libnet-ssh2-perl libxml-feed-perl libxml-rsslite-perl \
  libgirepository1.0-dev pkg-config libgtk-3-dev libfile-slurper-perl \
  libglib2.0-dev libglib2.0-0 gir1.2-webkit-3.0 \
  libgtk3-perl libgtk2-perl liblinux-inotify2-perl libnet-libdnet-perl \
  libclass-accessor-lite-perl libio-stringy-perl perl-tk
  #libtext-unidecode-perl
  #libconvert-uu-perl

# installs the rest from cpan
cpanm   CryptX Crypt::Curve25519 Crypt::Ed25519 Digest::Skein \
        POSIX::1003 XML::RSS::TimingBot File::MimeInfo::Magic \
        Config::Hosts HTTP::Soup Mediainfo Poppler Device::Gembird

xvfb-run cpanm Glib::Event Gtk3::WebKit X11::Tops
