#!/bin/bash

script_path=`realpath $0`
BIN_PATH=`dirname $script_path`

# installs cpanm and some basic (packaged) cpan modules
apt-get install xvfb cpanminus libevent-perl libio-aio-perl \
  libcryptx-perl libproc-processtable-perl libdigest-crc-perl \
  libsdl-perl libtext-lorem-perl libevent-perl liblwpx-paranoidagent-perl \
  libproc-processtable-perl libglib-perl libterm-readpassword-perl \
  libterm-readline-gnu-perl libx11-protocol-perl libhash-flatten-perl \
  libx11-protocol-other-perl libx11-keyboard-perl libtest-needsdisplay-perl \
  libfreezethaw-perl libclone-perl libtimedate-perl shared-mime-info \
  libhash-merge-simple-perl libwebkitgtk-dev libjson-xs-perl \
  libpoppler-glib-dev libgraphics-magick-perl libimage-exif-perl \
  libfile-mimeinfo-perl libnet-ssh2-perl libxml-feed-perl libxml-rsslite-perl \
  libgirepository1.0-dev pkg-config libgtk-3-dev libfile-slurper-perl \
  libglib2.0-dev libglib2.0-0 gir1.2-webkit-3.0 \
  liblinux-inotify2-perl libnet-libdnet-perl \
  libclass-accessor-lite-perl libio-stringy-perl libdigest-jhash-perl \
  libimager-perl libfont-freetype-perl liblwp-useragent-determined-perl

  #libtext-unidecode-perl
  #libconvert-uu-perl

# installs the rest from cpan
$BIN_PATH/perlmod_test_fail_overrides.sh # (temporary) test fail override(s)!
cpanm   Crypt::Curve25519 Crypt::Ed25519 Digest::Skein Tie::Dir \
        XML::RSS::TimingBot File::MimeInfo::Magic Config::Hosts \
        HTTP::Soup Mediainfo Poppler Device::Gembird Imager::Screenshot \
        Net::DNS

xvfb-run cpanm Glib::Event Gtk3::WebKit2

#,,.,,,,,,,,,,,.,,,..,.,,,,..,,,.,,..,...,,,,,..,,...,...,,..,.,.,,..,,,,,...,
#E34VPTAPCKIKCGRI6J35V2UAPJZPD2TT7FKCPIQAYUJWBN46EOJCERYSIO6BZANKHZ3YX44IN62E6
#\\\|FVIHXAWERNYUWMSSGYMU4HIZSNZGK7VF5GRTATDC4LUOQIS3W4U \ / AMOS7 \ YOURUM ::
#\[7]TPWSHOFDUIJBDXK7ZFIRGZY4M2RECLLJZB6XAVRKECB4VR74HABQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
