use v5.24; use strict; use warnings;
##  load stub under its package name from file directly  ##
package Crypt::Misc;
require "/data/projects/protocol-7/data/ai-mem/kimi/p7-elf-ab-recovery-harness/lib540/Crypt/Misc.pm";
package main;
##  real CryptX : load via full path into different package? CryptX is XS
##  with fixed package names -- instead: compare via separate processes.
my @vectors = (
    "Hello, world!",
    join( '', map { chr($_) } 0 .. 47 ),
    pack( 'Q*', 1234567890123456789, 987654321098765,
        5555555555555555, 1111111111111111 ),
    "\x00\x01\x02\x03",
    "a",
);
foreach my $v (@vectors) {
    my $enc = Crypt::Misc::encode_b32r($v);
    my $dec = Crypt::Misc::decode_b32r($enc);
    printf "stub : %s => %s %s\n", unpack( 'H8', $v ), $enc,
        $dec eq $v ? 'ROUNDTRIP-OK' : 'ROUNDTRIP-FAIL';
}

#,,,.,,.,,,.,,.,.,,,,,,.,,..,,...,.,.,...,..,,..,,...,...,,..,,,.,..,,,.,,.,,,
#BWU3YQR642QUHKCCIHAFTXKVDPXLBGRJCP5QVDYXRHNKLX6IM2HNDFVIGG5AJO3IULX5TR4PRKJPE
#\\\|RW2LYMFRBAU65DXTGWI6KTF6WEEVCIZXUMTX2WHFGROLP6SEJP4 \ / AMOS7 \ YOURUM ::
#\[7]ATIGJ5LJ75L7QMYZSC67XTDGICY22JHYCXZBOJCCJZWC2RJOZ2DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
