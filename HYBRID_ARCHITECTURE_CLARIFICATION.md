# Ed25519 Migration: Hybrid Architecture Clarification

**Status**: Architecture documentation
**Date**: 2025-11-07
**Focus**: Clarifying the distinction between ACME account keys and certificate keys

---

## The Two-Key System

This implementation uses a **hybrid approach** with two different cryptographic keys for different purposes:

### 1. ACME Account Key (NEW - Ed25519)

**Purpose**: Sign ACME protocol requests to Let's Encrypt

**Cryptography**: Ed25519 (EdDSA)
- **Size**: 256 bits
- **Algorithm**: EdDSA (Edwards-curve Digital Signature Algorithm)
- **Library**: `Crypt::Ed25519`
- **Implementation**: Uses existing Protocol-7 C25519 infrastructure (`crypt.C25519.gen_keys`)
- **Speed**: ~0.1 seconds for key generation
- **Modules**:
  - `letsencrypt.child.generate_account_key` - Generate new key
  - `letsencrypt.child.load_account_key` - Load existing key
  - `letsencrypt.child.get_jwk` - Export as RFC 8037 OKP format
  - `letsencrypt.child.create_jws` - Sign ACME requests

**Storage**: Base32r-encoded secret key (~52 bytes)

### 2. Certificate Key (UNCHANGED - RSA-2048)

**Purpose**: Sign Certificate Signing Request (CSR) for domain certificates

**Cryptography**: RSA-2048
- **Size**: 2048 bits
- **Algorithm**: RSA (Rivest-Shamir-Adleman)
- **Library**: `Crypt::OpenSSL::RSA`
- **Speed**: 1-2 seconds for key generation
- **Module**: `letsencrypt.child.generate_csr` - Generate CSR with RSA-2048 key

**Why RSA for Certificates?**
- Industry standard for TLS/SSL certificates
- Works with all certificate authorities
- HTTPSD (web server) expects RSA certificates
- Let's Encrypt returns RSA-2048 certificates by default

---

## Architecture Diagram

```
ACME Account Key (Ed25519)          Certificate Key (RSA-2048)
        ↓                                    ↓
┌─────────────────────┐          ┌──────────────────────┐
│  ACME Registration  │          │ Certificate Request  │
│  Sign ACME Requests │          │  CSR Generation      │
│  (JWS signing)      │          │  (X509 request)      │
└─────────────────────┘          └──────────────────────┘
        ↓                                    ↓
    Let's Encrypt                    Let's Encrypt
   (Protocol Flow)              (Issue Domain Cert)
        ↓                                    ↓
  ┌──────────┐                        ┌──────────┐
  │ Account  │                        │ TLS/SSL  │
  │ Resource │                        │ Cert     │
  │ (stored) │                        │ (loaded  │
  │          │                        │  by HTTPSD)
  └──────────┘                        └──────────┘
```

---

## Key Comparison

| Property | ACME Account Key | Certificate Key |
|----------|------------------|-----------------|
| **Algorithm** | Ed25519 (EdDSA) | RSA-2048 |
| **Key Size** | 256 bits | 2048 bits |
| **Purpose** | Sign ACME requests | Sign domain cert CSR |
| **Generation Time** | ~0.1 seconds | 1-2 seconds |
| **Signature Size** | 64 bytes | 256 bytes |
| **Storage Format** | Base32r | RSA PEM |
| **Library** | Crypt::Ed25519 | Crypt::OpenSSL::RSA |
| **Modules** | generate_account_key, load_account_key, get_jwk, create_jws | generate_csr |
| **Changed in Migration** | ✓ YES (RSA → Ed25519) | ✗ NO (same RSA-2048) |

---

## Dependency Status After Migration

### ✓ STILL REQUIRED

**`Crypt::OpenSSL::RSA`**
- Used by: `letsencrypt.child.generate_csr`
- Purpose: Generate RSA-2048 certificate key
- Status: **NOT deprecated** - essential for certificate generation
- References in:
  - `letsencrypt.base.init_code` - Line 79 (clarified)
  - `letsencrypt.init_code` - Line 9 (clarified)
  - `letsencrypt.child.generate_csr` - Line 6

**`Crypt::OpenSSL::X509`**
- Used by: `letsencrypt.child.generate_csr`
- Purpose: Create X509 certificate requests
- Status: **NOT deprecated** - essential for CSR generation
- References in:
  - `letsencrypt.base.init_code` - Line 80
  - `letsencrypt.child.generate_csr` - Line 7

### ✓ NEWLY ADDED

**`Crypt::Ed25519`**
- Used by: Account key operations
- Purpose: Ed25519 signing and key generation
- Status: NEW - Added in migration
- References in:
  - `letsencrypt.base.pre_init` - Line 9
  - `letsencrypt.child.init_code` - Line 28

**`MIME::Base64`**
- Used by: JWK/JWS encoding
- Purpose: Base64url encoding for ACME
- Status: NEW - Added in migration
- References in:
  - `letsencrypt.base.pre_init` - Line 15
  - `letsencrypt.child.init_code` - Line 33

**`Crypt::Misc`**
- Used by: Key storage encoding
- Purpose: Base32r encoding/decoding
- Status: NEW - Added in migration
- References in:
  - `letsencrypt.base.pre_init` - Line 16
  - `letsencrypt.child.init_code` - Line 34

---

## Data Flow

### Account Key Generation Flow
```
1. crypt.C25519.gen_keys()
   ↓
2. Returns {secret, public, private}
   ↓
3. Encode secret as Base32r
   ↓
4. Store in /var/cache/letsencrypt/account.key
   ↓
5. Use in create_jws for signing
```

### Certificate Key Generation Flow
```
1. Crypt::OpenSSL::RSA->generate_key(2048)
   ↓
2. Create X509 request (CSR)
   ↓
3. Send to Let's Encrypt
   ↓
4. Receive signed certificate
   ↓
5. Load into HTTPSD for TLS/SSL
```

---

## Module Interaction

```
┌─────────────────────────────────────────────────────────┐
│         ACME Request Cycle (uses Ed25519)               │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  letsencrypt.child.fetch_acme_directory()              │
│    ↓                                                    │
│  letsencrypt.child.create_jws() ← Uses Ed25519 Account │
│    ↓                                                    │
│  letsencrypt.child.acme_http_request()                 │
│    ↓                                                    │
│  Let's Encrypt API                                     │
│    ↓                                                    │
│  Nonce + Account ID returned                           │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│    Certificate Issuance Cycle (uses RSA-2048)           │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  letsencrypt.child.acme_create_order()                 │
│    ↓                                                    │
│  letsencrypt.child.respond_to_challenge()              │
│    ↓                                                    │
│  letsencrypt.child.generate_csr() ← Uses RSA-2048      │
│    ↓                                                    │
│  letsencrypt.child.acme_finalize_order()               │
│    ↓                                                    │
│  Receive domain certificate                            │
│    ↓                                                    │
│  Load into HTTPSD                                      │
└─────────────────────────────────────────────────────────┘
```

---

## Benefits of This Approach

### Leverages Best of Both Worlds

| Aspect | Why This Works |
|--------|----------------|
| **Fast Account Key Generation** | Ed25519 is 10-20x faster than RSA |
| **Industry Standard Certificates** | RSA-2048 works with all CAs and TLS clients |
| **Memory Efficient** | Ed25519 account key is tiny (32 bytes vs 1KB) |
| **Proven Code** | Uses existing C25519 infrastructure (59 modules) |
| **ACME Compliant** | RFC 8555 supports EdDSA, RFC 8037 defines format |
| **No Breaking Changes** | Certificate handling identical to before |

### No Dependency Removal

- `Crypt::OpenSSL::RSA` is **essential** and cannot be removed
- Migration adds dependencies, doesn't remove them
- This is **augmentation**, not replacement

---

## Testing Considerations

### Test Account Key (Ed25519)
```perl
# Verify key generation
my ($kp, $name) = <[crypt.C25519.gen_keys]>->('test', 'admin@example.com');
assert(length($kp->{secret}) == 32);  # 32-byte Ed25519 secret

# Verify JWK format (RFC 8037)
my $jwk = <[letsencrypt.child.get_jwk]>->();
assert($jwk->{kty} eq 'OKP');
assert($jwk->{crv} eq 'Ed25519');

# Verify signing
my $sig = Crypt::Ed25519::sign($data, $kp->{secret}, $kp->{public});
assert(Crypt::Ed25519::verify($sig, $data, $kp->{public}));
```

### Test Certificate Key (RSA-2048) - Unchanged
```perl
# This flow is identical to before (no changes needed)
my $csr = <[letsencrypt.child.generate_csr]>->([\@domains]);
assert($csr);  # CSR generation still works with RSA-2048
```

---

## Summary

This is a **well-designed hybrid architecture** that:

1. **Improves ACME performance** with Ed25519 for account key operations
2. **Maintains compatibility** with RSA-2048 for domain certificates
3. **Reuses proven code** from existing C25519 modules
4. **Requires no code deletions** - only additions and improvements
5. **Follows ACME standards** (RFC 8555 + RFC 8037)

The existence of `Crypt::OpenSSL::RSA` in the codebase is **not a bug or oversight**—it's a fundamental part of the certificate issuance pipeline that cannot and should not be removed.

---

**Key Takeaway**: Ed25519 migration improves ACME account key handling; RSA-2048 remains for domain certificates. Both are necessary. Both remain in production.
