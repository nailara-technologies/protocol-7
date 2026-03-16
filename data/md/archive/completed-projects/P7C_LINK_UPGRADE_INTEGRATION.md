# p7.c Link-Upgrade Integration Guide

**Status**: Documentation & implementation plan for C client encryption
**Created**: 2025-11-27
**Complexity**: Medium (requires popen() for helper calls)

---

## Overview

This guide documents how to integrate link-upgrade encryption support into the p7.c C client using the p7-link-upgrade-helper.pl Perl helper script.

The approach is:
1. Keep p7.c logic simple and focused on socket I/O
2. Offload complex crypto operations to the Perl helper
3. Use popen() to spawn helper processes for key generation/derivation
4. Handle encryption/decryption inline in C using helper output

---

## Current p7.c Flow

```c
main()
  ↓
  socket() + connect()                    // Create Unix socket
  ↓
  write(socket, auth_str)                 // Send: "select unix\nauth unix-<user>\n"
  ↓
  recv(socket) x3                         // Read auth response (3 lines)
  ↓
  write(socket, cmd_str)                  // Send command (currently plaintext)
  ↓
  while(recv(socket))                     // Read response (currently plaintext)
    output to stdout
  ↓
  exit
```

---

## Proposed Integration Points

### Integration Point 1: After Authentication Success (Line 148)

**Current code**:
```c
    }  // end of auth while loop at line 148

    /* send protocol-7 command string to socket */
    write( socket_fd, cmd_str, strlen(cmd_str) );
```

**Add link-upgrade negotiation here**:

```c
    }  // end of auth while loop

    // [NEW] Link-upgrade encryption negotiation (optional)
    struct encryption_state {
        int enabled;
        char *key;          // 32-byte key in base32
        unsigned int session_id;
        unsigned int read_counter;
        unsigned int write_counter;
    } enc_state = {0, NULL, 0, 0, 0};

    // Check if environment variable enables encryption
    char *link_upgrade_env = secure_getenv("PROTOCOL_7_LINK_UPGRADE");
    if (link_upgrade_env && strcmp(link_upgrade_env, "yes") == 0) {
        if (negotiate_link_upgrade(socket_fd, &enc_state) == 0) {
            fprintf(stderr, ":: link-upgrade encryption enabled ::\n");
            enc_state.enabled = 1;
        } else {
            fprintf(stderr, ":: link-upgrade negotiation failed, continuing plaintext\n");
        }
    }

    /* send protocol-7 command string to socket */
```

### Integration Point 2: Command Sending (Line 151)

**Current code**:
```c
    /* send protocol-7 command string to socket */
    write( socket_fd, cmd_str, strlen(cmd_str) );
    free(cmd_str);
```

**Add encryption wrapper**:

```c
    /* send protocol-7 command string to socket */
    if (enc_state.enabled) {
        char *encrypted_cmd = encrypt_message(socket_fd, cmd_str, &enc_state);
        write(socket_fd, encrypted_cmd, strlen(encrypted_cmd));
        free(encrypted_cmd);
    } else {
        write(socket_fd, cmd_str, strlen(cmd_str));
    }
    free(cmd_str);
```

### Integration Point 3: Response Reading (Line 167)

**Current code**:
```c
    while ( continue_read ) {
        result = recv( socket_fd, &byte, 1, MSG_WAITALL );
        if ( result < 1 ) {
            continue_read = 0;
        } else {
            // process byte...
```

**Add decryption handling**:

```c
    // For encrypted mode, we need to buffer responses
    char response_buffer[4096] = {0};
    int buffer_size = 0;

    while ( continue_read ) {
        if (enc_state.enabled) {
            // Read full encrypted message (until newline)
            buffer_size = read_encrypted_message(socket_fd, response_buffer, sizeof(response_buffer), &enc_state);
            if (buffer_size <= 0) {
                continue_read = 0;
            } else {
                // Process decrypted message
                for (int i = 0; i < buffer_size; i++) {
                    byte = response_buffer[i];
                    // [rest of existing byte-by-byte processing]
```

---

## Helper Functions to Add

### 1. negotiate_link_upgrade()

```c
int negotiate_link_upgrade(int socket_fd, struct encryption_state *state)
{
    // 1. Send link-upgrade init
    if (write(socket_fd, "link-upgrade\n", 13) < 0)
        return -1;

    // 2. Read server ephemeral pubkey (base32)
    char server_pubkey[256] = {0};
    if (read_line(socket_fd, server_pubkey, sizeof(server_pubkey)) < 0)
        return -1;

    // 3. Generate client ephemeral keypair via helper
    FILE *f = popen("p7-link-upgrade-helper.pl gen-ephemeral", "r");
    if (!f) return -1;

    char client_pubkey[256] = {0};
    char client_secret[256] = {0};
    fgets(client_pubkey, sizeof(client_pubkey), f);
    fgets(client_secret, sizeof(client_secret), f);
    pclose(f);

    // 4. Send client pubkey
    char send_buf[512];
    snprintf(send_buf, sizeof(send_buf), "link-pub-key %s\n", client_pubkey);
    if (write(socket_fd, send_buf, strlen(send_buf)) < 0)
        return -1;

    // 5. Read readiness confirmation
    char confirm[256] = {0};
    if (read_line(socket_fd, confirm, sizeof(confirm)) < 0)
        return -1;

    // 6. Compute DH shared secret via helper
    snprintf(send_buf, sizeof(send_buf),
             "p7-link-upgrade-helper.pl compute-dh %s %s",
             client_secret, server_pubkey);
    f = popen(send_buf, "r");
    if (!f) return -1;

    char shared_secret[256] = {0};
    fgets(shared_secret, sizeof(shared_secret), f);
    pclose(f);

    // 7. Derive encryption key via helper
    state->session_id = (unsigned int)time(NULL);
    snprintf(send_buf, sizeof(send_buf),
             "p7-link-upgrade-helper.pl derive-key %s %u",
             shared_secret, state->session_id);
    f = popen(send_buf, "r");
    if (!f) return -1;

    state->key = (char *)malloc(256);
    fgets(state->key, 256, f);
    pclose(f);

    // 8. Send confirm and complete
    if (write(socket_fd, "link-confirm-encoding\n", 22) < 0)
        return -1;

    if (read_line(socket_fd, confirm, sizeof(confirm)) < 0)
        return -1;

    if (write(socket_fd, "link-complete\n", 14) < 0)
        return -1;

    if (read_line(socket_fd, confirm, sizeof(confirm)) < 0)
        return -1;

    // 9. Success
    state->read_counter = 0;
    state->write_counter = 0;
    return 0;
}
```

### 2. encrypt_message()

```c
char* encrypt_message(int socket_fd, const char *plaintext, struct encryption_state *state)
{
    // Increment write counter
    state->write_counter++;

    // Prepare command for helper
    char cmd[1024];
    snprintf(cmd, sizeof(cmd),
             "p7-link-upgrade-helper.pl encrypt %s %u %u",
             state->key, state->session_id, state->write_counter);

    // Open pipe and write plaintext
    FILE *f = popen(cmd, "w");
    if (!f) return NULL;

    fwrite(plaintext, 1, strlen(plaintext), f);
    pclose(f);

    // Read encrypted output (binary) - NOT IMPLEMENTED (needs proper pipe handling)
    // This is complex in C - would need bidirectional pipes or temporary files
    return NULL;  // TODO: Implement proper crypto wrapping
}
```

### 3. Helper Functions

```c
// Read a line from socket until newline
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

// Clean up encryption state
void free_encryption_state(struct encryption_state *state)
{
    if (state->key)
        free(state->key);
    state->enabled = 0;
}
```

---

## Implementation Challenges

### Challenge 1: Bidirectional Pipes for Encryption

The current approach uses `popen()` with "r" mode (read) or "w" mode (write), but not both simultaneously. For encryption:

```c
// This doesn't work - can't both write and read
FILE *f = popen("helper.pl encrypt", "r+");  // Invalid
```

**Solutions**:
1. Use `popen()` with "w", get PID, use separate pipe to read output
2. Use `pipe()` + `fork()` + `dup2()` for full bidirectional communication
3. Write plaintext to temporary file, read encrypted output, delete temp file
4. Use stdin/stdout redirection in shell command

**Recommended**: Option 3 (temporary files) or enhanced option 1 (separate read pipe)

### Challenge 2: Binary Data Handling in C

Encryption output is binary (ciphertext + 16-byte auth tag), which may contain null bytes and other control characters.

**Solution**: Use `fwrite()`/`fread()` instead of string functions, track byte counts

### Challenge 3: Large Messages

Default implementation sends command as single message. For large output responses:

**Solution**: Batch responses into 4KB chunks, encrypt each batch separately

---

## Simplified Integration Approach

Given the complexity of bidirectional pipes in C, a simpler approach:

1. **For sending** (command encryption):
   - Write plaintext command to temp file
   - Call helper with temp file as input
   - Read encrypted output from helper's stdout
   - Send encrypted data to socket
   - Delete temp files

2. **For receiving** (response decryption):
   - Buffer raw response from socket
   - Write to temp file
   - Call helper with temp file as input
   - Read decrypted plaintext from helper's stdout
   - Process plaintext
   - Delete temp files

This approach is simple but slow due to temp file I/O.

---

## Testing Strategy

1. **Without encryption**: Test p7.c normally (baseline)
   ```bash
   p7 'echo hello'
   ```

2. **With encryption disabled**: Set PROTOCOL_7_LINK_UPGRADE=no
   ```bash
   PROTOCOL_7_LINK_UPGRADE=no p7 'echo hello'
   ```

3. **With encryption enabled**: Set PROTOCOL_7_LINK_UPGRADE=yes
   ```bash
   PROTOCOL_7_LINK_UPGRADE=yes p7 'echo hello'
   ```

4. **Compare outputs**: Should be identical regardless of encryption

---

## Estimated Effort

- **Lines of C code**: 200-300 lines
- **Time to implement**: 2-3 hours
- **Time to test**: 1-2 hours
- **Time to debug**: 2-4 hours

**Total**: 5-9 hours

---

## Recommendation

Given the complexity of C pipes and temporary file handling, I recommend:

1. **Priority 1**: Test nshell with link-upgrade (already implemented)
2. **Priority 2**: Document and plan p7.c integration (this document)
3. **Priority 3**: If time permits, implement simplified version with temp files
4. **Priority 4**: Optimize with proper bidirectional pipes if needed

The nshell implementation is more valuable since it's the primary interactive client and demonstrates the encryption mechanism fully.

---

## Files Modified

When implemented:
- `protocol-7/bin/c_src/p7.c` - Add ~200-300 lines for encryption support

## Dependencies

- `p7-link-upgrade-helper.pl` - Must be in PATH or modify commands with full path
- Temporary directory - /tmp or $TMPDIR for crypto file handling

---

## Next Steps

1. Test nshell encryption with test-link-upgrade zenka
2. If nshell works, document any issues/learnings
3. Return to p7.c integration with gained knowledge
4. Consider whether simplified or full bidirectional implementation is needed

#,,,,,,,,,,,.,,.,,...,.,.,..,,,,,,..,,,,,,,,,,..,,...,...,,.,,,..,,..,.,,,...,
#L2PMKU6ZGIYWFRCC5P4SORBI7VSZDIILGZVZOXIYKVG43DX4FB3E25LMHMN3ZOQU7WCEILD3HKNLG
#\\\|2RYXIKWT6KIR7QOYVGYILG3U6HNO5TEJ4YHLPXTSGTYXLWW5LJI \ / AMOS7 \ YOURUM ::
#\[7]S3MPYH6OBGSOHW2MS4Q62CORMV4DMWO5MM5RGTXOEJERJUFJ6GAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
