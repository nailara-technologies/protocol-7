#!/bin/sh

# you might need --force in some cases :/

cpanm Event Clone Hash::Flatten Hash::Merge::Simple \
      Term::ReadPassword Term::ReadKey Term::ReadLine::Perl \
      Crypt::OpenSSL::Random Proc::ProcessTable \
      Sys::Filesystem \
      Crypt::CBC \
      JSON JSON::PP \
      Net::SSH2 \
      LWP::UserAgent File::MimeInfo::Magic \
      X11::Protocol X11::Protocol::WM X11::Tops \
      Graphics::Magick FreezeThaw \
      XML::RSS::TimingBot XML::RSS::Parser \
      SDL \
      Crypt::Twofish2 \
      HTTP::Request \
      Gtk2::WebKit
