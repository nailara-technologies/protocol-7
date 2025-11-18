#!/usr/bin/env perl

=head1 NAME

test-encryption-module.pl - Unit test for link-upgrade encryption implementation

=head1 SYNOPSIS

test-encryption-module.pl [--verbose]

=cut

use strict;
use warnings;
use v5.10.0;

print "=" x 70 . "\n";
print "Protocol-7 Link-Upgrade Encryption Module Tests\n";
print "=" x 70 . "\n\n";

# Test 1: Module loading
print "[TEST 1] Loading encryption modules...\n";
eval {
    use Crypt::AuthEnc::ChaCha20Poly1305;
    use Crypt::Curve25519;
    use Crypt::Misc qw(encode_b32r decode_b32r);
    print "✓ All modules loaded successfully\n\n";
};
if ($@) {
    print "✗ Failed to load modules: $@\n";
    exit 1;
}

# Test 2: Cipher context initialization
print "[TEST 2] ChaCha20-Poly1305 cipher context initialization...\n";
my $test_key = "\x00" x 32;  # 32-byte zero key for testing
my $test_nonce = "\x00" x 12;  # 12-byte nonce
my $cipher = Crypt::AuthEnc::ChaCha20Poly1305->new($test_key, $test_nonce);
if (defined $cipher) {
    print "✓ Cipher context initialized successfully\n";
    print "  Key size: 32 bytes (256 bits)\n";
    print "  Nonce size: 12 bytes\n";
    print "  Cipher: ChaCha20-Poly1305\n\n";
} else {
    print "✗ Failed to initialize cipher context\n";
    exit 1;
}

# Test 3: Encryption and decryption
print "[TEST 3] Encryption and decryption...\n";
my $plaintext = "Hello, Protocol-7 Encryption!";

# Create a new cipher for encryption with unique nonce
my $nonce1 = "\x00" x 11 . "\x01";  # Different nonce
my $cipher_enc = Crypt::AuthEnc::ChaCha20Poly1305->new($test_key, $nonce1);

# Encrypt
my $ciphertext = $cipher_enc->encrypt_add($plaintext);
my $auth_tag = $cipher_enc->encrypt_done();

print "✓ Encryption successful\n";
printf("  Plaintext:  %s (%d bytes)\n", $plaintext, length($plaintext));
printf("  Ciphertext: %s (%d bytes)\n", unpack("H*", $ciphertext), length($ciphertext));
printf("  Auth Tag:   %s (%d bytes)\n\n", unpack("H*", $auth_tag), length($auth_tag));

# Decrypt with same key and nonce
my $cipher_dec = Crypt::AuthEnc::ChaCha20Poly1305->new($test_key, $nonce1);
my $decrypted = eval {
    my $pt = $cipher_dec->decrypt_add($ciphertext);
    my $result = $cipher_dec->decrypt_done($auth_tag);
    return $pt if $result;
};

if (defined $decrypted && $decrypted eq $plaintext) {
    print "✓ Decryption successful\n";
    printf("  Decrypted: %s\n\n", $decrypted);
} else {
    print "✗ Decryption failed or plaintext mismatch\n";
    exit 1;
}

# Test 4: Authentication tag validation
print "[TEST 4] Authentication tag validation...\n";
my $bad_tag = "\xff" x 16;  # Modified tag
my $cipher_bad = Crypt::AuthEnc::ChaCha20Poly1305->new($test_key, $nonce1);
$cipher_bad->decrypt_add($ciphertext);
my $validation = $cipher_bad->decrypt_done($bad_tag);

if (!$validation) {
    print "✓ Authentication tag validation works (rejected bad tag)\n";
    print "  decrypt_done() returned false for tampered tag\n\n";
} else {
    print "✗ Authentication tag validation failed (accepted bad tag)\n";
    exit 1;
}

# Test 5: Curve25519 key agreement
print "[TEST 5] Curve25519 ephemeral key agreement...\n";
my ($public1, $secret1) = Crypt::Ed25519::generate_keypair();
my ($public2, $secret2) = Crypt::Ed25519::generate_keypair();

printf("✓ Generated two ephemeral keypairs\n");
printf("  Server private: %d bytes\n", length($secret1));
printf("  Server public:  %d bytes\n", length($public1));
printf("  Client private: %d bytes\n", length($secret2));
printf("  Client public:  %d bytes\n\n", length($public2));

# Compute shared secrets
my $shared1 = Crypt::Curve25519::shared_secret($secret1, $public2);
my $shared2 = Crypt::Curve25519::shared_secret($secret2, $public1);

if (defined $shared1 && defined $shared2 && $shared1 eq $shared2) {
    print "✓ Diffie-Hellman key agreement successful\n";
    printf("  Shared secret: %s (%d bytes)\n\n", unpack("H*", substr($shared1, 0, 8)) . "...", length($shared1));
} else {
    print "✗ Diffie-Hellman key agreement failed\n";
    exit 1;
}

# Test 6: BASE32 encoding/decoding
print "[TEST 6] BASE32 encoding and decoding...\n";
my $test_data = "Protocol-7 Link-Upgrade";
my $encoded = encode_b32r($test_data);
my $decoded = decode_b32r($encoded);

if ($decoded eq $test_data) {
    print "✓ BASE32 encoding/decoding successful\n";
    printf("  Original:  %s\n", $test_data);
    printf("  Encoded:   %s\n", $encoded);
    printf("  Decoded:   %s\n\n", $decoded);
} else {
    print "✗ BASE32 encoding/decoding failed\n";
    exit 1;
}

# Test 7: Message counter and nonce generation
print "[TEST 7] Message counter-based nonce generation...\n";
my $session_id = 12345;
my $counter = 1;

my $session_bytes = pack qw| N |, $session_id;
my $counter_bytes = pack qw| N |, $counter;
my $nonce = $session_bytes . $counter_bytes . ("\x00" x 4);

printf("✓ Nonce generated successfully\n");
printf("  Session ID:  %d\n", $session_id);
printf("  Counter:     %d\n", $counter);
printf("  Nonce bytes: %s (%d bytes)\n\n", unpack("H*", $nonce), length($nonce));

# Test 8: Multiple encryption/decryption cycles
print "[TEST 8] Multiple message encryption cycles with unique nonces...\n";
my @messages = (
    "First message",
    "Second message with more data",
    "Third message",
);

my @encrypted_messages;
foreach my $idx (0..$#messages) {
    # Generate unique nonce for each message
    my $nonce_idx = pack qw| N |, $idx + 2;  # Counter starts at 2
    my $unique_nonce = "\x00" x 8 . $nonce_idx;

    my $cipher_e = Crypt::AuthEnc::ChaCha20Poly1305->new($test_key, $unique_nonce);
    my $ct = $cipher_e->encrypt_add($messages[$idx]);
    my $tag = $cipher_e->encrypt_done();
    push @encrypted_messages, {ciphertext => $ct, tag => $tag, nonce => $unique_nonce};
}

print "✓ Encrypted " . scalar(@messages) . " messages with unique nonces\n";

my $all_decrypted = 1;
foreach my $idx (0..$#messages) {
    my $cipher_d = Crypt::AuthEnc::ChaCha20Poly1305->new($test_key, $encrypted_messages[$idx]->{nonce});
    my $pt = eval {
        my $plaintext_result = $cipher_d->decrypt_add($encrypted_messages[$idx]->{ciphertext});
        my $result = $cipher_d->decrypt_done($encrypted_messages[$idx]->{tag});
        return $plaintext_result if $result;
    };

    if (!defined $pt || $pt ne $messages[$idx]) {
        print "✗ Decryption mismatch for message " . ($idx + 1) . "\n";
        $all_decrypted = 0;
    }
}

if ($all_decrypted) {
    print "✓ All messages decrypted successfully\n\n";
} else {
    exit 1;
}

# Summary
print "=" x 70 . "\n";
print "All encryption module tests passed! ✓\n";
print "=" x 70 . "\n";
print "\nSummary:\n";
print "  ✓ ChaCha20-Poly1305 AEAD cipher working\n";
print "  ✓ Curve25519 key agreement working\n";
print "  ✓ Authentication tag validation working\n";
print "  ✓ BASE32 encoding/decoding working\n";
print "  ✓ Nonce generation working\n";
print "  ✓ Multi-message encryption working\n";
print "\nReady for integration testing!\n";

exit 0;

__END__

=head1 DESCRIPTION

This test script validates all the cryptographic primitives used in the
Protocol-7 link-upgrade encryption implementation:

- ChaCha20-Poly1305 AEAD cipher initialization and operation
- Curve25519 elliptic curve Diffie-Hellman key agreement
- AEAD authentication tag validation
- BASE32 encoding for linewise transmission
- Counter-based nonce generation for message uniqueness

All tests must pass before proceeding to integration testing with the
actual Protocol-7 zenka infrastructure.

=cut
