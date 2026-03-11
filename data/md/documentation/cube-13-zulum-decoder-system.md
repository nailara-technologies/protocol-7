# Cube-13 / Zulum / Decoder System: LLM Handover

## What This System Is

A 13-stream harmonic entropy generator feeding a switch matrix that routes to a base32 accumulator.

**Zulum** generates 42-bit entropy from division-by-13 harmonic sequences. Seeds are `076923 × N` for streams 1-13. Each stream tracks `is_true` (harmonic truth state of current value).

**Cube-13** is the switch matrix. It maintains state for 13 streams and implements jump navigation (`jump true`, `jump reverse`, `jump next`). Only the *active stream* forwards entropy to the decoder.

**Decoder** receives entropy via `receive-entropy`, extracts 5-bit chunks (base32), and accumulates in buffer `level-5-B32`.

## Current State

| Phase | Status | Description |
|-------|--------|-------------|
| Phase 1 | ✅ Replaced | Direct zulum → decoder wiring (replaced by Phase 2) |
| Phase 2 | ✅ Complete | Full cube-13 switch matrix with jump routing |
| Phase 3 | 📋 Planned | Decoder boundary handling, stream change notifications |
| Phase 4 | 📋 Planned | Operator commands (pause, resume, reset) |

Verified working:
- `zulum.step N` generates entropy
- `cube-13.receive-entropy` routes to active stream
- `cube-13.jump true` switches active stream
- `decoder.show-accumulator` displays accumulated values

## Command Reference

### Zulum

| Command | Parameters | Returns | Description |
|---------|------------|---------|-------------|
| `step` | `[stream_id]` (1-13, default: 1) | stream info | Generate one entropy cycle |
| `stream-attach` | `stream_id`, `consumer` | attach confirmation | Attach callback (auto-called at init) |
| `stream-status` | `[stream_id]` | stream state | Check stream attachment |

### Cube-13

| Command | Parameters | Returns | Description |
|---------|------------|---------|-------------|
| `jump` | `<direction>` (true/reverse/next) | jump result | Switch active stream |
| `stream-status` | `[stream_id]` | matrix state | Show all streams or specific stream |
| `receive-entropy` | `<stream_id> <entropy_bits> <is_true>` | forward status | Ingest from zulum, route if active |

**Jump behavior:**
- `jump true` → Jump to stream 5 (TRUE position, gen×5 = 384615)
- `jump reverse` → Digit reversal of cycle position (e.g., 076923 → 329670)
- `jump next` → Next stream (13→1, wrap)

### Decoder

| Command | Parameters | Returns | Description |
|---------|------------|---------|-------------|
| `show-accumulator` | `[level]` (default: 5) | accumulator state | Display level-5 buffer contents |
| `show-buffer` | `<name>` (e.g., `level-5-B32`) | buffer content | Show rolling buffer |
| `receive-entropy` | `<stream_id> <entropy_bits>` | accept status | Internal handler (cube-13 calls this) |

## Cross-Zenka Wiring Rules

**Critical constraint:** Never call `<[other.zenka.module]>->()` directly across process boundaries. Each zenka has isolated `%data` and `%code` hashes.

Use cube routing:
```perl
# CORRECT: Route through cube
<[protocol-7.route-send]>->(
    {   'command'   => 'target_zenka.command_name',
        'call_args' => { 'args' => "space separated args" },
    }
);

# WRONG: Direct call fails silently or crashes
<[other.zenka.module]>->(...);
```

See `data/md/coding-tasks/zulum-decoder-routing-reference.md` for full routing patterns and permission setup.

## Verification Commands

Test the full chain:
```bash
# 1. Check cube-13 matrix
cube-13.stream-status

# 2. Generate entropy on stream 1
zulum.step 1

# 3. Verify decoder received values
decoder.show-accumulator

# 4. Switch to stream with truth
cube-13.jump true

# 5. Generate on new active stream (now stream 5)
zulum.step 5  # or zulum.step <active_stream>

# 6. Verify accumulation continued
decoder.show-accumulator
```

## What Comes Next

**Phase 3: Decoder Integration**
- Handle boundary markers on stream switch
- Close/persist level buffers on boundary
- Notify decoder of stream changes

**Phase 4: Operator Commands**
- Pause/resume stream processing
- Reset accumulator
- Query stream statistics

---

*Related: `zulum-decoder-routing-reference.md`*

#,,.,,..,,..,,.,,,.,.,..,,,.,,.,,,,.,,,..,.,.,..,,...,...,,,.,.,,,..,,,,,,...,
#3NTPGHYFWRUFP2LT6C66HDTOHXVIWPZ6OUUUTYEMOECUILDJPZ5INEZGXPL4UBTS4DOW2Z6TKPFXE
#\\\|M7GEQQTATGT7S6UIL5I55UE67QO2CFPSMSF4AV5D7R7YQ7TU55K \ / AMOS7 \ YOURUM ::
#\[7]7YSZRDQHKTXV7RKK7ZE6ADWSAVNQEMVJ3LSFLOBMKKQXQZV6RGAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
