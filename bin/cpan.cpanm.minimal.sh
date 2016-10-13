#!/bin/sh

cpanm Event POSIX::1003 IO::Handle::Record JSON::XS\
        Crypt::Ed25519 Crypt::Curve25519 Digest::BLAKE2\
        Clone Hash::Flatten Hash::Merge::Simple CryptX\
        Proc::ProcessTable Term::ReadKey Term::ReadPassword Term::ReadLine::Perl
