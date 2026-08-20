---
name: session-62
description: "httpd web-relay STRM refactor: SIZE→STRM, bytes::length fix, strm_open bugs FIXED (session 63)"
metadata:
  node_type: memory
  type: project
  originSessionId: 96c4f196-e9b8-4e2c-a467-d9c9d0824389
---

## what was done

fix `httpd.route.handler.web-relay` crashing httpd when jobs UI opens.
two separate root causes found:

### root cause 1: SIZE reply buffer overflow (confirmed)
`base.handler.command` receives SIZE reply from web zenka. if payload exceeds
httpd's configured input buffer size, bytewise reader pauses, SIZE never
completes, 23s input_handler timeout fires → `shutdown=TRUE` → session torn down.

fix: switch web zenka handlers from `mode=>'size'` to `mode=>'strm'` so data
arrives in chunks, avoiding the buffer size constraint.

### root cause 2: bytes::length before utf8::encode in base.handler.command
STRM mode in `base.handler.command` called `bytes::length($data)` BEFORE
`utf8::encode($chunk_data)`. for Perl strings with utf8 flag, utf8::encode
expands multi-byte chars → actual bytes > announced total → truncation.

fix applied (commit 1d16dac24, 2026-05-07): `utf8::encode($chunk_data) if
utf8::is_utf8($chunk_data)` then `bytes::length($chunk_data)` (post-encode).
JSON::XS data has no utf8 flag so for JSON responses this is a no-op.

## files modified

- `src/httpd.route.handler.web-relay` — `->timeout(undef)` added on
  input_handler (keeps watcher for EOF detection, disables 23s timeout)
- `src/httpd.handler.web-relay.strm_open` — NEW FILE (kimi), fixed in
  session 63 (see below)
- `src/plugin.web.jobs.sync` — changed `mode=>'size'` to `mode=>'strm'`
- `src/plugin.web.jobs.data` — changed `mode=>'size'` to `mode=>'strm'`
- `src/base.handler.command` — bytes::length fix (commit 1d16dac24)

## strm_open bugs — all FIXED in session 63

### bug 1 (session-62 analysis was WRONG — corrected in session 63)
session-62 claimed flush_shutdown was architecturally wrong for server-initiated
close. THIS WAS INCORRECT. `flush_shutdown` IS the correct mechanism.

`base.handler.write` line 153:
```perl
$session->{'shutdown'} = 1 if !$write_size and $session->{'flush_shutdown'};
```
this is checked inside base.handler.write AFTER each write, when buffer empties.
it has worked correctly for over a decade. on_eof setting `flush_shutdown=TRUE`
is correct and was NOT changed.

edge case added: if output buffer is already empty when on_eof fires (no
subsequent write to trigger line 153), set `shutdown=TRUE` directly:
```perl
$data{'session'}{$http_sid}{'shutdown'} = TRUE
    if not bytes::length(
    $data{'session'}{$http_sid}{'buffer'}{'output'} // '' );
```

### bug 2 (log "parameter 4 not defined")
session-62 analysis was wrong: thought it was `bytes::length(buffer)` returning
undef. actual cause: `$lc->{'content_type'}` is undef because
`base.strm.local.register` does NOT store custom opts keys — only stores:
`buf`, `bytes`, `started`, `watcher`, `on_eof`, `max_buf`.

fix: replace all `$lc->{'content_type'}` with closure variable `$content_type`
in both the watcher (Content-Type header) and on_eof (log format).

### bug 3 (log uses buffer length instead of transferred bytes)
on_eof log called `bytes::length($data{'session'}{$http_sid}{'buffer'}{'output'})`
— output buffer may be partially drained, giving wrong byte count.
fix: use `$lc->{'bytes'} // 0` (total bytes received from STRM producer).

## key architectural facts

- `->timeout(undef)` on Event->io watcher: removes timeout (keeps IO watcher
  active for EOF detection). used in httpd.route.handler.web-relay.
- `flush_shutdown`: checked in `base.handler.write` line 153 on every write
  when buffer becomes empty. correct for server-initiated close after drain.
- `base.strm.local.register` only stores: buf, bytes, started, watcher, on_eof,
  max_buf. custom opts keys are silently dropped. use closure vars instead.
- `base.session.cancel_route`: sends !TERM! to active STRM producers on cancel

## state after session 63 — CONFIRMED WORKING

jobs appear in browser after fix. confirmed working (session 63).

## remaining cosmetic issue

cube logs "STRM-reply to unknown route id [X], ignored." after each STRM stream.
cause: web zenka's `base.handler.command` sends standard TRUE command-completion
reply after `base.stream.close`. route already deleted (httpd removes it on STRM
close at receive-side lines 1075-1090). cube correctly ignores it, but it is noisy.

fix: in `base.handler.command` STRM send path, skip the fall-through TRUE reply
after `base.stream.close` (add explicit return or skip-flag for STRM mode).

#,,,,,,.,,,.,,..,,...,.,.,..,,,..,..,,.,,,,.,,..,,...,..,,...,,,,,,..,...,,..,
#XG7DMFGHGPNLJZX3ZHJRYSGF4ZH3ZXKYPGUM3CW2354I2K2IX4IQMANKOBLPFCQJ7E3L55JPNR572
#\\\|5RWENEUX7PEV7NEA5X36ORQMEG2YTNLXI3DQZOW5JN3M5QNKNTZ \ / AMOS7 \ YOURUM ::
#\[7]DURDFJLX3GJIE3PYYGLMBZ4QW5ND5D2TECL7WNRC6R56LGP2ACDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
