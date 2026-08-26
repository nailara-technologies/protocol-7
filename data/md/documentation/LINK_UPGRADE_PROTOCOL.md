# Protocol-7 Link-Upgrade (Encryption) Protocol

## Overview

Link-upgrade is an optional feature that allows Protocol-7 sessions to transition from unencrypted communication (state 1) to encrypted communication (state 3) using ChaCha20-Poly1305 AEAD cipher with Curve25519 key agreement.

## Design Principles

1. **Optional**: Sessions remain in state 1 indefinitely unless link-upgrade is explicitly requested
2. **Transparent**: Encryption is transparent to applications above the transport layer
3. **Negotiated**: Client and server negotiate capabilities (encryption, compression, encoding)
4. **Perfect Forward Secrecy**: Ephemeral Curve25519 keypairs for each session
5. **Layered**: Encryption wraps plaintext, encoding wraps encrypted data, all linewise

## States

### State 1: Authenticated (Stable)
- Normal unencrypted operation
- Sessions remain here indefinitely unless link-upgrade requested
- Zero overhead for unencrypted deployments

### State 2: Link-Upgrade Negotiation (Optional)
- Negotiates encryption parameters
- Performs C25519 Diffie-Hellman key exchange
- Exchanges ephemeral public keys (BASE32 encoded)
- Confirms encoding mode (utf7, base32, base32-xz)
- Timeout: 17 seconds default
- Failed negotiation returns to state 1

### State 3: Encrypted Session (Optional)
- ChaCha20-Poly1305 AEAD cipher active
- Optional link-layer encoding (BASE32, UTF-7, XZ compression)
- All traffic encrypted and authenticated
- Message counter-based nonce (session_id || counter || padding)
- Active for session lifetime

## Handshake Protocol

### 1. Initiate Link-Upgrade (Client → Server)

```
Client → Server: link-upgrade [encoding_mode]
Server → Client: TRUE
Server enters state 2, calls protocol.protocol-7.link-upgrade.init
- Generates ephemeral Curve25519 keypair
- Stores in session ephemeral key info
- Sends SIZE 0 (ready for key exchange)
```

### 2. Client Generates Keypair (Client-side)

```
Client:
- Generates ephemeral Curve25519 keypair
- Encodes public key in BASE32
```

### 3. Key Exchange (Client → Server)

```
Client → Server: link-pub-key <base32_encoded_pubkey>
Server:
- Decodes BASE32 public key
- Performs DH: shared_secret = DH(server_private, client_public)
- Stores shared secret in session
- Sends SIZE 0 (acknowledged)
```

### 4. Confirm Encoding (Client → Server)

```
Client → Server: link-confirm-encoding [utf7|base32|base32-xz|none]
Server:
- Validates encoding mode
- Stores negotiated encoding
- Sends SIZE 0 (acknowledged)
```

### 5. Complete Handshake (Client → Server)

```
Client → Server: link-complete
Server:
- Calls protocol.protocol-7.encryption.init
  - Derives encryption key from shared secret (AMOS7::13::key_32)
  - Initializes ChaCha20-Poly1305 cipher context
  - Installs encryption wrappers
  - Installs encoding wrappers (if negotiated)
- Transitions to state 3
```

## Message Format

### Encrypted Message Structure

```
[linewise input] → BASE32 decode (optional) → decompress (optional)
                → ChaCha20-Poly1305 decrypt → plaintext

plaintext → ChaCha20-Poly1305 encrypt → compress (optional)
         → BASE32 encode (optional) → [linewise output]
```

### AEAD Authentication Tag

- Location: Last 16 bytes of ciphertext
- Derived from: ChaCha20-Poly1305 authenticate_decrypt() / encrypt_done()
- Validates: Both ciphertext integrity and authentication

### Nonce Generation

```
12-byte nonce = [session_id (4-bytes)] || [message_counter (4-bytes)] || [padding (4-bytes)]

Read-side counter:  session->{'link_read_counter'}
Write-side counter: session->{'link_write_counter'}
```

## Encryption Key Derivation

```
shared_secret = C25519_DH(our_ephemeral_private, client_ephemeral_public)
encryption_key = AMOS7::13::key_32(\$shared_secret, session_id)
```

- Key size: 32 bytes (256 bits) - suitable for ChaCha20-Poly1305
- Derived from: Curve25519 ECDH shared secret (32 bytes)
- Seeded with: Session ID for entropy variation

## Implementation Status

### Server-Side ✅ Complete

- [x] Protocol.protocol-7.init_code - State definitions (0, 1, 2, 3)
- [x] cube.cmd.link-upgrade - Initiates link-upgrade, triggers state 1→2
- [x] protocol.protocol-7.link-upgrade.init - Sets up ephemeral keys, capabilities
- [x] base.handler.link-upgrade - Handles handshake protocol, triggers state 2→3
- [x] protocol.protocol-7.encryption.init - Initializes cipher, installs wrappers
- [x] base.handler.read.encryption-wrapper - Decrypts incoming messages
- [x] base.handler.write.encryption-wrapper - Encrypts outgoing messages
- [x] base.handler.read.encoding-wrapper - Decodes BASE32/UTF-7
- [x] base.handler.write.encoding-wrapper - Encodes to BASE32/UTF-7
- [x] crypt.C25519.compute_shared - Performs DH key agreement

### Client-Side ⚠️ Partial

- [ ] p7.c - C client needs: Curve25519 key generation, ECDH, BASE32 encoding
  - Note: Requires linking with libcrypto or similar
  - Can use system openssl if available

- [ ] bin/nshell - Perl client (has all crypto modules available)
  - Template: bin/test-link-upgrade-client.pl
  - Crypt::Curve25519 - already used in server-side code
  - Crypt::Misc - BASE32 encoding/decoding

- [x] test-link-upgrade-client.pl - Basic test client for validation

## Testing

### Test Client

```bash
# Run with default settings
/home/user/protocol-7/bin/test-link-upgrade-client.pl

# With verbose output
/home/user/protocol-7/bin/test-link-upgrade-client.pl --verbose

# With custom encoding
/home/user/protocol-7/bin/test-link-upgrade-client.pl --encoding base32 --verbose

# With custom socket path
/home/user/protocol-7/bin/test-link-upgrade-client.pl --socket /var/run/.7/UNIX/NIW7OAQ
```

### Test-Link-Upgrade Zenka

```bash
# Start test zenka
/home/user/protocol-7/bin/Protocol-7 test-link-upgrade

# In another terminal, run test client
/home/user/protocol-7/bin/test-link-upgrade-client.pl --verbose

# Check logs
/home/user/protocol-7/bin/Protocol-7 test-link-upgrade buffer-show
```

## Encoding Modes

### UTF-7 (future)
- 7-bit safe transmission
- Suitable for ASCII-limited channels
- Larger output than original (~14% overhead)

### BASE32 (recommended)
- 5-bit safe transmission
- Suitable for all channels
- ~25% size overhead
- Uses RFC4648 alphabet (A-Z, 2-7)

### BASE32-XZ (optimal compression)
- BASE32 + XZ compression
- Best for text-like data
- Largest encrypted payloads benefit most
- Requires libzma support

### None (default)
- No link-layer encoding
- Requires binary-clean transmission
- Minimal overhead

## Security Properties

### Confidentiality
- ChaCha20-Poly1305 AEAD cipher
- 256-bit symmetric keys
- Ephemeral Curve25519 DH for PFS

### Integrity & Authentication
- Poly1305 authentication tag (128-bit)
- Covers all ciphertext
- Detects tampering and replay

### Key Management
- Ephemeral keys per session
- Derived from fresh DH agreement
- Never reused across sessions
- Cleared when session ends

### Message Ordering
- Counter-based nonce prevents replay
- Separate counters for read/write
- Monotonically increasing per direction

## Limitations & Future Work

1. **No Perfect Forward Secrecy across sessions** - Keys derived once at start
2. **No key rotation** during session lifetime
3. **UTF-7 encoding not implemented** - stub only
4. **No negotiation of authentication algorithms** - only ChaCha20-Poly1305
5. **No client certificates** - server-authenticated only
6. **Response formatting handler** (base.handler.link-upgrade.response) - stub

## References

- Curve25519: https://cr.yp.to/ecdh.html
- ChaCha20-Poly1305: RFC 7539, RFC 8439
- Protocol-7: Internal specification

---

**Last Updated:** 2025-11-18
**Status:** Server implementation complete, awaiting client support

#,,.,,,,.,,,,,..,,,,.,,..,.,.,.,,,,.,,,..,.,.,..,,...,...,,,.,.,.,,,.,,.,,,..,
#77IO3RLSBY2XEF4YZNLDY56TFF3Q7DDLTA5VERFEFZ66BFDQRUEK5TWMGZWYFMPSOW5F3SGZ3Z3VS
#\\\|OKDV7LFWEXZIUR4VABVZWZKRVK7UZZCGWHAHDHBPJM332YKGVNG \ / AMOS7 \ YOURUM ::
#\[7]KPHBBDSM4R3IQINOM64KZZOVRGKODBWIXP4FRKKLNZE7Y762WQBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
