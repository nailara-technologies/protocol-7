#!/bin/sh

# temporary fixes to compile on i386 systems

cpanm --force POSIX::1003                  # failed tests but what we use works!
cpanm https://github.com/anotherlink/crypt-curve25519.git # renamed 'fmul', worx
