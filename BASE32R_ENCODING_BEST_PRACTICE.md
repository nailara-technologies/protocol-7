# Base32r Encoding Best Practice for Protocol-7 ACME

**Principle**: Encode all truly binary data to base32r for human readability in logs and debugging.

---

## Why Base32r Instead of Raw Binary?

### Benefits

1. **Human Readable**: Can see content in logs and debugging
2. **Text-Safe**: No control characters or encoding issues
3. **Protocol-7 Pattern**: Follows existing conventions (account keys use base32r)
4. **Debugging**: Easy to identify truncation or corruption
5. **Logging**: Safe to log without special handling

### Example: Certificate Data

**Without Base32r** (raw binary):
```
. letsencrypt . received certificate data: [BINARY - 1847 bytes]
. letsencrypt . storing certificate...
```
- Can't see content in logs
- Hard to debug if there's corruption
- Logging requires special handling

**With Base32r** (human-readable):
```
. letsencrypt . received certificate data: MIID3jCC...HZQUVPNF...
. letsencrypt . storing certificate...
```
- Can see the actual content
- Easy to spot truncation or errors
- Safe to log directly

---

## Implementation Pattern

### Sending Binary Data (Child → Parent)

**Step 1: Get binary data**
```perl
my $cert_pem = <[file.content]>->( $cert_file, \my $content, qw| :raw | );
# $cert_pem is raw binary certificate
```

**Step 2: Encode to base32r**
```perl
use Crypt::Misc qw(encode_b32r);

my $cert_b32 = encode_b32r($cert_pem);
# $cert_b32 is human-readable text
```

**Step 3: Return via SIZE mode**
```perl
return { 'mode' => 'size', 'data' => $cert_b32 };
# Protocol-7 frames: SIZE [length]\n[base32r data]\n
```

### Example: Complete Child Command

```perl
# modules/letsencrypt.child.cmd.renew-certificate
my $call = shift;
my $domain = $call->{'args'};

return { 'mode' => 'false', 'data' => 'domain required' }
    unless $domain;

# ... ACME workflow ...

# Get certificate from Let's Encrypt
my $cert_pem = <[letsencrypt.child.acme_finalize]>->(...);

# Encode for safe transmission
use Crypt::Misc qw(encode_b32r);
my $cert_b32 = encode_b32r($cert_pem);

<[base.log]>->( 2, "certificate obtained, returning to parent" );

return { 'mode' => 'size', 'data' => $cert_b32 };
```

---

## Receiving Binary Data (Parent ← Child)

### Step 1: Receive SIZE reply
```perl
# Parent automatically receives SIZE reply from child
# Reply contains: base32r-encoded certificate
my $cert_b32 = $reply_data;  # From SIZE mode reply
```

### Step 2: Decode from base32r
```perl
use Crypt::Misc qw(decode_b32r);

my $cert_pem = decode_b32r($cert_b32);
# $cert_pem is now raw binary certificate again
```

### Step 3: Use or store binary data
```perl
# Write to disk
<[file.put]>->( $cert_file, $cert_pem, qw| :raw | );

# Parse X.509 structure
my $x509 = <[letsencrypt.parent.parse_certificate]>->($cert_pem);
```

### Example: Complete Parent Handler

```perl
# In parent handler receiving certificate from child
my $cert_b32 = $reply_data;  # From SIZE reply

use Crypt::Misc qw(decode_b32r);
my $cert_pem = decode_b32r($cert_b32);

<[base.log]>->( 2, "certificate received from child" );

# Store certificate
my $cert_path = sprintf '%s/%s.pem', <letsencrypt.certs.dir>, $domain;
<[file.put]>->( $cert_path, $cert_pem, qw| :raw | );

# Update registry
<letsencrypt.parent.certs>{$domain}{cert_data} = $cert_pem;
<letsencrypt.parent.certs>{$domain}{cert_path} = $cert_path;

<[base.log]>->( 2, "certificate stored at $cert_path" );
```

---

## Other Binary Data Types

### Account Keys

```perl
# Account key (Ed25519 secret)
use Crypt::Misc qw(encode_b32r, decode_b32r);

my $secret_key = <[crypt.C25519.gen_keys]>->(...)->{secret};
# Store as base32r
my $secret_b32 = encode_b32r($secret_key);
<[file.put]>->( '/var/cache/letsencrypt/account.key', $secret_b32 );

# Load as base32r
my $stored_b32 = <[file.content]>->( '/var/cache/letsencrypt/account.key' );
my $secret_key = decode_b32r($stored_b32);
```

### Certificate Chains

```perl
# Full certificate chain (multiple certificates)
my $chain_pem = join "\n", @certificates;

use Crypt::Misc qw(encode_b32r);
my $chain_b32 = encode_b32r($chain_pem);

return { 'mode' => 'size', 'data' => $chain_b32 };
```

### CSR Data (Certificate Signing Request)

```perl
# CSR is binary DER data
my $csr_der = <[letsencrypt.child.generate_csr]>->(...);

use Crypt::Misc qw(encode_b32r);
my $csr_b32 = encode_b32r($csr_der);

# Send to ACME server (likely needs to convert to base64url first)
my $csr_b64url = <[letsencrypt.child.encode_base64url]>->($csr_der);
```

---

## Advantages Over Base64

Base32r (reverse alphabet base32) vs Base64:

| Aspect | Base32r | Base64 |
|--------|---------|--------|
| Alphabet | A-Z 2-7 (no confusion) | A-Za-z0-9+/ (easy to confuse) |
| Readability | Very readable | Very readable |
| Size | ~20% larger | ~33% larger |
| URL-safe | Yes | Sometimes (with variants) |
| Protocol-7 usage | Account keys | Not standard here |
| Confusion potential | Lower (fewer look-alikes) | Higher (1/l confusion) |

**Protocol-7 uses Base32r for consistency** with existing account key storage.

---

## Implementation Checklist

- [ ] All binary data identified (certs, keys, CSRs)
- [ ] Encoding added before returning via SIZE mode
- [ ] Decoding added when receiving from SIZE replies
- [ ] Base32r import added: `use Crypt::Misc qw(encode_b32r decode_b32r)`
- [ ] Logging shows readable data (not [BINARY])
- [ ] Round-trip tested (encode → decode → compare)
- [ ] Error handling added for decode failures

---

## Testing Encode/Decode

```perl
use Crypt::Misc qw(encode_b32r, decode_b32r);

my $original = "This is my certificate data";
my $encoded = encode_b32r($original);
my $decoded = decode_b32r($encoded);

die "Round-trip failed!" unless $original eq $decoded;
print "Original: $original\n";
print "Encoded:  $encoded\n";
print "Decoded:  $decoded\n";
```

---

## For ACME Implementation

When implementing the ACME workflow:

1. **Child returns certificate**: Use base32r encoding
2. **Parent receives certificate**: Use base32r decoding
3. **Store on disk**: Use raw binary (base32r is for transmission only)
4. **Log output**: Can safely show base32r data

This gives us the best of both worlds:
- Safe, text-based transmission via Protocol-7
- Human-readable debugging and logging
- Binary data fidelity on disk storage

---

## Summary

**Use Base32r encoding when**:
- Sending binary data through Protocol-7 SIZE mode
- Storing binary data in Protocol-7 cache files (following convention)
- Logging should show readable content
- Debugging requires visibility into data

**Don't use Base32r when**:
- Data is already text (PEM is text, keep as-is)
- Final storage format requires binary (write raw bytes to disk)
- Performance is critical (small encoding overhead exists)

For ACME certificates, the flow is:
```
Let's Encrypt → Child Gets PEM (text)
Child: Encode PEM to base32r
Child: Return via SIZE mode
Parent: Receive base32r
Parent: Decode to PEM
Parent: Write raw PEM to disk for HTTPS server
```

This is the Protocol-7 way!

