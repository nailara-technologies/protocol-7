#!/bin/sh

xvfbrun cpanm Event Clone Hash::Flatten Hash::Merge::Simple \
      Term::ReadPassword Term::ReadKey Term::ReadLine::Perl \
      Proc::ProcessTable Date::Parse \
      LWPx::ParanoidAgent \
      Sys::Filesystem \
      Crypt::CBC CryptX \
      JSON JSON::PP \
      Net::SSH2 Config::Hosts \
      LWP::UserAgent LWP::Protocol::https File::MimeInfo::Magic \
      X11::Protocol X11::Keyboard X11::Protocol::WM X11::Tops \
      Linux::Inotify2 \
      FreezeThaw \
      XML::RSS::TimingBot \
      SDL Gtk2 Glib::Event \
      Crypt::PRNG::Fortuna \
      Crypt::Twofish2 \
      HTTP::Request \
      Gtk3::WebKit \
      HTTP::Soup \
      Mediainfo \
      File::MimeInfo \
      Device::Gembird Net::Libdnet::Arp

# note: XML::SAX failed with cpanm ... installation with 'cpan' itself worked

# Graphics::Magick : http://sourceforge.net/projects/graphicsmagick/files/graphicsmagick/
#                    ..or check your distribution packages!
