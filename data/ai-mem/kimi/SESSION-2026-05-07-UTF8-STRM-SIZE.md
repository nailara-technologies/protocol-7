# UTF-8 Buffer Handling Fix — Session 2026-05-07

## Problem
`show-buffer` and STRM-SIZE fragmentation hung on buffers containing multi-byte
UTF-8 characters (e.g., ⚠ U+26A0, 😀 U+1F600). Root cause: `substr()` and
`length()` operate on **characters** when the UTF-8 flag is set, but
Protocol-7's SIZE/STRM/STRM-SIZE protocol headers carry **raw byte counts**.

`base.perlmod.autoload('bytes')` loads the module but does **NOT** enable the
`use bytes` pragma. Therefore `length()` and `substr()` remained character-oriented.

## Fix Applied

### Principle
Use `bytes::length()` and `bytes::substr()` explicitly for all byte-count
protocol logic. Downgrade strings with `utf8::downgrade()` before `bytes::`
operations, since `bytes::substr` on UTF-8-flagged strings has undefined behavior.

### Modules Changed

| Module | Change |
|--------|--------|
| `src/base.handler.command` | Sender-side: `utf8::encode($chunk_data)` before `substr` chunking (STRM/STRM-SIZE paths). Receiver-side: downgrade + `bytes::substr` for SIZE/STRM/STRM-SIZE body extraction. Unknown-route drop handler: downgrade + `bytes::substr`. |
| `src/base.handler.input` | `length` → `bytes::length` for buffer tracking |
| `src/base.handler.read` | `length` → `bytes::length` for `size_left` |
| `src/base.handler.write` | `length` → `bytes::length` for consistency |
| `src/net.read_bytewise` | `length` → `bytes::length` |
| `src/net.read_binary` | `length` → `bytes::length` |
| `src/net.read_linewise_estimated` | `length` → `bytes::length` |
| `src/base.stream.push/close/emit` | `utf8::downgrade` output buffer before frame append |
| `src/base.buffer.add_line` | `length` → `bytes::length` for size tracking |

### CHRSIZE Exception
CHRSIZE mode is intentionally character-aware and continues to use `substr`
(character-oriented) and `length` for character counts, with `bytes::length`
used only when converting to byte counts for buffer operations.

## Test Infrastructure Created

- `src/devmod.cmd.utf8-test-buffer` — creates a buffer with UTF-8 test lines
- `src/devmod.cmd.utf8-stream-test` — returns a large SIZE reply with UTF-8 content
- Both added to `access.cmd.usr.cube` in `cfg/zenki/coding/zenka.v7`

## Verification

`show-buffer big-utf8` (8000 lines, 419331 bytes) completes successfully via
`socat` direct socket connection. All 8000 lines with mixed 3-byte and 4-byte
UTF-8 characters are received correctly.

## Resolution — p7c Blocking (Claude session, 2026-05-07)

After kimi's token limit, Claude continued the investigation and found the
actual root cause:

**Root cause**: `base.handler.write` uses an `output_buffer` var watcher
(`poll => 'w'`, `repeat => FALSE`). When `syswrite` returns 0 (EAGAIN / kernel
socket buffer full), the watcher was immediately restarted via `$event->w->start`.
The watcher fires on WRITES to the output buffer — so writes from ongoing
STRM-SIZE chunks kept triggering retries. But once the last chunk arrived and
all 330400 bytes were in the output buffer, nothing else wrote to it. The var
watcher waited forever, p7c never received the remaining ~117KB.

socat worked because it reads fast enough to keep the kernel socket buffer
drained so EAGAIN rarely occurs.

**Fix in `base.handler.write`**:
- Track `$hit_eagain` flag in write loop
- On EAGAIN from var watcher: do NOT restart var watcher; instead create/start a
  per-session IO write-ready watcher (`write_handler`, `poll => 'w'`) on the socket
- IO watcher fires when p7c drains the kernel buffer → retries write
- IO watcher stays active (restarts on EAGAIN) until buffer empties, then stops
- This matches the client's actual read rate without busy-spinning

**Secondary fix in `base.session.cancel_route`**:
When the client session disconnects mid-STRM-SIZE, timers were running 12s and
`blocked_by_stream` remained set on the coding zenka session. Fix: on route
cancel, immediately cancel timers, clear `blocked_by_stream`, and delete stream state.

**Verified**: `p7c coding.show-buffer U8-TEST | wc -l` → 8000 ✓

## Files Changed (This Session)

- `src/base.handler.write` — EAGAIN + IO write watcher fix
- `src/base.session.cancel_route` — STRM-SIZE stream cleanup on disconnect
- `src/devmod.cmd.utf8-test-buffer` — shortened descr
- `src/devmod.cmd.utf8-stream-test` — shortened descr
- All kimi UTF-8 fixes remain correct and committed

#,,,,,...,.,.,,.,,,.,,.,.,...,..,,..,,..,,,.,,..,,...,..,,...,..,,...,,,.,,..,
#GXMSRXSTB5SM7YOOQF2LO2UGLNYYPTBIEQWH4NHWTT2R2K3E66XMRKZ4O6TDGQEW5DWQOBWCB5TIE
#\\\|M4GLZO3YOHZUTK4NYDKPWBDBPASCBUK56VKADLRU5N4IYUO56Z6 \ / AMOS7 \ YOURUM ::
#\[7]OLQB2WLIARDOCJBLLANKAYDM2MAC44IM6QSD3PRNERHOTSTHSOBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
