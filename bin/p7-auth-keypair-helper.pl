#!/usr/bin/env perl
# Protocol-7 Auth-Keypair Helper for C Client (p-7-r.c)
# Provides auth-keypair credentials (C25519 pubkey + Ed25519 signature)
#
# This helper is called by p-7-r.c via popen() to perform operations
# that are complex to implement directly in C code.

use strict;
use warnings;
use FindBin qw($RealBin);
use File::Spec;
use Cwd qw(abs_path);
use English;

##[ Setup Library Paths ]#######################################################

BEGIN {
    # Add Protocol-7 lib path
    my $up_dir   = File::Spec->updir;
    my $root     = abs_path( File::Spec->catdir( $RealBin, $up_dir ) );
    my $lib_path = File::Spec->catdir( $root, 'data', 'lib-path', 'pm' );

    die "Library path not found: $lib_path\n" unless -d $lib_path;
    unshift @INC, $lib_path;
}

# Import crypto modules
use Crypt::Misc qw(encode_b32r decode_b32r);
use Crypt::PRNG::Fortuna;
use Crypt::Curve25519 qw(curve25519_public_key);
use Crypt::Ed25519;
use IO::AIO;

##[ Main Entry Point ]##########################################################

my $operation = shift @ARGV // 'help';
my $username = shift @ARGV;

if ( $operation eq 'gen-auth' && $username ) {
    op_gen_auth($username);
} elsif ( $operation eq 'help' || $operation eq '-h' || $operation eq '--help' ) {
    print "Usage: p7-auth-keypair-helper.pl gen-auth <username>\n";
    exit 0;
} else {
    print STDERR "Unknown operation: $operation\n";
    exit 1;
}

##[ Operations ]################################################################

sub op_gen_auth {
    my ($username) = @_;

    my $key_dir = "$ENV{HOME}/.n/user-keys";
    die "Key directory not found: $key_dir\n" unless -d $key_dir;

    # Load user's Ed25519 secret key
    my $ed25519_secret_file = "$key_dir/$username.base.secret";
    die "Ed25519 secret not found: $ed25519_secret_file\n" unless -f $ed25519_secret_file;

    open my $fh, '<', $ed25519_secret_file or die "Cannot read secret key: $!\n";
    my $ed25519_secret_b32 = <$fh>;
    chomp $ed25519_secret_b32;
    close $fh;

    # Decode base32 secret to binary
    my $ed25519_secret_bin = decode_b32r($ed25519_secret_b32);
    die "Failed to decode Ed25519 secret\n" unless defined $ed25519_secret_bin && length($ed25519_secret_bin) >= 34;

    # Strip the 2-byte format prefix
    substr( $ed25519_secret_bin, 0, 2, '' );
    die "Failed to strip format prefix\n" unless length($ed25519_secret_bin) == 32;

    # Generate Ed25519 keypair from secret (same as load_keys_from_secret does)
    my ( $ed25519_pubkey_bin, $ed25519_private_bin ) = Crypt::Ed25519::generate_keypair($ed25519_secret_bin);
    die "Failed to generate Ed25519 keypair from secret\n" unless defined $ed25519_pubkey_bin && defined $ed25519_private_bin;
    die "Invalid public key length\n" unless length($ed25519_pubkey_bin) == 32;
    die "Invalid private key length\n" unless length($ed25519_private_bin) == 64;

    # Lock Ed25519 secret and private key in memory to prevent swapping
    IO::AIO::aio_mlock( $ed25519_secret_bin, 0, 32 );
    IO::AIO::aio_mlock( $ed25519_private_bin, 0, 64 );

    # Generate ephemeral C25519 keypair for session (new random secret)
    my $prng = Crypt::PRNG::Fortuna->new();
    my $c25519_secret = $prng->bytes(32);
    my $c25519_pubkey_bin = curve25519_public_key($c25519_secret);
    die "Failed to generate C25519 keypair\n" unless defined $c25519_pubkey_bin && length($c25519_pubkey_bin) == 32;

    # Lock C25519 secret in memory
    IO::AIO::aio_mlock( $c25519_secret, 0, 32 );

    my $c25519_pubkey_b32 = encode_b32r($c25519_pubkey_bin);

    # Create signature: sign the C25519 pubkey as proof of possession
    # Using Ed25519: sign(message, pubkey, privkey)
    my $ed25519_sig_bin = Crypt::Ed25519::sign(
        $c25519_pubkey_bin,        # message: the C25519 pubkey
        $ed25519_pubkey_bin,       # signer's public key (32 bytes)
        $ed25519_private_bin       # signer's private key (64 bytes)
    );
    die "Failed to generate Ed25519 signature\n" unless defined $ed25519_sig_bin && length($ed25519_sig_bin) == 64;
    my $ed25519_sig_b32 = encode_b32r($ed25519_sig_bin);

    # Output credentials (one per line)
    print "$c25519_pubkey_b32\n";
    print "$ed25519_sig_b32\n";

    # Securely wipe sensitive key material from memory before exit
    # Overwrite with random data to prevent key recovery from memory dumps
    erase_buffer_secure( \$ed25519_secret_bin );
    erase_buffer_secure( \$ed25519_private_bin );
    erase_buffer_secure( \$c25519_secret );

    exit 0;
}

##[ Helper: Secure buffer erasure ]###########################################

sub erase_buffer_secure {
    my ($buffer_sref) = @_;
    return 0 unless ref $buffer_sref eq 'SCALAR';
    return 0 unless defined $buffer_sref->$*;

    my $len = length( $buffer_sref->$* );
    return 0 if $len == 0;

    # Overwrite with random data multiple times for security
    my $prng = Crypt::PRNG::Fortuna->new();
    substr( $buffer_sref->$*, 0, $len, $prng->bytes($len) );
    substr( $buffer_sref->$*, 0, $len, $prng->bytes($len) );

    # Truncate to zero
    $buffer_sref->$* = '';

    return $len;
}

#,,,.,.,,,..,,,..,..,,.,.,,..,.,.,,..,..,,,.,,..,,...,...,.,,,..,,,,.,,,.,,.,,
#WN4FC4CDZWHY7GMHCHG23TFEKA7PORBMGF4A565XBELPS4UQN57JA2HK3M4IL47WKIMD2ZAU5TDKI
#\\\|UBPSMNACO3FKVHXZHH43F2VD5VWXFIL2YW5T42SSO57FJM7EUEC \ / AMOS7 \ YOURUM ::
#\[7]LIIKZZ4UQLYYG7NRFGYPMD5X6POYQDSMBQ2FTJWRDRXXLOC7TCAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
