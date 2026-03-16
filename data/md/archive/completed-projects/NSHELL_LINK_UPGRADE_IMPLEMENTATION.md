# nshell Link-Upgrade Implementation Guide

**Status**: Ready to implement
**File**: bin/nshell (591 lines)
**Changes**: ~150-180 lines of new code
**Integration Points**: 3 identified and documented

---

## Architecture Summary

### Current nshell Flow
```
Line 158-163:  Authentication (unix_auth or shell_auth)
Line 168:      Check socket is valid (-S $shell_sock)
Line 193:      Call shell_loop($shell_sock, $prompt)
  Line 399-400: Main loop readline($prompt)
  Line 436:     s_write($sock, "$line\n") - SEND COMMAND
  Line 482+:    stdout_fork() - READ RESPONSE
```

### With Link-Upgrade Encryption
```
Line 158-163:  Authentication (unix_auth or shell_auth)
Line ~167.5:   [NEW] link-upgrade negotiation block
  - Send "link-upgrade\n"
  - Read server pubkey
  - Generate client ephemeral keypair
  - Send "link-pub-key <pubkey>\n"
  - Compute DH shared secret
  - Derive encryption key
  - Send "link-confirm-encoding\n"
  - Send "link-complete\n"
  - Enable encryption mode in $state hash
Line 168:      Check socket is valid
Line 193:      Call shell_loop($shell_sock, $prompt) with $state
  Line 399-400: Main loop readline($prompt)
  Line 436:     s_write with ENCRYPTION if $state->{encrypted}
  Line 482+:    stdout_fork with DECRYPTION if $state->{encrypted}
```

---

## Implementation Steps

### Step 1: Add Link-Upgrade Negotiation (After Line 163)

```perl
# Right after successful authentication, add this block:

    # Link-upgrade encryption negotiation (optional)
    my %encryption_state = (
        enabled      => 0,
        key          => undef,
        session_id   => undef,
        read_counter => 0,
        write_counter => 0,
    );

    # Check if user wants encryption (optional: can also auto-negotiate)
    if ( defined $ENV{'PROTOCOL_7_LINK_UPGRADE'} and $ENV{'PROTOCOL_7_LINK_UPGRADE'} eq 'yes' ) {
        if ( negotiate_link_upgrade( $shell_sock, \%encryption_state ) ) {
            print " :: link-upgrade encryption enabled ::\n";
            $encryption_state{enabled} = 1;
        } else {
            warn_err("link-upgrade negotiation failed, continuing plaintext");
        }
    }
```

### Step 2: Pass Encryption State to shell_loop

**Line 193**: Change from:
```perl
shell_loop( $shell_sock, $prompt );
```

To:
```perl
shell_loop( $shell_sock, $prompt, \%encryption_state );
```

### Step 3: Update shell_loop Signature and Command Sending

**Line 376-377**: Update function signature:
```perl
sub shell_loop {
    my $sock             = $ARG[0];
    my $prompt           = $ARG[1];
    my $encryption_state = $ARG[2] // {};  # NEW

    # ... existing code ...
```

**Line 436**: Update command sending:
```perl
# BEFORE (existing):
if ( !s_write( $sock, sprintf( "%s\n", $line ) ) ) {

# AFTER (add encryption):
my $command_to_send = sprintf( "%s\n", $line );
if ( $encryption_state->{enabled} ) {
    $command_to_send = encrypt_message( $command_to_send, $encryption_state );
}
if ( !s_write( $sock, $command_to_send ) ) {
```

### Step 4: Update Response Reading (stdout_fork)

Find `stdout_fork()` function and update response handling:

```perl
# When reading responses from socket, decrypt if encrypted:
while ( my $out = <$shell_sock> ) {
    # NEW: Decrypt if encryption enabled
    if ( $encryption_state->{enabled} ) {
        $out = decrypt_message( $out, $encryption_state );
        next unless defined $out;  # Skip if decryption failed
    }

    # EXISTING: Process output
    # print $out, ...
}
```

### Step 5: Add Link-Upgrade Negotiation Function

Add these new functions at the end of nshell (before __END__):

```perl
sub negotiate_link_upgrade {
    my ( $sock, $state_ref ) = @_;

    # 1. Send link-upgrade init
    if ( !s_write( $sock, "link-upgrade\n" ) ) {
        return 0;
    }

    # 2. Read server ephemeral pubkey
    my $server_pubkey_b32 = s_read( $sock );
    chomp($server_pubkey_b32);
    return 0 unless $server_pubkey_b32;

    # 3. Generate client ephemeral keypair
    my $gen_result = <[crypt.C25519.gen_keys]>->(
        'nshell-ephemeral-' . time(),
        undef,  # no passphrase
        undef   # generate new secret
    );
    return 0 unless $gen_result and ref($gen_result) eq 'HASH';

    my $client_pubkey = $gen_result->{'public'};
    my $client_secret = $gen_result->{'secret'};

    # Encode to base32
    use Crypt::Misc;
    my $client_pubkey_b32 = Crypt::Misc::encode_b32r($client_pubkey);

    # 4. Send client pubkey
    if ( !s_write( $sock, "link-pub-key $client_pubkey_b32\n" ) ) {
        return 0;
    }

    # 5. Read readiness confirmation
    my $confirm = s_read( $sock );
    return 0 unless $confirm;

    # 6. Compute DH shared secret
    my $server_pubkey = Crypt::Misc::decode_b32r($server_pubkey_b32);
    my $shared_secret_ref = <[crypt.C25519.compute_shared]>->(
        \$client_secret,
        $server_pubkey
    );
    return 0 unless $shared_secret_ref;

    my $shared_secret = $$shared_secret_ref;

    # 7. Derive encryption key
    use AMOS7;
    my $session_id = time() & 0xFFFFFFFF;  # Use time as session ID
    my $encryption_key = AMOS7::13::key_32( \$shared_secret, $session_id );
    return 0 unless $encryption_key;

    # 8. Send confirm and complete
    if ( !s_write( $sock, "link-confirm-encoding\n" ) ) {
        return 0;
    }

    my $enc_confirm = s_read( $sock );
    return 0 unless $enc_confirm;

    if ( !s_write( $sock, "link-complete\n" ) ) {
        return 0;
    }

    my $complete = s_read( $sock );
    return 0 unless $complete;

    # 9. Store encryption state
    $state_ref->{key}           = $encryption_key;
    $state_ref->{session_id}    = $session_id;
    $state_ref->{read_counter}  = 0;
    $state_ref->{write_counter} = 0;

    return 1;  # Success
}

sub encrypt_message {
    my ( $plaintext, $state_ref ) = @_;
    return $plaintext unless $state_ref->{enabled};

    use Crypt::AuthEnc::ChaCha20Poly1305;

    # Increment write counter before use
    $state_ref->{write_counter}++;

    my $nonce = pack( 'N', $state_ref->{session_id} ) .
                pack( 'N', $state_ref->{write_counter} ) .
                "\0\0\0\0";

    my $cipher = Crypt::AuthEnc::ChaCha20Poly1305->new(
        $state_ref->{key},
        $nonce
    );
    $cipher->encrypt_add($plaintext);
    my $auth_tag = $cipher->encrypt_done();

    return $cipher->ciphertext() . $auth_tag;
}

sub decrypt_message {
    my ( $ciphertext, $state_ref ) = @_;
    return $ciphertext unless $state_ref->{enabled};

    use Crypt::AuthEnc::ChaCha20Poly1305;

    # Increment read counter before use
    $state_ref->{read_counter}++;

    my $nonce = pack( 'N', $state_ref->{session_id} ) .
                pack( 'N', $state_ref->{read_counter} ) .
                "\0\0\0\0";

    my $auth_tag = substr( $ciphertext, -16 );
    my $encrypted = substr( $ciphertext, 0, -16 );

    my $cipher = Crypt::AuthEnc::ChaCha20Poly1305->new(
        $state_ref->{key},
        $nonce
    );
    my $plaintext = $cipher->decrypt_add($encrypted);
    my $success = $cipher->decrypt_done($auth_tag);

    return $success ? $plaintext : undef;
}
```

### Step 6: Find stdout_fork and Add Decryption

Find the `stdout_fork()` function (around line 482) and update the response reading loop to decrypt messages if encryption is enabled.

---

## Integration Points Summary

| Line | Current Code | Change |
|------|--------------|--------|
| 163 | Auth complete | Add link-upgrade negotiation |
| 193 | `shell_loop($shell_sock, $prompt)` | Pass encryption state: `shell_loop($shell_sock, $prompt, \%encryption_state)` |
| 376-377 | Function signature | Accept third parameter: `\%encryption_state` |
| 436 | `s_write($sock, sprintf("%s\n", $line))` | Encrypt if enabled before writing |
| 482+ | `while (<$shell_sock>)` | Decrypt if enabled before processing |
| EOF | Add functions | `negotiate_link_upgrade()`, `encrypt_message()`, `decrypt_message()` |

---

## Testing Checklist

- [ ] Syntax: `perl -c bin/nshell` (check for errors)
- [ ] nshell starts without errors
- [ ] Regular plaintext commands still work
- [ ] Set `PROTOCOL_7_LINK_UPGRADE=yes` environment variable
- [ ] Link-upgrade negotiation succeeds
- [ ] Encrypted commands execute correctly
- [ ] Responses decrypt properly
- [ ] Multi-line output handled correctly
- [ ] Connection recovery works with encryption
- [ ] Test with test-link-upgrade zenka

---

## Key Technical Details

### Nonce Generation
```perl
$nonce = pack('N', $session_id) .      # 4 bytes
         pack('N', $counter) .         # 4 bytes
         "\0\0\0\0";                   # 4 bytes padding
```

### Counter Management
- **Separate read/write counters**: Bi-directional communication
- **Increment before use**: `$counter++` happens first
- **First message uses counter=1**: Counter starts at 0

### Cipher Instance Management
- **Fresh instance per message**: Create new cipher for each encryption/decryption
- **Do NOT reuse cipher instances**: This is critical for security

### Response Handling
- **Multi-line responses**: Handle lines that contain multiple messages
- **Partial messages**: Buffer incomplete messages until full message received
- **Authentication tags**: Last 16 bytes are the auth tag, not plaintext

---

## Estimated Implementation Time

| Task | Time |
|------|------|
| Modify authentication section | 15 min |
| Update shell_loop signature | 10 min |
| Add encryption/decryption wrapper | 30 min |
| Create negotiation function | 45 min |
| Update response reading | 30 min |
| Testing & debugging | 1-2 hours |
| **Total** | **~3 hours** |

---

## Important Notes

1. **Environment Variable**: Link-upgrade is optional, controlled by `PROTOCOL_7_LINK_UPGRADE` env var
2. **Backwards Compatible**: Works with plaintext connections if encryption not enabled
3. **Session ID**: Uses timestamp as simple session identifier (can be refined)
4. **Error Handling**: Returns false on any negotiation failure, continues with plaintext
5. **v7 Auto-Reload**: Changes automatically picked up when nshell is re-executed

---

## Next Steps

1. **Edit nshell** following the steps above
2. **Syntax check**: `perl -c bin/nshell`
3. **Manual test**: Run nshell with `PROTOCOL_7_LINK_UPGRADE=yes`
4. **Test with zenka**: Connect to test-link-upgrade zenka
5. **Verify encrypted communication**: Check messages are encrypted

---

**Status**: Ready to implement
**Complexity**: Medium (mostly straightforward socket I/O)
**Risk Level**: Low (encryption is isolated, doesn't affect plaintext mode)

#,,,,,,..,.,.,,..,..,,.,,,.,.,...,..,,,,.,...,.,.,...,...,.,,,.,,,.,.,,..,.,.,
#B7PJM33WSY4BFOAVJSYGULDW63VC3Q4R2TUSWKY22KCBTVSK4PTTAKBTSDOQS3INVE52WOBKMG4SS
#\\\|DPZJWT6HFIISDG3HWDPHDMO7DWKTDK3PAFAZYGZWDLEET47NQ5Z \ / AMOS7 \ YOURUM ::
#\[7]RWI3SVKXKLLLDGLGNYCZM3PT6DEH6GA34AWAJKMK2AOMQIJVW6CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
