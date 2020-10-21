#!/bin/sh

cpanm Event IO::Handle::Record JSON::XS\
        Crypt::Ed25519 Crypt::Curve25519 Digest::Skein Digest::CRC\
        Clone Hash::Flatten Hash::Merge::Simple CryptX\
        Date::Parse Proc::ProcessTable Digest::JHash\
        Term::ReadKey Term::ReadPassword Term::ReadLine::Perl
