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

### Phase 1a: Local Command Response Handler
Location: base.handler.command ~line 1261 (LOCAL CMD SIZE mode)

**Local SIZE Mode** (direct to caller):
- If `$reply->{'mode'} eq 'SIZE'`: send directly to output buffer
  - Send: `<cmd_id> SIZE <byte_count>\n<complete_data>`
  - **No fragmentation** - session buffers are large enough (128KB+)
  - **No STRM-SIZE** - would confuse clients expecting SIZE mode

**Local STRM Mode** (direct streaming):
- If `$reply->{'mode'} eq 'STRM'`: send STRM sequence:
  - Header: `<cmd_id> STRM open <total_bytes>\n`
  - Per chunk: `<cmd_id> STRM <chunk_size>\n<chunk_data>`
  - Closing: `<cmd_id> STRM close\n`
  - Caller processes packets as they arrive (no reassembly)

**Design Decision**: Command implementers returning large data should use STRM mode, not SIZE.

### Phase 1b: Routed Response Handler
Location: base.handler.command ~line 521+ (routed SIZE replies)

**Routed SIZE Mode** (between zenki, with strm-lock):
- If response is routed AND `$reply->{'mode'} eq 'SIZE'` AND `bytes::length($data) > THRESHOLD` AND strm-lock enabled:
  - Can use STRM-SIZE fragmentation: send STRM-SIZE sequence
    - Header: `<cmd_id> STRM-SIZE open <total_bytes>\n`
    - Per chunk: `<cmd_id> STRM-SIZE <chunk_size>\n<chunk_data>`
    - Closing: `<cmd_id> STRM-SIZE close\n`
  - Intermediate cubes forward fragments as-is
  - Final destination reassembles transparently
- Else: send regular SIZE (if fits in buffer)

**Design Decision**: Routed responses prefer explicit STRM mode (non-blocking) over STRM-SIZE with strm-lock.

### Phase 2: Receiver/Handler Side - Reply Type Matching
Location: base.handler.command ~line 385 (reply type recognition)

Extend reply type pattern matching:
- Add `STRM` and `STRM-SIZE` to recognized reply types
- Route handling: distinguish based on reply type prefix

### Phase 3: Receiver/Handler Side - Plain STRM Handler (Local)
Location: base.handler.command ~line 635+ (STRM reply handling)
- STRM open: initialize stream state
- STRM packets: accumulate in buffer
- STRM close: deliver complete data to handler
- Handler interface: same as SIZE (receives complete payload)

### Phase 4: Receiver/Handler Side - STRM-SIZE Handler (Routed with strm-lock)
Location: base.handler.command ~line 635+ (when response is routed)
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

## Local vs Routed Responses (Critical Distinction)

### Local Command Responses (Direct to Caller)
Commands that are executed directly (not routed through other zenki) return responses to the calling session:

```perl
Command handler running in zenka returns:
    { mode => 'SIZE', data => '...payload...' }
        ↓
Direct handler sends to calling session's output buffer
        ↓
Caller receives SIZE mode response
```

**Important**: Local responses should **NOT** use STRM-SIZE fragmentation because:
1. Caller expects SIZE mode, not STRM-SIZE packets
2. Session output buffer (128KB+) is typically large enough
3. If response exceeds buffer, use STRM mode instead: `{ mode => 'STRM', data => ... }`
4. STRM mode uses explicit streaming - caller knows to expect multiple packets

**Design rule for command implementers:**
- Small/medium response? → `{ mode => 'SIZE', data => ... }`
- Large response (>64KB)? → `{ mode => 'STRM', data => ... }` (not SIZE!)

### Routed Responses (Between Zenki)
When a command's response is routed through another zenka (inter-zenka communication):

```perl
Zenka A: Command handler returns
    { mode => 'SIZE', data => '...large_payload...' }
        ↓
Route A → Zenka B (cube) → Route B → Zenka C (destination)
        ↓
With strm-lock enabled:
    - Protocol can fragment SIZE response into STRM-SIZE chunks
    - Intermediate zenka (B) forwards fragments as-is
    - Final destination (C) reassembles transparently
    - Caller sees atomic SIZE response (strm-lock provided clean SIZE interface)
```

**Design rule for routed responses:**
- STRM-SIZE fragmentation **only** applies to routed responses with `strm-lock`
- Local responses never use STRM-SIZE
- Routed responses prefer explicit STRM mode (non-blocking) over STRM-SIZE with strm-lock

### Buffer Constraints
- **Local session buffers**: 128KB+ (no fragmentation needed for typical SIZE responses)
- **Network between cubes**: May have smaller buffers, fragmentation helps
- **Intermediate cube buffers**: Size varies by configuration
- **Routed response decision**: Use STRM-SIZE only if cubes are configured with strm-lock AND intermediate buffers are constrained

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

---

## Implementation History & Critical Bugs Fixed

### Issue: STRM-SIZE in Local Command Responses (Commit C9C76584B35B8C7AEE10B250B00ED72A7F48567B)

**Problem:**
- STRM-SIZE fragmentation was being applied to local command responses (e.g., `dump`)
- Protocol was trying to send `STRM-SIZE open`, `STRM-SIZE chunk`, `STRM-SIZE close` packets to local callers
- Clients expect SIZE mode responses, not STRM-SIZE packets
- Parser rejected STRM-SIZE as invalid reply type → protocol errors
- Large dump commands that exceeded 65KB threshold would fail

**Root Cause:**
- Confusion about where STRM-SIZE applies
- STRM-SIZE fragmentation was incorrectly placed in LOCAL CMD handler (line ~1274)
- Should only appear in routed response paths with strm-lock enabled

**Solution (Commit e0ec80ce1):**
- Removed STRM-SIZE fragmentation code from local command response handler
- Clarified: For local commands with large responses, use STRM mode instead: `{ mode => 'STRM', data => ... }`
- STRM-SIZE remains available only for routed responses with strm-lock
- Updated documentation to explain the distinction

**Lesson:**
- STRM-SIZE is for routed inter-zenka responses (with strm-lock), not local command responses
- Explicit STRM mode is cleaner and more predictable than transparent STRM-SIZE
- Session buffers are large enough for typical SIZE responses - no fragmentation needed locally
- Design principle: Make response mode explicit at command level, not implicit in protocol layer

**Recommendation for Command Implementers:**
```perl
# If response < 128KB:
return { mode => 'SIZE', data => $payload };

# If response > 128KB:
return { mode => 'STRM', data => $payload };

# Never rely on transparent STRM-SIZE fragmentation for local commands
```

---

## CRITICAL MILESTONE: Complete Transparent Reply Size Support (2026-02-19)

### Achievement

**Protocol-7 is now transparent to any reply size by default.**

For the first time, the system can deliver responses of **any size** without code changes:
- Works with or without STRM awareness in clients
- Automatic fragmentation when replies exceed buffer limits
- Transparent protocol conversion (STRM-SIZE → SIZE at final hop)
- No size constraints on command implementations

### Implementation Status: ✅ COMPLETE

**What works:**
- SIZE responses automatically fragment to STRM-SIZE when exceeding buffer limit
- Cube forwards STRM-SIZE packets route-internally (zenki-to-zenki)
- Final hop converts STRM-SIZE → SIZE transparently for clients
- Clients (p7c.c, nshell) receive SIZE protocol regardless of internal fragmentation
- Child zenki can return large SIZE responses without code/config changes
- Buffer sizes can be dynamically tuned per client type without breaking protocol

**Architecture benefits:**
- Session managers (cube, parent zenki) use per-session buffer limits
- Individual zenki use unlimited scalar buffers for output
- Event loop prioritizes output (draining) over input (reading)
- Buffer allocation by client type: main zenki (generous), external clients (conservative)
- Single base.handler.command implementation handles all fragmentation

**Verified working:**
- debian.install-history returning 477KB (3028 lines) via STRM-SIZE
- p7c.c client receiving SIZE protocol transparently
- Cube stability maintained under large response load
- Route cleanup and blocked_by_stream flag management correct

---

## Known Limitation: Blocking Attack Vulnerability

### Security Issue

**STRM-SIZE relies on route locking which can be abused:**

Malicious zenka attack scenario:
1. Return large SIZE response (triggers STRM-SIZE fragmentation)
2. Send STRM-SIZE open (sets `blocked_by_stream` flag on route)
3. Send partial data chunks
4. Never send STRM-SIZE close
5. Target zenka remains blocked indefinitely

**Impact:**
- Blocked routes prevent other commands from being processed
- No timeout mechanism for incomplete streams
- Trust-based system vulnerable to misbehaving zenki

### Potential Solutions

#### Option A: Async-Capable Handler
Make base.handler.command handle streams without blocking:
- Remove route locking for STRM-SIZE
- Allow command interleaving during stream reception
- Stream state maintained independently of route blocking
- Complexity: significant refactoring required

#### Option B: Target-Controlled Exclusion
Allow zenki to exclude fragmented reply types:
- Target declares: "no STRM-SIZE accepted"
- Sender must use STRM mode or fail
- Explicit opt-in for fragmentation support
- Simpler but less transparent

#### Option C: Capability-Based Command Registry
Comprehensive command capability system:
- Registry defines what each command can return (SIZE, STRM, STRM-SIZE)
- Route validation checks sender capability vs target acceptance
- Only allow safe command/reply-type combinations
- Most secure but most complex

### Current Mitigation

For now, Protocol-7 operates on **trust model**:
- Only trusted zenki should be connected to cube
- Misbehaving zenki can be detected and disconnected manually
- Future: implement timeout + automatic stream abort for incomplete STRM-SIZE

---

## Future Enhancements

### STRM-CHRSIZE Support
Extend transparent fragmentation to character-counted responses:
- Same pattern as STRM-SIZE
- STRM-CHRSIZE open → send CHRSIZE header to client
- STRM-CHRSIZE chunks → forward raw data
- STRM-CHRSIZE close → cleanup

### STRM-YAML, STRM-* Variants
Apply transparent fragmentation to other reply types:
- Each STRM-* variant converts to base type at final hop
- Single implementation pattern scales to all reply types

### Stream Timeout Protection - IMPLEMENTED DESIGN

**STRM-SIZE Timeout Architecture:**

STRM-SIZE requires timeout to prevent blocking attacks. Timeout is **derived from zenka heartbeat timeout** to ensure stream abort triggers before v7 restart.

**Calculation:**
```perl
## zenka calculates during auth ##
my $heartbeat = <zenka.heartbeat.timeout>;  ## from startup config ##
my $strm_timeout = int($heartbeat * 0.7);   ## 70% safety margin ##

## example: heartbeat=17s → strm_timeout=12s → 5s margin ##
```

**Declaration Flow:**

1. **Zenka startup file provides heartbeat timeout:**
   ```
   zenka.heartbeat.timeout = 17  ## v7-managed zenki ##
   ```

2. **Auth routine calculates and declares STRM-SIZE timeout:**
   ```perl
   ## during authentication, before traffic ##
   if (defined <zenka.heartbeat.timeout>) {
       my $strm_timeout = int(<zenka.heartbeat.timeout> * 0.7);
       print $socket "declare-strm-size-timeout $strm_timeout\n";
   }
   ## if undefined: skip declaration, cube uses defaults ##
   ```

3. **Cube receives during auth (base.handler.auth):**
   ```perl
   elsif ($input =~ m/^declare-strm-size-timeout\s+(\d+)/) {
       $session->{'strm_size_timeout'} = 0 + $1;
       ## continue auth ##
   }
   ```

4. **Cube uses declared or default timeout:**
   ```perl
   ## STRM-SIZE stream management ##
   $stream->{'max_idle'} = $session->{'strm_size_timeout'} // 12;
   $stream->{'last_activity'} = time();

   ## timeout check: idle time since last chunk ##
   if (time() - $stream->{'last_activity'} > $stream->{'max_idle'}) {
       ## send STRM-SIZE close-timeout ##
       send_abort($stream_id);
   }
   ```

5. **Runtime adjustment (optional):**
   ```perl
   ## before large operation ##
   <[base.protocol-7.send.local]>->(
       qw| cube |,
       'declare-strm-size-timeout 60'
   );
   ```

**Who declares what:**
- ✅ **v7-managed zenki** (httpd, debian, system): Have `<zenka.heartbeat.timeout>` → calculate and declare
- ❌ **Non-v7-managed** (nshell, console, standalone): No heartbeat config → skip declaration
- 🎯 **Cube defaults**: Use 12s (based on v7 internal defaults: 17s * 0.7)
- 🔧 **Runtime adjustment**: Any zenka can override via `cube.cmd.declare-strm-size-timeout`

**Timeout abort mechanism:**
```
STRM-SIZE close           # normal completion (bytes match expected)
STRM-SIZE close-timeout   # timeout abort (idle too long)
```

**Target handling:**
- Regular close: Validate byte count, success if complete
- Timeout close: Explicit abort signal, return timeout exit code
- p7c.c: Terminate session on timeout close
- Zenki: Log timeout, return error to handler

**Nested timeout safety:**
- STRM-SIZE timeout < heartbeat timeout
- Stream abort triggers before v7 restart
- 70% factor provides 30% safety margin
- Activity-based: resets on each chunk received

---

### STRM vs STRM-SIZE Philosophy

**STRM-SIZE (Transparent Fragmentation):**
- Purpose: SIZE protocol extension for large responses
- Timeout: **Required** (prevents blocking attacks)
- Calculation: `<zenka.heartbeat.timeout> * 0.7`
- Use case: Large responses that **must complete** in reasonable time
- Philosophy: Time-bounded, safety-first, transparent to endpoints

**STRM (Explicit Streaming):**
- Purpose: Intentional multi-packet streaming
- Timeout: **Optional** (can be indefinite)
- Use cases:
  - File transfers through unreliable routes
  - Real-time logs/events (continuous streams)
  - Monitoring data (never-ending)
  - Potentially slow/blocking sources
  - Network conditions with intermittent connectivity
- Philosophy: Explicit intent, flexibility-first, streaming semantics
- Future: Optional timeout capability while allowing indefinite mode

**Design separation:**
- Need SIZE semantics + fragmentation? → **STRM-SIZE** (transparent, timeout required)
- Need streaming semantics? → **STRM** (explicit, timeout optional)
- Need timeout guarantee? → **STRM-SIZE** or STRM with timeout
- Need indefinite stream? → **STRM** (no timeout)

#,,,,,..,,,,.,,.,,...,..,,,,.,,,,,,.,,..,,.,,,..,,...,...,,..,,,.,..,,.,.,..,,
#A4Z4XQW4PX5LLWOR57WK2PDZFTJLB4XDOUPTZSVPKK627TR26N3C7LWWWMHAWSIHBDRK2NL4MUL36
#\\\|7XPOHKGSECA5YTYJYVZMEA6OM3PX52DQNM3M65ASGIQEJN22TIG \ / AMOS7 \ YOURUM ::
#\[7]IMZRSIJ6V4T3UTN7JPM4TOF3PXXZXOM52VS7LATJGCFU5RP4A6AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
