#!/bin/sh

export PERL5LIB=. # <- for HTTP::Soup

xvfb-run cpanm Event Clone Hash::Flatten Hash::Merge::Simple \
      Term::ReadPassword Term::ReadKey Term::ReadLine::Perl \
      POSIX::1003 Proc::ProcessTable Date::Parse File::Slurper \
      IO::Socket::Multicast LWPx::ParanoidAgent \
      Sys::Filesystem IO::Scalar \
      Crypt::CBC CryptX \
      JSON JSON::PP \
      Net::SSH2 Config::Hosts \
      LWP::UserAgent LWP::Protocol::https File::MimeInfo::Magic \
      X11::Protocol X11::Keyboard X11::Protocol::WM X11::Tops \
      Convert::Color \
      Linux::Inotify2 \
      FreezeThaw \
      XML::RSS::TimingBot XML::RSSLite \
      SDL Gtk2 Glib::Event \
      CryptX \
      Crypt::Twofish2 \
      HTTP::Request \
      Gtk3::WebKit \
      HTTP::Soup \
      Mediainfo \
      Imager::Sreenshot \
      File::MimeInfo \
      Device::Gembird Net::Libdnet::Arp \
      Crypt::Curve25519 Crypt::Ed25519 \
      https://github.com/gitpan/Module-Build-Pluggable-XSUtil.git \
      Digest::BLAKE2

# note: XML::SAX failed with cpanm ... installation with 'cpan' itself worked

# Graphics::Magick : http://sourceforge.net/projects/graphicsmagick/files/graphicsmagick/
#                    ..or check your distribution packages!
