#!/usr/bin/perl
##  reproduce encryption-time key_32 chain under perl 5.40 :      ##
##  old inline_elf .so [ oct 2025 ] + old bit_string_to_num .so   ##
##  [ feb 2026 ] + pure-perl calc_true [ no true_int .so left ]   ##

use v5.24;
use strict;
use warnings;
use English;
use DynaLoader;

BEGIN {
    unshift @INC, qw| /data/projects/protocol-7/data/ai-mem/kimi/p7-elf-ab-recovery-harness/lib540 |;
    unshift @INC, qw| /data/projects/protocol-7/data/lib-path/pm |;
}

printf "perl version : %s\n", $];

use AMOS7;
use AMOS7::CHKSUM::ELF;
use AMOS7::Assert::Truth qw| is_true |;
use AMOS7::13;

sub boot_old_so {    ##  boot an Inline-built .so, return installed coderef  ##
    my ( $so_path, $sub_name ) = @ARG;
    die "not found : $so_path" if not -f $so_path;
    my $libref = DynaLoader::dl_load_file( $so_path, 0 )
        or die "cannot load $so_path : " . DynaLoader::dl_error();
    my $pkg_path = $sub_name;
    $pkg_path =~ s|::|__|g;
    my $symref;
    for my $n ( '000' .. '010' ) {
        $symref = DynaLoader::dl_find_symbol( $libref,
            "boot_COMPILE__${n}__${pkg_path}" );
        last if $symref;
    }
    die "boot symbol not found in $so_path" if not $symref;
    DynaLoader::dl_install_xsub( 'P7TEST::boot_it', $symref, $so_path );
    P7TEST::boot_it();
    ( my $short_name = $sub_name ) =~ s|^AMOS7__||;
    $short_name =~ s|__|::|g;    ##  e.g. CHKSUM::ELF::inline_elf  ##
    ( $short_name ) = $short_name =~ m|([^:]+)$|;
    no strict 'refs';
    for my $pkg ( 'AMOS7::INLINE', 'AMOS7::CHKSUM::ELF', 'AMOS7::BitConv' ) {
        my $code = *{"${pkg}::${short_name}"}{CODE};
        return $code if defined $code;
    }
    die "$short_name not registered by boot";
}

my $HOME = $ENV{'HOME'};

my $elf_impl = boot_old_so(
    "$HOME/.7/inline-code/inline_elf.IJGVOPO3EXIKZZY/lib/auto/"
        . 'COMPILE/000/AMOS7/CHKSUM/ELF/inline_elf/inline_elf.so',
    'AMOS7__CHKSUM__ELF__inline_elf'
);
{   no strict 'refs'; no warnings 'redefine';
    *{'AMOS7::CHKSUM::ELF::inline_elf'} = $elf_impl;
}
print "installed OLD inline_elf .so [ oct 2025 ]\n";

my $bitconv_impl = boot_old_so(
    "$HOME/.7/inline-code/bit_string_to_num.IJGVOPJOWWTYPIQ/lib/auto/"
        . 'COMPILE/000/AMOS7/BitConv/bit_string_to_num/'
        . 'bit_string_to_num.so',
    'AMOS7__BitConv__bit_string_to_num'
);
{   no strict 'refs'; no warnings 'redefine';
    *{'AMOS7::BitConv::bit_string_to_num'} = $bitconv_impl;
}
print "installed OLD bit_string_to_num .so [ feb 2026 ]\n";

##  sanity : old elf values on binary vectors  ##
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

#,,.,,.,.,...,,.,,,,.,.,,,,..,.,.,...,..,,..,,..,,...,...,...,,,.,..,,,,,,,,,,
#2ZNOPYZKCIGXA5Q56KYFD2QM5QW4E263RZ5YQ37OOYT4QXFFO7OYM62C2MMFQISHT3T4EKC4M7WGS
#\\\|654RIHVDV7T7REIKA3QEYA2UJCHCLKHLZ5ZGLCZOD64ZJ4DLXDI \ / AMOS7 \ YOURUM ::
#\[7]FRIECMAJ7TWHICFR56XW66BYEFJCABP5SAXG7XPRZVJ3UW4QJECQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
