---
name: feedback-verify-instance-callbacks-initialized-deadlock
description: "v7's verify-instance handshake is driven entirely by console-log-scraping two specific lines ('cube session id received', 'instance verification [KEY:...]'); silenced console verbosity or a deferred get_session_id call both stall it identically, and system.callbacks.initialized only ever drains once it succeeds"
metadata:
  type: feedback
---

v7 learns a freshly-spawned instance exists, and later confirms it, **purely by
pattern-matching the instance's raw console stdout** — not via any reply, not via
`base.session.send_init_reports`. Two config-driven regexes in
`configuration/zenki/v7/zenka-output.patterns` (matched by `v7.handler.zenka_output`
→ `v7.handler.process_output_line`) drive the whole handshake:

```
^cube session id received \[(\d+)\]$   → zenka.set_cube_sid:<instance_id>,<match_1>
^instance verification \[KEY:([a-zA-Z\d]+)\]$ → v7.handler.instance_verification:<instance_id>,<match_1>
```

The real chain, confirmed end-to-end 2026-08-10:

```
get_session_id (sync) / base.handler.whoami_reply (async)
  → logs "cube session id received [...]" to CONSOLE
  → v7's stdout pattern-matcher sees it → calls zenka.set_cube_sid
  → set_cube_sid sends the "verify-instance" command
  → base.cmd.verify-instance logs "instance verification [KEY:...]" to CONSOLE
  → v7's stdout pattern-matcher sees it → calls v7.handler.instance_verification
  → sets instance status 'online' directly
  → base.cmd.verify-instance ALSO drains <system.callbacks.initialized> itself
    [ the array most zenki push their real deferred startup work onto ]
```

**`base.session.send_init_reports` is NOT part of this chain** — despite being
gated by the same `<system.zenka.initialized>` flag that `get_session_id` also
sets, it drains a *different*, unrelated queue (e.g. `base.log.send-buffer.
send-idle-callback`'s "waiting for log target p7-log..." entries). An earlier
version of this memory wrongly credited it as how v7 learns about a new instance —
it doesn't; the console-log pattern match above is the entire mechanism. Don't
reintroduce that wrong causal link.

## trap 1: deferring get_session_id past a system.callbacks.initialized push

Never defer `[base.get_session_id]` (or `base.async.get_session_id`) past whatever
a zenka pushes onto `<system.callbacks.initialized>` in its own `*_init`/start
sequence — e.g. `coding.init_code`, `index.init_code`, `tile.init_code`,
`ticker.init_code`, `web-browser.init_code`, `mpv.startup.init`, and others.

If any callback pushed onto `<system.callbacks.initialized>` is itself a
precondition for `get_session_id` running (e.g. "call it once the socket this
callback opens is ready"), the chain above is circular and nothing ever moves —
v7 never sees the "cube session id received" console line, never sends
verify-instance, `<system.callbacks.initialized>` never drains, the instance sits
in v7's `starting` status forever, and v7's own start/verify timeout fires and
restarts the instance — forever, since the same deadlock recurs every restart.

**How to apply:** keep `get_session_id` before any step whose completion the
zenka's own deferred (`system.callbacks.initialized`) work depends on — normally
that means early/unconditional, exactly where it already is in most start files.

## trap 2: console verbosity silences the two handshake lines (fixed 2026-08-10, `base.log.forced_console`)

Both console-scraped lines above are logged via plain `base.logs` at its default
level 1. `base.log`'s gate (`return TRUE if $log_level > console and > buffer and
> logfile`) drops a line entirely — not written anywhere, not even the zenka's own
buffer for *this specific write path* if buffer/logfile are also too low — the
moment ALL THREE verbosities sit below the log level. Any zenka configured with
`system.zenka.verbosity.console = 0` (a completely reasonable, common setting for
"silence regular operation") hits this: `get_session_id` runs fine internally,
`<system.zenka.initialized>` becomes true, but the console line v7 needs never
gets written — v7 never learns the cube_sid, never calls `zenka.set_cube_sid`,
never sends verify-instance at all. Symptom is identical to trap 1 (stuck in
`starting`, restart loop) but the zenka itself did nothing wrong — confirmed live
on the `site-yaml` zenka (`system.zenka.verbosity.console = 0` in its own start
file), which stalled at exactly this point every restart.

**Fix**: new shared helper `modules/base.log.forced_console` — same calling
convention as `base.logs` ([level] fmt args...), saves
`<system.zenka.verbosity.console>`, forces it up to at least the log's own level
only if it was lower, logs, restores. Used at both console-scraped call sites:
`base.get_session_id` and `base.handler.whoami_reply` ("cube session id
received"), and `base.cmd.verify-instance` ("instance verification [KEY:...]").
Safe by construction — forcing only ever *raises* visibility for that one write,
never lowers it below what was configured.

**Gotcha hit while writing the helper**: `my $forced = not defined $x or $x <
$level;` — `or`/`and` bind looser than `=`, so this assigns `$forced` only the
`not defined $x` half; `$x < $level` evaluates standalone in void context
("Useless use of numeric lt (<) in void context" warning) and its result is
silently discarded. Use `||`/`&&` (or explicit parens) for any assignment RHS
that mixes multiple `or`/`and` clauses — the low-precedence keyword forms are for
control-flow chaining (`open(...) or die`), not for building a value.

**How to apply:** any log line another process depends on reading back
(handshake confirmations, health-check markers, anything polled externally via
raw stdout/log buffer rather than a wire reply) needs `base.log.forced_console`
treatment if verbosity silencing could plausibly hide it. Don't assume a
"default level 1" log call is actually visible — check what verbosity the call
site can realistically run under, especially for zenki that intentionally
silence console output for normal operation.

Diagnosis path: check `p7c <zenka>.show-buffer "zenka <N>"` (buffer verbosity is
usually higher than console, so this often reveals the line even when console
silenced it) for whether "cube session id received" and "instance verification
[KEY:...]" both appear. Neither appearing at all (not even in the buffer) →
trap 1 (deadlock, the code never ran). "cube session id received" in the buffer
but never in v7's actual pattern-matched behavior (status stuck on `starting`,
no `instance N : verified : success` from v7) → trap 2 (verbosity hid it from
console specifically).

[[topic-mpv-jobqueue-startup]]

#,,..,,.,,..,,..,,.,,,,.,,,..,..,,,.,,.,,,..,,..,,...,...,.,,,,,,,.,,,.,.,..,,
#UDBUKM6VWIPCACNUTHJE47IIPOEUGLZXRRWVC64QMMFINESGLLUHUFPUQSS6W7QW6EHNCBELXMZ7A
#\\\|AYDJDGWN3O64J7K6OIVG2UQFXRUR7NK24YBF6XS73RWKCA2PALJ \ / AMOS7 \ YOURUM ::
#\[7]HIOM4XZ7KPYVITZKNEWRAQLKF7WRS6EBWXAZF2JLUTZMEXN4L6AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
