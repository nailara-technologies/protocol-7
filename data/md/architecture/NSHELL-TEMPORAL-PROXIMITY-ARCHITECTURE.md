# nshell: Protocol-Agnostic Client with Temporal Proximity Mapping

## Overview

nshell is a protocol-agnostic terminal client for Protocol-7's distributed zenka network. Rather than enforcing strict command-reply routing (which nshell cannot support), it uses **temporal proximity mapping** as a privacy-preserving, universally-applicable layer for correlating commands with responses, debugging, forensics, and security analysis.

## Architecture

### Layer 1: Protocol-Agnostic Output Capture (Current)

**Design Principle**: nshell doesn't know or care about command boundaries.

```
User types: list users
           ↓
nshell.shell_loop:
- Accumulates characters into complete line
- Appends to cube's input buffer as raw text
- Returns immediately (doesn't wait for result)
           ↓
Cube processes command
           ↓
Cube sends reply (may be routed, may be unmapped)
           ↓
nshell.hook.unknown_reply_route (catches unmapped replies):
- Extracts output from reply data
- Prints to terminal
- Logs to terminal-history buffer
- Returns (handler complete)
           ↓
User sees output on screen + in terminal-history
```

**Why this design**:
- nshell has no knowledge of protocol routing
- Doesn't know if command will be forwarded to other zenka
- Doesn't know if response will be direct or multi-hop
- Doesn't know if response will come immediately or after queuing
- **Yet it works** because output is treated as raw asynchronous stream

**Current Implementation**:
- `nshell.shell_loop` - Accumulates user input, sends to cube buffer
- `nshell.hook.unknown_reply_route` - Intercepts unmapped replies, displays output
- `nshell.handler.command_reply` - Logs to terminal-history (incomplete, being improved)
- `nshell.read_from_buffer` - Handles editor input processing with debug logging

### Layer 2: Temporal Proximity Mapping (Planned)

**Problem**: How do you correlate replies to commands if you don't send route IDs?

**Solution**: Use **timestamps as a privacy-preserving correlation mechanism**.

#### Cube-Side Temporal Tracking

**Collection point**: When reply is routed (as route is being purged as completed)

**Full lifecycle captured**: Command departure → Reply arrival with exact byte ranges

```perl
# Internal cube tracking (log level 2-3, cube-side only)
$temporal_map = {
    # Reply timestamp as key (when packet arrived)
    1234567890.650 => {
        # Command departure (from base.route.add at send time)
        start_time   => 1234567890.456,
        start_offset => 10000,           # Where command's output starts

        # Reply arrival (collected when route is routed/purged)
        reply_time   => 1234567890.650,
        current_offset => 10300,         # Buffer position when reply arrives

        # Payload
        reply_packet_size => 300,        # Size of actual reply data

        # Context (stored internally, not exposed externally)
        session_id   => 'xyz123',        # Internal session tracking
        username     => 'taeki',         # Authenticated user
        zenka_name   => 'weather',       # Resolved zenka name
        command      => 'desc',

        # Supports all offset encoding strategies:
        # [start_offset, reply_packet_size]
        # [current_offset - reply_packet_size, reply_packet_size]
        # negative offsets from current_offset
    },
    1234567890.750 => {
        start_time   => 1234567890.550,
        start_offset => 10300,
        reply_time   => 1234567890.750,
        current_offset => 10550,
        reply_packet_size => 250,
        session_id   => 'xyz123',
        username     => 'taeki',
        zenka_name   => 'calc',
        command      => '2+2',
    },
};

# Privacy-preserving external queries (on-demand resolution):
# Question: "What happened at timestamp 1234567890.650?"
# Answer: "Output from user taeki via zenka weather" (no IDs exposed)
# (Internal cube resolves session_id → zenka, never exposed to external clients)
```

**Why this data combination**:
- `start_time` + `reply_time`: Full latency window and temporal proximity
- `start_offset` + `current_offset`: Byte range boundaries with flexibility for encoding
- `reply_packet_size`: Exact response size (no estimation needed)
- `session_id` + `username`: Internal correlation for cube-side forensics
- Stored as internal logging only (log level 2-3 events)
- Available for local analysis, never exposed externally

#### Reply Correlation: Byte-Range Based with Temporal Hints

**Core mechanism**: Cube allocates **exact byte ranges** for each command's output:

```
Cube's temporal map with byte ranges:
  1234567890.123 => { start_offset: 0,    range_size: 50,   zenka: 'weather' }
  1234567890.456 => { start_offset: 50,   range_size: 100,  zenka: 'calc' }
  1234567890.789 => { start_offset: 150,  range_size: 100,  zenka: 'list' }

When SIZE reply arrives:
  "SIZE 87" at timestamp 1234567890.500
  ↓
  Find closest timestamp: 1234567890.456 (44ms away)
  ↓
  Extract exactly bytes [50-137] from session buffer
  ↓
  Output ready to display, perfectly correlated
```

**Why byte-ranges over timestamps**:
- **Byte-exact** — No ambiguity in which output belongs where
- **Format-independent** — Works with any protocol, encoding, or data
- **Works with SIZE protocol** — SIZE already specifies byte count
- **Temporal proximity** — Used as hint for which byte range to read
- **Async-aware** — Handles out-of-order replies automatically

**Adaptive offset encoding** (for long sessions):
```
Instead of: [start: 9847352847, end: 9847352947]  (20+ digits)
Use:        [offset: 9847352847, size: 100]       (13 digits)
Or:         [delta: +250, size: 100]              (7 digits)
Or:         [back: -5000, size: 200]              (10 digits)
```

Handlers transparently decode any format, choosing most compact representation.

**Temporal proximity algorithm**:
```
Given: output timestamp T
Find:  closest command send timestamp from map
Return: byte range [offset, size] for that command
Extract: exactly those bytes from buffer
```

Validation happens separately through harmonic signatures (not temporal distance).

#### Optional: Map Sharing with nshell

Cube can optionally share the temporal map with nshell:

```perl
# nshell receives:
[
    {
        timestamp => 1234567890.123,
        zenka     => 'weather',
        command   => 'desc',
        status    => 'sent'
    },
    {
        timestamp => 1234567890.456,
        zenka     => 'calc',
        command   => '2+2',
        status    => 'sent'
    },
    ...
]

# nshell can use for:
# - Terminal-history annotation (show which zenka replied)
# - Ctrl+O cycling with metadata
# - User-facing debugging information
```

**Note**: Timestamps alone don't prove authenticity. They're a **correlation hint**, not validation. Validation happens through harmonic signatures.

### Asynchronous Reality

Temporal proximity mapping **acknowledges real-world async constraints**:

1. **Queue populations**: Multiple commands in flight simultaneously
2. **System load**: Variable processing time per zenka
3. **Dependency chains**: Command 3 might wait for Command 1 completion
4. **Bandwidth variations**: Some zenka respond fast, others slowly
5. **Complex routing**: Multi-hop responses take longer

**Solution**:
- **Allow ordering ambiguity**: When multiple commands are close in time, multiple could match
- **Use window-based correlation**: Accept matches within reasonable time window
- **Validate by content**: Harmonic signature proves the output is correct, not just close in time
- **Track via harmonic topology**: Commands at different security levels take different paths, affecting response times

## Use Cases

### 1. Debugging Without Exposing Internals

**Traditional approach**:
```
ERROR: Unknown route ID 42
Session ID: xyz123
Route trace: cube→weather→cache→api
```
Exposes internal routing, session IDs, all sensitive information.

**Temporal proximity approach**:
```
ERROR at 1234567890.500:
- Closest command: "weather.desc" sent at 1234567890.123 (377ms ago)
- Expected response time: 100-500ms for this zenka
- Status: Likely delayed, not corrupted
- Suggestion: Check weather zenka load
```
No internal IDs exposed, but all debugging information available.

### 2. Forensic Analysis

Correlate user actions to system events without routing metadata:

```
Timeline (reconstructed from timestamps alone):
  1234567890.100: User types "list users"
  1234567890.200: User types "list sessions"
  1234567890.350: First output appears (list users response)
  1234567890.400: User types "show-buffer terminal-history"
  1234567890.450: Second output appears (list sessions response)
  1234567890.550: Third output appears (show-buffer response)

Analysis:
- list users took 150ms (fast)
- list sessions took 250ms (moderate load)
- show-buffer took 150ms (reasonable)
- Pattern suggests no bottleneck, consistent performance
```

### 3. Workload Pool Analysis

Identify batching patterns and dependency chains:

```
Temporal clusters:
  Cluster 1 (time: 1234567890.0-1234567890.5):
    - auth.login
    - weather.init
    - calc.ready
    Total: 3 commands, 500ms window

  Cluster 2 (time: 1234567891.0-1234567891.8):
    - list.users (depends on auth)
    - show.config
    - check.status
    Total: 3 commands, 800ms window

Pattern: Auth commands batch separately from operational commands
Implies: Authentication has cold-start overhead
```

### 4. Colorized Flow Diagrams

Visualize command/response flow with temporal and topological information:

```
Time →

User    Cube    Weather   Calc    System
 │      │         │        │       │
 ├─list─→         │        │       │
 │      ├────────→│        │       │  (200ms)
 │      │         ├─────→  │       │
 │      │         │        ├──────→│  (dependency: uses system time)
 │      │←────────┤        │       │  (response arrives)
 │      │         │        │←──────┤  (response arrives)
 │      │←────────┴────────┤       │  (aggregated response)
 │←output
 │

Color coding:
- Green: On-time response (within expected window)
- Yellow: Delayed (multiple standard deviations)
- Red: Very delayed (possible queue blocking)
- Purple: Dependency chain (one command waits for another)
```

### 5. Security Context Evaluation

Detect anomalies through temporal patterns:

```
Normal pattern (learned from baseline):
- "list users" commands typically arrive 5-10 minutes apart
- Always from authenticated session
- Average response time: 50-100ms
- Always from same zenka

Anomaly detected:
- "list users" command every 2 seconds
- Different session ID pattern
- Response time: 500ms (5x slower than normal)
- Being forwarded through unexpected zenka chain

Evaluation:
- Probability of attack: HIGH
- Type: Likely reconnaissance/information gathering
- Recommend: Audit session, check auth logs, inspect cache patterns
```

### 6. Compliance and Audit Trails

Create provenance records without exposing routing:

```
Audit Entry (simplified):
  Command timestamp: 1234567890.123
  Command text: "show-buffer users"
  Initiating user: taeki
  Response timestamp: 1234567890.200
  Response quality: 77ms (healthy)
  Harmonic validation: PASS (all ELF modes)

Audit Entry (forensic follow-up):
  Timestamp: 1234567890.200
  What happened: Output displayed to terminal
  Routing used: [REDACTED - not in audit trail]
  Validation results: Harmonic signature confirmed authenticity
  Data integrity: Verified by division-13 checksum
```

No routing metadata in audit record, but proof of:
- Authenticity (harmonic validation)
- Integrity (checksum)
- Timeliness (response window)
- Authorization (user can issue this command)

## Integration with Capability Negotiation Protocol

**Temporal mapping is enabled through the session capability interface**:

```
Command: "enable-tracking buffer_size=10485760"
       ↓
auth.zenka.cmd.set-session-attribute (wrapper)
       ↓
base.handler.auth.set_session_capability (dispatcher)
       ↓
Registry lookup: 'enable-tracking'
       ↓
base.handler.auth.callback.enable_tracking (delegates to callback)
       ↓
Callback initializes:
  - Session tracking state
  - Cube temporal map with buffer size
  - Auto-expiry rules based on buffer
```

**Capability definition**:
```perl
'enable-tracking' => {
    type => 'complex',
    description => 'Enable temporal proximity mapping with buffer size',
    handler => 'base.handler.auth.callback.enable_tracking',
    lock_after_auth => FALSE,      # Can be toggled at runtime
    requires_auth => FALSE,        # Can be pre-auth
}
```

**Alias support**:
```perl
$data{'alias'}{'enable-tracking'} = 'auth.zenka.cmd.set-session-attribute';
# Can also define custom names:
$data{'alias'}{'start-forensics'} = 'auth.zenka.cmd.set-session-attribute';
```

## Current Implementation Status

### Working ✓
- `nshell.shell_loop` - Protocol-agnostic command accumulation
- `nshell.hook.unknown_reply_route` - Output capture from unmapped replies
- Terminal-history buffer - Commands and responses logged with timestamps
- Debug logging - Detailed tracking of editor state and key processing
- Capability negotiation protocol - Framework for session features

### In Progress 🔄
- `nshell.handler.command_reply` - Terminal-history logging integration
- Ctrl+O cycling infrastructure - Needs temporal context for proper correlation
- `base.handler.auth.callback.enable_tracking` - Initialize temporal mapping in callback

### Planned 📋
- Cube temporal mapping - Track command timestamps and byte ranges
- Reply correlation algorithm - Match replies by temporal proximity + byte ranges
- Adaptive offset encoding - Start offset + range size + negative offsets
- Rolling buffer lifecycle - Auto-expiry when data rolls out
- nshell-cube sync - Share temporal maps for enriched debugging
- Anomaly detection - Identify unusual temporal patterns
- Flow visualization - Render temporal/topological flow diagrams
- Forensic tools - Reconstruct events from timestamp logs

## Security Implications

### Privacy Preservation
- Temporal proximity mapping reveals **what** (command type) and **when** (timing)
- Hides **how** (routing details, session IDs, internal architecture)
- Perfect for multi-tenant systems where one tenant shouldn't see another's routes

### Multi-Layer Defense
1. **Layer 1** (Output capture): Raw stream, no validation
2. **Layer 2** (Temporal mapping): Correlate to commands, detect anomalies
3. **Layer 3** (Harmonic validation): Verify authenticity and integrity
4. **Layer 4** (Topological isolation): False output can't propagate topologically

Even if temporal mapping is wrong or attacked:
- Harmonic validation catches corrupted output
- Topological layer prevents propagation
- No single point of failure

### Async-Aware Security
- Accepts that replies arrive out of order
- Doesn't create false certainty
- Uses temporal distance as **hint**, not proof
- Requires secondary validation (harmonic signatures)
- This is **correct security design** for async systems

## Integration with Harmonic Topology

Temporal proximity byte-range mapping integrates with harmonic topology security model:

**Byte-range allocation respects topological distances**:
- Commands at different security levels → different byte range sizes (reflect validation overhead)
- Multi-hop routes → larger expected response windows (longer paths take longer)
- Adjacent security levels → adjacent byte range allocations (topological coherence)

**Example correlation flow**:
```
User sends: "weather.desc" (routed to weather zenka, security level 8)
  ↓
Cube allocates bytes [10000-10300] (expects ~300 byte response)
  ↓
Records: 1234567890.456 => { offset: 10000, size: 300, level: 8, zenka: 'weather' }
  ↓
Command gets routed through topology (path determined by harmonic alignment)
  ↓
Reply arrives at 1234567890.650 (194ms later)
  ↓
Cube's temporal map:
  - Find closest timestamp: 1234567890.456 (194ms away)
  - Expected window for level 8: 100-500ms ✓ (within range)
  - Get byte range: [10000-10300]
  ↓
Extract bytes 10000-10300 from buffer
  ↓
Harmonic validation: Check signature ✓ (authentic)
Topological validation: Response from expected zenka ✓ (coherent)
  ↓
Output ready for display with full context
```

**Multi-layer validation**:
1. **Byte-range correlation** — Gets right data
2. **Temporal proximity** — Confirms timing expectations
3. **Harmonic signature** — Verifies authenticity
4. **Topological origin** — Confirms message source
5. **Security level alignment** — Validates coherence

## Implementation: Collection Points and Data Sources

**Data sources are already available**, collection happens at two points:

### Point 1: Route Creation (base.route.add)

Data available when command is sent:
```perl
# From base.route.add (already implemented):
'start_time' => <[base.time]>->(5),      # Timestamp when route created
'user'       => <base.session.uname.server>,
'size'       => {
    'buffer' => {
        'input'  => $data{'size'}->{'buffer'}->{'input'},
        'output' => $data{'size'}->{'buffer'}->{'output'}  # Current offset
    }
},
```

Capture at route creation:
- `start_time` — Command departure time
- `start_offset` — Buffer position where output will go (current output buffer position)
- `session_id` — For internal tracking
- `username` — From authenticated session

### Point 2: Reply Routing (when route is purged as completed)

Data available when reply arrives:
- `reply_time` — High-resolution timestamp when reply packet was processed
- `current_offset` — Current buffer position (how far output buffer advanced)
- `reply_packet_size` — Actual size of reply payload
- `zenka_name` — Resolved target zenka

**Implementation approach**:
1. At route creation: store `start_time`, `start_offset`, session context
2. At reply routing: add `reply_time`, `current_offset`, `reply_packet_size`
3. Compute: `reply_packet_size = current_offset - start_offset` (verification)
4. Store in temporal_map with reply_time as key
5. Internal logging only (log level 2-3)

**No new data collection needed** — Everything is already available at these two collection points. Just organize into temporal_map structure at reply routing time when route is being purged.

## Conclusion

nshell's protocol-agnostic design is **not a limitation**—it's an architectural strength enabling:
- Privacy-preserving debugging
- Universal observability
- Multi-layer security
- Async-aware correlation
- Forensic analysis without exposing internals

By adding temporal proximity mapping, nshell becomes a **secure, observable, debuggable** client that works correctly in real distributed systems with:
- Queue variations
- Variable load
- Dependency chains
- Multi-hop routing
- Asynchronous responses

And provides complete auditability without exposing sensitive routing or session metadata.

---

*"The best security is architecture that makes attacks impossible, not rules that make them unlikely."*
