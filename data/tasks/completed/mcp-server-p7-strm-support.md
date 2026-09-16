## [:< ##

# name  = task: mcp-server-p7 STRM-mode reply support
# descr = bin/mcp-server-p7 has no STRM case at all -- an STRM reply is
#         returned as its bare first line and the remaining frames are
#         left in the reused socket, corrupting the NEXT unrelated tool
#         call. add a shared drain helper with a socket-clean-or-tear-
#         down invariant, plus an idle-bounded safety valve for streams
#         that never close by design

## context

raised 2026-09-13, fully diagnosed the same session -- everything below
is verified against source and reproduced live, do NOT re-derive it.

protocol-7's cube reply protocol has these reply types: `TRUE`, `FALSE`,
`SIZE <n>`, `NACK`, and `STRM` (plus the `STRM-SIZE` / `CHRSIZE`
variants). `bin/mcp-server-p7`'s `cube_command` (line 1770) dispatches on
the first reply line and handles only `TRUE` / `FALSE` / `SIZE` / `NACK`.
there is no `STRM` case anywhere in the file -- `grep -n STRM
bin/mcp-server-p7` matches nothing.

so whenever a command opens a stream, `cube_command` falls through to
its "unknown reply type -- return raw" branch at line 1838, returns
after reading exactly one line (literally `STRM open`), and never drains
the pushed frames or the eventual close frame.

**what actually puts STRM frames on the wire is `<[base.stream.open]>`,
not a particular return mode -- don't conflate the two.** `{ mode =>
'deferred' }` only says "this command will not produce its reply now,
reply later"; it says nothing about which mode that later reply uses. a
command can open an STRM stream and return `deferred` (as
`coding.cmd.subscribe-session` does, because the stream IS the reply and
no ordinary reply should follow), and equally a command can open a
stream and start pushing immediately without ever involving `deferred`.
so the client cannot predict STRM from anything about the command it
sent -- **it must detect STRM from the reply line itself**, which is
precisely what the fix below does and why it is worth doing generically
rather than per-command.

**why this is worse than "one tool call returns a useless string":**
`cube_connect()` (line 1617) caches and reuses ONE persistent socket
across separate `cube_command` calls -- an mcp-server-p7-internal design
choice, confirm it by reading `cube_connect` yourself before changing
anything. the undrained STRM frames sit in that socket's receive buffer,
and the NEXT unrelated `cube_command` reads those leftover bytes instead
of its own reply.

reproduced live: after one `coding.subscribe-session` call through the
`p7_command` MCP tool, two subsequent unrelated calls
(`coding.get-result`, `coding.task-info`) came back as `"TRM 5"` and
`"elloSTRM 1"` -- fragments of leftover STRM frame bytes bleeding into
replies that had nothing to do with the stream.

**blast radius, confirmed and bounded.** this is scoped to the one
mcp-server-p7 process's own single socket/session. STRM push frames are
written into `$session->{'buffer'}{'output'}` keyed by that session's own
`sid` (`src/base.stream.push`, line 59), so no other user's or zenka's
session can be corrupted by this. it is a client-side robustness gap in
`bin/mcp-server-p7` specifically -- not a security bug, and not a bug in
the cube/zenka protocol implementation. do not "fix" anything under
`src/base.stream.*`; that side is correct.

## the hard invariant -- read this before designing anything else

**the STRM path either reaches `close` with the socket left byte-clean,
or it calls `cube_disconnect()`.**

every early exit -- safety-valve trip, read error, malformed or
non-numeric frame length, `!TRM!`, bounded-total mismatch, an `alarm`
firing mid-frame -- MUST tear the socket down before returning. no
exceptions, no "probably fine, we only lost the close frame."

the reason is that the bug IS leftover bytes in a reused connection. a
safety valve that returns `[stream still open, N bytes so far]` and
leaves the socket cached reproduces the exact corruption it was added to
prevent, only with a nicer-looking first call. reconnecting is cheap
here: `cube_connect` re-does a unix-socket connect + banner + `select
unix` + `auth`, all already implemented and already exercised on every
stale-socket path.

`cube_disconnect` (line 1762) writes `"close\n"` if the socket still
reports `connected` before closing -- that is harmless mid-stream. do NOT
try to "politely drain the rest first" before tearing down; that is the
hang this valve exists to avoid.

## wire format, verified against source

frames are emitted by `src/base.stream.open` / `.push` / `.close`:

- **open, unbounded**: `"<cmd_id_str>STRM open\n"`
- **open, bounded**: `"<cmd_id_str>STRM open <total_bytes>\n"`
- **push, zero or more**: `"<cmd_id_str>STRM <chunk_len>\n"` followed by
  **exactly `chunk_len` bytes** of payload -- no trailing delimiter
  beyond the declared length. the length prefix is the only framing.
- **close**: `"<cmd_id_str>STRM close\n"`
- `cmd_id_str` is `''` when cmd_id is 0/undef, else `"(N)"` with no
  trailing space -- `base.stream.open` lines 32-35. **but a producer may
  pass `cmd_id_str` explicitly, and the documented override form in that
  module's own `# param` block (line 7) is `'(NNN) '` -- WITH a trailing
  space.** both forms must parse.
- `STRM-SIZE` appears in the same four shapes with `STRM-SIZE` as the
  type token (`src/base.stream.open` accepts both types).
- **`(N)!TRM!\n`** -- emitted by `base.stream.push` lines 33-46 when a
  push is gated and there is an upstream relay. treat it as abnormal
  termination: return whatever was collected, tear the socket down.

**the unbounded open is the normal case, and `STRM close` is its ONLY
terminator.** a bare `STRM open` carries no total -- the producer does
not know the size, and `base.stream.open` writes no number (line 52).
**but an unknown total does NOT mean unknown framing.** every individual
push frame still carries its own exact `<chunk_len>` header, unbounded
stream or not -- so reading is never guesswork at the frame level: read
header line, read exactly that many bytes, repeat. the reader always
knows precisely where it is in the byte stream and exactly how many bytes
to consume next. the only thing missing in the unbounded case is how
many such frames are still to come.

consequently there is nothing in the stream from which *completion* can
be inferred: not a running byte count (there is no target to compare it
to), not a chunk count, not a small or short chunk (chunk sizes are
arbitrary and vary per push -- a 3-byte frame is as normal as an 8KB
one), not a gap in arrival. the reader keeps consuming exactly-framed
header/payload pairs for as long as they keep coming, and stops on
exactly one of three things: the `close` frame (clean), `!TRM!`
(abnormal), or the safety valve (indeterminate, still open). do not
build any completion heuristic
beyond those three -- an unbounded stream that has delivered a
plausible-looking amount of data is not finished, and treating it as
finished puts the remaining frames back in the socket, which is the
whole bug.

`base.stream.open` refuses `total => 0` outright (lines 24-29), so a
declared total is always > 0 -- meaning `total` present vs absent is a
clean two-way test, with no zero-length edge case to special-case.

**nothing follows the close frame.** `bin/c_src/p7c.c` sets
`continue_read = 0` on `close` and returns -- there is no terminating
`TRUE` after the stream. an implementer's natural instinct is to read one
more line "to finish the reply"; that will block forever. don't.

**detection must tolerate the `(N)` prefix, in both its spacings.** the
existing `split( m|\s+|, $first_line, 2 )` at line 1802 is the wrong
tool here: on `"(5)STRM open"` it yields `reply_type = '(5)STRM'`, and on
the trailing-space form `"(5) STRM open"` it yields `reply_type = '(5)'`
-- which falls straight back into the unknown-reply branch, i.e. the bug
unfixed for prefixed streams.

**do not parse STRM header lines with that split at all.** strip a
leading `^\( \d+ \)\s*` first, then parse the remainder as type + arg.
apply this to every header read inside the drain loop, not only to the
first line. mcp-server-p7 sends bare commands so the prefix should not
appear in practice (consistent with the observed `"TRM 5"` /
`"elloSTRM 1"` garbage, which shows unprefixed frames) -- handle it
anyway, it is three characters of regex against a whole class of
silent-corruption failures. note `p7c.c` does NOT handle the prefix --
it is the reference for the frame state machine, not for this part.

## reference implementations already in the tree

- **`bin/c_src/p7c.c` lines ~330-560** -- a complete, working, shipped
  client-side STRM reader. it is the closest thing to a spec: parses
  `open <bytes>` / bare `open` (sets `expected_bytes = -1`) / `close` /
  bare-numeric chunk headers, accumulates `received_bytes`, and at close
  errors out when `expected_bytes != -1 && received != expected`. mirror
  that validation -- a bounded-total mismatch is a real failure, not
  something to return silently.
- **`data/md/design/STRM_DESIGN.md`** -- the protocol design doc
  (receiver-side pseudocode around the "Receiver/Handler Side - New
  Logic" section matches the loop wanted here).
- **`data/md/documentation/SIZE_PROTOCOL_MODES.md`** -- STRM-SIZE
  fragmentation and the client capability-declaration effects (see the
  scope-out below, it matters).
- existing STRM producers, for testing against: `src/radio.cmd.listen`
  and `src/X-11.cmd.subscribe-screen-change` (deliberately never-closing
  by design), `src/kimi-web.cmd.dispatch_stream` (one bounded agent
  response, closes when it finishes), `src/coding.cmd.subscribe-session`
  (new this session, closes when the subscribed task hits a terminal
  state -- this is what surfaced the bug).

## primitives already present in bin/mcp-server-p7

this is compositional from what is already there, not a from-scratch
socket parser:

- `sock_readline` (line 1573) -- byte-at-a-time blocking `sysread`,
  chomps the line, returns undef on EOF/error.
- `sock_write` (line 1588).
- `sock_read_bytes( $sock, $count )` (line 1603) -- exactly what a chunk
  payload read needs; already used for the `SIZE` case at line 1819.

## concrete steps

1. **one shared helper, two call sites.** write
   `drain_strm_stream( $sock, $first_line )` and call it from BOTH
   `cube_command` (line 1770) and `cube_command_multiline` (line 1690).
   `cube_command_multiline`'s reply dispatch at lines 1736-1759 has the
   **identical** fall-through gap (`return ( 1, $first_line )` at 1759).
   do not write two parsers.

2. **the drain loop.** from the already-read open line: record bounded
   total if present, then loop reading a header line via `sock_readline`
   and dispatching on it --
   - bare numeric (with optional `(N)`/type prefix per the grammar
     above) -> `sock_read_bytes` exactly that many bytes, append to the
     accumulator, add to `received_bytes`, continue.
   - `close` -> validate bounded total if one was declared, return the
     concatenated payload, socket stays cached [ this is the clean exit,
     the only one that does not disconnect ].
   - `!TRM!` -> abnormal end: return collected + disconnect.
   - undef from `sock_readline`, a non-numeric unrecognised header, or a
     short/failed payload read -> return an error + disconnect.

3. **return shape.** stay with the existing `( $ok, $text )` convention
   so `tool_p7_command` and every other caller need no change. a clean
   close returns `( 1, $payload )`. a valve trip returns `( 1, $payload
   . "\n[stream still open, N bytes collected, M seconds idle]" )` -- the
   partial content is genuinely useful to the calling model, but the
   marker must be unambiguous so it does not read as the whole answer.
   an error returns `( 0, <reason> )`.

4. **do NOT extend the retry into the STRM path.** the `$retry`
   parameter and its two `return cube_command( $command, 0 ) if $retry`
   sites (lines 1788, 1797) exist for a failure BEFORE the first reply
   line -- i.e. before the command has taken effect. retrying after a
   partial drain re-executes a command whose server-side effects already
   happened; for `coding.cmd.subscribe-session` specifically it would
   double-register a listener in `<coding.session.listeners>`. the STRM
   path disconnects and returns; it never retries.

5. **harden the fall-through itself -- the branch that caused this bug.**
   after adding the STRM case, make the remaining unknown-reply-type
   fall-through (`return ( 1, $first_line )` at line 1838, and its twin
   at line 1759) call `cube_disconnect()` before returning the raw line.
   one line at each site. reason: STRM is not the only reply type this
   client does not handle -- `CHRSIZE` is handled by `p7c.c` but has no
   case in `cube_command` either, and it corrupts the next call by
   exactly the mechanism diagnosed above; so will any reply type added
   later. disconnecting on an unrecognised reply closes the whole class
   without expanding scope into implementing those types. this is the
   same argument used to reject a per-command denylist below: prefer the
   fix that covers what nobody has enumerated yet.

6. **timeout mechanism -- verify before committing to one.**
   `sock_readline` is a blocking byte-at-a-time `sysread` with no
   timeout whatsoever, so a quiet-but-open stream blocks the whole MCP
   server indefinitely. two candidate shapes:
   - `alarm` + `local $SIG{ALRM}` -- the idiom already appears in this
     file at lines 2048, 2222, 2418, 2576. **caveat: those existing uses
     wrap `qx`/subprocess calls, not socket reads.** it is precedent for
     the idiom, not proof that it interrupts this `sysread` cleanly on
     this platform -- verify empirically.
   - a `select`-based readline variant (`IO::Select`, or a four-arg
     `select` on the socket's fileno) that returns a distinct
     timed-out status instead of relying on a signal.

   whichever is chosen: an `alarm` firing mid-frame leaves the socket
   dirty **by construction** -- which is exactly why the teardown rule in
   the invariant section is mandatory rather than defensive.

## the design question -- resolved, with the reasoning

MCP tool calls are single-shot request/response: the calling model gets
one text result per invocation, with no native mid-call streaming back
to it. so "handle STRM" needs an actual policy, not just a parser.

**decision: one universal safety valve applied to every STRM stream. no
per-command classification, no denylist of known-unbounded commands.**

why not a denylist: it **cannot express
`coding.cmd.subscribe-session`**, which is bounded when the subscribed
task finishes and unbounded when it does not -- the very command that
surfaced this bug. a denylist also rots the moment a new STRM producer
lands, and new ones are landing (four exist today, one added this
session). one valve applied uniformly degrades gracefully for producers
nobody has classified yet, and makes `p7_command` STRM-safe for every
future command rather than only the handful known today.

**the valve's primary bound is an IDLE timeout -- quiet interval since
the last frame -- not a total-duration cap.** a total cap truncates a
legitimately slow but genuinely bounded stream, which is the common good
case (a model streaming tokens for several minutes is working
correctly). an idle bound is what actually distinguishes "still
producing" from "parked open indefinitely." add a total-bytes cap as a
secondary bound so a fast runaway producer cannot balloon a single tool
result without limit.

on trip: return what was collected plus the marker from step 3, and
**disconnect** (invariant).

## explicitly out of scope -- do not do these

- **do NOT declare STRM client capability as part of this task.**
  reading "add STRM support" naturally suggests reaching for
  `declare-strm-support` (`src/auth.callback.cap-neg.declare-strm-
  support`) or `select-strm-mode locked` (`src/cube.cmd.select-strm-
  mode`, which `p7c.c` sends up front) at connect time. per
  `data/md/documentation/SIZE_PROTOCOL_MODES.md` lines ~226-247, a
  client that declares STRM support changes **what the cube sends it**:
  large `{ mode => 'SIZE' }` replies that are currently converted
  STRM-SIZE -> SIZE for this client would instead be delivered as STRM.
  that converts currently-working SIZE paths into STRM paths -- a real
  behavior change with a far wider blast radius than the bug being
  fixed. a separate follow-up, once the drain path is proven.
- side note for whoever picks that follow-up up: `strm_support` and
  `strm-mode-locking` are SET by those two handlers but no reader for
  either was found anywhere in `src/` -- only design pseudocode
  (`SIZE_PROTOCOL_MODES.md:239` shows `$next_hop->{'strm_support'}`).
  treat that as "no consumer found in current code, verify before
  relying on either flag," not as "inert."
- no changes to `src/base.stream.*`. the producer side is correct.

## acceptance test

1. **the original failure, reproduced then fixed**: call an STRM
   producer through the `p7_command` MCP tool, then make two unrelated
   `p7_command` calls (`coding.get-result`, `coding.task-info` were the
   live repro) -- both must return their real answers, not frame
   fragments.
2. **bounded stream**: `kimi-web.cmd.dispatch_stream`, or
   `coding.cmd.subscribe-session` against a task that reaches a terminal
   state -- the tool result is the complete concatenated payload, and
   the bounded-total check passes.
3. **unbounded stream**: the call returns within the valve with the
   partial-content marker, **and the next unrelated `p7_command` call
   still succeeds**. that second clause is the only part of the whole
   suite that actually verifies the invariant -- do not skip it.
   easiest producer to use is `coding.cmd.subscribe-session` against a
   task that has NOT reached a terminal state -- known live, no extra
   setup. `radio.cmd.listen` needs the radio zenka running and
   `X-11.cmd.subscribe-screen-change` needs a real display (its own
   hazard on this WSL host) -- use those only if convenient.
4. **both call sites**: exercise the multiline path
   (`cube_command_multiline`) against an STRM producer too, not just
   `cube_command`.

## open, not yet decided [ genuinely the implementer's call ]

- **the actual numbers.** the shape is fixed (idle-primary,
  bytes-secondary); the values are not. pick them against a real
  `coding.cmd.subscribe-session` run so the idle bound sits comfortably
  above the real inter-token/inter-round gap, and consider making both
  overridable per call so a caller expecting a long quiet stretch can
  raise them.
- **which timeout mechanism** -- `alarm` vs `select`-based readline, per
  step 6. resolve empirically, not by preference.
- **whether the valve marker should be structured** rather than a
  trailing text line -- e.g. a separate field the MCP layer surfaces
  distinctly. only worth it if a caller is actually going to branch on
  it; a text marker is sufficient for a model reader.

#,,,.,,..,.,.,,.,,.,.,.,.,,,,,..,,...,,..,,..,..,,...,...,,..,,,,,,,,,,,.,,,,,
#IBMZKXH2DGMT62KXMJ7WF7IF2SGAAG72VT552DOJVI2V7ZHI2DMIN33UVQDMIKHBUZCERCDYEO5DG
#\\\|2VENJIAWGKZLKHWSSFNBNOUVUU7Q6OXPPXIH5FXBIGSUEQDP4BP \ / AMOS7 \ YOURUM ::
#\[7]YE2M4XY64BFB6HRW2BKLSMZPSAMNSTIRVONFSLQHFLT2YPZDLMBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
