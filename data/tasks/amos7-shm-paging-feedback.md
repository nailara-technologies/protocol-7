# task: AMOS7::SHM — standalone-hybrid paged shared-memory transfer with feedback channel

## status [ 2026-06-22 ]

**phases 1 and 2 are implemented and live-verified.** phase 1 (standalone
`AMOS7::SHM` promotion) committed `410805f43`. phase 2 (paging, see "phase 2
— DONE" below) committed same day. **phase 3's design is now fully resolved**
[ FIFO notify mechanism + ntime freshness stamp + the `data.channel.shm.*`
question — all settled by empirical testing this session, not preference,
see "RESOLVED" below ] but **not yet implemented** — nothing for phase 3
exists on disk. phase 4 (cleanup hooks) is still design only. read "phase 1 —
DONE" / "phase 2 — DONE" for what's actually built, then the "RESOLVED" /
"phase 3 —" sections for what to implement next.

## signatures note

do NOT add the single-line `#,,.,,,...` stub at end of new files.
leave files clean — signatures are added by the signing system automatically.

## objective

provide a **generic, reusable, secure, paged shared-memory transfer
mechanism** for moving large scalar values between same-trust-domain P7
commands / zenki — and between standalone scripts and zenki — without
shipping the payload across a cube command line.

today there is no such generic path. the motivating incident
[ see "why this design exists" ] was a one-off: `bin/mcp-server-p7` needed to
checksum up to ~400KB of session text and routed it through a cube-exposed
command [ `bmw-L13 :B32:<encoded content>` ] as a single command line.
`modules/base.handler.command`'s single-line command buffer caps at
**242707 bytes**; the ~640KB B32-encoded payload blew past it. the failure was
not clean — a `session_catchup` against a 30MB session appeared to hang
indefinitely with no buffer-exceeded message in the log, the connection simply
left in a bad state. the fix applied *there* was specific to that call: port
the checksum algorithm to run standalone inside `bin/mcp-server-p7`, avoiding
the wire entirely for that one case [ landed — see
`data/tasks/task-summary-topic-tree.md`, the "BMW-L13 checksum switch" /
"how each origin computes bmw-L13" sections ].

this task generalizes that escape so the **next** command needing a large
scalar parameter does not need its own bespoke workaround: a paged SHM channel
the writer announces and the reader pulls from, with cryptographic
[ not OS-permission ] access control already provided by the existing
`data.mount.shm.*` family, and a standalone-loadable `AMOS7::SHM::*` core so
scripts get the same mechanism zenki do.

## what to read first

```bash
ls modules/data.mount.shm.*                          ## the 27-module foundation
cat modules/data.mount.shm.create                    ## file-backed mmap segment + $mount hashref
cat modules/data.mount.shm.open                       ## owner-pubkey path/header cross-check
cat modules/data.mount.shm.permission.verify          ## signed-grant authorization [ the real gate ]
cat modules/data.mount.shm.header.read                ## 512-byte text header pack/unpack
cat modules/data.mount.shm.init_code                  ## SIGINT handler [ unlocks, does NOT unlink ]
cat modules/data.mount.shm.test.basic                 ## current access = bare substr() at offset 512
cat configuration/zenki/data/start                     ## confirms data.* = the data zenka's own load set
cat modules/data.channel.shm.create                    ## existing ring-buffer ; read before phase 3
cat modules/data.cmd.shm-self-test                      ## the regression gate every phase must keep passing
cat modules/jobqueue.event.register_job_queues        ## tested as a candidate, ruled out -- see RESOLVED
cat modules/base.event.add_var                         ## generic Event->var() wrapper jobqueue calls
cat data/lib-path/pm/AMOS7/CHKSUM.pm                   ## the standalone/hybrid precedent to mirror
cat modules/base.chk-sum.amos                          ## thin zenka wrapper -> standalone package fn
sed -n '1,60p' data/tasks/shm-streaming-payload-pipeline.md  ## ADJACENT, DIFFERENT — do not merge [ see below ]
```

## what already exists vs what is new

### what already exists [ the foundation — landed, real code ]

`modules/data.mount.shm.*` [ 27 modules ] already implements file-backed SHM
mounting with cryptographic access control. verified against the actual code:

- **segment creation**: `data.mount.shm.create($pubkey, $size_bytes,
  {mlock=>0|1})` creates a file-backed mmap segment [ via `Sys::Mmap`, with a
  scalar-ref fallback ] at `/dev/shm/p7:M:<PUBKEY>:<SUBPATH>` —
  deliberately **file-backed, not POSIX/SysV shm**, for portability. returns a
  `$mount` hashref: `path`, `type` [ `'file'` ], `total_size`, `mmap_ptr`
  [ a scalar ref — `substr(${$mount->{mmap_ptr}}, $offset, $len)` reads/writes
  directly into the mapped region, no read-load-write cycle ].
- **header**: 512 bytes, text-based, colon-delimited —
  `P7SH:<version>:<owner_pubkey>:<created_ntime>:<data_size>:<hdr_size>:<flags>:\n`
  then null-padded to 512. flags are comma-separated `key=0/1`
  [ `mlocked`, `encrypted`, `compressed` ]. `data.mount.shm.header.read` /
  `.write` [ aka `.unpack_shm_header` / `.pack_shm_header` ] parse / build it.
- **security is real, not metadata-only**: `data.mount.shm.open` parses the
  owner pubkey out of the path and cross-checks it against the header's
  `owner_pubkey` field [ consistency check ]. actual authorization is
  `data.mount.shm.permission.verify` — owner always has full access;
  non-owners are checked against a `header->{permissions}` list of **signed**
  grants [ signed by the owner's C25519 private key ], each checked for expiry,
  requester-pubkey-or-group match, path-pattern match, and rights sufficiency
  [ sub-checks: `.path_pattern_match`, `.rights_sufficient`, `.group_contains`,
  `.verify_permission_sig` ]. `/dev/shm` itself is world-readable — there is
  **NO filesystem-level ACL**; the security is entirely cryptographic [ signed
  permission grants ], which is more in keeping with this project's style than
  relying on OS permissions anyway.
- **mlock**: `data.mount.shm.lock.memory` / `.lock.unlock` — mlock / munlock
  via IO::AIO with a BSD::Resource fallback, advisory-only if neither is
  available. default `mlock => 1`.
- **stats**: `data.mount.shm.stats` enumerates active segments by owner.
- **partial lifecycle**: `data.mount.shm.init_code` registers a `$SIG{'INT'}`
  handler that iterates `$data{'mount'}{'shm'}{'segments'}` [ the in-memory
  registry of open mounts ] and **unlocks** [ NOT unlinks ] each mlocked region
  on SIGINT. `data.mount.shm.unlink` / `.remove` exist for explicit deletion.

### this is the **data zenka's own working internals**, not a neutral shared library

`configuration/zenki/data/start` loads the bare `data` namespace token — every
`data.*` module, including all of `data.mount.shm.*`, is the **literal data
zenka's** own loaded code, actively in service today. This is not a coincidence
of dot-prefix naming to design around; it is a real backward-compatibility
constraint on every phase below. Two more pieces confirm this, found in the
same investigation:

- **`data.channel.shm.*`** builds a **ring-buffer channel** abstraction on top
  of `data.mount.shm.create`, for inter-zenka communication —
  `data.channel.shm.create` packs a `read_pos`/`write_pos`/`wrap_count`/
  `capacity` header (`pack('NNNN', ...)`) at a fixed offset right after the
  512-byte mount header, sized via `SHM_CHANNEL_SIZE` (256KB default).
  Producer and consumer each own one counter — **already a not-quite-identical
  prior-art sibling to this task's reader/writer-feedback idea**: same
  single-writer-per-counter shape, but framed as a continuous ring buffer
  (bytes wrap, low-latency channel) rather than discrete numbered pages
  (bulk one-shot transfer, announce-then-pull).

  **RESOLVED: different tool, not a specialization — do not merge.** a ring
  buffer's `read_pos`/`write_pos` describe a continuous byte stream that wraps
  and has no natural concept of "page N of M" or an announced, checksummed
  index — that's a structurally different access pattern from
  announce-then-pull paging, not a parameterization of the same one. forcing
  the feedback mechanism into a ring-buffer specialization would mean bending
  wrap-around byte-stream semantics to fit random/sequential page-pull, for no
  benefit — they solve different problems [ ring buffer: ongoing bidirectional
  low-latency channel traffic; paging: move one large scalar once, pull-based ].
  build the feedback channel as its own thing, sized for two `Q`-packed
  integers [ see "the feedback integer also carries an ntime freshness stamp"
  below ], not on top of `data.channel.shm.*`.
- **`data.cmd.shm-self-test`** is the existing regression check — it runs
  `data.mount.shm.test.basic` and `data.channel.shm.test.basic` and reports
  pass/fail. **Treat a clean `p7c data.shm-self-test` run as a hard phase
  gate**, not a nice-to-have: every phase below must leave it passing
  unchanged, since it's the only automated signal that the data zenka's
  current behavior wasn't regressed.

### what is new [ this task ]

two confirmed gaps in the foundation, plus a standalone promotion:

- **confirmed gap #1 — no paging abstraction**: there is no read / write /
  paging layer above raw `substr()` on the mmap'd scalar. the test module
  [ `data.mount.shm.test.basic` ] writes / reads via bare `substr()` at a
  hardcoded offset [ 512, right after the header ]. → addressed in **phase 2**.
- **confirmed gap #2 — no full lifecycle / auto-cleanup**: the SIGINT handler
  only unlocks mlock; it does **not** unlink files. segments persist in tmpfs
  [ `/dev/shm` ] until explicit `unlink()` or the next reboot. nothing is hooked
  into normal P7 session teardown / disconnect events. → addressed in
  **phase 4**.
- **standalone promotion**: the core mmap / header / permission mechanics are
  P7-module-only today; standalone scripts cannot use them. → promoted to a
  standalone-loadable `AMOS7::SHM::*` package in **phase 1**.

## the standalone / hybrid precedent to follow

`AMOS7::CHKSUM` [ `data/lib-path/pm/AMOS7/CHKSUM.pm` ] is loadable **both**
standalone [ e.g. `bin/amos-chksum`, `bin/mcp-server-p7` ] and from inside a
P7 zenka, via the project-wide hybrid pattern: check
`defined $main::PROTOCOL_SEVEN` — if undefined, running standalone
[ CLAUDE.md documents this; e.g. `AMOS7.pm`'s `error_exit` exits with a code
standalone but returns undef in zenka mode ]. P7-side zenka modules
[ e.g. `modules/base.chk-sum.amos` ] are thin wrappers calling straight into
the standalone-capable package function.

the new design follows this exact precedent. promote the core mmap / header /
permission mechanics of `data.mount.shm.*` into a new standalone-loadable
`AMOS7::SHM::*` package family under `data/lib-path/pm/AMOS7/SHM/`, organized
the way `AMOS7::CHKSUM` already is — an umbrella `AMOS7/CHKSUM.pm` plus a
`AMOS7/CHKSUM/` directory with `BMW384.pm` / `ELF.pm` / `Nested.pm` siblings.
**recommended layout** [ matching that precedent ]:

```
  data/lib-path/pm/AMOS7/SHM.pm          ## umbrella : create/open/close, header, permission
  data/lib-path/pm/AMOS7/SHM/Page.pm      ## paging abstraction [ phase 2 ]
  data/lib-path/pm/AMOS7/SHM/Feedback.pm  ## feedback-variable channel [ phase 3 ]
```

then existing / new `modules/data.mount.shm.*` P7 wrapper modules call through
to the standalone core — same as `base.chk-sum.amos` does for
`AMOS7::CHKSUM::amos_chksum` — **or** call the new paging / feedback logic
directly in-process where that is cleaner [ judgment call per function, the
same flexibility `coding.cmd.summarize-context` already exercises by calling
`<[chk-sum.bmw.L13-str]>` directly rather than through a defensive double-key
dispatch ].

### the standalone / zenka difference is lifecycle, not mechanics

this is the load-bearing distinction — say it plainly to whoever implements:

- **identical either way** [ pure functions, no context branching needed ]:
  mmap mapping, header pack / unpack, and permission-signature verification.
  these are computation; they do not care whether a zenka is running.
- **the only thing that differs is cleanup**:
  - **zenka mode** — cleanup can ride the existing session / event-teardown
    machinery [ hook unlink into session-disconnect / zenka-exit, the natural
    home for gap #2's fix ].
  - **standalone mode** — there is no session to hook into. `AMOS7::SHM` needs
    its own explicit cleanup path: an `END` block and / or an explicit
    `unlink` call the caller must invoke. the `$main::PROTOCOL_SEVEN` check
    selects between these two cleanup behaviors — and **only** these; the
    mechanics above stay branch-free.

the BMW-L13 standalone port [ landed, see motivation below ] is **proven
precedent**, not just motivating pain: it is exactly a P7-module-only piece of
logic ported to be callable both standalone and in-zenka, verified
byte-identical to the live cube command's output. cite it as evidence the
hybrid pattern already works for precisely this kind of promotion.

## explicitly NOT `shm-streaming-payload-pipeline.md` — adjacent, different in kind

`data/tasks/shm-streaming-payload-pipeline.md` [ written 2026-05-19, **never
implemented** — confirmed via `git log`, and no `base.shm.*` or
`httpd.handler.shm_write` modules exist on disk ] is a **different problem** and
must not be folded into this one. recorded here so nobody re-discovers the
confusion later:

- **that doc** authenticates a large HTTP POST body crossing a **network trust
  boundary** [ an external `jobsite` host syncing to `httpd` ], using C25519
  signing, Twofish encryption, BMW384 incremental streaming hashing, and
  ntime-based replay protection — a real **sender-authentication** problem for
  a potentially-untrusted **remote** host.
- **this task** is **same-trust-domain, same-deployment**: P7 commands / zenki
  [ and standalone scripts ] passing large scalars to each other, where
  `data.mount.shm.*`'s already-built owner-pubkey + signed-permission-grant
  system is already the right amount of security. no network boundary, no
  remote sender to authenticate.

**namespace lesson learned from that old doc** [ apply it here ]: it proposed
`base.shm.write` / `base.shm.read` / `base.shm.path` under the `base.*`
namespace. per CLAUDE.md, `base.*` is loaded by most / all zenki — so **every**
zenka would carry SHM-handling code whether it ever uses it or not. the existing
`data.mount.shm.*` family avoids this correctly [ opt-in via `modules.load`,
not auto-loaded ]. the new work **must stay under `data.mount.shm.*`** [ or a
clearly-scoped sibling under `data.*` ], **never `base.*`**.

## why `pager.*` was rejected as the paging base — decided, recorded so it is not re-litigated

`modules/pager.*` [ 51 modules ] was investigated and **rejected** as a base for
the new paging layer. it is an **item-centric** framework [ structured records
with fields like `path` / `name` / `size` / `mtime`, filter chains, multi-key
sort, LRU item caching, viewport rendering ] built for listing / filtering
things like file lists or checksum lists — **not raw byte / scalar chunking**.
pluggable sources exist [ `pager.source.register`, requiring `next_batch()` /
`get_item_at()` / `close()` ] but none are scalar-oriented, and wiring SHM in
would mean implementing that interface only to immediately bypass ~90% of what
the framework does [ filtering, sorting, rendering ] for zero benefit.

**do not reuse or extend `pager.*` for this** — build a small, separate,
dedicated layer [ `AMOS7::SHM::Page` ]. this decision is already made; this
section exists only to record it.

## the paging + feedback-variable design

goal: let a reader pull large scalar data through an SHM segment in
bounded-size **pages**, with the writer able to keep only recently-needed pages
in memory if it is itself streaming from a larger source [ e.g. a big file ],
rather than requiring the entire payload to be materialized in the segment at
once.

### announce-then-pull, not unannounced-push

this is a concrete instance of the **originally-envisioned but
little-implemented** Protocol-7 behavior: content is **announced**
[ with a checksum ] and then **requested from the target in reverse** [ pulled ],
rather than pushed unannounced. this enables load balancing and selective
traffic. the writer announces an index [ total pages, page size, and a checksum
— the existing `data.mount.shm.*` header's `data_size` field is the natural
carrier ], and the reader **pulls pages by number** against that announced
index.

### two SHM regions, deliberately asymmetric flow — this is what makes it lock-free

  - **data channel**: writer writes [ the announced content, paged ], reader
    only reads.
  - **feedback channel**: a single integer = "last page read by the reader" —
    but the **flow is reversed** from the data channel: the **reader** writes
    this integer [ its own read progress ], and the **writer only reads** it.

**core elegance — state it as the design's center, not a footnote**: because
each of the two channels has exactly **one writer**, there is **no lock / mutex
needed in either direction**. "there is no conflict." a single-writer region
has no contended write; the sole reader of each value never races a second
writer because there is none.

because the writer is the **sole reader** of the feedback integer, it can
trivially **sanitize / clamp** that value against the announced total-page range
[ reject / clamp anything outside `[0, total_pages]` ] — it knows the valid
range it itself announced.

### streaming-source case

if the writer is itself pulling from something larger than fits comfortably in
memory [ e.g. a big file ], it can use the feedback pointer to **discard / avoid
materializing** pages the reader has already consumed, keeping only pages from
the reader's current position forward — bounding the writer's own memory use to
roughly the **lookahead window** rather than the full source size.

### RESOLVED — reader-paced, via a native FIFO notify + ntime freshness stamp

this was flagged as an open fork, deliberately unresolved, in an earlier draft
of this doc. it is now resolved — by empirical testing during this session,
not by preference — because the testing eliminated reader-paced's only stated
downside. record of how it got resolved, since the *process* matters as much
as the conclusion here:

**`Event->var()` was tested and ruled out first.** the candidate considered
for writer-paced [ a polling-free variable watcher, mirroring `jobqueue`'s use
of `base.event.add_var` ] was verified live with a fork+write test: a child
process wrote into the watched mmap'd region while the parent ran
`Event::loop()` for 3 seconds. **the watcher fired zero times**, despite the
write landing correctly in shared memory [ confirmed by reading it back
afterward ]. `man Event`'s own description of `var` watchers explains why —
they fire on Perl-level reads/writes to the SV in the watching process's own
interpreter, never on an external process's raw memory write. this rules out
`Event->var()` for cross-process use entirely, not just for this design.

**`Linux::Inotify2` was tested next, also ruled out** — confirmed live that
`IN_MODIFY` does **not** fire reliably for an mmap'd write [ even on `/dev/shm`,
which does support inotify fine for *regular* writes — confirmed separately ].
the kernel only reliably reports mmap'd changes around `msync()`/`munmap()`,
and `Sys::Mmap` does not even expose `msync()`. not worth the syscall
complexity for an unreliable signal.

**the actual answer**: a native FIFO + `Event->io()`, the same technique
`IPC::Notify` (CPAN) uses internally [ confirmed by reading its source —
`_read_from_fifo` is exactly `IO::Select->can_read($timeout)` on a `mkfifo`'d
filehandle ] — but reimplemented directly in `AMOS7::SHM`, not taken as a
dependency, same as `lock_memory`/`unlock_memory` were ported rather than
pulled in from a library. a FIFO write is a **regular** file write, not an
mmap write, so it has none of the `Event->var()` / inotify unreliability —
it fires immediately, every time, for both mechanisms tried above.

**why this resolves the fork, not just adds a mechanism to it**: reader-paced's
only downside was never "polling cost" [ it never polls — the reader pushes ];
the actual gap was *how the writer learns the push happened* without itself
polling the feedback integer to notice. the FIFO ding is exactly that —
zero-cost, event-driven, no poll loop anywhere. the stalled-reader liveness
concern [ reader dies mid-transfer, never dings again ] is **already solved**
by `base.event.add_io`'s existing `timeout` / `timeout_cb` parameters — the
writer's wait degrades cleanly into "fire after N seconds of silence," no new
plumbing needed. writer-paced gains nothing from any of this [ it doesn't
depend on the reader signaling at all ] and is strictly worse once reader-paced
has a real push mechanism. **decision: reader-paced, FIFO + `Event->io()` +
`base.event.add_io`'s built-in timeout for the stall case.**

**a FIFO sits alongside each segment**, named consistently with the existing
scheme [ e.g. `/dev/shm/p7:M:<pubkey>:<subpath>.notify` ], created in
`AMOS7::SHM::Page::create` / cleaned up in the same lifecycle hooks phase 4
already plans to build — not a new category of lifecycle problem, the same one.

### the feedback integer also carries an ntime freshness stamp

resolves "who has the latest data" with the project's own addressing
convention [ checksum + timestamp ], not a new scheme. the feedback region is
not just `last_page_read` — it is `(last_page_read, ntime)`, both packed as
64-bit integers [ `Q` — `last_page_read` alone would fit in 32 bits, but the
real `ntime` value does not [ see below ], so both fields use `Q` for one
consistent pack format ]. the writer, on waking via the FIFO ding, compares
the ntime stamp against the last one it acted on — a stamp that is not
strictly newer is a stale/duplicate ding and is skipped.

**the exact formula** [ confirmed live from two independent existing
implementations, not approximated ] — `bin/Protocol-7`'s `p7_ntime` /
`bin/atom-delta-term`'s `calc_ntime`:

```
ntime = sprintf( "%.0f", ( unix_time - 1023228000 ) * 4200 )   ## integer form
```

`1023228000` is the protocol-7 epoch [ 2002-06-05 ]; `4200` is the network-time
scale factor. **this must be exact, not `int()`** — `sprintf("%.0f", ...)`
rounds to nearest, `int()` truncates toward zero; they disagree on the
fractional half, and the two sides [ zenka / standalone ] must compute the
*same* value for the *same* instant or the comparison is meaningless.

**the harmony question — be explicit in the API, this is the part that must
not be glossed over**:
- **zenka side**: inject the **real** `<[base.ntime]>` [ no param — integer
  precision, higher resolution than unix time, per the project's own usage
  convention ] via the existing `time_source` option [ same injection point
  `created` already uses ]. this goes through `p7_ntime`'s real harmony-retry
  loop [ `base.assert.harmony` ] — a fully validated, "true" network time.
- **standalone side**: the bare arithmetic above, **no harmony validation at
  all** — there is no zenka/network context to validate against standalone,
  and `bin/atom-delta-term`'s `calc_ntime` already establishes this as an
  accepted, existing pattern [ not an invention for this task ].
- **document this asymmetry explicitly wherever the timestamp field is
  described** — the value is "network-time-shaped" for comparability and
  consistency with the rest of the project's addressing conventions, but only
  the zenka-computed value carries actual harmonic-truth / collision-retry
  guarantees. the standalone value is a comparator, not a security primitive.
  do not let either side's caller assume the other guarantee applies.

### guard against the clock moving backward

a freshness comparator is only correct if the clock it's built on only moves
forward. it doesn't always — NTP correction, a manual clock change, a VM
snapshot restore. without a guard, a single backward jump poisons the
comparison **permanently, not just once**: if the writer's own recorded
`last_seen_ntime` is left sitting above what the clock now reports as `now`,
every *subsequent real update* looks "older" than that stale high-water-mark
and is silently skipped forever, not just during the jump itself.

**the guard**: on each ding, before comparing, the writer also checks its own
freshly-computed `now` against its own `last_seen_ntime` bookkeeping —
independent of whatever `ntime` the incoming feedback region carries:

```
if last_seen_ntime > now:      ## the writer's clock has regressed ##
    last_seen_ntime = now      ## rebase to current clock, not 0 — see why below
```

**rebase to `now`, not `0`**: resetting to `0` would make the *next* ding —
whatever its `ntime`, even one from well before the jump — look unconditionally
fresher than `0` and get accepted, which is *more* permissive than the
ordering check is supposed to allow; it throws away the ordering guarantee
entirely rather than just absorbing the jump. rebasing to `now` keeps the
comparison meaningful going forward — the next real ding still has to clear
a real bar, just one rebased to the clock's current [ lower ] reading, not the
stale higher one.

**this is still a judgment call worth recording explicitly when implemented**,
not a settled fact — note in the implementing code which choice was made and
why, the same way phase 3's other resolved decisions are recorded, in case a
future situation [ e.g. a detected anomaly far larger than an NTP correction ]
argues for the more distrustful `0` reset instead.

## phased implementation

### phase 1 — promote `data.mount.shm.*` core to standalone `AMOS7::SHM`

- extract the mmap mapping, header pack / unpack, and permission-signature
  verification mechanics into `data/lib-path/pm/AMOS7/SHM.pm` [ umbrella ],
  loadable standalone via a lib-path `BEGIN` block [ the pattern
  `bin/amos-chksum` uses ].
- existing `modules/data.mount.shm.*` modules become thin wrappers calling into
  `AMOS7::SHM` — **zero behavior change on the zenka path** [ same as
  `base.chk-sum.amos` -> `AMOS7::CHKSUM::amos_chksum` ].
- `$main::PROTOCOL_SEVEN` gates **only** the cleanup behavior [ see "the
  standalone / zenka difference is lifecycle, not mechanics" ] — the mechanics
  stay branch-free.

acceptance:
- [ ] `p7c data.shm-self-test` passes unchanged on the data zenka — this is the
      **hard gate**, not a nice-to-have: `data.mount.shm.*` is the data
      zenka's own live working code today, not a neutral shared library, and
      this is its only automated regression signal
- [ ] a standalone script can `use AMOS7::SHM`, create / open a segment, and
      pass `data.mount.shm.permission.verify`'s signed-grant check, with no
      zenka running
- [ ] cleanup-behavior selection keys on `defined $main::PROTOCOL_SEVEN` and
      nothing else branches on context

### phase 2 — DONE, live-verified 2026-06-22 [ closes gap #1 ]

**what landed**:
- `AMOS7::SHM::Page` (`data/lib-path/pm/AMOS7/SHM/Page.pm`) — sibling package
  to `AMOS7::SHM`, same branch-free-mechanics style. a fixed **32-byte page
  index** [ `P7PG` magic + `total_pages` + `page_size`, both packed `N`, +
  13-byte bmw-L13 checksum ] sits between the 512-byte mount header and the
  first page of data — `data_offset() == SHM_HEADER_SIZE + 32 == 544`.
  `create($pubkey, $content_size, $page_size, $checksum, $options)` computes
  `total_pages`, sizes the underlying `AMOS7::SHM::shm_create` segment to
  fit index+all pages, then **overwrites the mount header's `data_size`** to
  the real content length [ not the padded index+pages region ] — this is
  what lets `read_page` clip the final, possibly-partial page correctly
  without picking up trailing zero-padding.
- thin zenka wrappers, same pattern as phase 1: `modules/data.mount.shm.page.{create,write,read}`,
  `.page.index.{write,read}`. `page.create`'s wrapper injects the time source
  and re-adds the external mlock call, mirroring `data.mount.shm.create`'s
  wrapper exactly — `shm_create`'s standalone-only self-mlock branch
  [ phase 1 ] does not fire when called this way in zenka mode, same reason
  the original wrapper needed it.
- `modules/data.mount.shm.page.test.basic` + a 4th test wired into
  `data.cmd.shm-self-test` (`p7c data.shm-self-test` now runs mount / channel
  / stats / **page** in one pass).
- `modules/data.mount.shm.init_code` autoloads `AMOS7::SHM::Page` alongside
  `AMOS7::SHM`.

**verified live, not just unit-tested**: byte-identical reassembly with a
content length that is *not* an exact multiple of `page_size` [ exercises the
last-page clip ]; out-of-range rejection on both `read_page` and `write_page`;
header region [ first 512 bytes ] confirmed untouched after paging; and —
the actual point of phase 1 — **cross-process**: a forked child re-opens the
segment via `shm_open` and reassembles all pages written by the parent,
byte-identical. `p7c data.shm-self-test` passes all 4 tests.

acceptance:
- [x] a writer can page out a multi-page payload and a reader can reassemble it
      byte-identically by pulling pages in order — confirmed same-process and
      cross-process (forked reader)
- [x] page boundaries respect the 512-byte header offset [ no payload written
      into the header region ] — confirmed: index occupies bytes 512-543,
      page data starts at 544, mount header magic/fields verified intact
      after writing all pages
- [x] a pulled page out of the announced range is rejected, not read past the
      segment end — confirmed on both `read_page` (returns `undef`) and
      `write_page` (returns `{error=>'page_out_of_range'}`)

### phase 3 — feedback channel, FIFO notify, ntime stamp — all resolved, see above

design fully resolved during this session [ see "RESOLVED — reader-paced, via
a native FIFO notify" and "the feedback integer also carries an ntime
freshness stamp" above, and "different tool, not a specialization" for the
`data.channel.shm.*` question ]. this phase is now implementation of decided
design, not decision-making. concretely:

- `AMOS7::SHM::Feedback` [ new sibling package, same branch-free-mechanics
  style as `AMOS7::SHM::Page` ]: a fixed region holding two `Q`-packed 64-bit
  integers — `last_page_read`, `ntime` — reverse flow from the data channel
  [ reader is the sole writer of this region ; the writer/page-source is the
  sole reader ]. the writer clamps `last_page_read` against the announced
  `[0, total_pages]` range from the page index [ phase 2 ] before trusting it.
- a FIFO created alongside the segment [ `<path>.notify`, `mkfifo` ], cleaned
  up in the same lifecycle hooks as phase 4. reader: write the feedback region,
  then write one byte to the FIFO. writer: `base.event.add_io` [ zenka ] /
  `IO::Select` [ standalone ] on the FIFO's read end, with a `timeout`/
  `timeout_cb` for the stalled-reader case — no poll loop anywhere.
- on each ding, the writer reads the feedback region and compares `ntime`
  against the last value it acted on ; not strictly newer = stale/duplicate
  ding, skip. `ntime` computed via the project's real formula
  [ `sprintf("%.0f", (unix_time - 1023228000) * 4200)` ] — zenka side injects
  the real `<[base.ntime]>` [ harmony-validated ] via the existing
  `time_source` option ; standalone computes the bare arithmetic [ no harmony
  validation — document this asymmetry in the module's own comments, not just
  this doc ].
- streaming-source path: writer uses `last_page_read` to bound its own
  in-memory lookahead window once a ding confirms it's current.

acceptance:
- [ ] data channel has exactly one writer [ the writer ]; feedback channel has
      exactly one writer [ the reader ] — no lock / mutex anywhere in either
      direction
- [ ] the writer clamps / rejects a `last_page_read` value outside
      `[0, total_pages]`
- [ ] the FIFO ding fires the writer's `Event->io()`/`IO::Select` wakeup
      reliably and immediately — confirmed live, cross-process, same method as
      phase 1/2's verification [ fork + timing, not a same-process check ]
- [ ] a stalled reader [ stops dinging ] triggers the writer's `timeout_cb`,
      not an indefinite wait
- [ ] `ntime` is computed identically in formula on both zenka and standalone
      paths [ `sprintf("%.0f", ...)`, not `int()` ] ; only the zenka path is
      harmony-validated, and this asymmetry is documented in the code, not
      just this doc
- [ ] a stale/duplicate ding [ same or older `ntime` than already seen ] is
      detected and skipped, not reprocessed
- [ ] a backward clock jump [ writer's own `now` drops below its recorded
      `last_seen_ntime` ] is detected and rebased [ to `now`, not `0` — see
      "guard against the clock moving backward" ], confirmed by a test that
      forces `last_seen_ntime` ahead of a freshly-computed `now` and checks a
      subsequent real ding is still accepted afterward, not permanently stuck
- [ ] a streaming writer's resident memory stays bounded to the lookahead
      window, not the full source size, while the reader pulls

### phase 4 — close the cleanup gap, lifecycle hooks for both modes [ closes gap #2 ]

- **zenka mode**: hook segment unlink into normal session-teardown /
  zenka-exit / disconnect events — not only SIGINT, and **unlink**, not merely
  unlock. extend `data.mount.shm.init_code`'s registry walk so teardown
  releases segments the way SIGINT releases mlock today.
- **standalone mode**: `AMOS7::SHM` registers an `END` block and / or exposes an
  explicit cleanup call the caller invokes, since there is no session to ride.

acceptance:
- [ ] a zenka that creates a segment and then exits / disconnects normally
      leaves no orphaned file in `/dev/shm` [ not just on SIGINT ]
- [ ] a standalone script that exits normally cleans up its own segments via
      the `END` path / explicit call
- [ ] mlocked regions are unlocked before unlink in both modes [ no leaked
      locked pages ]

## why this design exists [ lessons from the motivating incident — do not bury ]

during phase 1 of `data/tasks/task-summary-topic-tree.md` [ landed ], a real
production incident occurred: `bin/mcp-server-p7` [ standalone, not a zenka ]
needed to checksum up to ~400KB of session text and routed it through the
cube-exposed `bmw-L13 :B32:<encoded content>` command as **one command line**.
the ~640KB B32 payload exceeded `base.handler.command`'s **242707-byte**
single-line buffer. the failure was **not clean** — a `session_catchup` against
a 30MB session appeared to hang indefinitely, no buffer-exceeded message in the
log, the connection left in a bad state. the **constraint was diagnosed from
architecture knowledge, before any error message confirmed it**.

the fix there — porting the checksum algorithm to run standalone in
`bin/mcp-server-p7` — was a **one-off escape** from this exact underlying
constraint [ content-sized data must not cross a cube command line ]. two
lessons fold into this task:

  1. **the one-off proves the hybrid pattern.** the BMW-L13 port is precisely a
     P7-module-only piece of logic made callable both standalone and in-zenka
     via `$main::PROTOCOL_SEVEN`, verified byte-identical to the live command.
     this task reuses that proven pattern at larger scope — cite it as
     precedent, not just as the pain that prompted the work.
  2. **decide the load-bearing fork deliberately.** the incident came from a
     transfer-path assumption made implicitly under time pressure. this design
     surfaced its one comparable assumption [ reader-paced vs writer-paced ]
     explicitly rather than resolving it silently — and resolved it only once
     the empirical evidence was in [ see "RESOLVED — reader-paced, via a
     native FIFO notify" above ], not before.

a third, smaller incident happened live during phase 1 itself, after the
`fileno()` mmap bug fix and the mlock-standalone-gap fix [ both landed,
verified live ]: a verification test that called `lock_memory` [ which uses
`IO::AIO::aio_mlock` ] and then `fork()`'d hung a child process at 100% CPU
indefinitely. **root cause**: `IO::AIO`'s background worker-thread state does
not survive `fork()` cleanly — this is a known, already-solved problem in this
codebase, just not yet documented inside `AMOS7::SHM` itself.
`modules/base.process-into-background`, `modules/vision-batch.parent.fork_child`,
and `modules/weather.base.fork_weather_child` all call `IO::AIO::reinit()`
immediately after `fork()` for exactly this reason — confirmed live, adding it
resolves the hang completely.

rather than push that as a caller-responsibility convention to remember
[ the first draft of this fix did exactly that, then was improved live ],
`AMOS7::SHM` **self-detects** the fork instead: `_io_aio_fork_guard()` tracks
the pid it last touched `IO::AIO` from in a package variable, and compares
against `$PID` [ `$$`, a cached interpreter value — one integer comparison,
not a syscall, negligible overhead ] on every `lock_memory` call. a mismatch
means a fork happened since the last touch, and it calls `IO::AIO::reinit()`
automatically before proceeding. **confirmed live with no manual reinit call
in the caller at all**: parent creates + mlocks, forks, child calls
`lock_memory` again with zero awareness of the fork-safety concern, and it
just works. this converts "callers must remember a convention" into "callers
cannot get it wrong" — strictly better than documenting the requirement.
**relevant to phases 2-4**: this guard already covers any streaming-source or
child-zenka-forking code path that goes through `lock_memory`; no further
action needed there unless a *different* IO::AIO-touching entry point is
added that bypasses it.

## style

- lowercase comments, `[ word ]` bracket annotations [ never `( word )` ]
- `$ARG` / `@ARG`, not `$_` / `@_`, where used implicitly
- `<mount.shm.segments>->{}` for dotted data keys, not `$data{'mount'}{'shm'}{}`
- `.cmd.` / whitelisted routines return `{ mode => true|false, data => STRING }`
  — split raw-hash / scalar-ref helpers into separate non-`.cmd.` routines +
  thin wrapper
- use `<[base.logs]>->( N, fmt, args )` for logging, not warn / print
- config paths via `<system.root_path>/...`; never bare relative
- TRUE / FALSE / UNKNOWN constants, never literal 0 / 1
- standalone packages use the lib-path `BEGIN` block + `$main::PROTOCOL_SEVEN`
  check [ mirror `AMOS7::CHKSUM` / `bin/amos-chksum` exactly ]
- new SHM modules stay under `data.mount.shm.*` / `AMOS7::SHM::*`, **never**
  `base.*` [ see the namespace lesson above ]
- guard any timer with a fallback interval [ undef interval = max-rate loop ]

## acceptance [ overall ]

- [x] `AMOS7::SHM` is loadable both standalone and in-zenka via the
      `$main::PROTOCOL_SEVEN` precedent; mechanics are branch-free, only cleanup
      differs by mode
- [x] every existing `data.mount.shm.*` behavior is unchanged after the phase-1
      promotion [ zero regression — `p7c data.shm-self-test` is the data
      zenka's own existing gate, this is its live working code, not a neutral
      shared library ]
- [x] the relationship between the new paging/feedback design and
      `data.channel.shm.*`'s existing ring-buffer counters is explicit, not
      silently duplicated [ RESOLVED: different tool, not a specialization —
      see "different tool, not a specialization — do not merge" above ]
- [x] paging reads / writes a multi-page payload by page number, reassembled
      byte-identically [ gap #1 closed — confirmed same-process and
      cross-process via a forked reader ]
- [ ] the feedback channel is a reverse-direction single-writer region [ two
      `Q`-packed integers : `last_page_read`, `ntime` ]; no lock / mutex in
      either direction; the writer clamps `last_page_read` to the announced range
- [x] the reader/writer-paced fork is **RESOLVED**: reader-paced, via a native
      FIFO + `Event->io()`/`base.event.add_io` [ `Event->var()` and
      `Linux::Inotify2` were both tested live and ruled out — see "RESOLVED"
      above ] — phase 3 implements this decision, does not re-decide it
- [ ] segments are cleaned up on normal teardown in both zenka and standalone
      mode [ gap #2 closed ] — now includes the phase-3 FIFO's lifecycle too
- [ ] no new SHM code lives under `base.*`; this design is kept distinct from
      `shm-streaming-payload-pipeline.md` [ network-boundary problem ]

### dispatch

model: opus
reasoning: high

prompt: |
  Implement phase 3 of data/tasks/amos7-shm-paging-feedback.md. Phases 1
  (data/lib-path/pm/AMOS7/SHM.pm, commit 410805f43) and 2
  (data/lib-path/pm/AMOS7/SHM/Page.pm, commit ac6315191) are DONE and
  live-verified — read "phase 1 — DONE" / "phase 2 — DONE" for what already
  exists before touching anything. Phase 3 builds on both.

  Phase 3's design is fully RESOLVED, not open — this is implementation of a
  decided design, not a decision-making pass. Read, in order: "RESOLVED —
  reader-paced, via a native FIFO notify" (why Event->var() and
  Linux::Inotify2 were both tested live and ruled out, and why a native FIFO +
  Event->io() is the answer — do not re-litigate this, the empirical tests
  are recorded), "the feedback integer also carries an ntime freshness stamp"
  (the exact formula, and the zenka/standalone harmony asymmetry — get this
  exact, sprintf("%.0f", ...) not int()), "guard against the clock moving
  backward" (a single backward clock jump must not permanently poison the
  freshness comparison — rebase to now, not 0, and test it), and "different
  tool, not a specialization" (why data.channel.shm.*'s ring buffer is not
  reused — do not merge them). Then "phase 3 —" section has the concrete
  build list and acceptance criteria.

  Hard constraints carried from earlier phases, still apply:
   - data.mount.shm.* / AMOS7::SHM::* is the data zenka's own live working
     code — p7c data.shm-self-test passing unchanged is a hard gate
   - new SHM code stays under data.mount.shm.* / AMOS7::SHM::*, never base.*
   - do NOT merge this with data/tasks/shm-streaming-payload-pipeline.md
     (different problem: network trust boundary, not same-trust-domain)
   - verify cross-process claims the same way phase 1/2 did: fork + a timing
     gap, never a same-process check (same-process checks produced false
     positives twice already in this project's history — see "why this
     design exists")

  Follow the project's lowercase-comment, dot-notation style exactly. No
  signature stubs — the signing system adds them.

#,,,.,,.,,..,,,..,.,,,,,.,.,.,,..,...,,.,,,..,..,,...,...,.,.,,,.,,.,,.,,,,..,
#6Q3H2Q6NETQVEOENOX4HX3GEZ7NDA4LZOL7VPBAB4M3337N3DIC47ODBCGC63EHBWU5BV7YEQYTA4
#\\\|2VGCXXOII52CBZYW6AFU7CRVMR4QRX5ESEZ5D4353QWI6B5OGYY \ / AMOS7 \ YOURUM ::
#\[7]FYIVHH6VGOQQQLUFS64HGTMFDSKKHUIEMRD2G6RQM37FO7UNM2AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
