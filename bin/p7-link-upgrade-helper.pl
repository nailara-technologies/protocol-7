#!/usr/bin/env perl
# Protocol-7 Link-Upgrade Helper for C Client (p7.c)
# Provides crypto operations for client-side link-upgrade encryption
#
# This helper is called by p7.c via popen() to perform operations
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
    my $up_dir = File::Spec->updir;
    my $root = abs_path(File::Spec->catdir($RealBin, $up_dir));
    my $lib_path = File::Spec->catdir($root, 'data', 'lib-path', 'pm');

    die "Library path not found: $lib_path\n" unless -d $lib_path;
    unshift @INC, $lib_path;
}

# Import crypto modules
use Crypt::Misc;
use Crypt::AuthEnc::ChaCha20Poly1305;
use Crypt::Curve25519;
use Digest::SHA qw(sha256);
use AMOS7;  # For key derivation functions

##[ Main Entry Point ]##########################################################

my $operation = shift @ARGV // 'help';

if ($operation eq 'gen-ephemeral') {
    op_gen_ephemeral();
} elsif ($operation eq 'compute-dh') {
    op_compute_dh();
} elsif ($operation eq 'derive-key') {
    op_derive_key();
} elsif ($operation eq 'encrypt') {
    op_encrypt();
} elsif ($operation eq 'decrypt') {
    op_decrypt();
} elsif ($operation eq 'help' || $operation eq '-h' || $operation eq '--help') {
    show_help();
} else {
    die "Unknown operation: $operation\n";
}

exit 0;

##[ Operations ]################################################################

sub op_gen_ephemeral {
    # Generate ephemeral C25519 keypair for client
    # Returns: base32(pubkey) on line 1, base32(secret) on line 2

    # Generate a random secret (32 bytes for Curve25519)
    my $secret = Crypt::Misc::random_bytes(32);

    # Compute public key from secret
    my $pubkey = Crypt::Curve25519::curve25519_public_key($secret);

    die "Failed to generate ephemeral keypair\n"
        unless $secret and $pubkey and length($secret) == 32 and length($pubkey) == 32;

    # Output in base32 format for easy transmission
    print Crypt::Misc::encode_b32r($pubkey) . "\n";
    print Crypt::Misc::encode_b32r($secret) . "\n";
}

sub op_compute_dh {
    # Compute Diffie-Hellman shared secret using Curve25519
    # Input: client_secret_b32 server_pubkey_b32
    # Returns: base32(shared_secret)

    my $client_secret_b32 = shift @ARGV;
    my $server_pubkey_b32 = shift @ARGV;

    die "Usage: $0 compute-dh <client_secret_b32> <server_pubkey_b32>\n"
        unless $client_secret_b32 and $server_pubkey_b32;

    # Decode from base32
    my $client_secret = Crypt::Misc::decode_b32r($client_secret_b32);
    my $server_pubkey = Crypt::Misc::decode_b32r($server_pubkey_b32);

    # Compute DH shared secret using Curve25519
    my $shared_secret = Crypt::Curve25519::curve25519_shared_secret($client_secret, $server_pubkey);

    die "Failed to compute DH shared secret\n"
        unless $shared_secret and length($shared_secret) == 32;

    # Return in base32 format
    print Crypt::Misc::encode_b32r($shared_secret) . "\n";
}

sub op_derive_key {
    # Derive encryption key from shared secret
    # Input: shared_secret_b32 session_id
    # Returns: base32(encryption_key)
    #
    # Uses simple SHA256-based KDF: key = SHA256(shared_secret || session_id)
    # For production, this should use a proper KDF like PBKDF2

    my $shared_secret_b32 = shift @ARGV;
    my $session_id = shift @ARGV;

    die "Usage: $0 derive-key <shared_secret_b32> <session_id>\n"
        unless $shared_secret_b32 and defined $session_id;

    # Decode shared secret
    my $shared_secret = Crypt::Misc::decode_b32r($shared_secret_b32);

    # Derive encryption key: SHA256(shared_secret || session_id)
    # This produces a 32-byte key suitable for ChaCha20-Poly1305
    my $key = sha256($shared_secret . pack('N', $session_id));

    die "Failed to derive encryption key\n" unless $key and length($key) == 32;

    # Return in base32 format
    print Crypt::Misc::encode_b32r($key) . "\n";
}

sub op_encrypt {
    # Encrypt message with ChaCha20-Poly1305
    # Input: base32(key) session_id counter
    # Input data: plaintext via STDIN
    # Returns: ciphertext + auth_tag (binary) on stdout

    my $key_b32 = shift @ARGV;
    my $session_id = shift @ARGV;
    my $counter = shift @ARGV;

    die "Usage: $0 encrypt <key_b32> <session_id> <counter> < plaintext\n"
        unless $key_b32 and defined $session_id and defined $counter;

    # Read plaintext from STDIN
    my $plaintext = join('', <>);

    # Decode key from base32
    my $key = Crypt::Misc::decode_b32r($key_b32);

    # Generate nonce: 4-byte session_id + 4-byte counter + 4 zero bytes
    my $nonce = pack('N', $session_id) . pack('N', $counter) . "\0\0\0\0";

    # Create cipher and encrypt
    my $cipher = Crypt::AuthEnc::ChaCha20Poly1305->new($key, $nonce);
    $cipher->encrypt_add($plaintext);
    my $auth_tag = $cipher->encrypt_done();

    # Output binary ciphertext + auth_tag
    # Note: This is binary data, not base32
    print STDOUT $cipher->ciphertext() . $auth_tag;
}

sub op_decrypt {
    # Decrypt message with ChaCha20-Poly1305
    # Input: base32(key) session_id counter
    # Input data: ciphertext + auth_tag (binary) via STDIN
    # Returns: plaintext on stdout (or error on stderr)

    my $key_b32 = shift @ARGV;
    my $session_id = shift @ARGV;
    my $counter = shift @ARGV;

    die "Usage: $0 decrypt <key_b32> <session_id> <counter> < ciphertext\n"
        unless $key_b32 and defined $session_id and defined $counter;

    # Read ciphertext from STDIN (binary data)
    my $ciphertext_with_tag = join('', <>);

    # Decode key from base32
    my $key = Crypt::Misc::decode_b32r($key_b32);

    # Extract auth tag (last 16 bytes) and ciphertext
    my $auth_tag = substr($ciphertext_with_tag, -16);
    my $ciphertext = substr($ciphertext_with_tag, 0, -16);

    # Generate nonce: 4-byte session_id + 4-byte counter + 4 zero bytes
    my $nonce = pack('N', $session_id) . pack('N', $counter) . "\0\0\0\0";

    # Create cipher and decrypt
    my $cipher = Crypt::AuthEnc::ChaCha20Poly1305->new($key, $nonce);
    my $plaintext = $cipher->decrypt_add($ciphertext);
    my $success = $cipher->decrypt_done($auth_tag);

    # Output plaintext or error
    if ($success) {
        print STDOUT $plaintext;
        exit 0;
    } else {
        die "Authentication tag verification failed\n";
    }
}

##[ Help ]######################################################################

sub show_help {
    print <<'EOF';
Protocol-7 Link-Upgrade Helper for p7.c

Usage: p7-link-upgrade-helper.pl <operation> [args]

Operations:

  gen-ephemeral
    Generate ephemeral C25519 keypair for client
    Output: Two lines (base32 encoded)
            Line 1: Public key
            Line 2: Secret/Private key

  compute-dh <client_secret_b32> <server_pubkey_b32>
    Compute Diffie-Hellman shared secret
    Input:  Client secret (base32), Server public key (base32)
    Output: Shared secret (base32)

  derive-key <shared_secret_b32> <session_id>
    Derive ChaCha20 encryption key from shared secret
    Input:  Shared secret (base32), Session ID (integer)
    Output: Encryption key (base32)

  encrypt <key_b32> <session_id> <counter>
    Encrypt message with ChaCha20-Poly1305
    Input:  Key (base32), Session ID, Counter (from stdin: plaintext binary)
    Output: Ciphertext + Auth Tag (binary)

  decrypt <key_b32> <session_id> <counter>
    Decrypt message with ChaCha20-Poly1305
    Input:  Key (base32), Session ID, Counter (from stdin: ciphertext + tag binary)
    Output: Plaintext (binary)

Example usage from p7.c:

    // Generate ephemeral keys
    FILE *f = popen("p7-link-upgrade-helper.pl gen-ephemeral", "r");
    char pubkey[256], secret[256];
    fgets(pubkey, sizeof(pubkey), f);
    fgets(secret, sizeof(secret), f);
    pclose(f);

    // Compute shared secret
    FILE *f = popen("p7-link-upgrade-helper.pl compute-dh <client_secret> <server_pubkey>", "r");
    // ... read shared secret
    pclose(f);

    // Encrypt a message
    FILE *f = popen("p7-link-upgrade-helper.pl encrypt <key> <session_id> <counter>", "w");
    fwrite(plaintext, 1, plaintext_len, f);
    pclose(f);
    // Read output from pipe for ciphertext

EOF
    exit 0;
}

__END__

=head1 NAME

p7-link-upgrade-helper.pl - Cryptographic helper for p7.c link-upgrade

=head1 SYNOPSIS

    p7-link-upgrade-helper.pl gen-ephemeral
    p7-link-upgrade-helper.pl compute-dh <client_secret_b32> <server_pubkey_b32>
    p7-link-upgrade-helper.pl derive-key <shared_secret_b32> <session_id>
    p7-link-upgrade-helper.pl encrypt <key_b32> <session_id> <counter>
    p7-link-upgrade-helper.pl decrypt <key_b32> <session_id> <counter>

=head1 DESCRIPTION

This helper script provides cryptographic operations for the p7.c Protocol-7
client to support link-upgrade encryption. It bridges the gap between C code
that needs complex crypto operations and Perl code that can easily interface
with AMOS7 and Crypt libraries.

Each operation reads configuration from command-line arguments and performs
the requested cryptographic operation, outputting the result to stdout.

=head1 OPERATIONS

=head2 gen-ephemeral

Generates an ephemeral C25519 keypair for the client session.

Output format: Two newline-separated base32-encoded strings
  Line 1: Public key (for sending to server)
  Line 2: Secret/Private key (for local DH computation)

=head2 compute-dh

Computes the Diffie-Hellman shared secret using C25519.

Arguments:
  - client_secret_b32: Client's private key (base32)
  - server_pubkey_b32: Server's public key (base32)

Output: Shared secret (base32)

=head2 derive-key

Derives the ChaCha20-Poly1305 encryption key from the shared secret.

Arguments:
  - shared_secret_b32: DH shared secret (base32)
  - session_id: Numeric session identifier

Output: Encryption key (base32)

=head2 encrypt

Encrypts plaintext with ChaCha20-Poly1305 AEAD cipher.

Arguments:
  - key_b32: Encryption key (base32)
  - session_id: Numeric session identifier
  - counter: Message counter for nonce generation

Input (STDIN): Plaintext (binary)
Output (STDOUT): Ciphertext + 16-byte auth tag (binary)

=head2 decrypt

Decrypts ciphertext with ChaCha20-Poly1305 AEAD cipher.

Arguments:
  - key_b32: Encryption key (base32)
  - session_id: Numeric session identifier
  - counter: Message counter for nonce generation

Input (STDIN): Ciphertext + 16-byte auth tag (binary)
Output (STDOUT): Plaintext (binary)
Exit: 0 on success, 1 on auth tag verification failure

=head1 NONCE GENERATION

All encryption/decryption uses the nonce format:
  pack('N', session_id) . pack('N', counter) . "\0\0\0\0"
  = 4 bytes (session) + 4 bytes (counter) + 4 bytes (padding)
  = 12 bytes total (standard for ChaCha20-Poly1305)

=head1 DEPENDENCIES

Requires AMOS7 and Crypt modules from Protocol-7:
  - AMOS7 (for key derivation)
  - Crypt::Misc (for base32 encoding/decoding)
  - Crypt::AuthEnc::ChaCha20Poly1305 (for AEAD encryption)
  - crypt.C25519.gen_keys (Protocol-7 module)
  - crypt.C25519.compute_shared (Protocol-7 module)

=head1 AUTHOR

Protocol-7 Development Team

=head1 LICENSE

As per Protocol-7

=cut
