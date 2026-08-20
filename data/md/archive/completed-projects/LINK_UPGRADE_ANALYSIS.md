# Link-Upgrade Client Implementation - Architecture Analysis

**Date**: 2025-11-27
**Analysis Status**: Complete
**Implementation Ready**: YES

---

## Code Base Analysis

### 1. p7.c (C Client) - 277 lines
**Current Structure**:
```
Lines 1-79:    Helper functions (concat), defines
Lines 80-123:  Socket connection setup
Lines 81-149:  Authentication sequence (select unix, auth)
Lines 150-152: Command sending
Lines 154-277: Response reading with protocol handling (SIZE, CHRSIZE, TRUE, FALSE)
```

**Key Integration Point**:
- **Line 151**: After authentication succeeds (line 148)
- Need to check if `cmd_str == "link-upgrade"`
- If yes: perform handshake instead of sending as regular command
- If no: continue normal flow

**Challenge**: C client needs crypto support
- Option A: Call Perl helper script for key operations (recommended - simpler)
- Option B: Link libsodium (faster - more complex)

---

### 2. nshell (Perl Shell) - 591 lines
**Current Structure**:
```
Lines 1-60:    Headers, module includes, constants
Lines 50-60:   Uses AMOS7, AMOS7::TERM, AMOS7::Protocol::P7
Lines 61-591:  Main loop, command handling, response processing
```

**Advantages**:
- ✅ Already Perl, can use Crypt modules directly
- ✅ Already has AMOS7 module ecosystem
- ✅ Can access crypt.C25519.* and encryption functions
- ✅ No FFI or compilation needed
- ✅ v7 auto-reload works automatically

**Challenge**: Find authentication and command handling loop

**Recommended Order**:
1. **Implement nshell first** (easier, Perl-native)
2. **Then p7.c** (C client with Perl helper support)

---

## Implementation Strategy

### Phase 1: nshell Implementation (Easiest)

**Step 1.1**: Locate authentication in nshell
- Find where "select unix" and "auth" are sent
- Identify where auth response is checked
- Mark this as `post_auth_point`

**Step 1.2**: Add link-upgrade support after auth
```perl
# After successful authentication...
if ($first_command eq 'link-upgrade') {
    # Send link-upgrade init
    send_command('link-upgrade');

    # Read server ephemeral pubkey
    my $server_pubkey = read_response();

    # Generate client keys via AMOS7::C25519
    my ($client_pubkey, $client_secret) =
        generate_ephemeral_keypair();

    # Send client pubkey
    send_command("link-pub-key $client_pubkey");

    # Compute shared secret
    my $shared_secret = compute_dh($client_secret, $server_pubkey);

    # Derive encryption key
    my $encryption_key = derive_key($shared_secret, $session_id);

    # Confirm and complete
    send_command('link-confirm-encoding');
    read_response();
    send_command('link-complete');
    read_response();

    # Switch to encrypted mode
    $encrypted_mode = 1;
}
```

**Step 1.3**: Add encryption/decryption to message pipeline
```perl
sub send_command {
    my ($cmd) = @_;
    if ($encrypted_mode) {
        my $ciphertext = encrypt_message($cmd, $encryption_key, $read_counter++);
        $socket->send($ciphertext);
    } else {
        $socket->send($cmd);
    }
}

sub read_response {
    my ($data) = @_;
    if ($encrypted_mode) {
        my $plaintext = decrypt_message($data, $encryption_key, $write_counter++);
        return $plaintext;
    } else {
        return $data;
    }
}
```

**Step 1.4**: Test with test-link-upgrade zenka

---

### Phase 2: p7.c Implementation

**Step 2.1**: Create Perl helper script `bin/p7-crypto-helper.pl`
```perl
#!/usr/bin/env perl
# Helper script for p7.c to perform crypto operations

use Crypt::Curve25519;
use AMOS7::Crypt;

my $operation = shift @ARGV;

if ($operation eq 'gen-keys') {
    # Generate ephemeral keypair
    my ($pubkey, $secret) = generate_ephemeral_keypair();
    print "$pubkey\n$secret\n";
} elsif ($operation eq 'dh') {
    # Compute DH shared secret
    my $secret = shift @ARGV;
    my $pubkey = shift @ARGV;
    my $shared = compute_dh($secret, $pubkey);
    print encode_b32($shared) . "\n";
} elsif ($operation eq 'derive-key') {
    # Derive encryption key
    my $shared = shift @ARGV;
    my $session_id = shift @ARGV;
    my $key = AMOS7::13::key_32(\$shared, $session_id);
    print encode_b32($key) . "\n";
}
```

**Step 2.2**: Modify p7.c to call helper script
```c
// After successful auth, before sending command
if (strcmp(cmd_str, "link-upgrade") == 0) {
    // Step 1: Get server pubkey
    write(socket_fd, "link-upgrade\n", 13);
    char server_pubkey[256];
    read_until_newline(socket_fd, server_pubkey);

    // Step 2: Generate client keys
    system("perl /path/to/p7-crypto-helper.pl gen-keys > /tmp/p7_keys");
    FILE *keys_file = fopen("/tmp/p7_keys", "r");
    char client_pubkey[256];
    char client_secret[256];
    fgets(client_pubkey, sizeof(client_pubkey), keys_file);
    fgets(client_secret, sizeof(client_secret), keys_file);
    fclose(keys_file);

    // Step 3: Send client pubkey
    asprintf(&cmd_str, "link-pub-key %s\n", client_pubkey);
    write(socket_fd, cmd_str, strlen(cmd_str));

    // Step 4: Compute shared secret and derive key
    // (Call Perl helper or compute locally)

    // Step 5: Confirm and complete
    write(socket_fd, "link-confirm-encoding\n", 22);
    read_until_newline(socket_fd, NULL);
    write(socket_fd, "link-complete\n", 14);
    read_until_newline(socket_fd, NULL);

    // Step 6: Enable encryption mode
    encryption_enabled = 1;
}

// Then modify send/recv for encryption
if (encryption_enabled) {
    // Encrypt before sending
    ciphertext = encrypt_message(plaintext, encryption_key, write_counter++);
    write(socket_fd, ciphertext, ciphertext_len);
}

// And on receive
if (encryption_enabled) {
    plaintext = decrypt_message(ciphertext, encryption_key, read_counter++);
    process_response(plaintext);
}
```

---

## File Locations and Dependencies

### Crypto Infrastructure (Available)
- ✅ `src/crypt.C25519.gen_keys` - Ephemeral keypair generation
- ✅ `src/crypt.C25519.compute_shared` - DH computation
- ✅ `src/protocol.protocol-7.link-upgrade.init` - Server init
- ✅ `src/protocol.protocol-7.link-upgrade.handshake` - Server handshake
- ✅ `src/base.handler.link-upgrade` - Server DH handler
- ✅ Crypt::Curve25519 Perl module
- ✅ Crypt::AuthEnc::ChaCha20Poly1305 Perl module
- ✅ AMOS7::Crypt Perl module

### Test Infrastructure
- ✅ `bin/test-link-upgrade-client.pl` - Reference implementation
- ✅ `cfg/zenki/test-link-upgrade/start` - Test zenka config
- ✅ `src/protocol.protocol-7.link-upgrade.*` - Server handlers

---

## Implementation Sequence

### Recommended Order of Work

**Week 1: nshell (Highest ROI)**
- [ ] Day 1-2: Analyze nshell auth/command loop
- [ ] Day 3-4: Implement link-upgrade negotiation
- [ ] Day 5: Implement encryption/decryption wrapper
- [ ] Day 6: Test with test-link-upgrade zenka
- [ ] Day 7: Document and commit

**Week 2: p7.c Helper + Integration**
- [ ] Day 1-2: Create p7-crypto-helper.pl
- [ ] Day 3-4: Integrate into p7.c
- [ ] Day 5-6: Test encrypted p7 client
- [ ] Day 7: Optimize and document

**Week 3: Remote Testing**
- [ ] Deploy test-link-upgrade on internet-accessible server
- [ ] Test encrypted connections from remote locations
- [ ] Verify letsencr certificate management works

---

## Success Criteria per Phase

### nshell Complete ✅
- [ ] "link-upgrade" command initiates handshake
- [ ] Server ephemeral pubkey received and parsed
- [ ] Client ephemeral keypair generated
- [ ] Client pubkey sent and acknowledged
- [ ] Shared secret computed correctly
- [ ] Encryption key derived correctly
- [ ] Subsequent commands encrypted/decrypted transparently
- [ ] Commands work identically encrypted or plaintext
- [ ] Test-link-upgrade zenka confirms state transitions

### p7.c Complete ✅
- [ ] p7 client supports "link-upgrade" command
- [ ] Encryption works via Perl helper
- [ ] Encrypted remote testing possible
- [ ] Low-latency connections verified

### Production Ready ✅
- [ ] Encrypted letsencr certificate testing works
- [ ] Remote server access secure and reliable
- [ ] No performance degradation (<5% latency overhead)

---

## Key Technical Notes

### nshell Advantages
- Direct Perl module access
- No compilation/building
- Uses existing AMOS7 ecosystem
- v7 auto-reload (modifications picked up immediately)
- Easier debugging (Perl stack traces)

### p7.c Approach
- Use Perl helper for crypto (simplest path)
- Avoid C crypto libraries (no external dependencies)
- Keep modifications minimal
- v7 auto-reload rebuilds binary

### Critical Crypto Points
1. Nonce format: `pack('N', $session_id) . pack('N', $counter) . "\0\0\0\0"`
2. Counter starts at 0, incremented before each use
3. Separate read/write counters
4. Fresh cipher instance per message
5. Key derivation: `AMOS7::13::key_32(\$shared, $session_id)`

---

## Testing Resources

**Reference Implementation**: bin/test-link-upgrade-client.pl
- Shows complete handshake sequence
- Demonstrates encryption/decryption
- Test server: test-link-upgrade zenka
- Enable verbose logging for debugging

**Debugging**:
- test-link-upgrade zenka logs all state transitions
- Perl warnings on crypto operation failures
- Can trace protocol flow byte-by-byte

---

## Estimated Timeline

**nshell**: 3-4 days (Perl, higher-level logic)
**p7.c**: 2-3 days (C, using Perl helper)
**Testing & Optimization**: 2-3 days
**Total**: 7-10 days concentrated effort

**With v7 auto-reload**: No rebuild delays, test immediately after changes

---

## Status: Ready to Implement

All infrastructure is in place:
- ✅ Server-side encryption complete
- ✅ Test frameworks available
- ✅ Reference implementations exist
- ✅ nshell is analyzable (Perl)
- ✅ p7.c is small and focused (277 lines)
- ✅ Helper script approach is viable

**Next Action**: Start with nshell analysis and implementation

#,,.,,,,.,..,,.,.,...,,..,,.,,,,.,,,.,.,,,,,.,..,,...,...,.,.,..,,...,,.,,,.,,
#535JF2WFLFIFYN3G7P42DTHYOQUHWPSYVDNBHWDVN3SLKQQOVZO2NCMV2LFZF7XOO5FV4FY4CQ4WY
#\\\|ATEUJSGC3LOB3CMNUXS45TBQKTEN5EIZMP6E44XDA3U7LS663PZ \ / AMOS7 \ YOURUM ::
#\[7]GCZ47ZJTOJMPHZVPOMISW3UURELKZYV77CGCQMHLEPVQTXKYJ2BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
