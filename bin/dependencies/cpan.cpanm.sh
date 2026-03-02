#!/bin/sh

export PERL5LIB=. # <- for HTTP::Soup

xvfb-run cpanm Event Clone Hash::Flatten Hash::Merge::Simple \
      Term::ReadPassword Term::ReadKey Term::ReadLine::Perl \
      Proc::ProcessTable Date::Parse File::Slurper \
      IO::Socket::Multicast LWPx::ParanoidAgent \
      Sys::Filesystem IO::Scalar \
      Crypt::CBC CryptX Digest::JHash \
      JSON JSON::PP \
      Net::SSH2 Config::Hosts File::MimeInfo::Magic \
      LWP::UserAgent LWP::Protocol::https Protocol::WebSocket \
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

#,,,.,,..,,.,,,,,,,,.,..,,,,.,,..,.,,,,.,,.,,,..,,...,...,.,.,.,.,,..,.,.,,,.,
#DLS4OINYQRSQIBJ3RVMLQOBKV4AYRIOJOYZXZ5CKEWAF7PSYRCP2UB4RFOBRS3EDJ77ZGF6GRQOLA
#\\\|NJYHIKYFW4X5HISML5JEZOWEIUJNHBWUIVTFNTRD3IZQBZUDG4Z \ / AMOS7 \ YOURUM ::
#\[7]USEE5KK2FV2YWBZCESY7PSSUFYNCRNXHK6WRE73F64FWA7MKX4BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
