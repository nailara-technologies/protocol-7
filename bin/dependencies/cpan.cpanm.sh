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
# ______________________________________________________________________________
#\\PYHXOWOSKPBVFM4TKZUCN2YPEH57Z6SXQL7RBTU2FENN47NMVZYXH6XCQTZU3B2CLR4ZCAFF5WBDM
# \\ YGG46TEG7LY75ZKNSLN6T6XYGWMFH47KKMOG5GC4A5G22HLY6C63 \\// C25519-BASE-32 //
#  \\// 3VPKWJGBACO7FETKAUSA5HIYEBNJMYUFYT6HFMAMOUP5YTKMCBY \\ CODE SIGNATURE \\
#   ````````````````````````````````````````````````````````````````````````````
