# task: AMOS7::SHM — handshake-then-upgrade log channel between a log-emitting zenka and p7-log

## status [ 2026-06-22 ]

**design only — nothing implemented.** *revised this session*: the mechanism was
changed from "fix + promote the `data.channel.shm.*` ring" to a **dynamic pool of
independent fixed-size `AMOS7::SHM` segments** [ see "ARCHITECTURE CHANGE" below ].
the ring is rejected, not patched. this is the planning artifact for the
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
that source, by writing log records into a **dynamic pool of fixed-size
`AMOS7::SHM` segments** that `p7-log` reads directly [ see "ARCHITECTURE CHANGE"
— this was originally a `data.channel.shm.*`-style ring, now a segment pool ] —
**additively and backward-compatibly**, with a clean graceful fallback to the
existing per-line command path for any zenka / version that does not support or
fails the handshake.

the bar here is **stricter than the prompt-transport doc's** — see "the
correctness bar is higher than one-shot transport" below. a log stream is
continuous, ordered, and needs exactly-once delivery; the one-shot prompt case
moves a bounded scalar once and can simply retry.

## why this design exists — grounded in the actual current code

### the per-line round-trip, confirmed from source [ the cost ]

`src/base.log.send-buffer.send-idle-callback` is the sender side. for each
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

`src/p7-log.cmd.append` is the receiver side. it parses
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

## ARCHITECTURE CHANGE [ 2026-06-22 ] — the ring is REJECTED, a segment pool replaces it

an earlier revision of this doc proposed building `AMOS7::SHM::Channel` by
**fixing** the existing `data.channel.shm.*` ring buffer's wrap-around bug and
composing the phase-3 feedback atoms onto it. **that approach is superseded.** a
live design conversation with the project owner concluded the ring should be
**replaced, not patched**, by a fundamentally simpler mechanism: a **dynamic
pool of independent, individually created / destroyed fixed-size `AMOS7::SHM`
segments**, instead of one big segment containing a byte-framed ring.

the section below is kept as the **historical record of why the ring was
rejected** — it is no longer the proposed substrate. the new mechanism is "the
segment-pool design" further down ; read that for what is actually proposed.

## the ring buffer as it existed — read it, this is WHY it was rejected

`src/data.channel.shm.*` [ 7 modules: `create`, `write`, `read`, `poll`,
`close`, `init_code`, `test.basic` ] is the existing ring-buffer channel built
on `data.mount.shm.create`. confirmed against the actual code:

- `data.channel.shm.create:29-31` packs a `read_pos / write_pos / wrap_count /
  capacity` header `pack('NNNN', 0,0,0,$shm_size)` at offset 512, default
  `SHM_CHANNEL_SIZE = 256*1024` [ `:6` ].
- `data.channel.shm.write` frames each message as `[4-byte N length]
  [message bytes]` at `512 + 16 + write_pos`, advancing `write_pos` [ `:23-24`,
  `:47-51` ]. **message order is preserved by the length-prefix framing** — this
  part is sound, and the redesign keeps it [ moved *inside* a slot, see below ].
- `data.channel.shm.read:31-54` reads up to `max_messages` frames from
  `read_pos`, advancing it. single-writer-per-counter, lock-free in spirit.
- `data.channel.shm.poll:17-21` reports `has_data = (read_pos != write_pos)`.

**the wrap-around accounting is a genuine data-corruption defect** — and this
defect is now the **stated motivation for the architecture change**, not a gap
to fix. read `data.channel.shm.write` in source:

- `:26` carries the author's own admission:
  `# Check available space (simplified - doesn't handle wrap-around fragmentation)`.
- the `available` calc [ `:27-34` ] treats free space as one contiguous span
  [ `capacity - write_pos + read_pos` when `write_pos >= read_pos`, `:28-29` ],
  but after a wrap the free space is **fragmented** into an end-piece and a
  start-piece — the single number overcounts.
- the wrap itself [ `:39-45` ] resets `write_pos = 0` and writes from the start
  **without checking the wrapped write will not pass `read_pos`** — it can
  **overwrite not-yet-read frames**, silently clobbering log lines. for a
  one-shot demo channel this never surfaced ; for a **sustained** log stream
  where the reader momentarily falls behind, it is a data-corruption bug.

rather than carry, fix, and forever maintain this fragmented-free-space
arithmetic, the project owner chose to **sidestep the entire bug class** with a
design that has no shared free-space arithmetic at all — see next.

### is the ring still relevant as a building block? — NO, it is orphaned for this purpose

verified this session: **nothing in the codebase actually calls the ring at
runtime.** `grep` for `data.channel.shm.*` callers across `src/`, `bin/`,
`cfg/`, `data/lib-path/` finds only `data.cmd.shm-self-test:20`
[ `<[data.channel.shm.test.basic]>`, the regression harness ] plus
whitelist / `base.list.subroutines` index entries. there is **no production
`create` / `write` / `read` / `poll` caller anywhere**. the ring is a
tested-but-unused demo channel.

consequence for this design: `data.channel.shm.*` is **not a promotion target
for `AMOS7::SHM::Channel`** — the new design does not build on it at all. it may
remain on disk as-is [ it serves the self-test and harms nothing ], but it is
**orphaned as a building block** for this work. `p7c data.shm-self-test` must
still pass unchanged [ it exercises `test.basic`, untouched by this design ].

## the segment-pool design — what `AMOS7::SHM::Channel` actually is now

**core idea**: instead of one ring-buffer segment with internal byte-level frame
fragmentation risk, the channel is a **pool of separate, whole `AMOS7::SHM`
segments**, each fixed-size [ one `page_size`-equivalent per slot ]. growing
capacity under burst load = **creating one more segment** [ `AMOS7::SHM::shm_create`,
a fully landed, proven phase-1 primitive — **zero new low-level mechanics** ].
shrinking = **retiring a slot** once the reader has fully consumed it. this
sidesteps the ring's entire bug class: there is **no byte-level wrap-around and
no fragmented free-space arithmetic to get wrong**, because each slot is a clean,
whole, independently-addressed unit.

### what a "slot" holds, and where the length-framing went

a slot is **not** one log line — that would mean one `shm_create` per line, absurd
for the busiest cube client. a slot is a `page_size` segment holding a **batch of
length-framed records**, sealed and rotated as a whole unit. the 4-byte
length-prefix framing from the old ring [ `data.channel.shm.write:23-24,47-51` ]
**does not vanish — it moves *inside* a slot**, framing the records packed into
that one segment. what the pool eliminates is the **wrap-around free-space
arithmetic across a shared ring**, not the framing.

the analogy that grounds this in real code: `<log.send-buffer>->{$name}->@*`
[ `base.log.send-buffer.send-idle-callback:81-84` pops `->[0]` ; the queue grows
via push, drains via shift ] is exactly this shape — a growing / shrinking array
of units. the pool is the same shape, except **each element [ a slot ] is backed
by its own SHM segment instead of an in-process scalar**, and each element
carries a *batch* of records rather than a single line. push / shift is on
**slots** entering / leaving the active rotation, not on individual lines.

### the three-state slot lifecycle

every pool slot is in exactly one of three states. preserving this three-way
distinction is load-bearing — do **not** flatten it to a two-state alive / dead:

1. **active** — in the read / write rotation. the writer is packing records into
   it [ or has sealed it and moved to the next ] ; the reader has not
   [ necessarily ] finished with it. capacity grows by adding active slots.

2. **drained-and-erased [ warm spare ]** — the reader has fully consumed the
   slot, and **before** it is reused or released its content region is
   **securely overwritten with entropy** [ see "secure erase" below ], after
   which it is kept around as a **warm spare** — ready for instant reuse on the
   next burst, rather than immediately unlinked. **this is the fast path**:
   shrinking the *active* count is cheap and immediate — a slot just transitions
   active → drained, gets erased, and waits. the active → drained transition is
   where the secure erase happens [ immediately, when the reader finishes with a
   slot — not deferred to unlink time ].

3. **released [ unlinked ]** — the slot is actually `unlink`ed [ + its FIFO, if
   per-slot ; see open questions ]. this happens **only** to a spare that has sat
   in the drained-and-erased pool past a **longer decay period** [ slower than
   the active → drained transition ]. the point of the warm-spare tier: a burst
   can **reuse an already-erased warm spare instantly** [ no `shm_create` cost,
   no fresh mmap ] rather than the pool re-creating segments from scratch every
   time load fluctuates. only sustained low load lets spares decay to release.

### the per-slot state model — `state`, `refcount`, `last_updated`

the three-state lifecycle above is the *narrative*; this is the **precise,
implementable record** behind it, settled in conversation after the rest of this
doc was drafted. every pool slot carries exactly three fields:

- **`state` ∈ `{ used, unused }`.** not a richer enum — `used` covers both
  "active, being written" and "active, being read but not yet fully consumed";
  `unused` is the single state covering both "warm spare" and "about to be
  released." the three-state *narrative* [ active / drained-and-erased-spare /
  released ] is `used` vs `unused` plus **how long** a slot has sat `unused`
  [ via `last_updated`, below ] — released is not a fourth state, it is
  "`unused` long enough to decay."
- **`refcount`** — an integer ≥ 0, incremented when a consumer attaches to the
  slot [ the reader opening it, or — generalizing beyond the single-reader
  p7-log case this doc otherwise assumes — any consumer that needs to ] and
  decremented when it detaches. **`state` transitions to `unused` exactly when
  `refcount` reaches 0** — this is the generalization that resolves the
  single-reader assumption the rest of this doc otherwise makes: if a pool is
  ever attached to by more than one consumer, `refcount` is the correct signal
  for "nothing needs this anymore," not "the one known reader said so."
  **overwriting [ the secure-erase + reuse step ] is permitted if and only if
  `state == unused`** — equivalently, `refcount == 0`. this is both the
  **trigger** [ refcount hitting zero is what *causes* the active → drained
  transition and its erase ] and the **gate** [ nothing may erase or reuse a
  slot while any reference remains, full stop, including during the shutdown
  wipe below ].
- **`last_updated`** — an `ntime` timestamp [ same idiom as phase-3
  `AMOS7::SHM::Feedback`'s freshness stamp, including its clock-regression
  guard — reuse, don't reinvent ], set to **the moment of the last `state`
  transition** [ most importantly, the moment `refcount` hit zero and `state`
  flipped to `unused` ]. **purpose**: it is what answers open question 2's
  "how long has this warm spare sat idle" — the drained → released decay timer
  is `now - last_updated` compared against the decay-period tunable [ still
  open, see OQ2 ; this field is the *mechanism*, the threshold value is not yet
  chosen ]. secondary use: a slot stuck `used` far longer than the channel's
  normal cadence, with `last_updated` not advancing, is a reasonable
  stalled-attachment diagnostic — not the primary reason for the field, but a
  useful side effect of having it.

### shutdown safety — the pool's own end_code wipe, and why it must NOT mirror phase 4 part A's append-only registry

phase 4 part A [ `amos7-shm-coding-zenka-prompt-transport.md` / the landed
`data.mount.shm.cleanup` ] registers every created segment into
`$data{'mount'}{'shm'}{'segments'}` and **never removes an entry** — that is
correct *there* because that registry only ever has to answer "what did this
process create, full stop," for a one-shot transport with no concept of a slot
being recycled mid-process-lifetime.

**the pool cannot reuse that pattern verbatim.** a channel's slot registry must
support **deregistration**, not just registration, because slots cycle through
`used` → `unused` → reused-or-released *during normal operation*, long before
the zenka itself shuts down. if the registry only ever grew, the shutdown wipe
below would see entries for slots already cleanly released earlier in the
pool's own lifecycle and either redundantly act on them or — worse — act on a
stale path that something else has since reused. so: **register a slot's path
into the channel's own registry at slot creation ; deregister it when the slot
is actually `unlink`ed [ the drained → released transition, not active →
drained — a slot stays registered while it is a warm spare, since it still
exists on disk and still needs wiping on an unexpected shutdown ].**

a **separate, channel-specific** end_code callback [ registered the same way
phase 4 part A's `data.mount.shm.cleanup` was — `push <callbacks.end_code>->@*,
qw| your.channel.cleanup.module |`, **not** reusing `data.mount.shm.cleanup`
itself, since that one's registry and this one's are different lists with
different recycling semantics ] fires on the sender's own unexpected
`SIGTERM`/`SIGINT`/normal exit and **wipes + releases every slot still in the
channel's registry, regardless of `state`** — this is the one place `state`/
`refcount` gating is correctly **bypassed**, and the reason is specific to
*who* is shutting down: the writer owns every slot's lifetime [ "writer owns
the segment lifetime," carried throughout this design ], and if the writer
process itself is exiting, no further legitimate write — or, by the same logic,
no further legitimate *read* originating from work *this process* would have
coordinated — is coming. a reader [ p7-log ] still attached mid-read when the
writer vanishes is already a handled case elsewhere in this doc [ "on p7-log
disconnect / restart" / "on sender death" above ] — it is a disconnect, not a
correctness violation, and the reader's fallback-to-cube path covers it. **so
the shutdown wipe does not need to wait for `refcount` to reach 0** — it
erases and unlinks everything still registered, unconditionally, because the
owner leaving *is* the end of every reference's validity, not a thing to
politely wait out.

this end_code wipe is the **fast, graceful** path — it still does not cover
`SIGKILL`, same limitation phase 4 part A has generally. that gap is exactly
phase 4 part B's TTL sweep [ `amos7-shm-phase4-ttl-reap-sweep.md`, already
landed ], which reaps the whole pool via the prefix-glob already named in
"on sender death" above, regardless of whether any per-channel end_code ever
ran.

### secure erase — the project's own `base.erase_buffer_content` idiom, adapted

the precedent is `src/base.erase_buffer_content`. read in source: it
overwrites the buffer with PRNG entropy via
`substr( $buffer_sref->$*, 0, $r_cnt, <[base.prng.characters]>->($r_cnt) )`
[ `:26` ] where `$r_cnt` is the real content length **plus randomized padding**
`$padding_bytes //= int( rand(13) ) + 7` [ `:9`, `:21` ] — the extra bytes
deliberately **mask the true content length** from anyone inspecting the erased
buffer afterward. it then truncates with `$buffer_sref->$* = ''` [ `:28` ].

apply this idiom to a slot's **content region** at the **active → drained**
transition — erase immediately when the reader finishes with a slot, before it
becomes a spare or gets released. **two adaptations are required, not a verbatim
port**:

- **no truncate.** the final `$$ref = ''` [ `:28` ] is meaningless for a
  fixed-size mmap segment — there is nothing to truncate, the segment stays its
  fixed size. the adapted idiom is **overwrite-in-place only**: write
  `real_record_bytes + int( rand(13) ) + 7` entropy bytes into the slot's
  content region [ **capped at the slot's content size** — never past the
  segment end ], and stop. the length-masking rationale carries over but its
  meaning shifts: it now masks the **valid-data boundary within the fixed slot**
  [ how far the real records extended ] from a later inspector of the spare.

- **standalone-safe entropy source.** `AMOS7::SHM.pm` is the standalone-or-zenka
  hybrid core — **no `<[...]>` zenka-bracket syntax is allowed in it** [ same
  rule as everywhere in this SHM work ]. so `<[base.prng.characters]>` cannot be
  called there. the project's own standalone entropy engine is already a
  dependency and already the engine *behind* `base.prng.characters`: that module
  calls `<base.prng.fortuna>->string_from(...)`, i.e. a **`Crypt::PRNG::Fortuna`**
  object. `Crypt::PRNG::Fortuna` is loaded standalone elsewhere in this codebase
  already — `data/lib-path/pm/AMOS7/13.pm:26` [ `use Crypt::PRNG::Fortuna qw| irand |` ]
  and `data/lib-path/pm/AMOS7/TERM.pm:23` [ `qw| rand | ` ]. confirmed this
  session that `Crypt::PRNG::Fortuna` exposes **`random_bytes($n)`** [ also
  `bytes` / `string_from` ]. mirror the functional-import form 13.pm already
  uses [ `use Crypt::PRNG::Fortuna qw| irand |; irand()` ] so an implementer
  does not hit a method-vs-function `$self` surprise. the standalone-safe
  secure-erase fill:

  ```perl
  ## at top of AMOS7::SHM::Channel : import the byte source by name           ##
  use Crypt::PRNG::Fortuna qw| random_bytes |;

  ## secure-erase a slot's content region in place [ standalone-safe ]        ##
  ## overwrite real_len + randomized padding with fortuna entropy, capped to  ##
  ## the slot content size ; NO truncate [ fixed-size mmap segment ]          ##
  my $pad      = int( rand(13) ) + 7;             ## mask the data boundary    ##
  my $fill_len = $real_len + $pad;
  $fill_len = $slot_content_size if $fill_len > $slot_content_size;
  substr( ${ $slot->{'mmap_ptr'} }, $content_offset, $fill_len )
      = random_bytes($fill_len);
  ```

  no new dependency is introduced — `Crypt::PRNG` / `Crypt::Misc` are already
  pervasive across `AMOS7::*` standalone packages. the zenka thin-wrapper path
  may still route through `<[base.prng.characters]>` if preferred, but the
  standalone core must use `Crypt::PRNG::Fortuna::random_bytes` directly.

### swap protection — confirm and don't break it, ZERO new code

the precedent the project owner pointed at is the C25519 key-locking pattern
`IO::AIO::aio_mlock( $keys{'C25519'}{$name}{'private'}, 0, 64 )` — the real
occurrences live in `src/crypt.C25519.gen_keys:114` [ and `:375`,
`load_keys_from_secret:147`, etc. ], **not** in `AMOS7::SHM.pm`. confirmed from
`AMOS7::SHM`'s `shm_create`: **`mlock` is already a default-on option** —
`'mlocked' => $options->{'mlock'} // 1` [ `data/lib-path/pm/AMOS7/SHM.pm:537` ],
composed through the already-landed `lock_memory` / `unlock_memory` pair [ `:290`,
`:336` ] with the self-detecting `_io_aio_fork_guard` from phase 1.

**stated explicitly: no new code is needed for swap protection.** every pool
slot is an ordinary `AMOS7::SHM::shm_create` segment, so it gets `mlock` by
default automatically — **as long as the pool-creation call does not override
the default to `mlock => 0`**. this is a "confirm and don't break it" item, not a
build item.

## the handshake design

### who initiates, and what the key-echo proves here

**recommendation: `p7-log` advertises the capability and generates + delivers
the nonce; the sender echoes it back through the new SHM channel.** this is the
backward-compatible direction and it gets the security property right.

the precedent is `src/base.cmd.verify-instance` + `v7.zenka.set_cube_sid`:
v7 generates a private 13-char key [ `v7.zenka.set_cube_sid:43`,
`uc(<[base.prng.chars-anum]>->(13))` ], hands it to the instance over a **direct
command** [ `:57-61` ], and then watches the instance's own log stream for the
echo [ `cfg/zenki/v7/zenka-output.patterns:29`,
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
2. **the sender's proof = echo the nonce as the content of the FIRST active
   pool segment it creates.** the ring is gone, so there is no "first frame" —
   the equivalent is the **first active slot**. the sender creates its first pool
   segment [ `shm_create`, granting p7-log read ] and writes the nonce as that
   slot's content [ as the first framed record in it, before any real log
   record ]. `p7-log` opens the slot read-only and reads the nonce back. because
   `/dev/shm` is world-readable, *seeing* a nonce is not proof — but **writing**
   the correct nonce into a segment whose write access is granted to the
   sender's pubkey, in response to a nonce that only the authenticated session
   received, proves all three things at once:
   - **identity**: the writer is the same entity as the authenticated cube
     session [ the verify-instance property — it received the private nonce ].
   - **the sender can write** a pool segment [ it produced one containing the
     nonce ].
   - **p7-log can read** the pool segment end-to-end [ it got the nonce back ].
3. **what is confirmed before the switch**: channel created [ sender created the
   first segment + granted p7-log read ]; both ends opened it [ proven by the
   echoed nonce making the full round trip ]; and the **pool state at switchover
   is unambiguous** — see the next point, the nonce-bearing slot is the cut.

### the nonce-bearing first slot is the ordering cut-point — no separate sync negotiation

the echoed nonce doubles as the **barrier** between the two transports, the clean
answer to "no line duplicated or dropped during transition":

- **everything up to and including the nonce-delivery `cmd.append`** went via the
  per-line cube path, as today.
- **the nonce is the first record in the first active slot.** when `p7-log` reads
  and matches it, it records "source X switched to SHM as of nonce N" and **stops
  expecting cube `cmd.append`s from X** [ the sender stops sending them ].
- **the first real log record is the next framed record after the nonce** [ in
  the same slot, or the next slot in the pool once that one seals ]. there is no
  overlap window: the sender does not write a real record into the pool until it
  has written the nonce, and does not send another cube `cmd.append` once it has
  begun writing the pool. the echoed nonce **is** the synced confirmation — no
  separate "is the pool empty" handshake is needed.

### switchover mechanics — sender side [ `base.log.send-buffer.send-idle-callback` ]

additive, behind a per-buffer state flag. **today's path is the
`else` / per-line branch; it stays the default and the fallback.**

```perl
## per send-buffer, a transport state : 'cube' [ today ] | 'handshaking' |    ##
## 'shm'. defaults to 'cube' — unset means today's behavior, unchanged.       ##
my $transport = <log.send-buffer>->{$name}->{'transport'} // qw| cube |;

if ( $transport eq qw| shm | ) {
    ## fast path : pack the record into the current active slot, no cube cmd   ##
    ## [ AMOS7::SHM::Channel::write_record — see "where the generic part       ##
    ##   lives" ; record = ( buffer_name, log_time, log_level, log_message )   ##
    ##   exactly as p7-log.cmd.append:104 reassembles ]. if the active slot is ##
    ##   full, Channel seals it and grows the pool [ reuse a warm spare, or    ##
    ##   shm_create a new active slot ] — see the segment-pool design.         ##
    my $ok = <[data.channel.shm.transport.write]>->( $channel_id, \@record );
    if ($ok) {
        ## DO NOT shift here — a pool write is NOT delivery [ see below ].     ##
        ## the line stays queued until p7-log ACKS durable consumption via the ##
        ## ack-by-slot-index feedback region ; a separate ack-reaping step     ##
        ## shifts everything up to last_acked_slot off $b_ref->{'data'}.       ##
        ## learns of new data via the FIFO ding [ below ].                     ##
    } else {
        ## pool exhausted / write failed [ e.g. a hard slot-count ceiling hit  ##
        ## with no acks freeing slots ] : fall back for THIS line, see         ##
        ## "failure" [ the line is still queued — nothing was shifted ]        ##
        <[base.log.send-buffer.fallback-to-cube]>->($name);
    }
} elsif ( $transport eq qw| handshaking | ) {
    ## awaiting the nonce in a cmd.append reply ; keep sending via cube until  ##
    ## the reply arrives and we write+confirm the nonce in the first slot      ##
    ## [ no overlap ] ... existing per-line send, plus the 'shm-capable' marker ##
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

`p7-log` needs a **new per-source pool reader loop alongside** its existing
`cmd.append` cube path — `cmd.append` is NOT removed; it remains the path for
non-upgraded sources and the fallback target. the reader loop is driven by the
**FIFO ding**, exactly the phase-3 `AMOS7::SHM::Feedback` mechanism, watched via
`base.event.add_io`:

- `src/base.event.add_io` takes a filehandle + `handler` + `timeout` /
  `timeout_cb` [ `base.event.add_io:3-4,16-46` ] — install one watcher on the
  read end of the channel's `.notify` FIFO. when the sender dings, the handler
  reads each **un-consumed active slot in order** [ `shm_open` read-only, unpack
  its framed records ] and feeds each record through the **same**
  `<[p7-log.add_line]>` write path `cmd.append:108` already uses. **the
  record-handling logic is shared; only the intake differs.**
- after durably writing all records of a slot, the reader **publishes the
  slot index it has fully consumed through** [ the ack-by-slot-index feedback
  region, below ] and dings nothing — the sender reads that on its own. the
  reader's per-slot completion is what lets the sender transition that slot
  active → drained [ erase + warm-spare ] and shift the matching lines off its
  outstanding queue.
- this is event-driven, no poll loop — the same reason phase 3 chose FIFO +
  `Event->io()` over `Event->var()` / inotify, both tested and ruled out for
  mmap writes [ `amos7-shm-paging-feedback.md:308-341` ].
- a `timeout_cb` on the watcher is the stalled-sender liveness check [ same
  pattern phase 3 used for the stalled-reader case ].

**note**: the old ring's `data.channel.shm.poll` was **poll-only** [ `:17-21`
returns a `has_data` flag, no notify FIFO ]. the pool model does not inherit the
ring at all — instead it **reuses phase-3 `AMOS7::SHM::Feedback`'s already-landed
FIFO-ding atom** [ `create_notify_fifo` / `ding` / `watch_fifo` ] directly. the
ding is not "free in the ring code" because there is no ring code in this design;
it is composed from the proven phase-3 atom — see the reframed gap section.

### failure / disconnect mid-stream — degrade to cube without loss or duplication

this is **the harder-than-prompt-transport part** and must be designed, not
hoped. the invariants:

- **shift on ACK, not on write — a pool write is NOT delivery.** the segments are
  sender-owned in world-readable `/dev/shm`; a record packed into a slot but not
  yet durably read by p7-log has not reached the log file, and would be lost on
  p7-log disconnect or sender-death-TTL-reap. so the sender keeps every line in
  `$b_ref->{'data'}` until p7-log **acks durable consumption** via the
  ack-by-slot-index feedback region [ gap #3 ], then `shift`s everything up to
  the records of `last_acked_slot` off the queue. a **failed** pool write shifts
  nothing — the line stays queued. **no line is dropped on write failure, on
  disconnect, or on reap, because nothing is removed from the queue until it is
  durably acked.** [ this is *why* the feedback channel exists — it is not an
  optimization, it is the exactly-once mechanism. this invariant is identical to
  the rejected-ring version; only the ack granularity changed from a byte
  `read_pos` to a slot index. ]
- **"acked" means p7-log durably WROTE the records of a slot**, i.e.
  `<[p7-log.add_line]>` returned success for every record in that slot
  [ `cmd.append:108` is the same write path the pool reader feeds ], **not**
  merely "read the slot." otherwise a p7-log crash between slot-read and
  file-write would lose lines the sender already considered acked. the
  slot-index the reader publishes advances **only after the durable write of all
  that slot's records succeeds** — so a slot is acked **whole** [ a partially-
  consumed slot is not yet acked, and on a crash mid-slot the sender re-supplies
  that slot's records, unduplicated, because none were shifted ].
- **fallback is per-source and atomic at a known cut**: on pool-exhaustion,
  write-error, or p7-log signalling it can no longer read, the sender sets its
  buffer `transport` back to `cube` and resumes the per-line path **from the
  first not-yet-acked line** — which, by the shift-on-ack discipline above, is
  exactly `$b_ref->{'data'}->[0]`, the front of the still-queued lines. this
  requires the sender to know **which slot index p7-log has durably consumed
  through** — which a bare segment does NOT provide [ see gap #3 ]. the
  **reader→writer ack-by-slot-index feedback channel** [ phase-3 `Feedback`'s
  reader-writes-its-own-position technique, the *position value is now a slot
  index* rather than a page or byte offset ] is what makes exactly-once fallback
  possible: lines in slots past `last_acked_slot` were never shifted, so resuming
  cube sends re-sends **none** of the acked lines [ no duplication ] and skips
  **none** of the unacked ones [ no loss ]. [ open question 1 option (a) — a
  **p7-log-owned** ack region — is what makes this work cross-user *and* is the
  mechanism behind shift-on-ack: p7-log writes its own ack segment [ same-user,
  no cross-user-write tension ], the sender reads it to advance `last_acked_slot`
  and shift. ]
- **on p7-log disconnect / restart**: the channel segments are owned by the
  **sender** [ writer-owns-lifetime, carried from the prompt-transport doc ].
  if p7-log goes away, its FIFO read end closes; the sender's `write_record`
  eventually fails [ the active pool grows to its ceiling with no acks freeing
  slots into the warm-spare tier ] and it falls back to cube, which will itself
  pause until p7-log is back online [ the existing `notify_online` liveness gate,
  `send-idle-callback:62-79` ]. no line is lost because none was `shift`ed
  without an ack.
- **on sender death**: phase 4 cleanup [ writer-owned, + a TTL safety-net sweep,
  exactly as `amos7-shm-coding-zenka-prompt-transport.md` specifies ] reaps **all
  the orphaned pool segments + the FIFO**. p7-log drains whatever slots are
  already committed before they are reaped [ committed slots are the sender's
  acked-as-written work ]. note the pool has *N* segments to reap, not one — the
  sweep must enumerate the whole pool [ a shared sub_path prefix per channel
  makes this a clean prefix-glob ; see open questions ].

### the correctness bar is higher than one-shot transport — stated explicitly

`amos7-shm-coding-zenka-prompt-transport.md` moves **one bounded scalar once**;
if it fails, the caller retries the whole thing — there is no ordering or
exactly-once concern, the checksum verify is the whole correctness story. **this
design is different and harder**: a log stream is **continuous, ordered, and
exactly-once**. a duplicated log line corrupts the append-ordered log file; a
dropped line loses data silently. so this design carries two correctness
mechanisms the prompt-transport doc does not need: **(a)** length-prefix framing
*within each slot* preserves intra-slot order and slots are consumed in pool
order, so the whole stream stays ordered, and **(b)** the ack-by-slot-index
feedback channel makes the cube fallback exactly-once. call this out to whoever
implements: **do not port the one-shot doc's "announce, pull, verify checksum,
done" mental model here — the stream never ends and the fallback must be
lossless.**

## the gap section — reframed for the segment-pool model

the original three ring gaps are re-evaluated against the pool design. one is
**dissolved by the architecture change itself** [ not "fixed" ]; the other two
still need solving, but now compose cleanly from already-landed phase-3 atoms
rather than needing new ring code.

1. **notify — still needed, but composed from phase-3, not built fresh.** the
   pool has no `poll` and needs none. p7-log must be woken when the sender writes
   new records, without polling every channel. **resolved by reusing**
   `AMOS7::SHM::Feedback`'s already-landed FIFO-ding atom
   [ `amos7-shm-paging-feedback.md` phase 3, `create_notify_fifo` / `ding` /
   `watch_fifo` + `base.event.add_io` ] — the same mechanism, applied per
   channel. this is a **compose**, not a build: the atom exists and is
   cross-process-proven [ phase 3 acceptance ]. open: one FIFO per channel vs one
   per slot [ see open questions ].

2. **wrap-around data-corruption — DISSOLVED, not applicable.** the ring's gap #2
   [ the `data.channel.shm.write:26-45` clobber detailed in the historical
   section above ] **cannot exist in the pool model**: there is **no shared
   free-space arithmetic between slots at all**. each slot is a whole, independent
   `AMOS7::SHM` segment with its own fixed content region; the only intra-slot
   accounting is "does the next framed record fit in the remaining bytes of *this*
   slot," and if not, the slot is **sealed and a new active slot is added** — no
   wrap, no `write_pos` reset over a shared buffer, nothing to overwrite. **this
   is the central reason the architecture was changed**: the bug class is
   designed out, not patched. confirm in the doc as "not applicable," not "fixed."

3. **reader→writer ack — still needed, composed from phase-3, granularity
   changed.** the sender must learn **which slot index p7-log has durably
   consumed through**, as an ack it can trust, to drive both shift-on-ack and the
   active → drained [ erase + warm-spare ] transition. **resolved by reusing**
   phase-3 `Feedback`'s reader-sole-writer position region [ + ntime freshness
   stamp, clamped to the announced range by the sole reader of it, the writer ] —
   **the only change is the position value's meaning: a slot index, not a page
   or byte offset.** this is the same single-writer-per-region lock-free shape
   phase 3 already proved cross-process; it composes onto the pool unchanged
   except for what the integer counts. it does **carry forward** the genuine
   cross-user-write tension [ p7-log writes this region into a possibly-taeki-
   owned channel ] — see open question 1, unchanged in force by the redesign.

**note — dropped non-issues, re-confirmed**: slot indices fit comfortably in 32
or 64 bits; intra-slot length framing preserves order. neither is a gap.

## does this generalize beyond p7-log? — yes : a THIRD distinct SHM use case

the task asked whether this is log-specific or a nameable pattern. it is a
**third distinct `AMOS7::SHM` use case**, alongside:

| use case | shape | primitive |
|---|---|---|
| one-shot paged transport [ prompt-transport doc ] | move one bounded scalar once, pull-based, verify-checksum-done | `AMOS7::SHM::Page` + `Transport` |
| data zenka internal [ legacy ring, unused at runtime ] | low-latency bidirectional channel traffic | `data.channel.shm.*` ring |
| **continuous-stream-with-handshake-and-ack [ THIS doc ]** | unbounded ordered stream, identity-proven switchover, lossless fallback | **new : segment-pool + ack-by-slot-index feedback + key-echo confirmation** |

**neither existing tool provides this today** — say it plainly:

- the legacy `data.channel.shm.*` ring is **not used at runtime** [ verified —
  only the self-test calls it ] and carries the wrap-around clobber bug ; the new
  design **does not build on it at all**. it is orphaned as a building block.
- phase-3 `AMOS7::SHM::Feedback` has the reader-writes-position + FIFO-notify
  atoms, proven cross-process — and the pool design **reuses those atoms
  directly** [ FIFO ding for notify, position region re-purposed to carry a slot
  index ]. what is new is the **pool management** [ create / seal / rotate / erase
  / retire of fixed-size segments ] and the **key-echo confirmation step**.

### where the generic part should live

the generic, reusable part is **segment-pool management + ack-by-slot-index
feedback + key-echo confirmation** — recommend a new standalone-loadable sibling
**`data/lib-path/pm/AMOS7/SHM/Channel.pm`**, mirroring the
`Page.pm` / `Feedback.pm` layout [ `amos7-shm-paging-feedback.md:182-186` ],
that **composes**:

- a **pool of fixed-size `AMOS7::SHM::shm_create` segments** [ each holding
  length-framed records ], with the three-state slot lifecycle [ active /
  drained-and-erased-warm-spare / released ] and the secure-erase-on-drain step
  — **no new low-level mmap / header / permission mechanics, all phase-1 atoms**,
- `AMOS7::SHM::Feedback`'s position region + FIFO-notify atom [ reused, not
  re-derived ; position value carries a slot index ],
- a small generic **key-echo confirmation step** [ the verify-instance property,
  generalized: "the first active slot must contain a nonce delivered over the
  trusted path" ].

thin zenka wrappers `src/data.channel.shm.transport.*` follow the same
pattern as the prompt-transport doc's `data.mount.shm.transport.*` — **these are
new modules, NOT the legacy `data.channel.shm.{create,write,read,poll}` ring
modules**, which stay untouched and unused. **stays under `data.channel.shm.*` /
`AMOS7::SHM::*`, never `base.*`** — the namespace lesson, repeated. the key-echo
confirmation step is generic enough that it could later serve any "prove the same
authenticated peer opened the new channel" need, not only logging — but **do not
build that generality speculatively**; extract `Channel.pm` to serve p7-log
first, note the reuse potential.

### carried over from the prompt-transport doc — referenced, not re-derived

- **writer owns the segment lifetime** [ sender creates + grants, p7-log opens
  read-only ] — `amos7-shm-coding-zenka-prompt-transport.md` "phase 4 is a
  prerequisite" + "writer owns the segment lifetime".
- **p7-log opens slots read-only** [ `shm_open` read-only mode — **already
  present**, `SHM.pm:609`: `$open_mode = (($options->{'mode'}//'') eq 'read') ?
  '<' : '+<'` ; no new code needed for the read side ] — and **this is a
  genuinely cross-user pair**: senders may run as `taeki`
  [ coding-admin-group ] or as bare `protocol-7` [ `task`, etc. ], while
  **`p7-log` itself is bare `protocol-7`** [ `cfg/zenki/p7-log/zenka.v7:24`,
  bare `[root.drop_privs:<system.amos-zenka-user>]` ]. a `taeki`-owned segment
  read by a bare-`protocol-7` p7-log is exactly the `'+<'`-EACCES case the
  read-only open fixes [ `/dev/shm` world-readable ]. **but** the sender here is
  also a **writer that the reader writes back to** [ the ack-by-slot-index region ],
  so this design hits the **reader-write cross-user tension** the
  prompt-transport doc explicitly deferred — see open question 1.

## phased plan

- **phase A — the segment pool core**: build the standalone-loadable
  `AMOS7::SHM::Channel` pool over phase-1 `shm_create` — create / seal / rotate
  fixed-size slots, intra-slot length-framing, the three-state lifecycle
  [ active / drained-and-erased-warm-spare / released ] including the
  secure-erase-on-drain step [ `Crypt::PRNG::Fortuna::random_bytes`,
  overwrite-in-place, no truncate ]. thin **new** `data.channel.shm.transport.*`
  wrappers call through — the legacy ring modules are untouched.
  `p7c data.shm-self-test` passes unchanged. **hard gate**, same as every prior
  phase. **no gap-#2 fix to do — the bug class is designed out** [ no ring ].
- **phase B — compose notify + ack-by-slot-index feedback** [ gaps #1, #3 ] onto
  the pool from `AMOS7::SHM::Feedback`'s already-landed atoms [ FIFO ding +
  position region carrying a slot index ]. cross-process proven with a standalone
  fork + timing-gap script, **never a same-process check** [ the phase-3 lesson,
  `amos7-shm-paging-feedback.md` "how this landed" ].
- **phase C — the handshake**: nonce-in-cmd.append-reply, echo-as-content-of-
  first-active-slot, the `transport` state flag in `send-idle-callback`, the
  FIFO-driven pool reader loop in p7-log alongside `cmd.append`.
- **phase D — fallback correctness**: pool-exhaustion / disconnect / sender-death
  paths, exactly-once via `last_acked_slot`, the TTL safety-net sweep over the
  **whole pool** [ prefix-glob ]. phase 4 cleanup is a hard prerequisite, same as
  the prompt-transport doc — and must reap **all** pool segments + the FIFO, not
  a single segment.

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

- [ ] `AMOS7::SHM::Channel` is loadable standalone + in-zenka, composing a pool
      of fixed-size `shm_create` segments + `AMOS7::SHM::Feedback`'s position+FIFO
      atoms [ position = slot index ] + a generic key-echo confirmation — **no
      new mmap / header / permission mechanics**
- [ ] capacity grows by adding active slots and shrinks by retiring them; the
      three-state lifecycle is observable — a consumed slot is **securely erased
      in place** [ entropy + randomized length-mask, no truncate ] at active →
      drained, kept as a **warm spare**, and only `unlink`ed after a longer decay
- [ ] a slot that fills is sealed and a new active slot added — **no shared
      free-space arithmetic, no wrap, nothing overwrites unread records** [ the
      ring's gap #2 is structurally impossible, proven with a sustained
      fill-faster-than-the-reader test that shows growth, not clobber ]
- [ ] a handshake-capable sender and an upgraded p7-log complete the
      nonce-in-reply / nonce-as-first-active-slot handshake; an old sender OR an
      old p7-log silently stays on the per-line cube path
- [ ] after switchover, log records flow writer→pool→p7-log via the FIFO ding
      [ `base.event.add_io` ], in write order, with **no** cube command per line
- [ ] mid-stream pool-exhaustion / p7-log-disconnect / sender-death all degrade
      to the per-line cube path with **no line dropped and no line duplicated** —
      proven with an ordered-sequence test that injects a failure mid-stream and
      checks the written log file is exactly the input, once, in order
- [ ] p7-log opens pool slots read-only and the transfer works **cross-user**
      [ `taeki`-owned segments, bare-`protocol-7` p7-log ] — genuinely cross-user
      test, not a same-user fork [ note: the read-only `shm_open` mode this needs
      already exists, `SHM.pm:609` ]
- [ ] every existing per-line `cmd.append` call is byte-for-byte unchanged; the
      capability marker is ignorable by the old 6-field parse
- [ ] `p7c data.shm-self-test` passes unchanged [ legacy ring untouched ] + new
      channel checks
- [ ] no new SHM mechanics under `base.*`

## open questions [ for the project owner — do not decide unilaterally ]

1. **[ MOST IMPORTANT ] the reader-write cross-user tension this design forces
   into the open.** the read-only `shm_open` mode [ `SHM.pm:609`, already present ]
   makes the **data slots** cross-user-clean — p7-log only reads those. but the
   **ack-by-slot-index region is *written by the reader*** [ p7-log, bare
   `protocol-7` ] into a channel whose segments may be **owned by a `taeki`
   sender** [ coding-admin-group, or another `taeki`-running zenka ]. a
   world-readable segment is not world-*writable*, and read-only-open does **not**
   touch this — it remains the genuine cross-user-write problem. **the options**:
   (a) the ack region is a **separate** small segment owned by **p7-log**
   [ writer-of-ack owns it ], so p7-log writes its own file and the sender reads
   it [ inverting ownership per-region — clean, matches "single writer owns its
   region," but means a second segment [ + possibly a second FIFO ] per channel ];
   (b) a shared unix group both sides join + a group-writable ack segment
   [ reintroduces the OS-perm dependency the project avoids ];
   (c) restrict the SHM log fast-path to **same-user** sender/p7-log pairs only
   [ e.g. only `protocol-7`-user zenki like `task` → `protocol-7` p7-log ], and
   leave `taeki`-running senders on the cube path. **which ownership model for
   the ack region?** (a) looks right and is the project-native "each region has
   one owner-writer" answer, but it adds a per-channel object — confirm before
   building, as it sets the `AMOS7::SHM::Channel` shape. [ unchanged in force by
   the ring→pool redesign — only the position value's meaning changed. ]

2. **warm-spare decay period and pool ceiling.** the three-state lifecycle
   introduces two tunables with no obvious right value: **(a)** how long does a
   drained-and-erased warm spare sit before it is actually `unlink`ed
   [ the active → drained transition is immediate; the drained → released decay
   is deliberately slower — but how much slower? a fixed seconds-timer, or scaled
   to recent burst frequency? ]; and **(b)** how many warm spares to keep before
   forcing release [ a soft target ], and is there a **hard ceiling on total
   active+spare slots** that, when hit with no acks freeing slots, triggers the
   per-line cube fallback? the fallback path depends on this ceiling existing —
   confirm whether it is a fixed count, a total-bytes budget, or adaptive.

3. **the capability marker on the wire.** the sender advertises handshake
   capability via the `cmd.append` `args`. an extra trailing token risks the
   6-field `split( m| |, $param_str, 6 )` [ `p7-log.cmd.append:11` ] folding it
   into `log_message`. safer as a multiline `param` an old p7-log ignores, or a
   distinct out-of-band `p7-log.shm-offer` command? leaning out-of-band command
   for cleanliness, but it adds one command round-trip per source [ one-time,
   negligible ] — confirm.

4. **per-source pool, and uniform vs varying slot size.** one pool per
   (source-zenka, instance) pair, or one shared multi-writer pool into p7-log? a
   shared pool breaks the single-writer-per-slot lock-free property and
   reintroduces contention, so **per-source** is strongly recommended — but that
   means p7-log holds N FIFO watchers for N active log sources [ how many distinct
   log sources does cube relay for, in the heaviest deployment? ]. **and a
   sub-question the pool model newly raises**: should every slot in a pool be the
   **same fixed size** [ simplest — one `page_size` for all, uniform warm-spare
   reuse ], or could slot size vary [ e.g. a larger slot under heavy burst ]?
   uniform is recommended for warm-spare interchangeability, but a record larger
   than one slot's content region needs an answer regardless — confirm uniform +
   a max-record-size policy.

5. **records-per-slot / slot-size sizing.** a slot holds a *batch* of
   length-framed records, not one line — so slot size sets the
   records-per-slot batching factor, which trades off per-slot overhead [ create
   / seal / erase / ack cost amortized over more records ] against latency [ a
   record is not visible to p7-log until its slot is dinged ; an under-filled
   slot must still be sealed and dinged on an idle-flush so a low-rate source is
   not stranded mid-slot ]. **how big is a slot, and what idle-flush policy seals
   a partially-filled active slot?** this is the pool analogue of the old "ring
   capacity" choice, but with a real latency dimension the ring did not have.

#,,,,,.,.,,.,,.,.,,,,,...,.,,,..,,.,.,,,.,,.,,..,,...,...,,,,,...,.,,,...,.,.,
#KJMC6E32LYQK4R3ZUP3UGMEG22BJG6WIR6WFZKYJAGYKCEZX4BKHN5N4Q2PAWYYY5HK34SIHZI57Y
#\\\|RSW55OJHRY2Z6K5Q2JFSQ4XVWNO24SIEFAQ33ST7LHXVFZGT34U \ / AMOS7 \ YOURUM ::
#\[7]ERTZFIC2RCDBAWUJMJNQGIW5PLM54XM3YIY2RYNKX3CDG5WLMOAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
