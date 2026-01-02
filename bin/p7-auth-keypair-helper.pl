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

    # Load user's Ed25519 private key
    my $ed25519_private_file = "$key_dir/$username.base.private";
    die "Ed25519 private key not found: $ed25519_private_file\n" unless -f $ed25519_private_file;

    open my $fh, '<', $ed25519_private_file or die "Cannot read private key: $!\n";
    my $ed25519_private_b32 = <$fh>;
    chomp $ed25519_private_b32;
    close $fh;

    # Decode base32 private key to binary
    my $ed25519_private_bin = decode_b32r($ed25519_private_b32);
    die "Failed to decode Ed25519 private key\n" unless defined $ed25519_private_bin && length($ed25519_private_bin) >= 66;

    # Strip the 2-byte format prefix (format marker)
    substr( $ed25519_private_bin, 0, 2, '' );
    die "Failed to strip format prefix\n" unless length($ed25519_private_bin) == 64;

    # Generate ephemeral C25519 keypair for session (new random secret)
    my $prng = Crypt::PRNG::Fortuna->new();
    my $c25519_secret = $prng->bytes(32);
    my $c25519_pubkey_bin = curve25519_public_key($c25519_secret);
    die "Failed to generate C25519 keypair\n" unless defined $c25519_pubkey_bin && length($c25519_pubkey_bin) == 32;
    my $c25519_pubkey_b32 = encode_b32r($c25519_pubkey_bin);

    # Derive Ed25519 public key from private key
    my $ed25519_pubkey_bin = Crypt::Ed25519::eddsa_public_key(substr($ed25519_private_bin, 0, 32));
    die "Failed to derive Ed25519 public key\n" unless defined $ed25519_pubkey_bin && length($ed25519_pubkey_bin) == 32;

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

    exit 0;
}

#,,,,,.,,,,.,,...,,..,,,,,,..,,..,.,,,,,,,.,.,..,,...,...,...,.,,,,,,,.,.,,,.,
#Y5O6EGKTLKAAUMLELIMKPBMLVBWSLNPVTIPB656U4GKGWUUE7ZLGXAQILUO5N32O6RMGZYNDX7M34
#\\\|CIXPNXMLT6ZDIX7LPGKOEHNKIA7TUEF3FW4JLTRMXFQTXWRMILA \ / AMOS7 \ YOURUM ::
#\[7]GGYKFXN225CG5VXXTL6O2XGBXHJSPFEO5CVJUITJTQMSQMDBJADQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
