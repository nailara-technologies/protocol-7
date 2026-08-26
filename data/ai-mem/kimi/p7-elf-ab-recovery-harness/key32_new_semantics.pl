#!/usr/bin/perl
##  tonight's key_32 chain under perl 5.42, with true_int / true_float  ##
##  stash-deleted so both A/B sides use pure-perl calc_true             ##

use v5.24;
use strict;
use warnings;
use English;

BEGIN {
    unshift @INC, qw| /data/projects/protocol-7/data/lib-path/pm |;
}

printf "perl version : %s\n", $];

use AMOS7;
use AMOS7::CHKSUM::ELF;
use AMOS7::Assert::Truth qw| is_true |;
use AMOS7::13;

##  force pure-perl calc_true path on this side too  ##
delete $AMOS7::Assert::Truth::{true_int};
delete $AMOS7::Assert::Truth::{true_float};
print "true_int/true_float stash-deleted [ pure-perl calc_true ]\n";

##  sanity : new elf values on binary vectors  ##
{
    my $vec = pack( 'Q*', 1234567890123456789, 987654321098765,
        5555555555555555, 1111111111111111 );
    printf "sanity elf7/elf4 on random 32B : %s / %s\n",
        AMOS7::CHKSUM::ELF::elf_chksum( \$vec, 0, 7, 13 ),
        AMOS7::CHKSUM::ELF::elf_chksum( \$vec, 0, 4, 13 );
}

print "== key_32 derivation [ fixed test passphrases ] ==\n";
foreach my $pass (
    qw| test-passphrase-13chars |,
    qw| another-test-password-12345 |,
    "unicode-\x{E9}\x{FC}-passphrase-test",
) {
    my $pass_copy = $pass;
    my $key       = AMOS7::13::key_32( \$pass_copy );
    printf "pass '%s' => key_32 = %s\n",
        $pass,
        defined $key ? unpack( 'H*', $key ) : qw| [undef] |;
}
print "== done ==\n";

#,,,.,.,,,.,,,..,,.,,,..,,...,.,.,..,,.,,,,.,,..,,...,...,,.,,,,,,.,,,.,,,,.,,
#XQVWFPI4KM2SLN63KOQNLVPBHBVFWMJX2PTA3NZO22I6JTRWMLHAOCBGMS5YOW2YRRPF2S5ZXJZ6O
#\\\|IHFFQ7RHFSUPUE7JMAZLNT46GSE2GHYTXZ325XIQOXMEQTZ6PWA \ / AMOS7 \ YOURUM ::
#\[7]5XGDAUK33HCH5CR52YSLNSR3DIJRPO7L6HNCIBRGNLTDRRKJ6YAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
