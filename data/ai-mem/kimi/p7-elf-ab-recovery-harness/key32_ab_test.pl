#!/usr/bin/perl
##  A/B test : key_32 + elf_chksum under perl 5.40 vs 5.42  ##
##  usage : /usr/bin/perl5.40-x86_64-linux-gnu key32_ab_test.pl  ##
##          perl key32_ab_test.pl                                ##

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

##  fixed binary test vectors [ malformed + valid UTF-8 mixes ]  ##
my @bin_vectors = (
    join( '', map { chr($_) } 0 .. 31 ),               ## control bytes   ##
    join( '', map { chr( 200 + $_ % 56 ) } 0 .. 31 ),  ## high bytes      ##
    pack( 'Q*', 1234567890123456789, 987654321098765,
        5555555555555555, 1111111111111111 ),          ## random-ish 32 B ##
    "\xC3\xA9\xFF\xFE\x80\xED\xA0\x80\xF4\x90\x80\x80\x00\x41\xC2\x7F",
    ## ^ mixed : valid 2-byte, invalid FF FE, stray cont 80, surrogate    ##
    ##   ED A0 80, out-of-range F4 90 80 80, NUL, 'A', valid C2 7F       ##
);

print "== elf_chksum on binary vectors ==\n";
my $i = 0;
foreach my $vec (@bin_vectors) {
    my $sum_7 = AMOS7::CHKSUM::ELF::elf_chksum( \$vec, 0, 7, 13 );
    my $sum_4 = AMOS7::CHKSUM::ELF::elf_chksum( \$vec, 0, 4, 13 );
    my $t = AMOS7::Assert::Truth::is_true( $vec, 0, 5 ) ? qw| TRUE | : qw| false |;
    printf "vec %d : elf7=%s elf4=%s is_true(elf)=%s\n",
        $i++, $sum_7, $sum_4, $t;
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

#,,..,.,,,...,,.,,.,.,,.,,,,.,.,,,.,.,..,,,,.,..,,...,...,...,.,,,,,,,..,,.,.,
#BJ4EBVN5H2E6C2HKRKFIYVKVRGPDY6IIW452A6TNKX6DAH5NZMPTSGZKYWBK52QIWE42AUH7NAT3E
#\\\|SH2ZFBIH5JFGOD6O626AU5ORGT3UEQAM4THSQTVH5QL5MIUPOF7 \ / AMOS7 \ YOURUM ::
#\[7]D5YANGA5DSOYXIRMT7H4X3GQRBMNBRMGCTBRD3D74FKXD2NPKGCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
