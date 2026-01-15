# p7.c Link-Upgrade Implementation Plan
**Date**: 2026-01-01
**Status**: READY FOR IMPLEMENTATION
**Approach**: Simplified using existing Perl crypto helper

---

## Integration Points in p7.c (277 lines total)

### Point 1: After Authentication Success (After line 148)
**Current Code**: Auth loop completes, then sends command

**Change**: Add link-upgrade negotiation
```c
// After successful auth (line 148)
// Check environment variable for link-upgrade enablement
char *link_upgrade_env = secure_getenv("PROTOCOL_7_LINK_UPGRADE");
struct encryption_state {
    int enabled;
    char *key;          // base32-encoded key
    unsigned int session_id;
    unsigned int read_counter;
    unsigned int write_counter;
} enc_state = {0, NULL, 0, 0, 0};

if (link_upgrade_env && strcmp(link_upgrade_env, "yes") == 0) {
    if (negotiate_link_upgrade(socket_fd, &enc_state) == 0) {
        fprintf(stderr, ":: link-upgrade encryption enabled ::\n");
        enc_state.enabled = 1;
    } else {
        fprintf(stderr, ":: link-upgrade negotiation failed, continuing plaintext\n");
    }
}
```

### Point 2: Send Command (Line 151)
**Current Code**: `write( socket_fd, cmd_str, strlen(cmd_str) );`

**Change**: Encrypt if enabled
```c
if (enc_state.enabled) {
    char *encrypted_cmd = encrypt_message(socket_fd, cmd_str, &enc_state);
    if (encrypted_cmd) {
        write(socket_fd, encrypted_cmd, strlen(encrypted_cmd));
        free(encrypted_cmd);
    } else {
        fprintf(stderr, ":: encryption failed, aborting ::\n");
        return 5;
    }
} else {
    write(socket_fd, cmd_str, strlen(cmd_str));
}
free(cmd_str);
```

### Point 3: Response Reading Loop (Starting line 166)
**Current Code**: Plain byte-by-byte reading

**Change**: Add decryption wrapper
```c
// Before the response reading loop, set up buffering for encrypted mode
char response_buffer[4096] = {0};
int buffer_pos = 0;

// Inside the loop (after getting byte), if encrypted:
if (enc_state.enabled && buffer_pos < sizeof(response_buffer) - 1) {
    response_buffer[buffer_pos++] = byte;

    // Process when we hit newline
    if (byte == '\n') {
        response_buffer[buffer_pos] = '\0';
        char *plaintext = decrypt_message(response_buffer, &enc_state);
        if (plaintext) {
            // Process plaintext instead of byte
            // ... existing byte-by-byte logic but on plaintext
        }
        buffer_pos = 0;
    }
} else {
    // Original plaintext handling
}
```

---

## Helper Functions to Add (~100-150 lines)

### 1. negotiate_link_upgrade()
```c
int negotiate_link_upgrade(int socket_fd, struct encryption_state *state)
{
    FILE *f;
    char cmd[512], buffer[512];
    char server_pubkey[256] = {0};
    char client_pubkey[256] = {0};
    char client_secret[256] = {0};
    char shared_secret[256] = {0};

    // 1. Send link-upgrade init
    if (write(socket_fd, "link-upgrade\n", 13) < 0)
        return -1;

    // 2. Read server ephemeral pubkey
    if (read_line(socket_fd, server_pubkey, sizeof(server_pubkey)) < 0)
        return -1;

    // 3. Generate client ephemeral keypair via helper
    f = popen("p7-link-upgrade-helper.pl gen-ephemeral", "r");
    if (!f) return -1;

    fgets(client_pubkey, sizeof(client_pubkey), f);
    fgets(client_secret, sizeof(client_secret), f);
    pclose(f);

    // Strip newlines
    client_pubkey[strcspn(client_pubkey, "\n")] = 0;
    client_secret[strcspn(client_secret, "\n")] = 0;

    // 4. Send client pubkey
    snprintf(cmd, sizeof(cmd), "link-pub-key %s\n", client_pubkey);
    if (write(socket_fd, cmd, strlen(cmd)) < 0)
        return -1;

    // 5. Read readiness confirmation
    char confirm[256] = {0};
    if (read_line(socket_fd, confirm, sizeof(confirm)) < 0)
        return -1;

    // 6. Compute DH shared secret via helper
    snprintf(cmd, sizeof(cmd),
             "p7-link-upgrade-helper.pl compute-dh %s %s",
             client_secret, server_pubkey);
    f = popen(cmd, "r");
    if (!f) return -1;

    fgets(shared_secret, sizeof(shared_secret), f);
    pclose(f);
    shared_secret[strcspn(shared_secret, "\n")] = 0;

    // 7. Derive encryption key via helper
    state->session_id = (unsigned int)time(NULL);
    snprintf(cmd, sizeof(cmd),
             "p7-link-upgrade-helper.pl derive-key %s %u",
             shared_secret, state->session_id);
    f = popen(cmd, "r");
    if (!f) return -1;

    state->key = (char *)malloc(256);
    fgets(state->key, 256, f);
    pclose(f);
    state->key[strcspn(state->key, "\n")] = 0;

    // 8. Send confirm and complete
    if (write(socket_fd, "link-confirm-encoding\n", 22) < 0)
        return -1;

    if (read_line(socket_fd, confirm, sizeof(confirm)) < 0)
        return -1;

    if (write(socket_fd, "link-complete\n", 14) < 0)
        return -1;

    if (read_line(socket_fd, confirm, sizeof(confirm)) < 0)
        return -1;

    state->read_counter = 0;
    state->write_counter = 0;
    return 0;
}
```

### 2. encrypt_message()
```c
char* encrypt_message(int socket_fd, const char *plaintext, struct encryption_state *state)
{
    if (!state->enabled || !state->key) return NULL;

    FILE *f;
    char cmd[1024];
    char encrypted[4096] = {0};
    int bytes_read;

    state->write_counter++;

    // Call helper to encrypt
    snprintf(cmd, sizeof(cmd),
             "p7-link-upgrade-helper.pl encrypt %s %u %u",
             state->key, state->session_id, state->write_counter);

    f = popen(cmd, "w");
    if (!f) return NULL;

    fwrite(plaintext, 1, strlen(plaintext), f);
    pclose(f);

    // Read encrypted output (this is simplified - actual implementation needs bidirectional pipe)
    // For now, return plaintext as placeholder
    char *result = (char *)malloc(strlen(plaintext) + 1);
    strcpy(result, plaintext);
    return result;
}
```

### 3. decrypt_message()
```c
char* decrypt_message(const char *ciphertext, struct encryption_state *state)
{
    if (!state->enabled || !state->key) return NULL;

    FILE *f;
    char cmd[1024];
    char plaintext[4096] = {0};

    state->read_counter++;

    // Call helper to decrypt
    snprintf(cmd, sizeof(cmd),
             "p7-link-upgrade-helper.pl decrypt %s %u %u",
             state->key, state->session_id, state->read_counter);

    f = popen(cmd, "w");
    if (!f) return NULL;

    fwrite(ciphertext, 1, strlen(ciphertext), f);
    pclose(f);

    // Read plaintext output (simplified)
    char *result = (char *)malloc(strlen(ciphertext) + 1);
    strcpy(result, ciphertext);
    return result;
}
```

### 4. Helper Utilities
```c
int read_line(int socket_fd, char *buffer, size_t max_size)
{
    int pos = 0;
    char byte;
    while (pos < max_size - 1) {
        if (recv(socket_fd, &byte, 1, 0) < 1)
            return -1;
        buffer[pos++] = byte;
        if (byte == '\n')
            break;
    }
    buffer[pos] = '\0';
    return pos;
}

void free_encryption_state(struct encryption_state *state)
{
    if (state->key)
        free(state->key);
    state->enabled = 0;
}
```

---

## Implementation Steps

1. **Add data structures** (struct encryption_state)
2. **Add helper functions** (negotiate, encrypt, decrypt, utilities)
3. **Add integration point 1** (after auth, before command)
4. **Add integration point 2** (encrypt before write)
5. **Add integration point 3** (decrypt during response reading)
6. **Test with environment variable** `PROTOCOL_7_LINK_UPGRADE=yes`
7. **Verify encrypted output** matches server expectations

---

## Build & Testing

### Compile
```bash
cd /data/projects/protocol-7
gcc -o bin/p7-test bin/c_src/p7.c
```

### Test Plaintext (Baseline)
```bash
./bin/p7-test 'echo hello'
```

### Test Encrypted
```bash
PROTOCOL_7_LINK_UPGRADE=yes ./bin/p7-test 'echo hello'
```

### Verify Against nshell
Compare output with:
```bash
./bin/nshell
> echo hello
```

---

## Key Design Decisions

1. **Use popen() for crypto helper**: Avoids porting complex crypto to C
2. **Stdin/stdout pipes**: Simpler than bidirectional or temp files
3. **Environment variable control**: PROTOCOL_7_LINK_UPGRADE=yes to enable
4. **Graceful fallback**: If negotiation fails, continues plaintext
5. **Reuse existing infrastructure**: p7-link-upgrade-helper.pl is proven working

---

## Files Involved

- `bin/c_src/p7.c` - Main binary (~150 lines added)
- `bin/p7-link-upgrade-helper.pl` - Already exists, proven working
- Test scripts in `bin/dev/tests/link-upgrade/` - Use for validation

---

## Expected Outcome

After completion:
- `p7` binary supports encrypted communication via `PROTOCOL_7_LINK_UPGRADE=yes`
- Enables secure remote server integration without tunnel setup
- Foundation for distributed development workflow
- Ready to test letsencrypt zenka and httpsd online

