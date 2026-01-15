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

## References

- Protocol-7 base handler: `modules/base.handler.command` (line 776)
- Message templates: `modules/protocol.protocol-7.message-templates`
- p7 Client source: `bin/c_src/p7.c`
