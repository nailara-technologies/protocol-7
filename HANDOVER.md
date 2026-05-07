# Session Handover — 2026-05-07 (complete)

## Completed This Session

### UTF-8 buffer handling fixed across IO stack
- Root cause: `autoload('bytes')` loads module but does NOT enable `use bytes`
  pragma, so `length()` and `substr()` remained character-oriented on
  UTF-8-flagged strings while Protocol-7 headers carry raw byte counts.
- Fix: explicit `bytes::length()` and `bytes::substr()` for all byte-count
  protocol logic; downgrade strings with `utf8::downgrade()` before
  `bytes::substr` (undefined behavior on UTF-8-flagged strings).
- Files touched: `base.handler.command`, `base.handler.input/read/write`,
  `net.read_bytewise/binary/linewise_estimated`, `base.stream.push/close/emit`,
  `base.buffer.add_line`
- CHRSIZE mode kept character-oriented (uses `substr`/`length` for chars,
  `bytes::length` only when converting to byte counts).

### p7c large-stream blocking — RESOLVED
- **Root cause**: `base.handler.write` var watcher (`output_buffer`, fires on
  writes to buffer) was restarted after EAGAIN. Worked while STRM-SIZE chunks
  kept arriving, but once the last chunk was buffered no more writes triggered
  it. Remaining ~117KB stuck in output buffer, p7c never received it.
- **Fix**: on EAGAIN, create a per-session IO write-ready watcher (`write_handler`,
  `poll => 'w'`) on the socket. Fires when p7c drains the kernel buffer. Stays
  active until buffer empties. Restarts itself on further EAGAIN (tracks the
  client's read rate). Stops and hands back to var watcher when buffer is empty.
- **Verified**: `p7c coding.show-buffer U8-TEST | wc -l` → 8000 ✓
- This fix likely also resolves the radio zenka mystery where regular command
  replies disappeared until a `heart` command flushed them — same EAGAIN/var-watcher
  stall was probably occurring with binary STRM data.

### STRM-SIZE cleanup on client disconnect — FIXED
- When client disconnects mid-STRM-SIZE, `blocked_by_stream` and timers on the
  coding zenka session were left running for 12s.
- Fix in `base.session.cancel_route`: on route cancel, immediately cancel timers,
  clear `blocked_by_stream`, and delete stream state.

### Test commands and tooling
- `devmod.cmd.utf8-test-buffer`, `devmod.cmd.utf8-stream-test` — descr strings shortened
- `bin/coding-task`: `-context NAME` alias fixed
- `module-header-normalization.yaml` template simplified

## Status
All issues resolved and verified. Changes signed and staged for commit.

## Token Status
- Kimi weekly tokens exhausted 2026-05-07, resets ~2026-05-12
