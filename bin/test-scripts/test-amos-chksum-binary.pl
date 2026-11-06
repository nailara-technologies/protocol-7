#!/usr/bin/perl
use v5.32.0;
use strict;
use warnings;

## amos_chksum input forms : valid utf-8 keeps its established checksum in
## both forms, every byte of binary input counts, the input is not changed

use FindBin qw| $RealBin |;
use lib "$RealBin/../../data/lib-path/pm";

use Encode;
use Test::More;
use Digest::BMW;
use AMOS7::CHKSUM;
use AMOS7::CHKSUM::ELF;

sub amos {
    my $copy = shift;
    return scalar AMOS7::CHKSUM::amos_chksum( \$copy );
}

## established text checksums ##
is( amos('abc'),      'QEYUJGY', 'ascii unchanged' );
is( amos("\xc3\xa9"), 'ZUXYKVQ', 'utf-8 octets unchanged' );
my $decoded = "\x{e9}";
utf8::upgrade($decoded);
is( amos($decoded), 'ZUXYKVQ', 'decoded text equals its octets' );

## no byte is swallowed ##
my @binary = (
    "\xff",     "\xfe",     "\xe9", "\xffa", "\xfea", "\xed\xa0\x80",
    "\x00\xff", "\xff\x00", join( '', map {chr} 128 .. 255 ),
);
my %seen;
$seen{ amos($_) }++ for @binary;
is( scalar keys %seen, scalar @binary, 'binary inputs all distinct' );

## bmw runs over the exact bytes, elf over byte values ##
foreach my $bytes (@binary) {
    my $elf_input = $bytes;
    my $elf_sum   = sprintf qw| %09d |, elf_chksum( $elf_input, 0, 7, 13 );
    my $ctx       = Digest::BMW->new(512);
    $ctx->add($bytes);
    my $expected = AMOS7::CHKSUM::amos_chksum(
        { 'elf_checksum' => $elf_sum, 'BMW_checksum' => $ctx->digest } );
    is( amos($bytes), $expected, 'bmw sees the exact bytes' );
}

## the caller's scalar stays as given ##
my $input = "\xff\xfe";
AMOS7::CHKSUM::amos_chksum( \$input );
ok( !utf8::is_utf8($input) && $input eq "\xff\xfe", 'input not modified' );

done_testing();

#,,,,,,,,,,..,.,.,,..,...,.,,,,,.,,,,,.,.,,.,,..,,...,...,..,,,,,,,..,,.,,,,.,
#IVESBQIXIFS3M7KE5TBMVHMXY4J3TXRXNPRQX5GUUXVUYQKKCUEFXUCBIUC7773WW4EPGYAQ4AWPQ
#\\\|XWNISM4JVIAYOQVYELC2DXZ26GDCBIDP35JKYYRWRU7USBANWZQ \ / AMOS7 \ YOURUM ::
#\[7]HHDWEW2VVVHKUMPSKLYR2DHDTOKUDOCMJCHQMXWPW2ALJGBSRGDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
