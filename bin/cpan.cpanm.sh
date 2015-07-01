#!/bin/sh

# you might need --force in some cases :/

cpanm Event Clone Hash::Flatten Hash::Merge::Simple \
      Term::ReadPassword Term::ReadKey Term::ReadLine::Perl \
      Crypt::OpenSSL::Random Proc::ProcessTable \
      Sys::Filesystem \
      Crypt::CBC \
      JSON JSON::PP \
      Net::SSH2 \
      LWP::UserAgent LWP::Protocol::https File::MimeInfo::Magic \
      X11::Protocol X11::Protocol::WM X11::Tops \
      FreezeThaw \
      XML::RSS::TimingBot XML::RSS::Parser \
      SDL \
      Crypt::Twofish2 \
      HTTP::Request \
      Gtk2::WebKit

# note: XML::SAX failed with cpanm ... installation with 'cpan' itself worked

# Graphics::Magick : http://sourceforge.net/projects/graphicsmagick/files/graphicsmagick/
#                    ..or check your distribution packages!
