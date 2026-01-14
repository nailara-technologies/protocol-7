# nshell-amos-term Buffer Interface Contract

## Overview

This document defines the interface contract between nshell zenka and amos-term buffer zenka. It specifies:
- Buffer data structure and layer semantics
- Read/write operations for keyboard input and shell output
- Byzantine consensus validation across 7 buffer nodes
- Frontend lifecycle and attachment mechanisms

---

## Buffer Architecture

### 3D Consensus Memory Structure

The amos-term buffer manages a **3D array** with spatial and layered composition:

```
[24 rows × 80 cols × N layers]
```

Each cell `(row, col)` contains multiple layers, composited during rendering:

- **Layer 0**: Content - ASCII/UTF-8 glyphs, ANSI escape sequences
  - Source: keyboard input, shell output, tool data
  - Unvalidated initially, confined by masks and templates

- **Layer 1**: Color - Byzantine-consensus-derived colors
  - NOT derived from Layer 0 ANSI codes
  - Rendered via 5-of-7 consensus across 7 buffer nodes
  - Translucency = visual proof of agreement

- **Layer 2**: Mask - Binary validity/transparency per cell
  - `1` = cell visible, content passes to rendered output
  - `0` = cell masked/transparent, content ignored
  - Architectural enforcement (not optional)

- **Layer 3**: Filter - Transformations and animations
  - Opacity modulation, sprite movement, collision detection
  - Game-engine capabilities native to buffer layer

- **Layer 4**: Template - Structural layout rules
  - Fixed 24×80 grid structure
  - Page templates, region boundaries
  - Architectural law (cannot be violated)

- **Layer 5**: Redirection - Virtual addressing
  - Maps display coordinates to distributed storage
  - Enables screen attach/detach without copying

- **Layer 6+**: Semantics - Type information and computation
  - `semantic.type`: 'shell_output', 'error', 'prompt', etc.
  - Metadata for post-hoc styling, filtering, searching

### Address Space

Each buffer cell is addressed as:

```
[row:0-23][col:0-79][layer:0-N]
```

Or as a serialized epoch-based key:

```
<EPOCH>/<AMOS_CHECKSUM>/<BMW_CHECKSUM>/<LAYER>/<ROW>/<COL>
```

Where:
- `EPOCH`: Network time epoch (sliding window, ~1 week per unit)
- `AMOS_CHECKSUM`: 7-char BASE32 content identifier
- `BMW_CHECKSUM`: Alternate checksum for deduplication
- `LAYER`: Layer number (0-N)
- `ROW`, `COL`: Position in grid

---

## Frontend-Buffer Attachment Model

### Lifecycle

1. **Frontend (nshell) starts** → connects to cube

2. **Frontend announces ready** → sends capabilities
   ```
   command: nshell.register-buffer
   args: {
     name: "nshell-001",
     type: "interactive_shell",
     capabilities: [
       "read_layer_0_input",
       "write_layer_0_output",
       "semantic_tagging"
     ],
     zenka_name: "nshell"
   }
   ```

3. **amos-term attaches buffer** → creates Layer 0 input/output channels
   ```
   amos-term.cmd.attach-frontend: nshell
   → returns buffer_id, session_key, consensus_nodes[1..7]
   ```

4. **Frontend enters event loop** → reads from buffer, writes results

5. **Byzantine consensus nodes** → validate all writes to Layer 0

6. **Frontend detaches** → on exit, amos-term persists session
   ```
   amos-term.cmd.detach-frontend: nshell
   → saves buffer state to disk, flushes consensus
   ```

### Multiple Frontends on Same Buffer

Multiple shells can attach to the same amos-term buffer instance:

```
amos-term buffer instance
├─ nshell (master, reads keyboard, renders primary output)
├─ bash child (attached, inherits buffer context)
├─ zsh child (attached, parallel execution)
└─ [future shells...]
```

Each frontend:
- Has its own `buffer_id` and `session_key`
- Can read Layer 0 input from shared keyboard
- Can write Layer 0 output (all writes go through consensus)
- Sees all other frontends' output in real-time

Consensus validates that all 7 buffer nodes agree on final Layer 0 state.

---

## I/O Operations

### Reading from Buffer (Layer 0 Input)

#### Operation: `read_from_buffer(buffer_id, timeout_ms)`

```perl
my $input_line = <[nshell.read_from_buffer]>;
```

Behavior:
- **Blocking read** from keyboard input queue for this buffer
- **Returns**: UTF-8 line when user presses Enter (or timeout)
- **Returns**: undef on timeout or EOF
- **Layer location**: Layer 0, rows [24] (virtual keyboard input layer)

Interface:
```perl
<[amos-term.buffer.read-keyboard]>->(
    $buffer_id,           # "nshell-001"
    $timeout_ms,          # 5000 for 5 second timeout
    $semantic_context     # optional: 'prompt', 'input', etc.
);
# Returns: { line => $text, timestamp => $epoch, context => $info }
```

Validation:
- Read operations are **non-consensus** (they don't modify state)
- Keyboard input is sourced from OS (xterm, physical input device)
- Input is validated for UTF-8 correctness before queuing

### Writing to Buffer (Layer 0 Output)

#### Operation: `write_to_buffer(buffer_id, content, layer, metadata)`

```perl
<[nshell.write_to_buffer]>->($output_text);
```

Behavior:
- **Writes** UTF-8 content to buffer Layer 0
- **Triggered validation**: All 7 Byzantine nodes validate independently
- **Returns**: TRUE if 5+ nodes agree, FALSE if consensus fails
- **Blocks until**: Majority consensus is reached (configurable timeout)

Interface:
```perl
<[amos-term.buffer.write-content]>->(
    $buffer_id,           # "nshell-001"
    $content,             # UTF-8 text to write
    {
        layer => 0,       # Always Layer 0 for shell output
        row => undef,     # Auto-position at cursor
        col => undef,     # Auto-position at cursor
        semantic_type => 'shell_output',  # for Layer 6
        origin_zenka => 'nshell',         # for auditing
        timestamp => time(),              # for sequencing
    }
);
# Returns: {
#   accepted => TRUE/FALSE,
#   consensus_nodes => { 1 => TRUE, 2 => TRUE, ... 7 => TRUE },
#   translucency => 0.75,    # visual proof (pixels matching / total)
#   amos_checksum => "ABCDEFG"
# }
```

### Cursor Management

```perl
<[amos-term.buffer.set-cursor]>->($buffer_id, {
    row => 5,
    col => 20,
    style => 'block',   # 'block', 'underline', 'bar'
    blink => TRUE,
});
```

---

## Byzantine Consensus Protocol

### Write Validation Flow

```
Frontend writes to Layer 0 at (row, col)
    ↓
amos-term routes to 7 consensus buffer nodes
    ↓
Each node independently:
  - Applies Layer 2 mask check (is this cell writable?)
  - Applies Layer 4 template check (violates structure?)
  - Applies Layer 6 semantic validation (type-safe?)
  - Computes Layer 1 color from context
    ↓
Nodes vote: accept/reject
    ↓
Majority wins (5 of 7):
  - Layer 0: accepted (content written)
  - Layer 1: consensus color computed
  - Layer 2: mask status determined
  - All nodes update independently
    ↓
Translucency metric: pixels_matching / total_pixels
  - Perfect overlay (100%) = cryptographic proof of agreement
  - Near-perfect (>98%) = acceptable consensus
  - Below 95% = collision/attack detected, log and retry
    ↓
Return {accepted, translucency, checksum} to frontend
```

### Consensus Nodes Configuration

```perl
# In nshell/start or dynamically discovered:
<amos-term.consensus.nodes> = [
    'buffer-node-1:7001',
    'buffer-node-2:7002',
    'buffer-node-3:7003',
    'buffer-node-4:7004',
    'buffer-node-5:7005',
    'buffer-node-6:7006',
    'buffer-node-7:7007',
];

# Quorum requirement:
<amos-term.consensus.quorum> = 5;  # 5 of 7
```

### Translucency Validation

The consensus result is validated by **visual overlay** (not signature files):

```
Consensus nodes render independently →
Compare pixel-by-pixel →
Percentage match = proof of agreement

Match > 98% = Byzantine agreement proven visually
  (cryptographically equivalent to signature verification)
  (requires malicious tampering across 5+ nodes to fake)
```

---

## Buffer Session Persistence

### Saving Session State

When frontend detaches or amos-term shuts down:

```perl
<[amos-term.buffer.save-session]>->({
    buffer_id => "nshell-001",
    frontend_zenka => "nshell",
    persist_to => {
        disk => "/data/files/<EPOCH>/<AMOS>/<BMW>/",
        format => "layer_based",  # not linear ANSI
    },
    include_history => TRUE,
    history_size => 10000,
});
```

Session is stored as:
```
/data/files/2026-01-14/ABC3DEF/123BMW01/
├── layer_0/
│   ├── row_00/
│   │   ├── col_00-19
│   │   └── col_20-39
│   └── row_01/
├── layer_1/
│   ├── color_map
│   └── translucency_proof
├── layer_2/
│   └── mask_bitmap
├── metadata.json  # session info, timestamps
└── history/       # replay log
```

### Re-attaching to Saved Session

```perl
<[amos-term.buffer.restore-session]>->(
    buffer_id => "nshell-001",
    from_disk => "/data/files/2026-01-14/ABC3DEF/123BMW01/"
);
# Returns: buffer with full state, history playable
```

---

## Error Handling and Recovery

### Consensus Failure

If < 5 nodes agree:

```
1. Log event with timestamp, content, nodes votes
2. Mark buffer as "degraded" (translucency < 95%)
3. Frontend gets {accepted => FALSE}
4. Frontend can:
   - Retry (automatic backoff)
   - Escalate to operator
   - Continue non-validated (fallback to single-node)
```

### Node Failure Detection

If a consensus node goes offline:

```
1. Remaining 6 nodes can still achieve quorum (5 of 6)
2. Performance degrades but service continues
3. When node comes back online:
   - Catches up on missed writes
   - Re-validates via Byzantine voting
   - Rejoins consensus
```

### Frontend Crash

If nshell zenka crashes:

```
1. amos-term detects broken socket
2. Saves buffer state to disk
3. Removes frontend from active list
4. When nshell restarts:
   - Connects with same buffer_id
   - amos-term recognizes re-attachment
   - Restores cursor position, history
   - Continues as if never interrupted
```

---

## Implementation Phases

### Phase 1: Basic Read/Write (Current)
- nshell reads keyboard input → returns one line
- nshell writes shell output → validates 1 write at a time
- Single amos-term node (no consensus yet)
- Layer 0 only (no Layer 1-6)

### Phase 2: Byzantine Consensus
- Full 7-node consensus
- Layer 1 color validation via majority vote
- Translucency proof calculation
- Consensus metrics/monitoring

### Phase 3: Multi-Frontend
- Attach bash, zsh as child frontends
- Coordinate multiple readers/writers on same buffer
- Session sharing and handoff

### Phase 4: Full Layers
- Layer 2 masks and Layer 4 templates
- Layer 6 semantic tagging
- Advanced transformations

---

## Testing Strategy

1. **Unit tests**: nshell reads keyboard, writes output
2. **Integration tests**: nshell ↔ amos-term buffer
3. **Consensus tests**: 7-node voting, majority rules
4. **Resilience tests**: Node failures, message loss
5. **Performance tests**: Throughput, consensus latency

---

## Examples

### Example 1: Simple Shell Command

```
User types: "ls -la"
           ↓
nshell.read_from_buffer → "ls -la\n"
           ↓
nshell executes: system("ls -la")
           ↓
nshell.write_to_buffer → "total 234\ndrwxr-xr-x ..."
           ↓
amos-term validates write
           ↓
Layer 0 now contains directory listing
Layer 1 contains consensus colors
           ↓
Terminal renders (Layer 0 × Layer 2) + Layer 4 + Layer 1
```

### Example 2: Error Reporting with Semantics

```
nshell.write_to_buffer(
    "Error: file not found",
    { semantic_type => 'error' }
)
           ↓
amos-term Layer 6 tags as 'error'
           ↓
Byzantine consensus Layer 1 renders as red
           ↓
Display shows error in red (via consensus color, not ANSI)
           ↓
Even if ANSI says green, consensus color is red
(ANSI confined by mask, consensus color is law)
```

### Example 3: Multi-Shell Attach

```
amos-term buffer "shared-001" running with nshell attached
           ↓
User runs: bash -o vi
           ↓
bash zenka created, sends: nshell.attach-buffer "shared-001"
           ↓
amos-term attaches bash to same Layer 0
           ↓
nshell and bash both write to same buffer
           ↓
All writes go through consensus
           ↓
User sees output from both shells
           ↓
On exit, bash detaches, nshell continues
```

