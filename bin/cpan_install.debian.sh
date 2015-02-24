#!/bin/sh

# installs cpanm and some basic (packaged) cpan modules
apt-get install cpanminus libevent-perl libdigest-sha-perl\
  libio-all-perl libcrypt-cbc-perl libcrypt-openssl-random-perl\
  libcrypt-openssl-rsa-perl libproc-processtable-perl perl-tk\
  libsdl-perl libtext-lorem-perl

# installs Crypt::Twofish2 (for which no package exists)
cpanm install Crypt::Twofish2 X11::Tops
