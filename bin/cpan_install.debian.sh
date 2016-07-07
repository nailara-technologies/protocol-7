#!/bin/sh

# installs cpanm and some basic (packaged) cpan modules
apt-get install cpanminus libevent-perl libdigest-sha-perl\
  libio-all-perl libcrypt-cbc-perl libproc-processtable-perl\
  libsdl-perl libtext-lorem-perl libevent-perl liblwpx-paranoidagent-perl\
  libproc-processtable-perl libglib-perl libterm-readpassword-perl\
  libterm-readline-perl-perl libx11-protocol-perl libhash-flatten-perl\
  libx11-protocol-other-perl libx11-keyboard-perl\
  libfreezethaw-perl libclone-perl\
  libhash-merge-simple-perl libwebkitgtk-dev libjson-xs-perl\
  libpoppler-glib-dev libgraphics-magick-perl libimage-exif-perl\
  libfile-mimeinfo-perl libnet-ssh2-perl libxml-feed-perl\
  libgirepository1.0-dev pkg-config libgtk-3-dev \
  libglib2.0-dev libglib2.0-0 gir1.2-webkit-3.0 \
  libgtk3-perl libgtk2-perl liblinux-inotify2-perl
  #libtext-unidecode-perl
  #libconvert-uu-perl

# installs the rest from cpan (note: Gtk3::WebKit needs X-server or Xvfb)
cpanm Crypt::Twofish2 X11::Tops Gtk3::WebKit Glib::Event \
      Crypt::PRNG::Fortuna XML::RSS::TimingBot File::MimeInfo::Magic \
      Config::Hosts HTTP::Soup Mediainfo Poppler Device::Gembird
