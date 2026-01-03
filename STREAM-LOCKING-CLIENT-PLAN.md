# Stream-Locking Client Implementation Plan

## Overview
Implement `stream-locking` mode in binary clients (p7c.c, p7-r.c) to safely handle STRM protocol responses. When enabled, clients enter strict streaming mode that only accepts STRM packets until stream completion.

## Design

### Client State Machine

```
NORMAL_MODE
  └─ User sends: stream-locking true
  └─ Response: TRUE (stream-locking enabled)
  └─ Transition to: STREAM_LOCKING_ENABLED

STREAM_LOCKING_ENABLED
  └─ User sends: <command> (e.g., test-strm)
  └─ Awaiting response...

  If receives STRM open <total_bytes>:
    └─ Initialize: expected_bytes = total_bytes, received_bytes = 0
    └─ Transition to: STREAMING
    └─ Log: "Stream started, expecting N bytes"

  Else (receives SIZE, FALSE, GET, etc.):
    └─ Exit with code 1 (unexpected reply type without stream)

STREAMING (strict mode)
  └─ Only valid packets:

    1. STRM <size> + <data>:
       └─ Parse chunk_size from line
       └─ Read exactly chunk_size bytes from next line
       └─ Output to stdout (pass-through)
       └─ received_bytes += chunk_size
       └─ Log (debug level): "STRM chunk: %d/%d bytes"

    2. STRM close:
       └─ Validate: received_bytes == expected_bytes
       └─ If match: Exit with code 0 (success)
       └─ If mismatch:
           └─ Log error: "Stream incomplete: %d/%d bytes"
           └─ Exit with code 1 (incomplete)
       └─ If received_bytes > expected_bytes:
           └─ Log error: "Stream overflow: %d > %d bytes"
           └─ Exit with code 1 (too many)

    3. Anything else (SIZE, FALSE, GET, etc.):
       └─ Log error: "Unexpected packet type in STREAMING mode"
       └─ Exit with code 1 (protocol violation)
```

### Code Changes

#### p7c.c Changes

1. **Global state tracking** (around session initialization):
   ```c
   struct {
       int stream_locking_enabled;   // 1 if stream-locking true
       int streaming;                // 1 if in STRM stream
       long expected_bytes;          // From STRM open <N>
       long received_bytes;          // Cumulative from STRM chunks
   } stream_state;
   ```

2. **Command parsing** (where "stream-locking" command is sent):
   - Recognize "stream-locking" as special command
   - Set `stream_state.stream_locking_enabled = 1`
   - Continue to main loop

3. **Response parsing** (main input reading loop):
   - After sending user command, check `stream_state.stream_locking_enabled`
   - If enabled and response starts with "STRM open":
     - Parse total_bytes
     - Set `stream_state.streaming = 1`
     - Set `stream_state.expected_bytes = total_bytes`
     - Set `stream_state.received_bytes = 0`
     - Log: "Stream started"
     - Continue to streaming input loop

4. **Streaming input loop** (new section):
   - While `stream_state.streaming`:
     - Read next line (protocol header)
     - If matches "STRM <size>":
       - Parse chunk_size
       - Read exactly chunk_size bytes
       - Write to stdout
       - received_bytes += chunk_size
       - Continue loop
     - Else if matches "STRM close":
       - Validate: received_bytes == expected_bytes
       - Return appropriate exit code (0 or 1)
       - Exit function
     - Else:
       - Unexpected packet type error
       - Exit with code 1
     - Set stream_state.streaming = 0

5. **Existing response handling**:
   - Skip/ignore if `stream_state.streaming == 1`
   - Let streaming loop handle all input

#### p7-r.c Changes

Same approach as p7c.c:
- Add stream_state struct
- Add stream-locking command recognition
- Add STRM response parsing
- Add strict streaming mode with byte validation
- Same state transitions and exit codes

#### nshell Changes

**No changes needed** - nshell is protocol-agnostic and passes everything through transparently after authentication.

### Error Handling & Exit Codes

| Condition | Exit Code | Message |
|-----------|-----------|---------|
| Stream complete | 0 | (no output, just exit) |
| Incomplete stream | 1 | "STRM incomplete: N/M bytes" |
| Stream overflow | 1 | "STRM overflow: N > M bytes" |
| Unexpected packet in stream | 1 | "Unexpected packet type in STREAMING mode" |
| Unexpected reply without stream | 1 | "Expected STRM but got [TYPE]" |
| stream-locking command error | 1 | (from server response) |

### Logging (debug level)

- "Stream-locking enabled"
- "Stream-locking disabled"
- "Stream started, expecting N bytes"
- "STRM chunk: N/M bytes"
- "Stream validation: N == N bytes ✓"

## Implementation Order

1. **p7c.c**:
   - Add stream_state struct
   - Add stream-locking command recognition
   - Add STRM open parsing
   - Add STRM streaming loop
   - Add exit code handling
   - Test with `p7c stream-locking true` then `p7c test-strm`

2. **p7-r.c**:
   - Mirror p7c.c implementation
   - Test similarly

3. **Integration testing**:
   - Test both clients with STRM responses
   - Test byte count validation
   - Test error cases (incomplete, overflow, wrong packet type)

## Testing Plan

```bash
# Enable stream-locking
p7c stream-locking true
# Should output: TRUE stream-locking enabled

# Request STRM response (should pass through payload only)
p7c test-strm 50
# Should output: 50KB of raw payload data, exit 0

# Test incomplete stream (inject error)
# (manual protocol injection test)
# Should exit 1 with error

# Test overflow (more data than announced)
# (manual protocol injection test)
# Should exit 1 with error
```

## Notes

- Stream-locking is per-session (not per-connection)
- Multiple commands can be run after enabling stream-locking
- Each STRM response uses same state machine
- Non-STRM responses work normally even with locking enabled
- Locking provides strict safety for automated use cases
