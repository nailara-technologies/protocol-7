# STRM (Stream) Protocol Design

## Current SIZE Reply Implementation (Baseline)

### Response/Sender Side (base.handler.command:878-907)
```
Command returns: { mode => 'SIZE', data => 'large_payload_string' }
        ↓
Handler counts bytes in $data (using bytes::length)
        ↓
Sends to output buffer: "<cmd_id> SIZE <byte_count>\n<entire_data_payload>"
        ↓
Client receives complete response atomically in one buffer write
```

### Receiver/Handler Side (base.handler.command:471-541)
```
Receiver sends: SIZE <expected_length>
        ↓
Handler loops, waiting until input buffer >= length bytes
        ↓
Once enough data: extract payload, call reply handler or forward
        ↓
Delete route (reply complete)
```

**Key Properties:**
- Entire response sent atomically in header + payload
- No fragmentation - buffer must hold complete SIZE response
- Problem: Conversation histories or large datasets exceed buffer limits

---

## STRM Modes Overview

### 1. Plain STRM - Explicit Streaming Mode
Application explicitly requests streaming:
```perl
return { mode => 'STRM', data => 'large_progressive_data' }
```
- Handler/caller processes packets as they arrive
- No reassembly - streaming semantics
- Use cases: Real-time logs, events, progressive delivery

### 2. STRM-SIZE - Transparent SIZE Fragmentation
Application requests SIZE, protocol handles fragmentation:
```perl
return { mode => 'SIZE', data => 'large_response' }
```
- Protocol decides: SIZE or STRM-SIZE based on threshold
- Reassembly transparent to handler/caller
- Handler sees complete atomic SIZE response

### 3. Future STRM-* Variants
Same pattern as STRM-SIZE for other reply types:
- `STRM-YAML` - Transparent YAML fragmentation
- `STRM-CHRSIZE` - Transparent CHRSIZE fragmentation
- Pattern is extensible for any reply type

---

## STRM-SIZE (Stream-to-SIZE) - Detailed Design

### Goal (STRM-SIZE specific)
When data exceeds SIZE buffer capacity:
1. Application declares `{ mode => 'SIZE', data => 'large_response' }`
2. Protocol layer transparently decides: SIZE or STRM-SIZE based on payload size
3. Receiver sees same interface as SIZE (atomic complete data)
4. Transport between cubes uses STRM-SIZE fragmentation
5. All intermediate routing is transparent - every packet labeled with final reassembly type

### Response/Sender Side - New Logic

```
Command returns: { mode => 'SIZE', data => 'large_payload' }
        ↓
Handler counts bytes: $data_bytes = bytes::length($data)
        ↓
IF $data_bytes <= SIZE_THRESHOLD (e.g., 64KB)
   └→ Use existing SIZE path
        ↓
ELSE (data exceeds threshold)
   └→ Use new STRM path:
      - Send: "<cmd_id> STRM open <total_bytes>\n"
      - Chunk data into PACKET_SIZE fragments (e.g., 8KB each)
      - For each chunk:
        Send: "<cmd_id> STRM <chunk_size>\n<chunk_data>"
      - Send final: "<cmd_id> STRM close\n"
        ↓
Application layer unaware: just got SIZE response
```

### Receiver/Handler Side - New Logic

```
Receiver sends: SIZE <expected_length>
        ↓
Handler receives response header:
   If "SIZE <bytes>" → existing SIZE path
        ↓
   Elif "STRM open <total>" → new STRM path:
      - Initialize stream buffer, expect <total> bytes
      - Loop waiting for "STRM <size>\n<data>" packets
      - Accumulate packets until "STRM close"
        ↓
Once complete (SIZE done or STRM closed):
   - Reply handler receives accumulated complete data
   - Handler/caller sees same interface as SIZE
        ↓
Delete route (reply complete)
```

---

## Implementation Strategy

### Phase 1: Response/Sender Side (Handler Output)
Location: base.handler.command ~line 878 (SIZE reply handling)

**Plain STRM** (explicit streaming):
- If `$reply->{'mode'} eq 'STRM'`: send STRM sequence:
  - Header: `<cmd_id> STRM open <total_bytes>\n`
  - Per chunk: `<cmd_id> STRM <chunk_size>\n<chunk_data>`
  - Closing: `<cmd_id> STRM close\n`

**STRM-SIZE** (transparent SIZE fragmentation):
- If `$reply->{'mode'} eq 'SIZE'` AND `bytes::length($data) > THRESHOLD`:
  - Send STRM-SIZE sequence (same structure with STRM-SIZE prefix)
- Else: send regular SIZE

### Phase 2: Receiver/Handler Side - Reply Type Matching
Location: base.handler.command ~line 385 (reply type recognition)

Extend reply type pattern matching:
- Add `STRM` and `STRM-SIZE` to recognized reply types
- Route handling: distinguish based on reply type prefix

### Phase 3: Receiver/Handler Side - Plain STRM Handler
- STRM open: initialize stream_state in session
- STRM packets: pass each chunk progressively to handler (if handler supports streaming)
- STRM close: mark stream complete
- No reassembly for plain STRM

### Phase 4: Receiver/Handler Side - STRM-SIZE Handler
- STRM-SIZE open: initialize stream_buffer in `$session->{'streams'}{cmd_id}`
- STRM-SIZE packets: append chunks to buffer
- STRM-SIZE close: reassemble complete buffer
- Call reply handler with `{ 'data' => complete_buffer, ... }` (same SIZE interface)

### Phase 5: Intermediate Routing (Transparent)
- Cube-to-cube forwarding sees `STRM` or `STRM-SIZE` packets
- Simply forwards through routes as-is (no reassembly needed)
- Intermediate cubes don't care about STRM format - just pass through

### Phase 6: Configuration
- `$config{'protocol.strm_size.threshold'}` - when to switch SIZE→STRM-SIZE (default 64KB)
- `$config{'protocol.strm_size.packet_size'}` - fragment size (default 8KB)
- `$config{'protocol.strm.packet_size'}` - explicit STRM fragment size (default 8KB)
- No session-level preference needed - mode is transparent/explicit

---

## Data Structure Changes

### Route Extension (for STRM-SIZE state tracking)

Current route structure (unchanged at source):
```perl
$data{'route'}{$route_id} = {
    'source' => { 'sid' => $id, 'cmd_id' => $cmd_id },
    'target' => { 'sid' => $target_sid, 'cmd_id' => $target_cmd_id },
    'reply'  => { 'handler' => '...', 'params' => {...} },
    ...
}
```

Session extension for STRM-SIZE state tracking:
```perl
# When STRM-SIZE stream is active on receiver side:
$session->{'streams'}{$cmd_id} = {
    'type'           => 'SIZE',    # reassembly target type
    'total_bytes'    => 65536,
    'received_bytes' => 0,
    'buffer'         => '',
    'started_at'     => time(),
    'route_id'       => $route_id, # reference back to route
}
```

This allows the receiver to accumulate STRM-SIZE packets and know when complete.

---

## Protocol Format

### SIZE (Unchanged - for reference)
```
<cmd_id> SIZE <byte_count>\n<data>
```

### STRM - Explicit Streaming Sequence (New)
For handlers that explicitly request streaming semantics:

```
<cmd_id> STRM open <total_bytes>\n
<cmd_id> STRM <chunk_size>\n<chunk_data>
<cmd_id> STRM <chunk_size>\n<chunk_data>
...
<cmd_id> STRM close\n
```

Example (100 byte total, progressive delivery):
```
(1) STRM open 100
(1) STRM 30
    [30 bytes of data - delivered immediately]
(1) STRM 30
    [30 bytes of data - delivered immediately]
(1) STRM 40
    [remaining 10 bytes of data - delivered immediately]
(1) STRM close
```

### STRM-SIZE - Transparent SIZE Fragmentation (New)
All packets use STRM-SIZE prefix to identify reassembly target (SIZE):

```
<cmd_id> STRM-SIZE open <total_bytes>\n
<cmd_id> STRM-SIZE <chunk_size>\n<chunk_data>
<cmd_id> STRM-SIZE <chunk_size>\n<chunk_data>
...
<cmd_id> STRM-SIZE close\n
```

Example (100 byte total, transparent reassembly to SIZE):
```
(1) STRM-SIZE open 100
(1) STRM-SIZE 30
    [30 bytes of data]
(1) STRM-SIZE 30
    [30 bytes of data]
(1) STRM-SIZE 40
    [10 bytes of data]
(1) STRM-SIZE close
    → Handler receives as: { 'data' => complete_100_bytes, ... }
```

### Future Extensions (Same Pattern)
```
STRM-YAML open <total>    (for large YAML responses)
STRM-YAML <size>
[data]
STRM-YAML close

STRM-CHRSIZE open <total> (for large CHRSIZE responses)
STRM-CHRSIZE <size>
[data]
STRM-CHRSIZE close
```

Each STRM variant includes reassembly type in every packet for transparency.

---

## Transparency Guarantees

1. **Application Level**: Modules returning `{ mode => 'SIZE', data => ... }` work unchanged
   - No code changes needed - threshold decision happens in protocol layer

2. **Reply Handler Level**: Handlers receive `{ 'data' => complete_buffer, ... }`
   - Whether response came via SIZE or STRM-SIZE, handler sees same interface

3. **Routing Level**: Cube-to-cube routing forwards STRM-SIZE packets as-is
   - Intermediate cubes don't reassemble - just forward based on route
   - STRM-SIZE type in header tells receiver how to reassemble

4. **Buffer Level**: Small output buffers work with large responses
   - Large data automatically fragmented (8KB chunks)
   - Receiver accumulates in $session->{'streams'} buffer
   - Final hop delivers complete data to handler

---

## Testing Plan

1. **Baseline**: Test SIZE still works for responses under 64KB threshold
2. **Fragmentation**: Test STRM-SIZE with response > 64KB
   - Verify packets are sent as expected
   - Check open/close sequence
3. **Reassembly**: Verify source zenka receives complete, correct data
   - Handler receives identical data whether SIZE or STRM-SIZE transport
4. **Multi-hop**: Test fragmentation across cube boundaries
   - Intermediate cube forwards STRM-SIZE packets unchanged
   - Final hop reassembles before handler
5. **Edge cases**:
   - Exactly at threshold (just under/over)
   - Single packet STRM-SIZE
   - Very large response (multi-megabyte)
   - Empty data
6. **Conversation channels**: Test with growing conversation histories
   - Large chat history as STRM-SIZE response
   - Verify blocking notifications work across STRM boundaries
