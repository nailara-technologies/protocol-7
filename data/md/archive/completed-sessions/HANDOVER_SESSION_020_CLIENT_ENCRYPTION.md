# Protocol-7 Client-Side Encryption Implementation
## Session Handover Document - Phase 2

**Previous Session Date**: November 18, 2025
**Prepared For**: Next session - Client-side encryption implementation
**Status**: ✅ Server infrastructure complete, ready for client implementation

---

## Executive Summary

Phase 1 (server-side encryption infrastructure) is **COMPLETE and TESTED**. All encryption infrastructure is operational on the server side, with automatic key management working correctly. The next phase is to implement client-side encryption handshake and message encryption in the C client and shell interpreter.

---

## Phase 1 Completion Status ✅

### What Was Built

1. **C25519 Elliptic Curve Cryptography**
   - Ephemeral keypair generation for each session
   - Diffie-Hellman shared secret computation
   - Proper code reuse via `crypt.C25519.gen_keys` and `crypt.C25519.compute_shared`

2. **ChaCha20-Poly1305 AEAD Cipher**
   - Per-message nonce generation (NOT persistent cipher context)
   - Nonce format: session_id (4 bytes) || counter (4 bytes) || padding (4 bytes)
   - Separate read/write message counters for bidirectional communication
   - Authentication tag validation on decryption

3. **Link-Upgrade Protocol (State 2→3 Transition)**
   - `src/protocol.protocol-7.link-upgrade.init` - Initial key generation and capability negotiation
   - `src/base.handler.link-upgrade` - Handles client's public key, computes DH, stores shared secret
   - `src/protocol.protocol-7.encryption.init` - Derives encryption key, installs encryption wrappers
   - `src/cube.cmd.link-upgrade` - Triggers state transitions from v7 client

4. **Automatic Key Management**
   - Fixed: `base.file.make_path` umask handling for reliable recursive directory creation
   - Fixed: Automatic key directory creation with `crypt.C25519.autocreate-user-key = yes`
   - Directories created with proper permissions: `/home/protocol-7/.n/user-keys/` (0700)
   - Keys created with proper permissions: 0600 (secret/private), 0640 (public)

### Critical Commits

```
9778537cf - docs: Update task.yaml - Phase 1 complete
3b8be6a6f - fix: Correct umask handling in base.file.make_path
6fcd2afe7 - fix: Enable automatic C25519 key directory creation
0565c3db3 - docs: Update task.yaml with protocol-7 session encryption work
694190553 - fix: Correct scalar reference syntax in compute_shared call
```

### Verified Working

- ✅ `cube` zenka - Initializes cleanly, ready for link-upgrade handshake
- ✅ `test-link-upgrade` zenka - Fully functional with C25519 module support
- ✅ `keys` zenka - Creates user keys with correct permissions
- ✅ `workflow` zenka - Auto-generates keys on first startup
- ✅ `sourcecode` zenka - Loads C25519 without auto-loading keys
- ✅ Key directories - Auto-created with correct ownership and permissions
- ✅ Encryption modules - ChaCha20-Poly1305 verified with unit tests
- ✅ DH computation - Test cases passing for shared secret generation

---

## Phase 2: Client-Side Implementation

### The Challenge

The server is ready for encrypted sessions. We need to implement the client-side mirror:
1. Parse link-upgrade protocol commands from server
2. Generate ephemeral C25519 keypairs
3. Send public key to server
4. Receive server's public key and negotiated parameters
5. Perform DH computation to get shared secret
6. Derive encryption key
7. Encrypt/decrypt all subsequent messages with ChaCha20-Poly1305

### Key Technical Details for Client Implementation

#### Link-Upgrade Protocol Flow (Client Perspective)

```
State 1 (Authenticated)
    ↓
Client sends: "link-upgrade\n"
    ↓
Server responds: (sends back its ephemeral public key in base32)
    ↓
State 2 (Link-Upgrade Negotiation)
    ↓
Client generates ephemeral keypair
Client sends: "link-pub-key <base32_encoded_pubkey>\n"
    ↓
Server computes DH(server_private, client_public)
Server derives encryption key: AMOS7::13::key_32(shared_secret, session_id)
    ↓
Client computes DH(client_private, server_public)
Client derives encryption key: AMOS7::13::key_32(shared_secret, session_id)
    ↓
Client sends: "link-confirm-encoding <mode>\n"  [or "none"]
    ↓
Client sends: "link-complete\n"
    ↓
Server transitions State 2→3 (encrypted)
    ↓
State 3 (Encrypted Communication)
    ↓
All messages encrypted with per-message nonces
```

#### Message Encryption Format

**Read Side (decryption)**:
```
Input: [ciphertext][auth_tag]
    - ciphertext: encrypted plaintext
    - auth_tag: 16-byte HMAC-Poly1305 authentication tag

Nonce generation:
    session_bytes = pack('N', session_id)     # 4 bytes
    counter_bytes = pack('N', read_counter)   # 4 bytes, increment each message
    nonce = session_bytes . counter_bytes . "\0\0\0\0"  # 12 bytes total

Decryption:
    cipher = Crypt::AuthEnc::ChaCha20Poly1305->new(encryption_key, nonce)
    plaintext = cipher->decrypt_add(ciphertext)
    success = cipher->decrypt_done(auth_tag)   # Returns 1 (success) or 0 (failed)
```

**Write Side (encryption)**:
```
Input: plaintext message
Output: [ciphertext][auth_tag]

Nonce generation:
    session_bytes = pack('N', session_id)      # 4 bytes
    counter_bytes = pack('N', write_counter)   # 4 bytes, increment each message
    nonce = session_bytes . counter_bytes . "\0\0\0\0"  # 12 bytes total

Encryption:
    cipher = Crypt::AuthEnc::ChaCha20Poly1305->new(encryption_key, nonce)
    cipher->encrypt_add(plaintext)
    auth_tag = cipher->encrypt_done()          # Returns 16-byte tag
    output = ciphertext . auth_tag
```

#### Key Derivation

```perl
# Shared secret is 32 bytes from C25519::shared_secret()
# Session ID is from protocol-7 session management

encryption_key = AMOS7::13::key_32(
    \$shared_secret,    # Scalar ref to 32-byte shared secret
    $session_id         # Session ID as seed for entropy variation
);

# Result: 32-byte encryption key for ChaCha20-Poly1305
```

### Code Reuse Opportunities for Client

The client can leverage existing Protocol-7 infrastructure:

1. **For C25519 key generation**:
   - Use `crypt.C25519.gen_keys` if available in client context
   - Otherwise implement direct Crypt::Curve25519::generate_keypair()
   - Or use C FFI bindings if available

2. **For base32 encoding/decoding** (for key exchange):
   - Use `Crypt::Misc::encode_b32r()` and `decode_b32r()`
   - These are already proven working in server code

3. **For DH computation**:
   - Use `crypt.C25519.compute_shared()` if available
   - Otherwise use `Crypt::Curve25519::shared_secret()` directly
   - Remember: function expects scalar references!

### Files to Modify

#### 1. bin/p7.c (Main C Client)
**Current State**: Has basic protocol-7 client implementation
**Needed Changes**:
- Add link-upgrade command parsing and response handling
- Implement state machine for state 2↔3 transitions
- Add C25519 key generation (via Perl wrapper or FFI)
- Add ChaCha20-Poly1305 encryption/decryption to message pipeline
- Handle per-message nonce generation

**Integration Points**:
```
Session establishment (state 1)
    ↓
User types/sends command
    ↓
IF encrypted (state 3): encrypt with nonce
ELSE: send plaintext
    ↓
Receive response
    ↓
IF encrypted (state 3): decrypt with nonce
ELSE: plaintext
    ↓
Display to user
```

#### 2. nshell (Shell Interpreter)
**Current State**: Command shell for protocol-7
**Needed Changes**:
- Support encrypted command execution
- Transparent encryption/decryption in command processing
- Session state awareness for when to encrypt

#### 3. bin/test-link-upgrade-client.pl (Already Exists)
**Current State**: Basic test framework
**Enhancement Needed**:
- Add full handshake test sequence
- Test encryption/decryption round-trip with actual messages
- Test state transitions (1→2→3)
- Test error cases (bad keys, timeout, etc.)
- Performance benchmarking

### Testing Strategy

1. **Unit Tests**
   - C25519 key generation (C client)
   - ChaCha20-Poly1305 encryption round-trip
   - Nonce generation correctness
   - Key derivation determinism

2. **Integration Tests with test-link-upgrade Zenka**
   ```
   Client                           Server (test-link-upgrade)
   link-upgrade command --------→
   ← ephemeral public key
   link-pub-key <pubkey> --------→
   ← ready response
   link-confirm-encoding --------→
   ← confirm
   link-complete --------→
   ← state 3 active

   [Encrypted message] --------→
   ← [Encrypted response]
   ```

3. **Performance Benchmarking**
   - Measure latency: unencrypted vs encrypted
   - Measure throughput: messages/second
   - Measure CPU overhead of encryption

### Known Issues & Gotchas

1. **Scalar References**
   - `crypt.C25519.compute_shared()` REQUIRES scalar references
   - Wrong: `compute_shared($secret, $public)`
   - Right: `compute_shared(\$secret, \$public)`

2. **ChaCha20-Poly1305 API**
   - Cipher instance is created WITH the nonce: `->new($key, $nonce)`
   - NOT: `->new($key)` then set nonce later
   - Each message gets a fresh cipher instance (do NOT reuse)

3. **Nonce Ordering**
   - Counter MUST be incremented BEFORE nonce generation
   - Counter starts at 0, first message uses counter=1
   - Separate counters for read and write sides

4. **Session ID Encoding**
   - Must use `pack('N', $session_id)` for 4-byte big-endian encoding
   - Not string conversion or other formats

5. **Key Directory Permissions**
   - If creating client-side key storage, use 0700 for directories
   - Use 0600 for secret/private key files
   - Use 0640 for public keys

### Debugging Aids

**Server-side logging** (if issues):
- `test-link-upgrade` zenka has verbose logging enabled
- Check for "DH completed" or "encryption initialized" messages
- Check for state transition failures

**Client-side testing**:
- Use test-link-upgrade-client.pl as a reference implementation
- Can trace protocol flow by examining server/client message exchange
- test-link-upgrade zenka will log all link-upgrade negotiation steps

**Encryption verification**:
- Test vectors available in `bin/test-encryption-module.pl`
- Can validate ChaCha20-Poly1305 implementation against known results
- Can validate C25519 against test vectors

---

## Directory Structure & Key Files

### Encryption Infrastructure (Complete)
```
src/
  ├── crypt.C25519.gen_keys                    # Ephemeral keypair generation
  ├── crypt.C25519.compute_shared              # DH computation (FIXED)
  ├── protocol.protocol-7.link-upgrade.init    # Server state 2 setup
  ├── protocol.protocol-7.encryption.init      # Server state 3 setup
  ├── base.handler.link-upgrade                # Server DH handler (FIXED)
  ├── base.handler.read.encryption-wrapper     # Server decryption
  ├── base.handler.write.encryption-wrapper    # Server encryption
  ├── base.file.make_path                      # Dir creation (FIXED)
  └── base.known_dependencies                  # Crypt module mappings

cfg/zenki/
  ├── cube/start                               # Cube config (UPDATED)
  ├── test-link-upgrade/start                  # Test zenka config (UPDATED)
  └── keys/start                               # Key management zenka

bin/
  ├── test-link-upgrade-client.pl              # Test framework
  └── test-encryption-module.pl                # Unit tests
```

### Key Configuration Additions
```
cube/start (line 27):
    crypt.C25519.autocreate-user-key = yes

test-link-upgrade/start (lines 18-20):
    crypt.C25519.autocreate-user-key = yes
    modules.load = auth net protocol io.unix crypt.C25519
```

---

## Quick Reference: Critical Constants & Formats

### Nonce Structure (12 bytes)
```
[4 bytes: session_id (big-endian N)] +
[4 bytes: message_counter (big-endian N)] +
[4 bytes: padding (zeros)]
```

### Authentication Tag
```
16 bytes from ChaCha20-Poly1305 HMAC-Poly1305
Must be verified on decryption (decrypt_done returns 0/1)
```

### Key Sizes
```
Session ID: 32-bit integer
Secret Key (C25519): 32 bytes
Public Key (C25519): 32 bytes
Shared Secret: 32 bytes
Encryption Key: 32 bytes (derived from shared secret)
```

### Perl Module Imports (for reference)
```perl
use Crypt::Curve25519 qw(secret_key public_key shared_secret);
use Crypt::AuthEnc::ChaCha20Poly1305;
use Crypt::Misc qw(encode_b32r decode_b32r);
use Crypt::PRNG;  # For random key generation
```

---

## Session Checklist for Phase 2

- [ ] Review client architecture for link-upgrade integration points
- [ ] Implement C25519 key generation in C client (or Perl wrapper)
- [ ] Implement link-upgrade protocol parsing and state machine
- [ ] Implement ChaCha20-Poly1305 encryption in message pipeline
- [ ] Implement nonce generation with proper counter management
- [ ] Create unit tests for C25519 operations
- [ ] Create unit tests for ChaCha20-Poly1305 encryption
- [ ] Integration test with test-link-upgrade zenka
- [ ] Performance benchmarking (encrypted vs unencrypted)
- [ ] Test error cases and edge conditions
- [ ] Document client-side encryption architecture
- [ ] Update nshell with encryption support
- [ ] Final integration testing with full v7 zenka
- [ ] Clean up and merge to base

---

## Notes for Next Session

1. **All infrastructure is stable** - No need to revisit Phase 1 unless bugs appear
2. **Server is waiting** - test-link-upgrade zenka can handle multiple client connections
3. **Clean history** - All commits are on base branch, development branch deleted
4. **Test harness ready** - test-link-upgrade-client.pl can be extended for Phase 2 testing
5. **Documentation complete** - See task.yaml for current status

### Contact Points if Issues Arise
- Review the fixed modules if scalar reference errors occur: `base.handler.link-upgrade:59-61`
- Review umask handling if directory creation fails: `base.file.make_path:20-23`
- Review autocreate configuration if zenkas won't start: `cfg/zenki/{cube,test-link-upgrade}/start`

---

**End of Handover Document**

Generated: November 18, 2025
Phase 1 Status: ✅ COMPLETE
Phase 2 Status: 📋 READY FOR IMPLEMENTATION

#,,,.,,..,.,,,.,,,.,.,...,,,.,...,,.,,.,.,.,.,..,,...,...,,.,,,..,..,,..,,,..,
#QPPVZW2QJMY3ZGPNIAAB3TGUKTS6SLKHLFP33SOVACVPBW6GM7ZJALGKQNYY5JPHC5EMDCHAEPU3W
#\\\|5PF3TJ72V2A7JJWL4EDS3TPQSRTUL3Q7TFEK3M7IUWB6PKQVAL3 \ / AMOS7 \ YOURUM ::
#\[7]HT333FPT2L65XH6JB2OXVCYZKR2OWVDUREQKXTYAADJQTLCTTQDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
