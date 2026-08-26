# Link-Upgrade Client-Side Encryption Implementation Plan

**Goal**: Enable encrypted client connections via C25519 + ChaCha20-Poly1305 in bin/p7.c and nshell
**Status**: Starting implementation
**Target**: Low-latency encrypted remote server testing for letsencr zenka

---

## Architecture Overview

### Current Client State (p7.c - 277 lines)
```
1. Connect to Unix socket
2. Send auth (select unix, auth <user>)
3. Wait for 3 lines of response
4. Send command
5. Read and output response
```

### Required Additions for Encryption
```
State 1 (Authenticated) → After auth successful
    ↓
Send: "link-upgrade\n"
    ↓
State 2: Receive server ephemeral public key (base32)
    ↓
Generate client ephemeral keypair (C25519)
    ↓
Send: "link-pub-key <base32_pubkey>\n"
    ↓
Compute DH shared secret
    ↓
Derive encryption key via AMOS7::13::key_32
    ↓
Send: "link-confirm-encoding\n" (or "none")
    ↓
Send: "link-complete\n"
    ↓
State 3 (Encrypted): All messages encrypted with per-message nonces
```

---

## Implementation Tasks

### Task 1: Add C25519 Cryptography Support
**File**: bin/c_src/p7.c
**Changes**:
- Include crypto headers (via Perl FFI or direct C library)
- Add C25519 keypair generation function
- Add DH computation function
- Add base32 encoding/decoding for key exchange

**Option A**: Call Perl for crypto (simpler, works with existing infrastructure)
- Use `system()` to call helper Perl script for key generation
- Pass keys via file or environment

**Option B**: Link C crypto library (faster, more complex)
- Link libsodium or libcurve25519
- Implement crypto operations directly in C

**Recommended**: Option A (Perl helper) for rapid implementation

### Task 2: Add ChaCha20-Poly1305 Encryption Wrapper
**File**: bin/c_src/p7.c
**Changes**:
- Add encryption/decryption functions for message pipeline
- Implement nonce generation (session_id + counter + padding)
- Add per-message counter management (separate read/write)
- Integrate into send/recv loops

**Key Functions**:
```c
struct encryption_state {
    unsigned char key[32];
    unsigned int session_id;
    unsigned long read_counter;
    unsigned long write_counter;
    int encrypted;  // 0=plaintext, 1=encrypted
};

void init_encryption(encryption_state *state,
                     unsigned char *shared_secret,
                     unsigned int session_id);
void encrypt_message(encryption_state *state,
                     unsigned char *plaintext, int plen,
                     unsigned char *ciphertext, int *clen);
int decrypt_message(encryption_state *state,
                    unsigned char *ciphertext, int clen,
                    unsigned char *plaintext, int *plen);
```

### Task 3: Integrate Link-Upgrade Protocol into Client
**File**: bin/c_src/p7.c
**Changes**:
- After successful authentication, check for "link-upgrade" command
- If user sends "link-upgrade", perform handshake
- Transition to encrypted state
- All subsequent messages encrypted/decrypted automatically

**Protocol Flow in Code**:
```c
// After auth successful...
if (strcmp(cmd_str, "link-upgrade") == 0) {
    // Send link-upgrade init
    write(socket_fd, "link-upgrade\n", 13);

    // Read server ephemeral pubkey
    read_server_pubkey(socket_fd, server_pubkey);

    // Generate client keys
    generate_client_keypair(client_pubkey, client_secret);

    // Send client pubkey
    send_client_pubkey(socket_fd, client_pubkey);

    // Compute shared secret
    compute_shared_secret(client_secret, server_pubkey, shared_secret);

    // Derive encryption key
    derive_encryption_key(shared_secret, session_id, encryption_key);

    // Confirm encoding
    write(socket_fd, "link-confirm-encoding\n", 22);
    read_confirmation(socket_fd);

    // Complete handshake
    write(socket_fd, "link-complete\n", 14);
    read_completion(socket_fd);

    // Enable encryption for subsequent messages
    state->encrypted = 1;
} else {
    // Regular plaintext command
}
```

### Task 4: Implement nshell Encryption Support
**File**: bin/nshell (or relevant shell interpreter)
**Changes**:
- Detect when p7 client supports encryption
- Automatically negotiate link-upgrade on connection
- Transparent encryption/decryption in command loop
- Session state awareness

**Implementation Strategy**:
1. After p7 connects and authenticates
2. Auto-send "link-upgrade" command
3. Handle encryption state transitions
4. All user commands encrypted automatically
5. All responses decrypted automatically

---

## Testing Strategy

### Phase 1: Unit Testing
**File**: bin/test-link-upgrade-client.pl (enhance)

**Test Cases**:
1. ✅ C25519 keypair generation
2. ✅ DH computation correctness
3. ✅ Nonce generation format
4. ✅ Key derivation determinism
5. ✅ ChaCha20-Poly1305 round-trip encryption/decryption
6. ✅ Authentication tag verification

### Phase 2: Integration Testing
**Server**: test-link-upgrade zenka
**Client**: Enhanced p7.c with encryption

**Test Sequence**:
```
1. Client connects to test-link-upgrade zenka
2. Client authenticates (select unix, auth)
3. Client sends "link-upgrade"
4. Client receives server ephemeral pubkey
5. Client generates keypair
6. Client sends "link-pub-key <pubkey>"
7. Client receives ready response
8. Client sends "link-confirm-encoding"
9. Client receives confirm
10. Client sends "link-complete"
11. Client can send encrypted commands
12. Server receives and decrypts correctly
13. Server sends encrypted responses
14. Client receives and decrypts correctly
```

### Phase 3: Performance Testing
- Measure latency: plaintext vs encrypted
- Measure throughput: messages/second
- Measure CPU overhead

### Phase 4: Remote Server Testing
- Deploy test-link-upgrade on internet-accessible server
- Test encrypted client connections from remote locations
- Verify letsencr certificate management with encryption

---

## File Modifications Summary

| File | Lines | Change Type | Impact |
|------|-------|-------------|--------|
| bin/c_src/p7.c | 277 | Major | Add encryption support |
| bin/nshell | TBD | Major | Add auto-negotiation |
| bin/test-link-upgrade-client.pl | 4534 | Enhancement | Add full test suite |
| cfg/zenki/test-link-upgrade/zenka.v7 | 2428 | Reference | Already set up |

---

## Critical Implementation Notes

### From HANDOVER_SESSION_020_CLIENT_ENCRYPTION.md

1. **Scalar References**
   - C25519 functions expect scalar refs in Perl
   - When using FFI, ensure proper memory handling

2. **ChaCha20-Poly1305 API**
   - Cipher instance created WITH nonce: `new($key, $nonce)`
   - Each message gets fresh cipher instance
   - Do NOT reuse cipher instances

3. **Nonce Ordering**
   - Counter incremented BEFORE nonce generation
   - Counter starts at 0, first message uses counter=1
   - Separate counters for read and write

4. **Session ID Encoding**
   - Use big-endian 4-byte encoding: `pack('N', $session_id)`
   - Not string conversion

5. **Key Derivation**
   - `AMOS7::13::key_32(\$shared_secret, $session_id)`
   - Result: 32-byte encryption key

---

## Dependencies

### Required Libraries
- libsodium (libcurve25519) for C25519 operations
- Crypt::AuthEnc::ChaCha20Poly1305 (Perl)
- Crypt::Misc for base32 encoding/decoding

### Already Available
- test-link-upgrade zenka (fully functional)
- test-link-upgrade-client.pl (reference implementation)
- Server-side encryption infrastructure (Phase 1 - complete)

---

## Success Criteria

- [x] Plan complete and documented
- [ ] C25519 key generation working in p7.c
- [ ] DH computation producing correct shared secrets
- [ ] Encryption key derivation matching server
- [ ] ChaCha20-Poly1305 encryption/decryption working
- [ ] Link-upgrade handshake completing successfully
- [ ] Messages encrypted/decrypted transparently
- [ ] nshell auto-negotiating encryption
- [ ] Remote server testing working
- [ ] Low-latency encrypted testing of letsencr zenka

---

## Next Steps

1. **Immediate**: Analyze p7.c structure for integration points
2. **Week 1**: Implement C25519 + DH in p7.c
3. **Week 2**: Implement ChaCha20-Poly1305 pipeline
4. **Week 3**: Implement link-upgrade protocol negotiation
5. **Week 4**: Test with test-link-upgrade zenka
6. **Week 5**: Implement nshell encryption support
7. **Week 6**: Remote server testing with letsencr

---

**Status**: Ready to implement
**Estimated Total Time**: 8-12 hours concentrated work
**v7 Auto-Update**: Will automatically reload p7 binary on recompile

#,,.,,,,.,,,.,,,.,,,.,.,.,.,.,.,,,.,,,,,,,,,.,.,.,...,...,,..,,.,,,,.,.,.,,,.,
#AN6VMQVSZUT6LL72YOL6EZJLQFAXX7BTNNOHEBSJ62ZQSZW2AEV2YKCY5L645VLEHA56SAROVC3SY
#\\\|CW2RU5UG23XRZRAYRTY6YUFKDXE4KWWXMUQLLNHGRDP5FXUOV5J \ / AMOS7 \ YOURUM ::
#\[7]D5SKPGXTDRR2XUHIIJCDB6USQHQFQ4B3WE7S64SES63D7755KQAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
