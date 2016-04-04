#!/bin/sh

xvfbrun cpanm Event Clone Hash::Flatten Hash::Merge::Simple \
      Term::ReadPassword Term::ReadKey Term::ReadLine::Perl \
      Proc::ProcessTable \
      LWPx::ParanoidAgent \
      Sys::Filesystem \
      Crypt::CBC CryptX \
      JSON JSON::PP \
      Net::SSH2 \
      LWP::UserAgent LWP::Protocol::https File::MimeInfo::Magic \
      X11::Protocol X11::Protocol::WM X11::Tops \
      FreezeThaw \
      XML::RSS::TimingBot \
      SDL Gtk2 Glib::Event \
      Crypt::PRNG::Fortuna \
      Crypt::Twofish2 \
      HTTP::Request \
      Gtk3::WebKit \
      HTTP::Soup \
      Mediainfo \
      Device::Gembird Net::Libnet::Arp

# note: XML::SAX failed with cpanm ... installation with 'cpan' itself worked

# Graphics::Magick : http://sourceforge.net/projects/graphicsmagick/files/graphicsmagick/
#                    ..or check your distribution packages!
