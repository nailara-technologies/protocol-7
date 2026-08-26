#!/usr/bin/perl
##  recovery harness for the 2026-08-25 key_32 / inline_elf divergence  ##
##                                                                     ##
##  step 1 [ derive OLD-semantics twofish key from real password ] :   ##
##    /usr/bin/perl5.40-x86_64-linux-gnu recover_key.pl derive         ##
##      -> prints 32-byte key as hex [ reads password from STDIN ]     ##
##                                                                     ##
##  step 2 [ decrypt + verify under current perl ] :                   ##
##    perl recover_key.pl decrypt <keyhex> <file.private> <file.public>##
##      -> decrypts with supplied key, verifies vs known public key,   ##
##         prints recovered 64-byte private key as hex on match        ##

use v5.24;
use strict;
use warnings;
use English;

my $mode = shift @ARGV // '';

if ( $mode eq qw| derive | ) {

    ##  old-semantics key derivation [ perl 5.40 + oct-2025 inline_elf ]  ##
    die "run this step under /usr/bin/perl5.40-x86_64-linux-gnu\n"
        if $] >= 5.042;

    require DynaLoader;
    BEGIN::unshift( @INC, qw| /data/projects/protocol-7/data/ai-mem/kimi/p7-elf-ab-recovery-harness/lib540 | )
        if defined &BEGIN::unshift;    ## placeholder, see unshift below ##
    unshift @INC, qw| /data/projects/protocol-7/data/ai-mem/kimi/p7-elf-ab-recovery-harness/lib540 |;
    unshift @INC, qw| /data/projects/protocol-7/data/lib-path/pm |;

    require AMOS7;
    require AMOS7::CHKSUM::ELF;
    require AMOS7::Assert::Truth;
    require AMOS7::13;

    my $boot_so = sub {
        my ( $so, $boot_sym, $installed_name ) = @ARG;
        my $libref = DynaLoader::dl_load_file( $so, 0 )
            or die DynaLoader::dl_error();
        my $symref = DynaLoader::dl_find_symbol( $libref, $boot_sym )
            or die "boot symbol not found : $boot_sym";
        DynaLoader::dl_install_xsub( 'P7TEST::boot_it', $symref, $so );
        P7TEST::boot_it();
        no strict 'refs';
        return *{$installed_name}{CODE} // die "no impl : $installed_name";
    };

    my $elf_impl = $boot_so->(
        "$ENV{HOME}/.7/inline-code/inline_elf.IJGVOPO3EXIKZZY/lib/auto/"
            . 'COMPILE/000/AMOS7/CHKSUM/ELF/inline_elf/inline_elf.so',
        'boot_COMPILE__000__AMOS7__CHKSUM__ELF__inline_elf',
        'AMOS7::INLINE::inline_elf'
    );
    no strict 'refs';
    no warnings 'redefine';
    *{'AMOS7::CHKSUM::ELF::inline_elf'} = $elf_impl;

    my $bitconv_impl = $boot_so->(
        "$ENV{HOME}/.7/inline-code/"
            . 'bit_string_to_num.IJGVOPJOWWTYPIQ/lib/auto/'
            . 'COMPILE/000/AMOS7/BitConv/bit_string_to_num/'
            . 'bit_string_to_num.so',
        'boot_COMPILE__000__AMOS7__BitConv__bit_string_to_num',
        'AMOS7::INLINE::bit_string_to_num'
    );
    *{'AMOS7::BitConv::bit_string_to_num'} = $bitconv_impl;

    print STDERR "enter passphrase : ";
    my $pass = <STDIN>;
    chomp $pass;
    my $key = AMOS7::13::key_32( \$pass );
    die "key derivation failed\n" if not defined $key;
    print unpack( 'H*', $key ), "\n";
    exit 0;
}

if ( $mode eq qw| decrypt | ) {

    my ( $key_hex, $priv_file, $pub_file ) = @ARGV;
    die "usage: decrypt <keyhex> <file.private> <file.public>\n"
        if not defined $pub_file;

    unshift @INC, qw| /data/projects/protocol-7/data/lib-path/pm |;
    require AMOS7;
    require AMOS7::Twofish;
    require Crypt::Misc;
    require Crypt::Ed25519;
    Crypt::Misc->import(qw| decode_b32r |);

    my $key = pack 'H*', $key_hex;
    die "keyhex must decode to 32 bytes\n" if length $key != 32;

    my $read_b32 = sub {
        my $path = shift;
        open my $fh, '<', $path or die "cannot open $path : $!";
        my $data = do { local $INPUT_RECORD_SEPARATOR = undef; <$fh> };
        close $fh;
        chomp $data;
        return decode_b32r($data);
    };

    my $enc_priv = $read_b32->($priv_file);
    my $pub      = $read_b32->($pub_file);

    ##  strip 2-byte prefix when present [ 66 bytes -> 64 ]  ##
    substr( $enc_priv, 0, 2, '' ) if length $enc_priv == 66;
    substr( $pub,      0, 2, '' ) if length $pub == 34;

    die sprintf "encrypted key not 64 bytes [ %d ]\n", length $enc_priv
        if length $enc_priv != 64;
    die sprintf "public key not 32 bytes [ %d ]\n", length $pub
        if length $pub != 32;

    AMOS7::Twofish::key_init( $key, qw| decryption recovery | )
        or die "key_init failed\n";
    my $dec_sref = AMOS7::Twofish::decrypt( qw|recovery|, \$enc_priv );
    die "decrypt failed\n" if not defined $dec_sref;
    my $dec = $dec_sref->$*;
    die sprintf "decrypted size %d != 64\n", length $dec if length $dec != 64;

    my ( $derived_pub, undef )
        = Crypt::Ed25519::generate_keypair( substr( $dec, 0, 32 ) );

    if ( $derived_pub eq $pub ) {
        print "MATCH : decrypted keypair verifies against public key\n";
        print "private key [ hex ] : ", unpack( 'H*', $dec ), "\n";
        exit 0;
    } else {
        print "NO MATCH : derived public key differs\n";
        printf "expected : %s\n", unpack( 'H*', $pub );
        printf "derived  : %s\n", unpack( 'H*', $derived_pub );
        exit 1;
    }
}

die "usage: recover_key.pl derive | decrypt <keyhex> <priv> <pub>\n";

#,,,.,,..,,..,.,.,,,,,...,.,,,.,.,.,,,...,,,,,..,,...,...,.,.,.,.,.,,,,,.,...,
#I2FUCTMUFEF75XN7C2U27EE6LCBYNYMKNBZGONCWIX3RHDWK6Y62HEULTGSNRVEPX7C4VPCT4KPBE
#\\\|MZ5WD3OCSVOKHL7YGSQOR6IQWBY5CY2CWYW4AKDHBXASUYAZ3L2 \ / AMOS7 \ YOURUM ::
#\[7]OCJLD2WDU35ZL2W6NDWW3MNLRHBGKZOXSTD7MEQAL3L6ZP7E2IDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
