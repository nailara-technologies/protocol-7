# task: AMOS7::SHM — handshake-then-upgrade log channel between a log-emitting zenka and p7-log

## status [ 2026-06-22 ]

**design only — nothing implemented.** this is the planning artifact for the
*third* distinct caller-shape of `AMOS7::SHM`, after:

1. the data zenka's own internal `data.mount.shm.*` / `data.channel.shm.*` use,
2. one-shot paged-scalar transport [ `amos7-shm-coding-zenka-prompt-transport.md`,
   the prompt / summarize-context fast-path ].

phases 1-3 of `AMOS7::SHM` are landed and live-verified [ see
`data/tasks/amos7-shm-paging-feedback.md` — **read it first**; this doc assumes
its conclusions and its API surface, in particular `AMOS7::SHM::Feedback`'s
reader-writes-its-own-position + FIFO-notify technique ]. phase 4
[ cleanup / lifecycle ] is still design-only there and is a hard prerequisite
here for the same reason it is in the prompt-transport doc — segments + FIFOs
must not leak.

## signatures note

do NOT add the single-line `#,,.,,,...` stub at end of new files.
leave files clean — signatures are added by the signing system automatically.

## objective

`p7-log` carries the **highest proportion of all traffic relayed by the `cube`
zenka** — and today every single buffered log line is sent as its **own
individual `cube_command` round-trip**. give a log-emitting zenka and `p7-log` a
**one-time handshake** after which the per-line command path is replaced, for
that source, by writing log records into a `data.channel.shm.*`-style ring
buffer that `p7-log` reads directly — **additively and backward-compatibly**,
with a clean graceful fallback to the existing per-line command path for any
zenka / version that does not support or fails the handshake.

the bar here is **stricter than the prompt-transport doc's** — see "the
correctness bar is higher than one-shot transport" below. a log stream is
continuous, ordered, and needs exactly-once delivery; the one-shot prompt case
moves a bounded scalar once and can simply retry.

## why this design exists — grounded in the actual current code

### the per-line round-trip, confirmed from source [ the cost ]

`modules/base.log.send-buffer.send-idle-callback` is the sender side. for each
buffered log line it does **one full command + reply round-trip**:

- `:81-84` pops `$b_ref->{'data'}->[0]` [ one buffered line, a scalar ref ].
- `:114-124` sends `<[protocol-7.command.send.local]>->({ command =>
  "$route_prefix$log_send_cmd", call_args => { args => join(' ', @send_line) },
  reply => { handler => 'base.log.send-buffer.reply-handler.send-reply', ... } })`
  — **per line**, then `:125` sets `$b_ref->{'waiting'} = TRUE` to register the
  outstanding reply before the next line can go.
- the buffer is **paused / resumed** depending on online-status checks against
  the target zenka [ `:37-79` — `v7` checks its registry, `cube` checks its
  sessions, other zenki ask `v7.notify_online` ]. so the path is not only
  one-command-per-line, it is one-command-per-line-gated-on-liveness.

`modules/p7-log.cmd.append` is the receiver side. it parses
`node_zenka instance_id buffer_name log_time log_level log_message` out of the
**single `args` string** [ `:8-12`, `split( m| |, $param_str, 6 )` ], validates
[ `:17-28` ], normalizes the timestamp [ `:53-102` ], and writes via
`<[p7-log.add_line]>` [ `:108` ]. **every field is squeezed through one `args`
string, one command, one reply, per line.** since p7-log is the busiest cube
client, this is the single largest reducible chunk of cube relay traffic.

### the ordering / record shape that must be preserved

the receiver's `p7-log.cmd.append:104` writes
`sprintf("%s %07d %d %s\n", $log_time, $instance_id, $log_level, $log_message)`.
so a log **record** is `( buffer_name, log_time, log_level, log_message )`
plus the source `node_zenka` + `instance_id` [ for non-cube senders the source
prefix is NOT added by the sender — `send-idle-callback:103-108` only `cube`
prepends `node.zenka` + sid; other zenki must not, or the prefix doubles ]. the
ring-buffer records must carry exactly these fields and be **consumed in write
order**, since log files are append-ordered.

## the ring buffer as it exists today — read it, do not assume it fits

`modules/data.channel.shm.*` [ 7 modules: `create`, `write`, `read`, `poll`,
`close`, `init_code`, `test.basic` ] is the existing ring-buffer channel built
on `data.mount.shm.create`. confirmed against the actual code:

- `data.channel.shm.create:29-31` packs a `read_pos / write_pos / wrap_count /
  capacity` header `pack('NNNN', 0,0,0,$shm_size)` at offset 512, default
  `SHM_CHANNEL_SIZE = 256*1024` [ `:6` ].
- `data.channel.shm.write:36-48` frames each message as `[4-byte N length]
  [message bytes]` at `512 + 16 + write_pos`, advancing `write_pos`. **message
  order is preserved by the length-prefix framing** — this part is sound and
  reusable.
- `data.channel.shm.read:31-54` reads up to `max_messages` frames from
  `read_pos`, advancing it. single-writer-per-counter, lock-free in spirit.
- `data.channel.shm.poll:17-21` reports `has_data = (read_pos != write_pos)`.

**this is the ring buffer's natural use case** — a continuous, ordered,
one-directional [ writer → p7-log ] stream of small-to-medium records — and that
judgment from the phase-1 notes holds: paging [ announce-then-pull a bounded
scalar ] is the *wrong* tool for a log stream; the ring buffer is the right
shape. **but the ring buffer as it stands does NOT yet support what a log stream
needs.** the gaps are real and are the centre of this design, not integration
details — see "the gap section" below. confirm them in the code before building.

## the design

### who initiates, and what the key-echo proves here

**recommendation: `p7-log` advertises the capability and generates + delivers
the nonce; the sender echoes it back through the new SHM channel.** this is the
backward-compatible direction and it gets the security property right.

the precedent is `modules/base.cmd.verify-instance` + `v7.zenka.set_cube_sid`:
v7 generates a private 13-char key [ `v7.zenka.set_cube_sid:43`,
`uc(<[base.prng.chars-anum]>->(13))` ], hands it to the instance over a **direct
command** [ `:57-61` ], and then watches the instance's own log stream for the
echo [ `configuration/zenki/v7/zenka-output.patterns:29`,
`^instance verification \[KEY:([a-zA-Z\d]+)\]$` → `v7.handler.instance_verification` ].
the security property: **only a process that actually received the privately
injected key can produce the echo.** that is exactly what we reuse — but the
direction matters because `/dev/shm` is **world-readable**
[ `amos7-shm-paging-feedback.md:96-98` ], so a nonce *planted in SHM* would not
be secret. therefore:

1. **the nonce travels the TRUSTED path, the echo travels the NEW path.**
   `p7-log`, on a `cmd.append` from a handshake-capable source, delivers a
   fresh nonce in its **existing reply** to that append [ the
   `reply-handler.send-reply` path already exists,
   `send-idle-callback:118-124` already registers a reply handler per line ].
   the reply is delivered over the cube-authenticated session, so the nonce
   reaches **only** the sender that owns that authenticated session.
2. **the sender's proof = echo the nonce as the FIRST frame written into the
   ring buffer it just created.** `p7-log` reads that first frame back. because
   `/dev/shm` is world-readable, *seeing* a nonce is not proof — but **writing**
   the correct nonce into a segment whose write access is granted to the
   sender's pubkey, in response to a nonce that only the authenticated session
   received, proves all three things at once:
   - **identity**: the writer is the same entity as the authenticated cube
     session [ the verify-instance property — it received the private nonce ].
   - **the sender can write** the ring [ it produced a frame ].
   - **p7-log can read** the ring end-to-end [ it got the frame back ].
3. **what is confirmed before the switch**: channel created [ sender created the
   segment + granted p7-log read ]; both ends opened it [ proven by the echoed
   nonce making the full round trip ]; and the **ring state at switchover is
   unambiguous** — see the next point, the nonce frame is also the ordering cut.

### the nonce frame is the ordering cut-point — no separate sync negotiation

the echoed nonce frame doubles as the **barrier** between the two transports,
which is the clean answer to "no line duplicated or dropped during transition":

- **everything up to and including the nonce-delivery `cmd.append`** went via the
  per-line cube path, as today.
- **the nonce is the first frame in the ring.** when `p7-log` reads it and
  matches, it records "source X switched to SHM as of nonce N" and **stops
  expecting cube `cmd.append`s from X** [ the sender stops sending them ].
- **the first real log line is the next ring frame after the nonce.** there is
  no overlap window: the sender does not write a real line into the ring until
  it has written the nonce, and does not send another cube `cmd.append` once it
  has begun writing the ring. the echoed nonce **is** the empty/synced
  confirmation — no separate "is the ring empty" handshake is needed.

### switchover mechanics — sender side [ `base.log.send-buffer.send-idle-callback` ]

additive, behind a per-buffer state flag. **today's path is the
`else` / per-line branch; it stays the default and the fallback.**

```perl
## per send-buffer, a transport state : 'cube' [ today ] | 'handshaking' |    ##
## 'shm'. defaults to 'cube' — unset means today's behavior, unchanged.       ##
my $transport = <log.send-buffer>->{$name}->{'transport'} // qw| cube |;

if ( $transport eq qw| shm | ) {
    ## fast path : write the record straight into the ring, no cube command   ##
    ## [ AMOS7::SHM::Channel::write_record — see "where the generic part       ##
    ##   lives" ; record = ( buffer_name, log_time, log_level, log_message )   ##
    ##   exactly as p7-log.cmd.append:104 reassembles ]                        ##
    my $ok = <[data.channel.shm.transport.write]>->( $channel_id, \@record );
    if ($ok) {
        ## DO NOT shift here — a ring write is NOT delivery [ see below ].     ##
        ## the line stays queued until p7-log ACKS durable consumption via the ##
        ## read-position feedback region ; a separate ack-reaping step shifts  ##
        ## everything up to last_acked off $b_ref->{'data'}. p7-log learns of  ##
        ## new data via the FIFO ding [ below ].                               ##
    } else {
        ## ring full / write failed : fall back for THIS line, see "failure"  ##
        ## [ the line is still queued — nothing was shifted ]                  ##
        <[base.log.send-buffer.fallback-to-cube]>->($name);
    }
} elsif ( $transport eq qw| handshaking | ) {
    ## awaiting the nonce in a cmd.append reply ; keep sending via cube until  ##
    ## the reply arrives and we write+confirm the nonce frame [ no overlap ]   ##
    ## ... existing per-line send, plus carry the 'shm-capable' marker ...     ##
} else {
    ## transport eq 'cube' : EXACTLY today's code, byte-for-byte unchanged     ##
}
```

the sender advertises capability by adding a small marker to its `cmd.append`
`args` [ or as a multiline `param`, see open questions ] that an **old** p7-log
simply ignores [ it `split`s `args` into 6 fields, `:8-12`; an extra trailing
token is absorbed or harmlessly ignored — confirm exact parse safety ]. an old
sender never sets the marker, so an upgraded p7-log never offers it a nonce —
**both directions degrade silently to today.**

### switchover mechanics — receiver side [ `p7-log` ]

`p7-log` needs a **new per-source ring-buffer reader loop alongside** its
existing `cmd.append` cube path — `cmd.append` is NOT removed; it remains the
path for non-upgraded sources and the fallback target. the reader loop is
driven by the **FIFO ding**, exactly the phase-3 `AMOS7::SHM::Feedback`
mechanism, watched via `base.event.add_io`:

- `modules/base.event.add_io` takes a filehandle + `handler` + `timeout` /
  `timeout_cb` [ `base.event.add_io:3-4,16-46` ] — install one watcher on the
  read end of the channel's `.notify` FIFO. when the sender dings, the handler
  drains all available ring frames via `data.channel.shm.read` and feeds each
  through the **same** `<[p7-log.add_line]>` write path `cmd.append:108` already
  uses. **the record-handling logic is shared; only the intake differs.**
- this is event-driven, no poll loop — the same reason phase 3 chose FIFO +
  `Event->io()` over `Event->var()` / inotify, which were both tested and ruled
  out for mmap writes [ `amos7-shm-paging-feedback.md:308-341` ].
- a `timeout_cb` on the watcher is the stalled-sender liveness check [ same
  pattern phase 3 used for the stalled-reader case ].

**note**: `data.channel.shm.poll` is **poll-only** [ `data.channel.shm.poll:17-21`
returns a `has_data` flag; there is **no** notify FIFO in the existing ring
channel ]. adding the FIFO ding is part of the gap, below — it is not free in
the ring code as it stands.

### failure / disconnect mid-stream — degrade to cube without loss or duplication

this is **the harder-than-prompt-transport part** and must be designed, not
hoped. the invariants:

- **shift on ACK, not on write — a ring write is NOT delivery.** the segment is
  sender-owned in world-readable `/dev/shm`; a frame written but not yet read by
  p7-log has not reached the log file, and would be lost on p7-log disconnect,
  sender-death-TTL-reap, or the gap-#2 clobber. so the sender keeps every line
  in `$b_ref->{'data'}` until p7-log **acks durable consumption** via the
  read-position feedback region [ gap #3 ], then `shift`s everything up to
  `last_acked` off the queue. a **failed** ring write shifts nothing — the line
  stays queued. **no line is dropped on write failure, on disconnect, or on
  reap, because nothing is removed from the queue until it is durably acked.**
  [ this is *why* the read-position feedback channel exists — it is not an
  optimization, it is the exactly-once mechanism. ]
- **"acked" means p7-log durably WROTE the record**, i.e. `<[p7-log.add_line]>`
  returned success [ `cmd.append:108` is the same write path the ring reader
  feeds ], **not** merely "read the frame off the ring." otherwise a p7-log
  crash between ring-read and file-write would lose a line the sender already
  considered acked. the read-position the reader publishes advances **only after
  the durable write succeeds.**
- **fallback is per-source and atomic at a known cut**: on ring-full,
  write-error, or p7-log signalling it can no longer read, the sender sets its
  buffer `transport` back to `cube` and resumes the per-line path **from the
  first not-yet-acked line** — which, by the shift-on-ack discipline above, is
  exactly `$b_ref->{'data'}->[0]`, the front of the still-queued lines. this
  requires the sender to know **what p7-log has durably consumed** — which the
  bare ring does NOT provide [ see gap #3 ]. the **reader→writer read-position
  feedback channel** [ phase-3 `Feedback`'s reader-writes-its-own-position
  technique, composed onto the ring ] is what makes exactly-once fallback
  possible: lines past `last_acked` were never shifted, so resuming cube sends
  re-sends **none** of the acked lines [ no duplication ] and skips **none** of
  the unacked ones [ no loss ]. [ open question 1 option (a) — a **p7-log-owned**
  ack region — is what makes this work cross-user *and* is the mechanism behind
  shift-on-ack: p7-log writes its own ack file [ same-user, no cross-user-write
  tension ], the sender reads it to advance `last_acked` and shift. ]
- **on p7-log disconnect / restart**: the channel segment is owned by the
  **sender** [ writer-owns-lifetime, carried from the prompt-transport doc ].
  if p7-log goes away, its FIFO read end closes; the sender's `write_record`
  starts failing [ ring fills, no acks advance ] and it falls back to cube,
  which will itself pause until p7-log is back online [ the existing
  `notify_online` liveness gate, `send-idle-callback:62-79` ]. no line is lost
  because none was `shift`ed without an ack.
- **on sender death**: phase 4 cleanup [ writer-owned, + a TTL safety-net sweep,
  exactly as `amos7-shm-coding-zenka-prompt-transport.md` specifies ] reaps the
  orphaned segment + FIFO. p7-log drains whatever frames are already committed
  in the ring before the segment is reaped [ committed frames are the sender's
  acked-as-written work ].

### the correctness bar is higher than one-shot transport — stated explicitly

`amos7-shm-coding-zenka-prompt-transport.md` moves **one bounded scalar once**;
if it fails, the caller retries the whole thing — there is no ordering or
exactly-once concern, the checksum verify is the whole correctness story. **this
design is different and harder**: a log stream is **continuous, ordered, and
exactly-once**. a duplicated log line corrupts the append-ordered log file; a
dropped line loses data silently. so this design carries two correctness
mechanisms the prompt-transport doc does not need: **(a)** the length-prefix
framing preserves order [ already in `data.channel.shm.write` ], and **(b)** the
read-position feedback channel makes the cube fallback exactly-once. call this
out to whoever implements: **do not port the one-shot doc's "announce, pull,
verify checksum, done" mental model here — the stream never ends and the
fallback must be lossless.**

## the gap section — does the ring buffer actually support this? [ NO, not yet ]

the task asked whether `data.channel.shm.*` supports what is needed. **read in
its own code, the honest answer is: it does not, today — these are real gaps,
not integration details.** three of them, each cited:

1. **no notify — poll-only.** `data.channel.shm.poll:17-21` returns a `has_data`
   flag; there is **no FIFO**, no event-driven wakeup. p7-log would have to poll
   every channel on a timer, which is exactly the cost this design exists to
   remove [ and a busy log stream polled on a timer reintroduces latency +
   wasted wakeups ]. **needs**: the phase-3 FIFO-ding technique
   [ `amos7-shm-paging-feedback.md` `AMOS7::SHM::Feedback`,
   `create_notify_fifo` + `Event->io()` ] composed onto the ring channel.

2. **the wrap-around / available-space logic is buggy for a sustained stream —
   a correctness defect, not just a limitation.** `data.channel.shm.write:26`
   carries the author's own admission: `# Check available space (simplified -
   doesn't handle wrap-around fragmentation)`. concretely:
   - the `available` calc [ `:27-34` ] treats the free space as one contiguous
     span [ `capacity - write_pos + read_pos` when `write_pos >= read_pos` ],
     but after a wrap the free space is **fragmented** into an end-piece and a
     start-piece; the single number overcounts.
   - the wrap itself [ `:39-45` ] resets `write_pos = 0` and writes from the
     start **without checking that the wrapped write will not pass `read_pos`**
     — i.e. it can **overwrite not-yet-read frames**, silently clobbering log
     lines. for a one-shot demo channel this never surfaced; for a **sustained**
     log stream where the reader can fall momentarily behind, it is a
     data-corruption bug.

   **needs**: a correct full/empty accounting that refuses the write [ → sender
   fallback ] rather than overwriting unread frames, and either no-wrap-past-
   reader or a correctly-fragmented free-space calc. **this must be fixed before
   the ring carries real log traffic** — flag it as a blocking gap.

3. **no reader→writer read-position feedback.** the ring's `read_pos` lives in
   the shared header and is advanced by the reader [ `data.channel.shm.read:57-58` ],
   but there is **no path for the writer to learn what the reader has durably
   consumed** as an acknowledgement it can trust — and the writer reading the
   shared `read_pos` directly races the reader's in-place update with no
   freshness / ordering guard. this is exactly what blocks **lossless fallback**
   [ the sender cannot know `last_acked` to resume cube sends from ]. **needs**:
   the phase-3 `Feedback` shape — a reader-sole-writer position region [ + ntime
   freshness stamp, clamped to the announced range by the sole reader of it, the
   writer ], composed onto the ring. neither the bare ring **nor** phase-3 paging
   `Feedback` provides this combination today.

**note — dropped non-issue**: the ring `read_pos` / `write_pos` are `N`
[ 32-bit ] but bounded by the 256KB capacity, so 32-bit is fine; and the 4-byte
length framing correctly preserves message order. those are **not** gaps. the
three above are.

## does this generalize beyond p7-log? — yes : a THIRD distinct SHM use case

the task asked whether this is log-specific or a nameable pattern. it is a
**third distinct `AMOS7::SHM` use case**, alongside:

| use case | shape | primitive |
|---|---|---|
| one-shot paged transport [ prompt-transport doc ] | move one bounded scalar once, pull-based, verify-checksum-done | `AMOS7::SHM::Page` + `Transport` |
| data zenka internal | low-latency bidirectional channel traffic | `data.channel.shm.*` ring |
| **continuous-stream-with-handshake-and-ack [ THIS doc ]** | unbounded ordered stream, identity-proven switchover, lossless fallback | **new : ring + read-position feedback + key-echo confirmation** |

**neither existing tool provides this today** — say it plainly:

- the bare `data.channel.shm.*` ring has the framing but lacks notify, a correct
  full/empty accounting, and read-position feedback [ the three gaps above ].
- phase-3 `AMOS7::SHM::Feedback` has the reader-writes-position + FIFO-notify
  technique, but it is bolted to the **paging** [ announce-then-pull ] model
  [ `amos7-shm-paging-feedback.md` phase 3 ], not to a wrap-around ring.

### where the generic part should live

the generic, reusable part is **ring + read-position-feedback + key-echo
confirmation** — recommend a new standalone-loadable sibling
**`data/lib-path/pm/AMOS7/SHM/Channel.pm`**, mirroring the
`Page.pm` / `Feedback.pm` layout [ `amos7-shm-paging-feedback.md:182-186` ],
that **composes**:

- the existing ring framing [ promoted / corrected from `data.channel.shm.*` ],
- `AMOS7::SHM::Feedback`'s reader-position + FIFO-notify region [ reused, not
  re-derived ],
- a small generic **key-echo confirmation step** [ the verify-instance property,
  generalized: "first frame must echo a nonce delivered over the trusted path" ].

thin zenka wrappers `modules/data.channel.shm.transport.*` follow the same
pattern as the prompt-transport doc's `data.mount.shm.transport.*`. **stays
under `data.channel.shm.*` / `AMOS7::SHM::*`, never `base.*`** — the namespace
lesson, repeated. the key-echo confirmation step is generic enough that it could
later serve any "prove the same authenticated peer opened the new channel"
need, not only logging — but **do not build that generality speculatively**;
extract `Channel.pm` to serve p7-log first, note the reuse potential.

### carried over from the prompt-transport doc — referenced, not re-derived

- **writer owns the segment lifetime** [ sender creates + grants, p7-log opens
  read-only ] — `amos7-shm-coding-zenka-prompt-transport.md` "phase 4 is a
  prerequisite" + "writer owns the segment lifetime".
- **p7-log opens read-only** [ the new `shm_open` read-only mode ] — and **this
  is a genuinely cross-user pair**: senders may run as `taeki`
  [ coding-admin-group ] or as bare `protocol-7` [ `task`, etc. ], while
  **`p7-log` itself is bare `protocol-7`** [ `configuration/zenki/p7-log/start:24`,
  bare `[root.drop_privs:<system.amos-zenka-user>]` ]. a `taeki`-owned segment
  read by a bare-`protocol-7` p7-log is exactly the `'+<'`-EACCES case the
  read-only open fixes [ `/dev/shm` world-readable ]. **but** the sender here is
  also a **writer that the reader writes back to** [ the read-position feedback
  region ], so this design hits the **reader-write cross-user tension** the
  prompt-transport doc explicitly deferred — see open question 1.

## phased plan

- **phase A — fix + promote the ring**: correct gap #2 [ wrap/available
  accounting — refuse-rather-than-clobber ] in a promoted, standalone-loadable
  `AMOS7::SHM::Channel` core; thin `data.channel.shm.*` wrappers call through;
  `p7c data.shm-self-test` passes unchanged + a corrected ring test. **hard
  gate**, same as every prior phase.
- **phase B — compose notify + read-position feedback** [ gaps #1, #3 ] onto the
  channel from `AMOS7::SHM::Feedback`. cross-process proven with a standalone
  fork + timing-gap script, **never a same-process check** [ the phase-3 lesson,
  `amos7-shm-paging-feedback.md` "how this landed" ].
- **phase C — the handshake**: nonce-in-cmd.append-reply, echo-as-first-frame,
  the `transport` state flag in `send-idle-callback`, the FIFO-driven reader
  loop in p7-log alongside `cmd.append`.
- **phase D — fallback correctness**: ring-full / disconnect / sender-death
  paths, exactly-once via `last_acked`, the TTL safety-net sweep. phase 4
  cleanup is a hard prerequisite, same as the prompt-transport doc.

## backward compatibility — stated as an invariant

- a buffer with `transport eq 'cube'` [ the default / unset state ] behaves
  **byte-for-byte as today** — the new branches only run once a handshake has
  set `transport` to `handshaking` / `shm`.
- an **old p7-log** never offers a nonce → an upgraded sender never switches →
  it stays on the per-line path. an **old sender** never advertises capability →
  an upgraded p7-log never offers it a nonce. **both directions degrade
  silently.**
- `p7-log.cmd.append` remains the path for non-upgraded sources **and** the
  fallback target; it is not removed and its parse is unchanged [ the capability
  marker must be ignorable by the old 6-field `split`, `cmd.append:8-12` —
  verify ].
- `p7c data.shm-self-test` passes unchanged + new channel checks.
- no new code under `base.*` for the SHM mechanics [ the `send-idle-callback` /
  send-buffer touch-points are necessarily in `base.log.*`, but they only
  *call* the `data.channel.shm.transport.*` wrappers — the mechanics stay out of
  `base.*` ].

## style

[ same binding list as `amos7-shm-paging-feedback.md` /
`amos7-shm-coding-zenka-prompt-transport.md` ]

- lowercase comments, `[ word ]` bracket annotations [ never `( word )` ]
- `$ARG` / `@ARG`, not `$_` / `@_`, where used implicitly
- `<log.send-buffer>->{}` dotted-data style, not `$data{'log'}{...}`
- `.cmd.` / whitelisted routines return `{ mode => true|false, data => STRING }`
  — split raw-hash / scalar-ref helpers into separate non-`.cmd.` routines
- `<[base.logs]>->( N, fmt, args )` for logging, not warn / print
- config paths via `<system.root_path>/...`; never bare relative
- TRUE / FALSE / UNKNOWN constants, never literal 0 / 1
- standalone packages use the lib-path `BEGIN` + `$main::PROTOCOL_SEVEN` check
  [ mirror `AMOS7::CHKSUM` / `bin/amos-chksum` ]
- new SHM code stays under `data.channel.shm.*` / `AMOS7::SHM::*`, **never**
  `base.*`
- guard any timer with a fallback interval [ undef interval = max-rate loop ]

## acceptance [ overall ]

- [ ] `AMOS7::SHM::Channel` is loadable standalone + in-zenka, composing the
      promoted/corrected ring + `AMOS7::SHM::Feedback`'s position+FIFO region +
      a generic key-echo confirmation — no new mmap / header / permission
      mechanics
- [ ] the ring's wrap/available bug [ gap #2 ] is fixed: a sustained stream that
      momentarily outruns the reader **refuses the write [ → fallback ]** rather
      than overwriting unread frames — proven with a fill-past-reader test
- [ ] a handshake-capable sender and an upgraded p7-log complete the
      nonce-in-reply / echo-as-first-frame handshake; an old sender OR an old
      p7-log silently stays on the per-line cube path
- [ ] after switchover, log records flow writer→ring→p7-log via the FIFO ding
      [ `base.event.add_io` ], in write order, with **no** cube command per line
- [ ] mid-stream ring-full / p7-log-disconnect / sender-death all degrade to the
      per-line cube path with **no line dropped and no line duplicated** — proven
      with an ordered-sequence test that injects a failure mid-stream and checks
      the written log file is exactly the input, once, in order
- [ ] p7-log opens the segment read-only and the transfer works **cross-user**
      [ `taeki`-owned segment, bare-`protocol-7` p7-log ] — genuinely cross-user
      test, not a same-user fork
- [ ] every existing per-line `cmd.append` call is byte-for-byte unchanged; the
      capability marker is ignorable by the old 6-field parse
- [ ] `p7c data.shm-self-test` passes unchanged + new channel checks
- [ ] no new SHM mechanics under `base.*`

## open questions [ for the project owner — do not decide unilaterally ]

1. **[ MOST IMPORTANT ] the reader-write cross-user tension this design forces
   into the open.** the prompt-transport doc's one-shot path could open the
   segment **read-only** and so work cross-user trivially on a world-readable
   `/dev/shm`, deferring the reader-*write* case as "no caller yet." **this
   design IS that caller**: p7-log [ bare `protocol-7` ] must **write** the
   read-position feedback region of a segment that may be **owned by a `taeki`
   sender** [ coding-admin-group, or another `taeki`-running zenka ]. a
   world-readable segment is not world-*writable*. so the read-position
   feedback channel needs a real cross-user-write answer — **the options**:
   (a) the feedback region is a **separate** small segment owned by **p7-log**
   [ writer-of-feedback owns it ], so p7-log writes its own file and the sender
   reads it [ inverting ownership per-region — clean, matches "single writer
   owns its region" but means two segments + two FIFOs per channel ];
   (b) a shared unix group both sides join + a group-writable feedback segment
   [ reintroduces OS-perm dependency the project avoids ];
   (c) restrict the SHM log fast-path to **same-user** sender/p7-log pairs only
   [ e.g. only `protocol-7`-user zenki like `task` → `protocol-7` p7-log ], and
   leave `taeki`-running senders on the cube path. **which ownership model for
   the feedback region?** (a) looks right and is the project-native "each region
   has one owner-writer" answer, but it doubles the per-channel object count —
   confirm before building, as it sets the `AMOS7::SHM::Channel` shape.

2. **is fixing the ring's wrap/clobber bug [ gap #2 ] in-scope here, or its own
   prerequisite task?** it is a **pre-existing correctness defect** in
   `data.channel.shm.write` independent of this design, and the data zenka's own
   `data.channel.shm.test.basic` evidently never exercised a fill-past-reader
   case [ or it would have surfaced ]. fixing it touches the data zenka's live
   ring code. do you want it fixed as phase A of this work, or split out as a
   standalone "fix the ring buffer" task with its own gate first?

3. **the capability marker on the wire.** the sender advertises handshake
   capability via the `cmd.append` `args`. an extra trailing token risks the
   6-field `split( m| |, $param_str, 6 )` [ `p7-log.cmd.append:11 ] folding it
   into `log_message`. safer as a multiline `param` an old p7-log ignores, or a
   distinct out-of-band `p7-log.shm-offer` command? leaning out-of-band command
   for cleanliness, but it adds one command round-trip per source [ one-time,
   negligible ] — confirm.

4. **per-source vs shared ring.** one ring per (source-zenka, instance) pair, or
   one shared multi-writer ring into p7-log? a shared ring breaks the
   single-writer lock-free property [ the whole reason the ring is lock-free ]
   and reintroduces contention, so **per-source** is strongly recommended — but
   that means p7-log holds N FIFO watchers for N active log sources. is that
   watcher count a concern at the project's busiest [ how many distinct log
   sources does cube relay for, in the heaviest deployment ]?

#,,..,..,,,,,,,.,,..,,,..,,,.,,,.,.,.,.,,,,..,..,,...,...,..,,..,,,,,,,.,,,.,,
#5MQKGQL2JPEGH5Y45NJTGYKTLMVEW4B7263PW3XZ66BQLVWMHTYTRWSC6FDR23WOFA4DQVXH4YHWI
#\\\|MSQ47657VPT7EQQXSX2ISUKOPCHOBKZOWUNO3EU4HSWDZQDLSOW \ / AMOS7 \ YOURUM ::
#\[7]H2LGQM3P22B5U5MZO34CVMS2AZ5DFJLJUXFOPRAFZ4Q7GW2E54BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
