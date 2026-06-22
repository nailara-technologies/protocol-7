# task: AMOS7::SHM — standalone-hybrid paged shared-memory transfer with feedback channel

## status [ 2026-06-22 ]

**design only — nothing here is implemented yet.** every phase below is a
plan, not an accomplishment. the *foundation* this builds on
[ `modules/data.mount.shm.*` ] is real, landed code [ see "what already
exists" ] — but the standalone promotion, the paging abstraction, the
feedback channel, and the lifecycle/cleanup hooks described here do **not**
exist on disk yet. read "what already exists vs what is new" carefully before
touching anything — this is an extension of working infrastructure, not a
green field.

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
cat modules/jobqueue.event.register_job_queues        ## polling-free var watcher : candidate for writer-paced
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
  (bulk one-shot transfer, announce-then-pull). **Read `data.channel.shm.*` in
  full before phase 3** — decide explicitly whether the new paging/feedback
  channel is a different tool for a different job (likely: ring buffers suit
  ongoing bidirectional traffic, paging suits "move this one large scalar
  once"), or whether the feedback-variable mechanic should actually be built
  as a thin specialization of the existing ring-buffer counters instead of a
  parallel mechanism. Don't silently duplicate without making that call.
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

### OPEN FORK — reader-paced vs writer-paced — DO NOT RESOLVE IN THIS DOC

this is flagged **prominently and left deliberately unresolved**. it is exactly
the category of decision that, made implicitly under time pressure, caused the
BMW-L13 / cube-buffer-cap incident this task generalizes a fix for. whoever
implements **must decide this consciously, up front**, not let it fall out of
whatever the first code happens to do.

the question: who drives the feedback pointer?

  - **reader-paced**: the reader writes / updates the feedback integer
    **proactively, immediately after consuming each page**.
    - tradeoff: the writer always has fresh progress with no polling cost; but
      a stalled / slow reader that stops updating the pointer can leave the
      writer guessing whether the reader is dead or merely slow.
  - **writer-paced**: the writer **polls** the feedback integer on its own
    schedule.
    - tradeoff: the writer controls its own cadence and overhead and can apply
      its own timeout / abandonment policy; but progress visibility lags the
      poll interval, and a naive poll loop needs its own fallback guard
      [ undef interval = max-rate loop ].
    - **candidate to investigate, not assumed working**: `jobqueue.*` already
      has a *polling-free* variable-watcher pattern for its own queue
      counters — `jobqueue.event.register_job_queues` registers via the
      generic `<[event.add_var]>->({ var=>\$scalar, poll=>'w', handler=>...,
      repeat=>1, prio=>0 })` [ `base.event.add_var`, wrapping Perl's
      `Event->var()` ], firing `jobqueue.handler.queue_counter` the instant
      the watched scalar is written — no poll loop, event-driven. **This
      would make writer-paced strictly better than the naive-poll tradeoff
      above IF it works** — but `Event->var()` watches *Perl-level variable
      writes in the watching process's own interpreter*. The feedback integer
      here is written by a **different process** (the reader zenka) via a
      raw mmap'd-memory write, not a Perl assignment opcode executing inside
      the writer's interpreter. **Verify empirically, before relying on it,
      whether `Event->var()` actually fires on an externally-mmap-modified
      scalar, or only on in-process Perl writes** — if it's the latter, this
      pattern doesn't transfer to the cross-process case and writer-paced
      reduces to plain polling after all. Read `jobqueue.event.register_job_queues`
      / `base.event.add_var` / `jobqueue.handler.queue_counter` and test this
      specific question before assuming it resolves the fork "for free."

each choice determines **who can stall whom under what failure mode**. present
both; **pick neither here**. the implementation phase [ phase 3 ] owns this
decision and must record which was chosen and why — including the outcome of
the `Event->var()` cross-process verification above, since it changes which
option is actually viable.

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

### phase 2 — paging abstraction over an existing segment [ closes gap #1 ]

- `AMOS7::SHM::Page` [ + a thin `data.mount.shm.page.*` wrapper if zenka callers
  want dotted access ]: read / write by **page number** above the raw
  `substr()` the test module currently does by hand at hardcoded offset 512.
- writer announces an index [ total pages, page size, content checksum ] via
  the header's `data_size` and a small index region; reader pulls page N.

acceptance:
- [ ] a writer can page out a multi-page payload and a reader can reassemble it
      byte-identically by pulling pages in order
- [ ] page boundaries respect the 512-byte header offset [ no payload written
      into the header region ]
- [ ] a pulled page out of the announced range is rejected, not read past the
      segment end

### phase 3 — feedback-variable channel + the reader/writer-paced decision

- **before writing any of this**: read `data.channel.shm.*` in full [ see "this
  is the data zenka's own working internals" above ] and make an explicit,
  recorded call — is the new feedback-variable mechanic a different tool for a
  different job than the existing ring-buffer `read_pos`/`write_pos` counters
  [ likely: ring buffer = ongoing bidirectional channel traffic, paging =
  one-shot bulk transfer ], or should it be built as a specialization of the
  ring-buffer counters instead of a parallel mechanism? Don't duplicate
  silently either way.
- `AMOS7::SHM::Feedback`: a second, reverse-direction single-integer channel —
  reader writes its last-read page number, writer reads / clamps it against the
  announced `[0, total_pages]` range.
- **resolve the reader-paced vs writer-paced fork** [ see OPEN FORK above ]
  consciously and **record the choice + rationale in the implementing commit /
  this doc** — do not leave it implicit.
- streaming-source path: writer uses the feedback pointer to bound its own
  in-memory lookahead window.

acceptance:
- [ ] the relationship to `data.channel.shm.*`'s ring-buffer counters is
      explicitly decided and recorded [ different tool vs. specialization ] —
      not silently duplicated
- [ ] data channel has exactly one writer [ the writer ]; feedback channel has
      exactly one writer [ the reader ] — no lock / mutex anywhere in either
      direction
- [ ] the writer clamps / rejects a feedback value outside `[0, total_pages]`
- [ ] a streaming writer's resident memory stays bounded to the lookahead
      window, not the full source size, while the reader pulls
- [ ] the chosen pacing model [ reader-paced or writer-paced ] is documented,
      not implicit
- [ ] if writer-paced via `Event->var()`/`base.event.add_var` was considered,
      the cross-process question [ does it fire on an externally-mmap-modified
      scalar, or only in-process Perl writes ] was actually tested, not
      assumed — record the result either way

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
     surfaces its one comparable assumption [ reader-paced vs writer-paced ]
     explicitly and refuses to resolve it silently — see OPEN FORK above.

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

- [ ] `AMOS7::SHM` is loadable both standalone and in-zenka via the
      `$main::PROTOCOL_SEVEN` precedent; mechanics are branch-free, only cleanup
      differs by mode
- [ ] every existing `data.mount.shm.*` behavior is unchanged after the phase-1
      promotion [ zero regression — `p7c data.shm-self-test` is the data
      zenka's own existing gate, this is its live working code, not a neutral
      shared library ]
- [ ] the relationship between the new paging/feedback design and
      `data.channel.shm.*`'s existing ring-buffer counters is explicit, not
      silently duplicated
- [ ] paging reads / writes a multi-page payload by page number, reassembled
      byte-identically [ gap #1 closed ]
- [ ] the feedback channel is a reverse-direction single-writer integer; no lock
      / mutex in either direction; the writer clamps it to the announced range
- [ ] the reader-paced vs writer-paced fork is decided **consciously** and
      recorded, not left implicit
- [ ] segments are cleaned up on normal teardown in both zenka and standalone
      mode [ gap #2 closed ]
- [ ] no new SHM code lives under `base.*`; this design is kept distinct from
      `shm-streaming-payload-pipeline.md` [ network-boundary problem ]

### dispatch

model: opus
reasoning: high

prompt: |
  Implement data/tasks/amos7-shm-paging-feedback.md. This is design only today
  — NOTHING in it is built yet. The foundation it extends, modules/data.mount.shm.*
  (27 modules), IS real landed code — read it first (see "what to read first").

  Start with phase 1: promote the core mmap / header / permission-signature
  mechanics of data.mount.shm.* into a standalone-loadable AMOS7::SHM package
  under data/lib-path/pm/AMOS7/SHM.pm, following the AMOS7::CHKSUM /
  base.chk-sum.amos hybrid precedent exactly (defined $main::PROTOCOL_SEVEN
  gates ONLY cleanup behavior — mechanics stay branch-free). Existing
  data.mount.shm.* modules become thin wrappers; zero behavior change on the
  zenka path is the phase-1 bar.

  Three hard constraints carried from the doc:
   - do NOT merge this with data/tasks/shm-streaming-payload-pipeline.md — that
     is a DIFFERENT problem (authenticating a large POST body across a network
     trust boundary); this is same-trust-domain scalar passing.
   - new SHM code stays under data.mount.shm.* / AMOS7::SHM::*, NEVER base.*
     (base.* is auto-loaded by every zenka — see the namespace lesson).
   - data.mount.shm.* is the data zenka's own live working code TODAY (loaded
     via the bare `data` modules.load token), not a neutral shared library —
     `p7c data.shm-self-test` passing unchanged is a hard gate on every phase,
     and before phase 3 you must read data.channel.shm.* and explicitly decide
     whether the new feedback-variable mechanic duplicates its existing
     ring-buffer read_pos/write_pos counters or is genuinely a different tool.

  When you reach phase 3, the reader-paced vs writer-paced feedback-pointer fork
  is DELIBERATELY UNRESOLVED in the doc. Decide it consciously, up front, and
  record the choice + rationale — do not let it fall out of whatever the first
  code happens to do. The whole design exists because exactly that kind of
  transfer-path assumption, made implicitly, caused the BMW-L13 / cube-buffer-cap
  incident (see "why this design exists").

  Follow the project's lowercase-comment, dot-notation style exactly. No
  signature stubs — the signing system adds them.

#,,..,,,,,,.,,...,,.,,.,.,.,,,,,.,,..,..,,..,,..,,...,...,...,.,.,...,,.,,...,
#NFGOAAQREEIG35STBQMDQZK5J7MDCCC5W5QBCPDXEVP7AXI6HYXVHELPQYC35AFT42EH7H3WROR4A
#\\\|AYY376P4SOSJSME2TK4HD6LHQ652JGZHBU5PUHNY3PP7AFASEZF \ / AMOS7 \ YOURUM ::
#\[7]H3LX2OKEL4N4PVK6RXTK7PWMBTQ5ZTIHRXB6ZNBGPLUICWQRNOBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
