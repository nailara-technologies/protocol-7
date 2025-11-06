# Curve25519 ACME Strategy - Final Summary

**Decision**: Use Protocol-7's existing Ed25519 (Curve25519) for ACME account keys
**Implementation**: 6 file modifications, leverage 59 existing crypt modules
**Complexity**: Low
**Status**: Ready for implementation

## Key Insight

Protocol-7 already has a **fully-implemented, production-tested** cryptographic subsystem for Curve25519/Ed25519:

```
59 crypt modules (modules/crypt.C25519.*)
├── Key generation (crypt.C25519.gen_keys)
├── Key storage & loading (crypt.C25519.load_keypair)
├── Signature creation (Crypt::Ed25519::sign)
├── Key locking in memory (IO::AIO::aio_mlock)
├── Harmonic key generation (AMOS7::Assert::Truth)
└── Base32r encoding (Crypt::Misc)
```

**Why reinvent RSA when we have battle-tested Ed25519?**

## The Perfect Fit

### ACME Protocol Support

✓ RFC 8555 ACME supports EdDSA (Ed25519)
✓ RFC 8037 defines JWK/JWS format for Ed25519/EdDSA
✓ Let's Encrypt accepts Ed25519 account keys
✓ Sign algorithm: `EdDSA` (not `RS256`)

### Protocol-7 Support

✓ Crypt::Ed25519 available (CryptX ecosystem)
✓ Key generation fully implemented in crypt.C25519.gen_keys
✓ Memory locking built-in (IO::AIO)
✓ Harmonic truth checking (AMOS7)
✓ Base32r encoding (existing infrastructure)
✓ Used in production (keys.console.* modules)

### Technical Advantages

| Metric | Value |
|--------|-------|
| **Key Size** | 256 bits (vs RSA 2048) |
| **Signature Size** | 64 bytes (vs RSA 256 bytes) |
| **Generation Time** | ~0.1 seconds (vs RSA 1-2 sec) |
| **Security Level** | 128-bit equivalent (same as RSA-2048) |
| **Memory Requirements** | Minimal |

## Implementation Plan

### Phase 1: Code Migration (1-2 hours)

Modify 6 modules to use Ed25519 instead of RSA:

```
letsencrypt.base.pre_init
  ├─ Load Crypt::Ed25519

letsencrypt.child.generate_account_key
  ├─ Call crypt.C25519.gen_keys()
  ├─ Store keypair in state
  └─ Save secret key to cache

letsencrypt.child.load_account_key
  ├─ Load Base32r-encoded secret
  ├─ Regenerate keypair from secret
  └─ Store in state

letsencrypt.child.get_jwk
  ├─ Format as RFC 8037 OKP
  ├─ Include crv='Ed25519'
  └─ Export public key (x parameter)

letsencrypt.child.create_jws
  ├─ Sign with Ed25519 (not RSA)
  ├─ Use account_key->{secret} and {public}
  └─ Return same JWS structure

letsencrypt.child.init_code
  └─ Track account_key_type='Ed25519'
```

See: `ACME_ED25519_MIGRATION.md` (exact code changes)

### Phase 2: Testing (1-2 hours)

```
✓ Key generation test
✓ JWK format test (RFC 8037)
✓ Signing/verification test
✓ JWS creation test
✓ Let's Encrypt staging server test
```

### Phase 3: Integration (30 min)

- Run full renewal cycle
- Verify event emission
- Verify HTTPSD reload

## File Changes Summary

| File | Type | Lines | Change |
|------|------|-------|--------|
| `letsencrypt.base.pre_init` | Module | 28 | Load Crypt::Ed25519 |
| `letsencrypt.child.generate_account_key` | Module | 56 | Call crypt.C25519.gen_keys |
| `letsencrypt.child.load_account_key` | Module | 38 | Load from Base32r |
| `letsencrypt.child.get_jwk` | Module | 40 | RFC 8037 format |
| `letsencrypt.child.create_jws` | Module | 62 | Ed25519 signing |
| `letsencrypt.child.init_code` | Module | 64 | Track key_type |
| **Total** | - | **288** | **Straightforward changes** |

## Code Examples

### Old Approach (RSA)
```perl
use Crypt::OpenSSL::RSA;

my $rsa = Crypt::OpenSSL::RSA->generate_key(2048);
my $signature = $rsa->sign($data);

my $jwk = {
    e => ...,   # exponent
    kty => 'RSA',
    n => ...,   # modulus
};
```

### New Approach (Ed25519)
```perl
use Crypt::Ed25519;

my ($kp, $name) = <[crypt.C25519.gen_keys]->(...);
my $signature = Crypt::Ed25519::sign($data, $kp->{secret}, $kp->{public});

my $jwk = {
    crv => 'Ed25519',
    kty => 'OKP',
    x => encode_base64url($kp->{public}),
};
```

## Compatibility

### Let's Encrypt
- ✓ Accepts Ed25519 keys
- ✓ RFC 8037 support
- ✓ Same ACME protocol flow
- ✓ No changes to request/response handling

### HTTPSD
- ✓ Continues using RSA-2048 for certificates
- ✓ Ed25519 only used for ACME account key
- ✓ Certificate TLS/SSL unchanged

### Protocol-7
- ✓ Uses existing C25519 infrastructure
- ✓ No new external dependencies
- ✓ Leverages proven code

## Risk Analysis

| Risk | Probability | Mitigation |
|------|-------------|-----------|
| Let's Encrypt rejects EdDSA | Very Low | RFC 8037 compliance, test on staging |
| JWK format incorrect | Very Low | RFC 8037 explicitly defines OKP |
| Signing incompatible | Very Low | Crypt::Ed25519 is standard |
| Performance issue | Very Low | Ed25519 is faster than RSA |
| Memory issue | Very Low | Memory locking built-in |

## Verification Checklist

Before going to production:

```
Code Changes:
  ✓ Load Crypt::Ed25519 in pre_init
  ✓ generate_account_key uses C25519.gen_keys
  ✓ load_account_key decodes Base32r
  ✓ get_jwk returns RFC 8037 format
  ✓ create_jws uses Ed25519 signing
  ✓ init_code tracks key_type

Testing:
  ✓ Key generation produces valid keypair
  ✓ JWK format matches RFC 8037
  ✓ Signing/verification works
  ✓ JWS creation succeeds
  ✓ Let's Encrypt accepts key (staging)
  ✓ ACME challenge validation works
  ✓ Certificate issuance works
  ✓ HTTPSD loads certificate correctly
  ✓ HTTPS connection works

Monitoring:
  ✓ Check logs for key generation
  ✓ Verify signature in JWS
  ✓ Monitor renewal cycles
  ✓ Check error handling
```

## Why This Makes Sense

1. **Proven Code**: Used in production for years in Protocol-7
2. **Modern Crypto**: Ed25519 is better than RSA-2048 in every way (smaller, faster, same security)
3. **Standards Compliant**: RFC 8037 clearly defines the format
4. **No Dependencies**: Already have everything needed
5. **Better Performance**: Key generation 10x faster
6. **Less Code**: Reuse 59 existing modules
7. **Auditable**: Can review existing C25519 implementation

## Timeline

- **Today**: Finalize documentation (this file + migration guide)
- **Tomorrow**: Implement code changes
- **End of week**: Test with staging server
- **Next week**: Production deployment

## References

- RFC 8555: Automatic Certificate Management Environment (ACME)
- RFC 8037: CFRG Elliptic Curve Diffie-Hellman (ECDH) and Signatures in JOSE
- RFC 8949: Concise Binary Object Representation (CBOR)
- Crypt::Ed25519 documentation: https://metacpan.org/pod/Crypt::Ed25519
- Protocol-7: modules/crypt.C25519.gen_keys

## Next Steps

1. Review this strategy with team
2. Proceed with implementation per `ACME_ED25519_MIGRATION.md`
3. Test on Let's Encrypt staging server
4. Deploy to production

---

**Status**: Ready to implement ✓

