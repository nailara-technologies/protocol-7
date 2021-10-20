#!/bin/sh

export PERL5LIB=. # <- for HTTP::Soup

xvfb-run cpanm Event Clone Hash::Flatten Hash::Merge::Simple \
      Term::ReadPassword Term::ReadKey Term::ReadLine::Perl \
      Proc::ProcessTable Date::Parse File::Slurper \
      IO::Socket::Multicast LWPx::ParanoidAgent \
      Sys::Filesystem IO::Scalar \
      Crypt::CBC CryptX Digest::JHash \
      JSON JSON::PP \
      Net::SSH2 Config::Hosts \
      LWP::UserAgent LWP::Protocol::https File::MimeInfo::Magic \
      X11::Protocol X11::Keyboard X11::Protocol::WM X11::Tops \
      Convert::Color \
      Linux::Inotify2 \
      FreezeThaw \
      XML::RSS::TimingBot XML::RSSLite \
      SDL Glib::Event \
      CryptX \
      HTTP::Request \
      Gtk3::WebKit2 \
      HTTP::Soup \
      Mediainfo \
      Imager::Sreenshot \
      File::MimeInfo \
      Device::Gembird Net::Libdnet::Arp \
      Crypt::Curve25519 Crypt::Ed25519 \
      https://github.com/gitpan/Module-Build-Pluggable-XSUtil.git \
      Digest::Skein Digest::CRC

# note: XML::SAX failed with cpanm ... installation with 'cpan' itself worked

# Graphics::Magick : http://sourceforge.net/projects/graphicsmagick/files/graphicsmagick/
#                    ..or check your distribution packages!

#,,,,,,..,..,,.,,,,,.,,,.,..,,,..,,..,...,...,..,,...,...,.,,,,..,..,,,,.,,,,,
#ZH6Q7G4JP2RFREEPGWXVAALEA5TMUNKS5DB42OF4Q3TEDPCUV4WKVQYJXRY72KIQW35BINTKXN3RQ
#\\\|N4M34RMM4YXRXHSVN5G7D7CACK555R6SLWXZTDW4SNRHGFP3AXF \ / AMOS7 \ YOURUM ::
#\[7]QWL3HX6SJJ662BQLSF4XODS4LVERKMMYI2OMYCTFR54WRGHGRWAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
