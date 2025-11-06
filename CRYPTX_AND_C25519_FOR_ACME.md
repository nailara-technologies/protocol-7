# CryptX and Curve25519 - Protocol-7 Existing Crypto for ACME

**Status**: Analysis of existing cryptographic infrastructure
**Date**: 2025-11-07
**Focus**: How to leverage existing Curve25519 and CryptX for ACME implementation

## Existing Cryptographic Infrastructure

Protocol-7 already has **comprehensive cryptographic implementations** that we can use for ACME:

### 1. Curve25519 Ed25519 (EdDSA)

**Location**: `modules/crypt.C25519.*`
**Library**: `Crypt::Ed25519` (already loaded and working)
**Status**: FULLY OPERATIONAL

#### Available Functions

| Module | Purpose | Status |
|--------|---------|--------|
| `crypt.C25519.gen_keys` | Generate Ed25519 keypair | ✓ Working |
| `crypt.C25519.load_keypair` | Load existing keypair | ✓ Working |
| `crypt.C25519.generate_session_keypair` | Session-specific keys | ✓ Working |
| `crypt.C25519.cmd.get-public-key` | Export public key | ✓ Working |
| `crypt.C25519.cmd.get-session-sig` | Get signature | ✓ Working |
| `crypt.C25519.decrypt_secret_key` | Decrypt stored key | ✓ Working |

#### Key Generation Flow

```perl
# From crypt.C25519.gen_keys (lines 29-95):

1. Generate 32-byte secret key:
   $secret_key = <[base.prng.bytes]>->(32)
   OR
   $secret_key = AMOS7::13::key_32(\$passphrase, \$name)

2. Ensure "harmonic" (true) public keys:
   while (not $TRUE) {
       $public_key = Crypt::Ed25519::eddsa_public_key($secret_key);
       $TRUE = AMOS7::Assert::Truth::is_true($public_key, ...)
       # Regenerate if needed for harmonic truth
   }

3. Generate keypair:
   ($public_key, $private_key) = Crypt::Ed25519::generate_keypair($secret_key);

4. Store with metadata:
   $keys{'C25519'}{$name} = {
       public => $public_key,      # 32-byte public key
       secret => $secret_key,      # 32-byte secret/seed
       private => $private_key,    # Computed private key
       time_loaded => <timestamp>,
   };

5. Lock in memory (no swap):
   IO::AIO::aio_mlock($keys{'C25519'}{$name}{'private'}, 0, 64);
   IO::AIO::aio_mlock($keys{'C25519'}{$name}{'secret'}, 0, 32);
```

#### Key Storage

```perl
# Public key export (crypt.C25519.cmd.get-public-key):
encode_b32r($keys{'C25519'}{$name}{'public'})

# Signature export:
$keys{'C25519'}{$session_keyname}{'sig-reply'}
```

#### Encoding

**Base32r** (Base32 RFC 4648 variant with reverse alphabet):
- Public key: 32 bytes → 52 Base32r characters
- Used throughout Protocol-7 for key representation

### 2. CryptX (Crypt::Digest, Crypt::PK::RSA)

**Library**: CryptX 0.087 (libcrypt_cver)
**Status**: PARTIALLY AVAILABLE

#### What Works

```
✓ Crypt::Digest::SHA256   - SHA-256 hashing
✓ Crypt::PK::RSA          - RSA-1024 key generation & signing
✓ Crypt::PK::ECC          - ECDSA (if available)
```

#### What Doesn't Work

```
✗ RSA-2048, RSA-4096      - CryptX limitation (buffer size issue)
✗ PEM export              - Buffer overflow on larger keys
```

**Solution**: Use `Crypt::OpenSSL::RSA` for RSA-2048+ keys (already available)

### 3. AMOS7 Custom Crypto

**Location**: `data/lib-path/pm/AMOS7/`
**Available**:
- `AMOS7::13::key_32()` - 32-byte key derivation from passphrase
- `AMOS7::Assert::Truth::is_true()` - Harmonic truth checking
- `AMOS7::CHKSUM::*` - Integrity verification

## ACME Implementation Strategy

### Option A: Pure Curve25519 (EdDSA) for ACME Account Key

**Advantages**:
- ✓ Already fully implemented in Protocol-7
- ✓ Ed25519 supported by Let's Encrypt
- ✓ Key locking in memory
- ✓ Harmonic key generation
- ✓ Proven in production

**Disadvantages**:
- ✗ RFC 8555 primarily uses RSA (though EdDSA supported)
- ✗ Requires implementing RFC 8037 (CFRG Elliptic Curve Signatures)

**Code Reuse**:
```perl
# Create ACME account with Ed25519
my ($ed_keypair, $key_name) = <[crypt.C25519.gen_keys]>->(
    'acme-account',
    $admin_email  # passphrase for deterministic key
);

# Get public key for JWK
my $public_key_b32 = encode_b32r($ed_keypair->{public});

# Sign ACME requests
my $signature = Crypt::Ed25519::sign($message, $ed_keypair->{secret}, $ed_keypair->{public});
```

### Option B: RSA-2048 (Traditional ACME) with CryptX/OpenSSL

**Advantages**:
- ✓ Standard ACME approach
- ✓ Works with Crypt::OpenSSL::RSA
- ✓ Better tool support

**Disadvantages**:
- ✗ Requires importing Crypt::OpenSSL::RSA
- ✗ More CPU for key generation

**Code Reuse**:
```perl
# Use existing RSA modules for CSR (we already have them)
use Crypt::OpenSSL::RSA;
use Crypt::OpenSSL::X509;

my $rsa = Crypt::OpenSSL::RSA->generate_key(2048);
# ... rest of RSA/ACME flow
```

### Option C: Hybrid (Recommended) ✓

**Use Curve25519 for ACME account key, RSA for certificate keys**:

```perl
# Account key: Ed25519 (from existing C25519 implementation)
my ($acme_account_key, $acme_key_name) = <[crypt.C25519.gen_keys]>->(
    'acme-account-' . time(),
    <letsencrypt.admin.email>
);

# Certificate keys: RSA-2048 (from Crypt::OpenSSL::RSA)
my $cert_rsa = Crypt::OpenSSL::RSA->generate_key(2048);

# Benefits:
# - Account key: Uses proven C25519 implementation
# - Cert key: Standard RSA for compatibility
# - Minimal new dependencies
```

## Recommended Implementation

### For ACME Account Key (EdDSA)

**Use existing**: `crypt.C25519.gen_keys` and `Crypt::Ed25519`

Replace in `letsencrypt.child.generate_account_key`:

```perl
## OLD (Crypt::OpenSSL::RSA):
my $rsa = Crypt::OpenSSL::RSA->generate_key(2048);
$rsa->use_sha256_hash();
my $key_pem = $rsa->get_private_key_string();

## NEW (Curve25519):
my ($keypair, $key_name) = <[crypt.C25519.gen_keys]>->(
    'acme-account',
    <letsencrypt.admin.email>
);
# keypair->{secret}, keypair->{public}, keypair->{private}

# For JWK, extract components from Base32r encoded key
my $public_key = $keypair->{public};  # 32 bytes
```

### For CSR Certificate Keys (RSA)

**Continue using**: `Crypt::OpenSSL::RSA` and `Crypt::OpenSSL::X509`

(Already implemented in `letsencrypt.child.generate_csr`)

### For Signing (EdDSA with Ed25519)

Replace JWS signing with Ed25519:

```perl
## OLD (RSA-PKCS#1 v1.5):
my $signature = $rsa->sign($signing_input);

## NEW (Ed25519):
my $signature = Crypt::Ed25519::sign(
    $signing_input,
    $acme_account_key->{secret},
    $acme_account_key->{public}
);
```

### For JWK Header (EdDSA)

According to RFC 8037 (CFRG in JOSE):

```perl
my $jwk = {
    kty => 'OKP',              # Octet Key Pair
    crv => 'Ed25519',          # Curve
    x => encode_base64url($public_key),  # Public key
};
```

## Implementation Changes Required

### 1. Module: `letsencrypt.child.generate_account_key`

Change from:
```perl
my $rsa = Crypt::OpenSSL::RSA->generate_key(2048);
```

To:
```perl
my ($ed_keypair, $key_name) = <[crypt.C25519.gen_keys]>->(
    'acme-account-' . <letsencrypt.admin.email>,
    <letsencrypt.admin.email>
);
<letsencrypt.child.acme_client>{account_key} = $ed_keypair;
```

### 2. Module: `letsencrypt.child.get_jwk`

Change from RSA-PKCS#1 v1.5 to RFC 8037 EdDSA:

```perl
my $jwk = {
    kty => 'OKP',
    crv => 'Ed25519',
    x => <[letsencrypt.child.encode_base64url]>->($account_key->{public}),
};
```

### 3. Module: `letsencrypt.child.create_jws`

Change from RSA signing to Ed25519:

```perl
# OLD:
my $signature = $rsa->sign($signing_input);

# NEW:
my $signature = Crypt::Ed25519::sign(
    $signing_input,
    <letsencrypt.child.acme_client>{account_key}->{secret},
    <letsencrypt.child.acme_client>{account_key}->{public}
);
```

### 4. Load Crypt::Ed25519 in pre_init

In `letsencrypt.base.pre_init`:
```perl
<[base.perlmod.autoload]>->('Crypt::Ed25519');
```

## Advantages of This Approach

| Aspect | Benefit |
|--------|---------|
| **Reuse** | Leverages 59 existing crypt modules |
| **Security** | Uses proven C25519 implementation |
| **Memory** | Key locking via IO::AIO::aio_mlock |
| **Entropy** | Uses Protocol-7's PRNG (Crypt::PRNG::Fortuna) |
| **Truth** | Harmonic key generation (AMOS7) |
| **Compatibility** | EdDSA supported by Let's Encrypt |
| **Dependencies** | Minimal new deps (already have CryptX + OpenSSL) |

## Testing Plan

1. **Key Generation**
   ```perl
   my ($kp, $name) = <[crypt.C25519.gen_keys]>->('test-acme', 'admin@example.com');
   assert($kp->{public} && length($kp->{public}) == 32);
   assert($kp->{secret} && length($kp->{secret}) == 32);
   ```

2. **Signing**
   ```perl
   my $sig = Crypt::Ed25519::sign("test message", $kp->{secret}, $kp->{public});
   assert(Crypt::Ed25519::verify($sig, "test message", $kp->{public}));
   ```

3. **JWK Format**
   ```perl
   my $jwk = {kty => 'OKP', crv => 'Ed25519', x => encode_base64url($kp->{public})};
   assert($jwk->{kty} eq 'OKP');
   ```

4. **ACME Registration**
   - Test with Let's Encrypt staging server
   - Verify EdDSA keys accepted
   - Verify nonce and challenge handling

## Migration Checklist

- [ ] Load `Crypt::Ed25519` in `letsencrypt.base.pre_init`
- [ ] Update `letsencrypt.child.generate_account_key` to use `crypt.C25519.gen_keys`
- [ ] Update `letsencrypt.child.get_jwk` for RFC 8037 format
- [ ] Update `letsencrypt.child.create_jws` to use Ed25519 signing
- [ ] Test key generation
- [ ] Test signing and verification
- [ ] Test JWK format
- [ ] Test with Let's Encrypt staging server
- [ ] Document RFC 8037 compliance in code

## References

- RFC 8037 - CFRG Elliptic Curve Diffie-Hellman (ECDH) and Signatures in JOSE
- RFC 8555 - Automatic Certificate Management Environment (ACME)
- Ed25519 - Edwards Curve Digital Signature Algorithm
- Protocol-7 modules: `modules/crypt.C25519.*`
- CryptX documentation: https://metacpan.org/pod/CryptX

## Conclusion

**Use hybrid approach: Ed25519 for ACME account key, RSA-2048 for certificate keys**

This leverages Protocol-7's existing, battle-tested Curve25519 implementation while maintaining ACME standard compatibility with the industry-standard RSA certificates.

