# SIZE Protocol: Hybrid Character/Octet Modes

## Overview

The Protocol-7 SIZE response protocol now supports two modes:
- **SIZE** (default): Character-oriented, Perl-philosophy approach
- **OCTETS**: Byte-oriented for clients that need precise byte counts

## Default Mode: SIZE (Character-Oriented)

### Behavior
- SIZE header contains **character count**, not byte count
- UTF-8 multi-byte characters (✓ = 1 character, even if 3 bytes)
- Client reads until character count is reached
- Backward compatible with previous implementation

### Example
```
Request:   letsencrypt.child.inst-self-signed
Response:  (123)SIZE 0147
           [147 characters of UTF-8 data, including ✓ = 1 char]
           Total bytes transmitted: 149 (147 chars + 2 extra bytes from ✓)
```

### p7 Client Behavior
- Detects "SIZE" response type
- Counts UTF-8 character boundaries
- Stops after reading 147 characters

## Alternative Mode: OCTETS (Byte-Oriented)

### When to Use
- Byte-oriented clients that need exact byte counts
- Systems that don't understand UTF-8 character encoding
- Mixed ASCII/UTF-8 content where byte precision is critical

### Behavior
- OCTETS header contains **byte count** (exact raw bytes)
- Client counts raw bytes, not UTF-8 characters
- Stop reading after exact byte count reached

### Example
```
Request:   letsencrypt.child.inst-self-signed (if session configured for OCTETS)
Response:  (123)OCTETS 0149
           [149 exact bytes of data]
```

### p7 Client Behavior
- Detects "OCTETS" response type
- Counts raw bytes (not character boundaries)
- Stops after reading 149 bytes exactly

## Session Configuration

### Setting OCTETS Mode
Currently, OCTETS mode is configured per-session at the server level:

```perl
$session->{'size_mode'} = 'OCTETS';  # Set to use OCTETS mode
$session->{'size_mode'} = 'SIZE';    # Reset to default SIZE mode
# Or leave unset for default SIZE mode
```

### Future: Client Negotiation
Planned features for automatic negotiation:
- Environment variable support in p7
- Auth-time capability advertisement
- Per-command mode override

## Compatibility

| Component | SIZE Mode | OCTETS Mode |
|-----------|-----------|------------|
| Perl Server | ✓ (default) | ✓ |
| p7 Client | ✓ | ✓ |
| nshell Client | ✓ (recommended) | ✓ |

## Technical Details

### SIZE Mode (Character Counting)
UTF-8 character boundary detection in p7:
- `0xxxxxxx` = ASCII character
- `11xxxxxx` = Start of multi-byte character
- `10xxxxxx` = Continuation byte (skip)

Count increments only on ASCII or multi-byte starts.

### OCTETS Mode (Byte Counting)
Simple byte counter - increments on each byte read.

## UTF-8 Example

String: `"✓"` (checkmark)
- Perl: `length("✓")` = 1 character
- UTF-8 bytes: `0xE2 0x9C 0x93` = 3 octets
- Perl with `utf8::encode()`: 3 bytes

### SIZE Response
```
SIZE 0001
✓
```
Client reads 1 character (3 bytes transmitted)

### OCTETS Response
```
OCTETS 0003
✓
```
Client reads exactly 3 bytes

## Migration Guide

### Existing Code
No changes needed! SIZE is the default and matches years of stable behavior.

### Transitioning to OCTETS
1. Identify byte-sensitive clients
2. Configure session: `$session->{'size_mode'} = 'OCTETS'`
3. Test both modes side-by-side
4. No protocol changes needed - both work simultaneously

## Testing

### Test SIZE Mode (Default)
```bash
p7 letsencrypt.child.inst-self-signed
```
Should show character count in SIZE header (147 in this example)

### Test OCTETS Mode
(Requires session configuration at server)
Should show exact byte count in OCTETS header (149 in this example)

## STRM-SIZE Mode (Transparent Fragmentation)

### Overview

STRM-SIZE provides **transparent SIZE fragmentation** for route-internal communication (zenki-to-zenki). Large SIZE responses are automatically fragmented into chunks, reassembled at the destination, then delivered as a single SIZE response to the final recipient.

**Key features:**
- Transparent to endpoints (looks like SIZE)
- Timeout protection (idle + absolute timers)
- Session locking during transfer
- Per-hop conversion based on capabilities

### Why STRM-SIZE?

**Problem**: Large SIZE responses (>500KB) block session during entire transfer
- Session locked waiting for SIZE completion
- Heartbeat timeouts if transfer takes too long
- Network issues can stall session indefinitely

**Solution**: Fragment large SIZE into STRM-SIZE chunks
- Each chunk small enough to complete quickly
- Idle timer detects stalled transfers
- Absolute timer prevents slow-drip attacks
- Session unlocks after completion or timeout

### Protocol Flow

```
Source: Sends (123)STRM-SIZE 1048576
  → Cube receives, checks size (1MB)
  → If next hop supports STRM-SIZE: forward as-is
  → If next hop supports STRM: convert STRM-SIZE → STRM
  → Otherwise: convert STRM-SIZE → SIZE (transparent, with timeout)

Chunks arrive:
  → (123)STRM-SIZE 32768 (chunk 1)
  → (123)STRM-SIZE 32768 (chunk 2)
  → ... (continues)
  → (123)STRM-SIZE close (completion)

Destination: Receives complete data as single SIZE response
```

### Dual-Timer Timeout System

**Purpose**: Protect against both stalled streams and slow-drip attacks

**Idle Timer:**
- Resets on each chunk received
- Fires if no activity for N seconds (default: 12s)
- Detects: Network stalls, crashed senders

**Absolute Timer:**
- Set once at STRM-SIZE open, never resets
- Fires after N seconds total (default: 12s)
- Detects: Slow-drip attacks (1 byte every 11s)

**Both timers use same timeout** (heartbeat * 0.7 = 12s default):
- Whichever fires first → abort stream
- Inject: `(cmd_id)STRM-SIZE close-timeout`
- Cancel other timer
- Log level 0 with timing details

### Timeout Behavior

**close-timeout vs close:**

| Event | Received | Expected | Action |
|-------|----------|----------|--------|
| close | Complete | Complete | Success, deliver data |
| close | Partial | Complete | Error, log mismatch, send FALSE |
| close-timeout | Any | Complete | Timeout abort, drop data, log |

**Handler path** (data already accumulated):
- Drop accumulated data (don't call handler)
- Log level 0: timeout abort with byte counts

**Routing path** (forwarding to target):
- Send FALSE to source with reason
- Example: `FALSE STRM-SIZE timeout: 1024/1048576 bytes`

### Capability Declarations

**Client declares STRM-SIZE support:**
```
declare-strm-size-support
```

**Effect**: Cube can send STRM-SIZE directly to this client instead of converting to SIZE

**Client declares STRM support:**
```
declare-strm-support
```

**Effect**: Cube can convert STRM-SIZE → STRM for this client

### Per-Hop Conversion (Future)

**Logic** (not yet implemented):
```perl
if ( $next_hop->{'strm_size_support'} ) {
    ## forward STRM-SIZE as-is ##
} elsif ( $next_hop->{'strm_support'} ) {
    ## convert STRM-SIZE → STRM ##
} else {
    ## convert STRM-SIZE → SIZE (with timeout) ##
}
```

**Benefits:**
- Avoids timeout risk when both ends support STRM
- Gradual protocol evolution
- Backwards compatible with SIZE-only clients

## References

- Protocol-7 base handler: `modules/base.handler.command` (STRM-SIZE handling)
- Timeout handlers: `modules/base.handler.strm_size_idle_timeout`, `modules/base.handler.strm_size_absolute_timeout`
- Timer callback: `modules/base.callback.reset_strm_size_timer`
- Message templates: `modules/protocol.protocol-7.message-templates`
- p7 Client source: `bin/c_src/p7.c`

#,,,.,.,,,,.,,,..,.,,,,,.,,,.,,..,..,,.,.,...,..,,...,..,,.,,,,..,,..,...,,..,
#TLNELSCO3ZY4TCN2NCCYFQLO2NJK5ZWXJAU3GAYECQIUN6TC34QR47PLUGG7C5SPOBIN5MZLAWU2U
#\\\|PJ2DFCLLSQDL3HL53RVT2L46UDH4HTAYMU7CM3IYLQVXGYQONTW \ / AMOS7 \ YOURUM ::
#\[7]FRN66J7VCN7GYLKT3ZZGB4LXACQVVIUDWP26LHWYLMVRCSCE6QDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
