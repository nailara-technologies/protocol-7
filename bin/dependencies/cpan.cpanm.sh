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

#,,..,...,.,.,...,,.,,,,,,..,,,,.,,.,,,.,,..,,..,,...,..,,...,,,.,...,,,.,,..,
#6OMAYZQKHD5MQ7AT745GPFE3IKS5XHS2F5QUJULFHXWKTSGXQ75OC63FNWGOG6COQVVC7FIZLENKC
#\\\|AWGKI5IVOIJODCAIL5ZY2JCDXLAUJVXBKAFB6LLLIKH4OMHGUJ2 \ / AMOS7 \ YOURUM ::
#\[7]ORDRAGRM5E2Y445XBOBBZVPPS7C6CWJ6YJ7KDP7ZMC7RIMSOTQCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
