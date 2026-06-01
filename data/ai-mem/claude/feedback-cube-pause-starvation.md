---
name: cube-socket pause starves all routed traffic on buffer-full
description: base.handler.read pauses input on buffer-full; on a cube-multiplexer socket this starves heartbeats and every other destination's commands — leading to v7 SIGTERM
type: feedback
originSessionId: 22e240a2-b6d9-41a1-bfe7-0b6526db01b4
---
## the bug

- `base.handler.read` pauses input watcher when session buffer hits capacity (`$size_left == 0`)
- On **cube socket** (multiplexer for all destinations) this is catastrophic — pauses heartbeats and all commands
- Failure chain [2026-04-18]: web emits ~1 MB SIZE reply to httpd via cube → cube routes as SIZE (not STRM-SIZE, httpd↔cube lacks `strm_size_support`) → httpd buffer fills → cube socket paused → v7 heartbeats queue → timeout → v7 SIGTERMs httpd
- Victim is the *receiving* zenka, not the sender

## root cause: missing STRM-SIZE capability

- STRM-SIZE auto-fragments SIZE replies > 65536 bytes when both sides declare support
- Relevant modules: `auth.callback.cap-neg.declare-strm-size-support`, `auth.callback.cap-neg.select-strm-mode`, `base.handler.strm_size_{absolute,idle}_timeout`, `devmod.cmd.test-strm-size`
- Zenka without STRM-SIZE support forces cube to fall back to unfragmented SIZE

## why existing drop path doesn't save us

- `base.handler.command` `ignore_bytes` drop path only fires on **unknown route / unknown reply-id / expired session**
- No size-threshold overflow drop exists

## constraint on overflow-drop fix

- Dropping SIZE partway requires consuming **exactly** remaining announced bytes before command parsing resumes
- Reuse existing `ignore_bytes` machinery — never invent new drop logic

## enforcement tiers

1. **Cube at route-time** — rejects payload exceeding own buffer. Blind spot: doesn't know target buffer sizes
2. **Target zenka at `base.handler.command`** — compare `announced` vs `buffer_max - headroom`; set `ignore_bytes = announced`; emit FAIL upstream. Minimal patch; no new primitive
3. **Route-traversal buffer probe** (future) — originator sends max-size probe; each hop reduces to `min(carried, local_buffer_max)`; target bounces back. Self-healing; eliminates sizing blind spot

## complementary options

- **STRM-with-handler** — large replies use STRM-SIZE; no full-payload buffer accumulation. Architecturally right for arbitrary-size content
- **Per-stream side-buffer** — dedicated allocation on SIZE; middle ground between rejection and STRM
- **Peer-aware pause policy** — refuse to pause on cube socket. Symptom-only; trades starvation for unbounded memory growth. Not recommended as sole fix

## recommended minimum

- **Step 1**: declare STRM-SIZE support at target zenka auth handshake — smallest effective change
- **Step 2a**: declare `buffer_max_read` at session init — senders and cube size replies accordingly
- **Step 2b**: off-band `!CANCEL! <session_id> <stream_id>` reverse-channel command — sender (cube) drops unsent tail bytes; no `ignore_bytes` tracking needed at target
- **Step 2c**: configurable per-session buffer-full policy (lowest priority)
- **Step 3**: route-traversal buffer probe (future)

## how to apply

1. New zenka: ensure STRM-SIZE declared at auth handshake — without it, any reply > ~64 KB can SIGTERM the zenka
2. Zenka SIGTERM'd with no obvious blocking call: check `$session->{'strm_size_support'}`
3. Endpoint returning > few-hundred-KB via cube: STRM-SIZE + sensible chunk size; pagination still good practice
4. Reviewing drop paths in `base.handler.read`/`command`: must set `ignore_bytes = remaining_payload_bytes` — never truncate mid-frame

## application-layer workaround

- Keep replies small: pagination, chunked APIs, compression
- Fastest path to unblocking a broken pipeline independent of protocol-layer fix

#,,.,,,..,,,,,,,.,.,.,.,.,..,,,,,,.,,,,,,,,..,..,,...,...,...,,,,,.,.,...,..,,
#5Z3SQ3XCZOHFSGTUHSPYZTQQJ2GNKLNTRLCMZ5BUJQTMP6LPGEO3DIQ4QQTS6MAT6J2FLAUBHE5HI
#\\\|QAV2FH3MQB5GDP353KFQCIUGOEBBGPRT4CQNCDZJDWEAWXSYUFQ \ / AMOS7 \ YOURUM ::
#\[7]XTZGO6QBKKB5FRB25JV4POQLP2EDPZRLZJM6UELV6WYGVZJFGGDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
