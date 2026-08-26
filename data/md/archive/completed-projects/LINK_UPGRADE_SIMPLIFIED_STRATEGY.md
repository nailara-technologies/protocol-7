# Link-Upgrade Client Implementation - SIMPLIFIED STRATEGY

**Key Insight**: Leverage existing Protocol-7 crypto infrastructure instead of reimplementing

**Date**: 2025-11-27
**Status**: Much simpler than originally planned

---

## Available Infrastructure to Leverage

### Crypto Functions Already Implemented
✅ `crypt.C25519.gen_keys` - Generate ephemeral keypairs (with or without passphrase)
✅ `crypt.C25519.compute_shared` - Compute DH shared secret
✅ `crypt.C25519.key_vars` - Key management variables
✅ `crypt.C25519.get_keyname` - Extract key names
✅ `base.handler.read.encryption-wrapper` - Server-side decryption
✅ `base.handler.write.encryption-wrapper` - Server-side encryption
✅ Crypt::Misc for base32 encoding/decoding
✅ Crypt::AuthEnc::ChaCha20Poly1305 (already available)

### Key Infrastructure
✅ Keys stored in standard location: `/home/protocol-7/.n/user-keys/`
✅ Automatic key directory creation
✅ Key checksums cached for performance
✅ Support for signatures and key verification
✅ Key listing and management via keys.console.* commands

---

## nshell Implementation (SIMPLIFIED)

### Strategy: Direct Use of Existing Functions

Instead of reimplementing crypto, **call existing zenka modules directly**:

```perl
#!/usr/bin/env perl
# In nshell, after successful auth...

if ($first_command eq 'link-upgrade') {
    # 1. Send link-upgrade init
    send_to_socket('link-upgrade');

    # 2. Read server ephemeral pubkey
    my $server_pubkey = read_from_socket();

    # 3. Generate client ephemeral keypair
    # Use existing: crypt.C25519.gen_keys
    my $gen_keys = <[crypt.C25519.gen_keys]>->(
        'ephemeral-client',  # key name
        undef,               # no passphrase
        undef                # generate new secret
    );

    my $client_pubkey = $gen_keys->{'public'};
    my $client_secret = $gen_keys->{'secret'};

    # 4. Send client pubkey
    send_to_socket("link-pub-key " . encode_b32r($client_pubkey));

    # 5. Compute shared secret
    # Use existing: crypt.C25519.compute_shared
    my $shared_secret = <[crypt.C25519.compute_shared]>->(
        \$client_secret,
        Crypt::Misc::decode_b32r($server_pubkey)
    );

    # 6. Derive encryption key
    # Use existing: AMOS7::13::key_32
    use AMOS7;
    my $session_id = ... # get from session
    my $encryption_key = AMOS7::13::key_32(\$shared_secret, $session_id);

    # 7. Confirm encoding
    send_to_socket('link-confirm-encoding');
    read_from_socket();

    # 8. Complete handshake
    send_to_socket('link-complete');
    read_from_socket();

    # 9. Enable encryption mode
    $state->{encrypted} = 1;
    $state->{encryption_key} = $encryption_key;
    $state->{read_counter} = 0;
    $state->{write_counter} = 0;
    $state->{session_id} = $session_id;
}

# For all subsequent messages:
sub send_command {
    my ($cmd) = @_;
    if ($state->{encrypted}) {
        # Increment counter first
        $state->{write_counter}++;
        my $ciphertext = encrypt_message($cmd, $state);
        send_to_socket($ciphertext);
    } else {
        send_to_socket($cmd);
    }
}

sub read_response {
    if ($state->{encrypted}) {
        # Increment counter first
        $state->{read_counter}++;
        my $plaintext = decrypt_message(read_from_socket(), $state);
        return $plaintext;
    } else {
        return read_from_socket();
    }
}

sub encrypt_message {
    my ($plaintext, $state) = @_;
    use Crypt::AuthEnc::ChaCha20Poly1305;
    use Crypt::Misc;

    my $nonce = pack('N', $state->{session_id}) .
                pack('N', $state->{write_counter}) .
                "\0\0\0\0";

    my $cipher = Crypt::AuthEnc::ChaCha20Poly1305->new($state->{encryption_key}, $nonce);
    $cipher->encrypt_add($plaintext);
    my $auth_tag = $cipher->encrypt_done();

    return $cipher->ciphertext() . $auth_tag;
}

sub decrypt_message {
    my ($ciphertext, $state) = @_;
    use Crypt::AuthEnc::ChaCha20Poly1305;

    my $nonce = pack('N', $state->{session_id}) .
                pack('N', $state->{read_counter}) .
                "\0\0\0\0";

    my $auth_tag = substr($ciphertext, -16);
    my $encrypted = substr($ciphertext, 0, -16);

    my $cipher = Crypt::AuthEnc::ChaCha20Poly1305->new($state->{encryption_key}, $nonce);
    my $plaintext = $cipher->decrypt_add($encrypted);
    my $success = $cipher->decrypt_done($auth_tag);

    return $success ? $plaintext : undef;
}
```

### Why This is Simpler
1. **No reimplementation** - Use existing functions
2. **No external dependencies** - Already in Protocol-7
3. **Tested code** - Server-side is proven working
4. **Consistent API** - Uses same functions as rest of system
5. **Automatic updates** - v7 auto-reload applies changes instantly

---

## p7.c Implementation (SIMPLER WITH PERL HELPER)

### Strategy: Minimal C Code + Perl Helper

Since `crypt.C25519.gen_keys` and similar exist, we can create a **minimal Perl helper**:

```perl
#!/usr/bin/env perl
# bin/p7-link-upgrade-helper.pl
# Helper for p7.c to handle crypto operations for link-upgrade

use strict;
use warnings;
use FindBin qw| $RealBin |;
use Cwd qw| abs_path |;

# Add Protocol-7 lib paths
my $root_path = abs_path("$RealBin/..");
unshift @INC, "$root_path/data/lib-path/pm";

use AMOS7;
use Crypt::Misc;
use Crypt::AuthEnc::ChaCha20Poly1305;

my $operation = shift @ARGV // '';

if ($operation eq 'gen-ephemeral') {
    # Generate ephemeral keypair
    my $gen_result = <[crypt.C25519.gen_keys]>->(
        'p7-ephemeral-' . time(),
        undef,  # no passphrase
        undef   # generate new
    );

    print encode_b32r($gen_result->{public}) . "\n";
    print encode_b32r($gen_result->{secret}) . "\n";

} elsif ($operation eq 'compute-dh') {
    # Compute DH shared secret
    my $client_secret = Crypt::Misc::decode_b32r(shift @ARGV);
    my $server_pubkey = Crypt::Misc::decode_b32r(shift @ARGV);

    my $shared = <[crypt.C25519.compute_shared]>->(
        \$client_secret,
        $server_pubkey
    );

    print encode_b32r($$shared) . "\n";

} elsif ($operation eq 'derive-key') {
    # Derive encryption key from shared secret
    my $shared_secret = Crypt::Misc::decode_b32r(shift @ARGV);
    my $session_id = shift @ARGV;

    my $key = AMOS7::13::key_32(\$shared_secret, $session_id);
    print encode_b32r($key) . "\n";

} elsif ($operation eq 'encrypt') {
    # Encrypt message
    my $key = Crypt::Misc::decode_b32r(shift @ARGV);
    my $session_id = shift @ARGV;
    my $counter = shift @ARGV;
    my $plaintext = join('', <>);  # read from stdin

    my $nonce = pack('N', $session_id) . pack('N', $counter) . "\0\0\0\0";
    my $cipher = Crypt::AuthEnc::ChaCha20Poly1305->new($key, $nonce);
    $cipher->encrypt_add($plaintext);
    my $tag = $cipher->encrypt_done();

    print $cipher->ciphertext() . $tag;

} elsif ($operation eq 'decrypt') {
    # Decrypt message
    my $key = Crypt::Misc::decode_b32r(shift @ARGV);
    my $session_id = shift @ARGV;
    my $counter = shift @ARGV;
    my $ciphertext = join('', <>);  # read from stdin

    my $nonce = pack('N', $session_id) . pack('N', $counter) . "\0\0\0\0";
    my $tag = substr($ciphertext, -16);
    my $encrypted = substr($ciphertext, 0, -16);

    my $cipher = Crypt::AuthEnc::ChaCha20Poly1305->new($key, $nonce);
    my $plaintext = $cipher->decrypt_add($encrypted);
    my $success = $cipher->decrypt_done($tag);

    if ($success) {
        print $plaintext;
    } else {
        die "Authentication tag verification failed\n";
    }
}
```

### Then in p7.c (minimal changes):

```c
// After authentication, if cmd_str is "link-upgrade":
if (strcmp(cmd_str, "link-upgrade") == 0) {
    // Send link-upgrade init
    write(socket_fd, "link-upgrade\n", 13);

    // Read server pubkey
    char server_pubkey[256];
    read_until_newline(socket_fd, server_pubkey);

    // Generate client keys via helper
    FILE *keys_pipe = popen("perl /path/to/p7-link-upgrade-helper.pl gen-ephemeral", "r");
    char client_pubkey[256], client_secret[256];
    fgets(client_pubkey, 256, keys_pipe);
    fgets(client_secret, 256, keys_pipe);
    pclose(keys_pipe);

    // Send client pubkey
    fprintf(socket_fd, "link-pub-key %s\n", client_pubkey);

    // Compute DH via helper (stdin/stdout)
    // ... similar approach ...

    // Derive encryption key
    // ... similar approach ...

    // Enable encryption state
    encryption_state_t state = init_encryption_state(encryption_key, session_id);

    // Send confirm and complete
    write(socket_fd, "link-confirm-encoding\n", 22);
    read_until_newline(socket_fd, NULL);
    write(socket_fd, "link-complete\n", 14);
    read_until_newline(socket_fd, NULL);
}

// For message encryption/decryption:
if (state.encrypted) {
    // Call helper with stdin/stdout for each message
    // Or cache helper process and keep pipe open
}
```

---

## Implementation Timeline (SIMPLIFIED)

### Week 1: nshell (2-3 days instead of 3-4)
- Day 1: Locate auth success point in nshell
- Day 2: Add link-upgrade negotiation
- Day 3: Add encryption/decryption wrapper

### Week 2: p7.c Helper + Integration (2-3 days instead of 2-3)
- Day 1: Create minimal Perl helper script
- Day 2: Integrate helper into p7.c
- Day 3: Test encrypted p7 client

### Week 3: Remote Testing (2 days)
- Deploy to internet server
- Test low-latency encrypted letsencr

**Total**: 6-8 days instead of 7-10 days

---

## Why This Approach is Better

1. **Reuses tested code** - Server encryption is proven working
2. **Less new code** - No reimplementation needed
3. **Fewer bugs** - Using existing, tested functions
4. **Easier maintenance** - Leverages Protocol-7 ecosystem
5. **Faster development** - Direct Perl calls vs C FFI
6. **v7 auto-reload** - Changes picked up automatically
7. **Consistent APIs** - Same functions everywhere
8. **Less complexity** - Perl helper avoids complex C code

---

## File Changes Summary

### nshell (existing file)
- Find authentication success point (~line 150-200?)
- Add link-upgrade negotiation block (~50-80 lines)
- Add encryption/decryption functions (~60-80 lines)
- **Total additions**: ~150-160 lines

### p7.c (existing file)
- Add encryption state structure (~5-10 lines)
- Add Perl helper invocation (~30-40 lines)
- Add encryption/decryption calls (~20-30 lines)
- **Total additions**: ~50-80 lines

### Create: bin/p7-link-upgrade-helper.pl (new file)
- ~100-120 lines (call existing zenka modules)

### Total New Code: ~250-300 lines
### Existing Code Leveraged: ~5000+ lines of tested crypto

---

## Testing Strategy

1. **Unit tests** - Use test-link-upgrade-client.pl as reference
2. **Integration** - Test with test-link-upgrade zenka
3. **Performance** - Measure encryption overhead (expect <5%)
4. **Remote** - Test from internet-accessible server

---

## Status: Ready to Implement

**Key Advantage**: Much less code, higher confidence in correctness

**Next Step**: Begin nshell analysis to find authentication success point

#,,..,...,,..,...,,,,,..,,,.,,,.,,,.,,.,.,.,,,.,.,...,...,,,.,.,,,.,,,,,,,.,.,
#GIXFDRECYJOJQG2BJUIEXQLWJOCNESJKP4CTA2BDZMGBL3HKNIQ3XKW4N6ZDERZ5JOH7EWDGGPS7W
#\\\|GDCAACFHLA5SI7Q5GFG5BFPAIEJ5GLU3DVFSYWLIPBSOUNCTCA5 \ / AMOS7 \ YOURUM ::
#\[7]JAVAENKLOT2EKMSNU462S4DNVILATC3VBHIRJ5LQYPONMYUXHUCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
