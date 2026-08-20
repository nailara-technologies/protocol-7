# task: AMOS7::SHM — use-case taxonomy + shared generic-core consolidation

## status [ 2026-06-22 ]

**design / taxonomy only — nothing new implemented here.** this is a
consolidating pass over the three caller-shapes of `AMOS7::SHM` now identified,
written after a live design conversation surfaced a **third** distinct shape and
a fuller candidate list across all three. it does not re-explain the two
existing per-shape docs — read them first and treat their conclusions as given:

- `data/tasks/amos7-shm-paging-feedback.md` — the landed substrate [ phases 1-3
  live-verified, phase 4 still open ]. **read this first** ; everything below
  composes its primitives.
- `data/tasks/amos7-shm-coding-zenka-prompt-transport.md` — shape 1 design
  [ one-shot bounded-scalar transport ].
- `data/tasks/amos7-shm-log-channel-handshake.md` — shape 2 design [ continuous
  append-only ordered stream with exactly-once ack ].

this doc adds: the third shape, the full candidate list under all three, the
**generic-core decomposition** the project owner asked for [ what is genuinely
shared across all three vs what truly diverges ], the cross-host boundary, and a
build order.

## signatures note

do NOT add the single-line `#,,.,,,...` stub at end of new files.
leave files clean — signatures are added by the signing system automatically.

## the three shapes

### shape 1 — one-shot transport [ doc #2 ]

a **bounded scalar, moved once, pull-and-verify-done.** the writer pages a
finite payload into a segment, announces a compact descriptor [ path + page
count + checksum + signed grant ], the reader pulls every page immediately and
verifies the announced checksum. there is no ordering concern across calls and
no exactly-once concern — if it fails, the caller retries the whole thing. **no
phase 3 at all** [ doc #2 scopes Feedback out explicitly ].

- proposed primitive: **`AMOS7::SHM::Transport`** [ `shm_announce` /
  `shm_receive` ] — **not built yet**, composes landed `AMOS7::SHM` +
  `AMOS7::SHM::Page`.

### shape 2 — continuous append-only stream, exactly-once [ doc #3 ]

an **unbounded ordered stream of records, ack-then-shift, identity-proven
handshake.** the writer packs records into a **pool of fixed-size segments**
[ each holding a batch of length-framed records ; **revised 2026-06-22 — was a
ring, now a segment pool**, see doc #3 "ARCHITECTURE CHANGE" ]; the reader drains
slots in pool order and publishes the durable slot index it has consumed through,
which the writer trusts as an ack; nothing is removed from the writer's queue
until acked, so a mid-stream failure degrades to the old cube path losslessly. a
one-time nonce-in-trusted-reply / nonce-as-first-active-slot handshake proves the
same authenticated peer opened the new channel. **uses all of phase 3.**

- proposed primitive: **`AMOS7::SHM::Channel`** [ segment pool +
  ack-by-slot-index feedback + key-echo confirmation ] — **not built yet**,
  composes a **dynamic pool of `AMOS7::SHM::shm_create` segments** [ NOT the
  legacy `data.channel.shm.*` ring, which is rejected and unused at runtime ] +
  `AMOS7::SHM::Feedback`'s atoms [ position value = slot index ] + a generic
  key-echo step.

### shape 3 — live-mounted current state [ NEW — not written up anywhere before ]

there is **no transfer.** the writer keeps a segment's content **current in
place** via the existing paging mechanism [ phases 1+2, no ring, no frames, no
delivery tracking ] ; any permitted reader `shm_open`s it and reads **whatever
is current**. optionally phase 3's notify-FIFO is reused for its more literal
original purpose — **"tell me when this changed"** — rather than doc #3's
position-tracking reuse of it. **no cube round-trip for read OR write after the
initial mount handshake.** this is the **simplest of the three to build** —
it needs **no new ack / ordering mechanics at all** beyond what phases 1-3
already landed [ see "the generic core", shape-3 column: it uses the **fewest**
atoms of any shape ].

- proposed primitive: **`AMOS7::SHM::Mount`** [ working name — see open
  question 4, it collides with the existing `data.mount.shm.*` mount concept ] —
  **not built yet**, composes **at most** landed `AMOS7::SHM::Page` [ but see the
  Page-mutation caveat below — Page is built for *announce-once*, not live
  mutation, so small live-state may skip it entirely ] + **only**
  `AMOS7::SHM::Feedback`'s notify-FIFO atom as a change-ding, + optionally its
  ntime stamp as a freshness marker. it does **not** use the position/ack atom at
  all [ there is nothing to ack — a reader reads current state, it does not
  consume-and-advance ].

  **the Page-mutation caveat [ a genuine divergence, flagged ]**: `AMOS7::SHM::Page`
  bakes **immutable-announce semantics** into its 32-byte index at create time —
  `Page::create` fixes `total_pages` *and* a 13-byte bmw-L13 **content checksum**
  in the index, and the last-page clip rides `data_size` in the mount header
  [ phase 2 ]. that is built for shape 1's *announce once, pull, verify, done*.
  shape 3 **mutates content live in place**, so on every change a Page-backed
  Mount would have to **rewrite the index + header** [ else `total_pages` and the
  announced checksum go stale ], or guarantee content never grows past the
  create-time `total_pages`. so the atom table's "Page: yes" for Mount is really
  **"optional — only for large live state, and only with index-rewrite-on-change"**.
  for the **small** shape-3 candidates [ a menu branch, a ticker line, a todo
  overlay ] bare-segment `substr` at offset 512 [ the `data.mount.shm.test.basic`
  pattern ] suffices with **no paging at all** — which *strengthens* the
  "simplest shape" ranking, just via a different mechanism than full Page reuse.
  whether Mount reuses Page with index-rewrite-on-change or skips Page for small
  fixed-size state is an **unresolved design choice** [ see open question 6 ], not
  settled reuse.

the key distinction from shapes 1 and 2: shape 3 has **no "done"** [ unlike
shape 1's pull-verify-done ] and **no "consumed" cursor** [ unlike shape 2's
ack-then-shift ]. the content is simply **live** ; readers sample it. the FIFO,
if used, answers only "it changed" — never "you may now discard / advance."

### freshness for tree-shaped Mount content — a per-node ntime tree, not a flat stamp [ NEW, project owner ]

the plain ntime-atom framing above [ "optionally a freshness marker" ] is right
for **flat** shape-3 content [ ticker's scalar text buffer — there is no
subtree to distinguish ], but it underserves the **tree-shaped** candidates
[ `protocol-7-menu`'s branches, a future multi-section OSD ]: a flat single
stamp tells a reader only "something changed somewhere in the whole mount,"
forcing either a full re-fetch/re-diff on every change or a coarse FIFO ding
with no indication of *where*.

**the proposal**: structure the freshness data itself as a dot-separated
namespace tree — the same shape the project already uses everywhere
[ `<a.b.c>` dotted-data convention, the `devmod dump` namespace-tree output ] —
where **each node's ntime value is the max of its own last-write time and every
descendant's**, propagated upward on write. concretely [ nested-hash in memory,
packed flat in the segment ]:

```
## conceptually : <menu.provider-a.last-updated> = ntime(provider-a's most
## recent change anywhere under it) ; <menu.last-updated> = max across all
## providers. one write to provider-a bumps provider-a's node AND every
## ancestor up to the root — that propagation is the one extra cost versus a
## flat stamp.                                                              ##
```

this gives a reader **two** things a flat stamp cannot: **(a)** one cheap
root-level check answers "has anything changed since I last looked," same as
the flat stamp ; **(b)** a reader interested in only **one** branch [ one menu
provider, one OSD section ] can check **just that node's** stamp directly,
without walking or diffing the rest of the tree — since that node's stamp
already reflects the latest change anywhere beneath it. this is strictly more
useful than the FIFO ding for tree-shaped content, and for those candidates it
likely **replaces** the ding rather than supplementing it: "check the stamp at
the path I care about, descend if it increased" is more precise than an
undifferentiated "the mount changed" event, with no watcher needed at all if
the reader is content to poll on its own cadence.

**costs, stated plainly, not hand-waved**: the writer must walk up the tree
and bump every ancestor's stamp on every leaf write [ O(depth) extra small
writes per update — cheap per write, but real bookkeeping the flat stamp does
not have ] ; and the tree needs a wire-format home in the segment [ a packed
`(path, ntime)` array at a fixed region, or serialized alongside the content
itself — not free, a real layout decision ]. **scope this to tree-shaped
content only** — applying it to ticker's flat buffer would be pure overhead
with no reader ever benefiting from the per-branch granularity.

## the candidate list — verified, with line citations

every code citation below was read in source this session. speculative/future
candidates are marked explicitly and carry no code claim.

### shape 1 [ one-shot transport ] candidates

- **`coding.cmd.submit` / `coding.cmd.summarize-context`** — doc #2, already
  covered there. `submit` is the genuinely unescaped cap case
  [ `coding.cmd.submit:14-66`, no `path=` option ] ; `summarize-context` has a
  partial `path=` file escape [ `coding.cmd.summarize-context:46-57` ]. both
  inherit the 242707-byte session-buffer ceiling
  [ `cfg/shared-params:33-34` ].
- **`web.cmd.process_template_ipc`** [ VERIFIED this session — confirm it is
  carried in doc #2's motivating-callers section if not already ]. the module
  [ `src/web.cmd.process_template_ipc` ] takes a **single `args` string** of
  the form `template_id:template_content_b32r:meta_vars_b32r:session_id`
  [ its own `# args =` header line + `:9`, `my $args_str = $hash_ref->{'args'}` ]
  and passes it straight to `<[web.process_template_ipc]>` [ `:12` ]. because the
  **whole** payload — including a base32r-wrapped template body and base32r meta
  vars — is colon-joined into one `args` string, it has the **identical
  242707-byte-cap exposure** as `coding.submit`, and the base32r wrapping makes
  it hit the cap **sooner** [ ~1.6x expansion, same as doc #2's base32 analysis ].
  this is a second real one-shot caller and belongs in doc #2's "why this design
  exists" / motivating-callers section.

### shape 2 [ continuous stream, ack ] candidates

- **`p7-log`** — doc #3, already covered. busiest cube relay client, one
  `cube_command` per log line [ `base.log.send-buffer.send-idle-callback:114-124`
  sends per line ; `p7-log.cmd.append:8-12` parses the single `args` string ].
  this is the motivating caller and the **only** one with a genuine cap-and-rate
  problem the ack mechanics exist to solve.
- **radio → httpd** [ NEW — VERIFIED this session ; this is hop-removal, NOT
  cap-avoidance, and it is distinct from why p7-log needs shape 2 ]. the radio
  audio relay is **already size-safe**: `radio.handler.stream-chunk:292` pushes
  each audio chunk to listeners via `<[base.stream.push]>->( $h, \$audio_chunk )`
  — the project's existing STRM streaming-reply mechanism [ direct writes into an
  open per-session stream ], **not** a `cube_command` per chunk. httpd registers
  itself as one of those STRM listeners: `radio.cmd.listen` opens a STRM handle
  [ `base.stream.open`, `:11-17` ] and pushes it onto `<radio.listeners>`
  [ `:29` ], and `radio.post_init:6-9` notifies httpd the endpoint is live via
  `httpd.radio_online`. so radio has **no buffer-size problem** ; the audio
  already flows over an unbounded STRM stream. **what shape 2 would remove here
  is the `cube` relay *hop*** — the radio→httpd STRM stream is relayed through
  `cube` so the bytes reach httpd's endpoint, and an `AMOS7::SHM::Channel`
  between radio and a same-host httpd would let httpd read the chunks directly
  out of shared memory instead of via the cube relay. **this is a same-host
  optimization only.** verify there is no existing same-host assumption being
  violated — there is not, today httpd and radio happen to co-locate, but **the
  cross-host case is real and forbids SHM entirely** [ see "the cross-host
  boundary" ; httpsd may run on a separate server precisely so audio traffic
  does not compete with command traffic — that case gets the tunnel/route type,
  not SHM ]. frame this candidate as **hop-removal for an already-size-safe
  stream**, never as cap-avoidance.
- **mpv future stdin-pipe audio mode** [ NEW — speculative/future, no code yet ].
  the idea: a future mpv zenka mode that starts the player with a raw-audio
  stdin pipe [ mpv supports `--demuxer=rawaudio` ] fed directly by an
  `AMOS7::SHM::Channel`, eliminating **HTTP entirely** [ not just the cube hop ]
  for the radio→player path. **key requirement the project owner flagged**: an
  audio consumer needs a **steady-ahead fill rate**, not just eventual delivery
  — underrun is audible. so this needs a **"comfortably-ahead"
  buffering/backpressure policy** layered on the same exactly-once mechanics, not
  just liveness like p7-log has. **mark speculative/future, name the requirement,
  do not over-design it** — the backpressure policy is a real distinguishing need
  but has no caller to validate against yet.
- **graphics-matrix zenka** [ NEW — speculative/future, no code yet ]. surveyed
  this session [ `ls src/ | grep '^graphics-matrix'` ]: the namespace is an
  **in-process** cell / voxel / channel / cursor / glow rendering framework
  [ `graphics-matrix.cell.place`, `.voxel-add`, `.channel.select`,
  `.cursor.move`, etc. ]. **there is no inter-zenka data-moving / buffer-transfer
  command in it today** — stated honestly, not inferred away. *if* a future mode
  needs to move frame/pixel buffers between zenki at low latency it would be the
  same shape as mpv [ continuous, steady-fill, low-latency ], but no such
  functionality exists to cite. speculative/future only.

### shape 3 [ live-mounted state ] candidates — all NEW, none written up before

- **ticker's text buffer** [ NEW — VERIFIED this session ]. the **current** push
  mechanism, read in source: a push source calls `ticker.cmd.read_file`
  [ alias → `ticker.cmd.read-file-cont` ] / `ticker.cmd.read-file-notify` with a
  **file path** [ `read-file-cont:7`, `read-file-notify:16` ] ; ticker then
  **re-slurps and bmw-checksums that file** to detect whether it actually changed
  [ `ticker.load_file_content:17-35` — `chk-sum.bmw.filesum`, skip if checksum
  unchanged ]. so today's "update push" is **"a command tells ticker to re-read a
  named file"**, and ticker re-reads + re-parses on each such command. mounting
  the live text buffer directly over SHM would bypass that entirely in **two**
  framings, both worth stating:
  - **ticker-as-holder**: ticker keeps its current content [ `<ticker.content.txt>`,
    surfaced by `ticker.cmd.current_content` ] live in an SHM segment ; other
    readers mmap it and see current state with no command at all.
  - **ticker-as-reader** [ the task's primary framing ]: ticker becomes the
    **reader** of *someone else's* live content segment — it mmaps the source's
    current state instead of being told "re-read this file" — eliminating the
    read-file-based push command and the re-slurp/re-checksum cycle entirely. the
    optional notify-FIFO ding replaces the per-update command [ "it changed,
    re-parse" ] without a cube round-trip.
- **future OSD display zenki for multiline status data** [ NEW —
  speculative/future, no code yet ] — e.g. a live todo-list overlay. **name the
  requirement only**: continuously-updated multiline text, many possible readers,
  no per-update push command needed — exactly shape 3. no code to cite.
- **`protocol-7-menu` mounting menu branches over SHM** [ NEW — VERIFIED this
  session ]. the **current** mechanism, read in source, is **two-layered**:
  - intra-zenka: an `event.add_var` watcher on `$menu_structure->{'last-changed'}`
    [ `protocol-7-menu.menu-structure-init:16-22` ] fires
    `protocol-7-menu.structure-changed` whenever `last-changed` is written
    [ `cmd.menu-update:122`, `handler.fetch-menu-data:48` ], which diffs old vs
    new and updates the GUI [ `structure-changed:14-43` ]. this is already
    event-driven and in-process — **SHM does not replace this layer.**
  - inter-zenka [ the hop SHM-mount would replace ]: a provider zenka pushes
    `protocol-7-menu.cmd.menu-update-notify <provider> <ref>`
    [ `cmd.menu-update-notify` ], and the menu zenka then **pulls** the data back
    with a `cube.<provider>.get-provider-data` round-trip
    [ `cmd.menu-update-notify:21-30` → `handler.fetch-menu-data` ]. that is a
    **per-provider notify + fetch round-trip over cube** on every update.
    mounting a provider's menu branch over SHM would let the menu zenka read the
    provider's current branch directly out of shared memory — the notify-FIFO
    ding replaces `menu-update-notify`, and the SHM read replaces the
    `get-provider-data` fetch hop. **be precise about which hop is replaced**: the
    provider→menu notify+fetch cube round-trip, not the intra-zenka watcher.
    [ note: the task's "any number of clients see edits instantly" framing is
    partly speculative — in the **current** code the menu zenka is itself the sole
    renderer/reader of provider data, not a fan-out to many external client
    readers. the concrete, citable improvement is the provider→menu fetch-hop
    removal ; a many-readers fan-out is a plausible extension, not present today.
    state both, don't conflate. ]

## the generic core — what is genuinely shared vs what truly diverges

this is the point of the consolidation pass [ task point 3 ]. the honest finding,
grounded in the landed `.pm` files [ subs verified this session via `grep ^sub` ]:

### the shared substrate is the already-landed phase 1-3 atom layer

the unification is **already real and already landed** — it is the
`AMOS7::SHM` / `Page` / `Feedback` primitive set, not a new framework to build.
the three shape-layers [ Transport / Channel / Mount ] are each a **thin
composition over the same atoms**, *not* three independent stacks. critically,
**`AMOS7::SHM::Feedback` is not a monolith — it decomposes into three separable
atoms**, and each shape uses a different subset. this subset table **is** the
"what diverges" answer:

| atom [ landed sub ] | source | shape 1 Transport | shape 2 Channel | shape 3 Mount |
|---|---|---|---|---|
| segment create / open / perm | `AMOS7::SHM::{shm_create, shm_open, permission_verify, sign_permission}` | yes | yes | yes |
| paging [ index + clip ] | `AMOS7::SHM::Page::{create, write_page, read_page, write_index, read_index}` | yes | n/a [ length-framed records in pool slots, not pages ] | **optional** [ only large live state, + index-rewrite-on-change — see caveat ] |
| segment-pool + intra-slot framing | new `AMOS7::SHM::Channel` over `shm_create` [ length-prefix framing moves *inside* each fixed-size slot ; legacy `data.channel.shm.*` ring rejected ] | no | **yes** | no |
| notify-FIFO atom | `AMOS7::SHM::Feedback::{create_notify_fifo, ding, watch_fifo, open_notify_fifo_reader}` | **no** [ phase 3 out of scope ] | yes | **optional** [ "changed" ding ] |
| position region atom [ ack ] | `AMOS7::SHM::Feedback::{write_feedback, read_feedback}` | no | **yes** [ position = ack ] | **no** [ nothing to ack ] |
| ntime freshness atom | `AMOS7::SHM::Feedback::{compute_ntime, process_feedback}` | no | yes [ guards ack ordering ] | **optional** [ freshness marker ] |

read down the columns: **shape 1 uses none of Feedback** ; **shape 2 uses all
three Feedback atoms** [ the position region *is* the ack, ntime guards its
ordering, FIFO wakes the reader ] ; **shape 3 uses only the FIFO atom**
[ as a literal "it changed" ding ] and **optionally** the ntime atom [ as a
freshness marker ], and **never** the position/ack atom. that is the genuine
divergence — and it is a clean atom-subset divergence, not a structural fork.

### the shape-specific layers must NOT be forced into a common API

this is the part that would be **false unification** if got wrong. the three
shape interfaces are genuinely different in kind and should stay independent:

- **Transport** is **asymmetric one-shot** — `shm_announce` is caller-side,
  `shm_receive` is handler-side ; they are deliberately not symmetric [ doc #2,
  "the asymmetry is deliberate and minimal" ].
- **Channel** is **ordered + exactly-once + ack + handshake** — a continuous
  stream interface with a nonce-echo confirmation and a lossless cube fallback.
- **Mount** is **no-ordering, no-ack, no-done** — "keep this current, read
  whatever is current, optionally ding on change."

forcing these three into one shape-level API would mean bending one-shot-pull,
ordered-ack-stream, and live-mount semantics into a single interface — the
classic premature-abstraction trap [ exactly the `data.channel.shm.*`-vs-paging
mistake doc #1 already resolved as "different tool, not a specialization" ]. **so
the correct output is: three thin, independent shape-layers, each composing the
shared atom set — not a grand unified SHM-use-case framework.** the unification
lives **at the atom layer** [ already landed ], not at the shape layer.

### what each shape-layer would concretely call

- **`AMOS7::SHM::Transport`** [ shape 1 ] : `shm_announce` composes
  `Page::create` + `Page::write_page` + `sign_permission` + header grant add ;
  `shm_receive` composes `shm_open` + `permission_verify` + `Page::read_index` +
  `Page::read_page` ×N + checksum compare. uses the **read-only `shm_open` mode**
  [ `{ mode => 'read' }`, already present — `SHM.pm:609` ]. uses **no** Feedback
  atom.
- **`AMOS7::SHM::Channel`** [ shape 2 ] : composes a **dynamic pool of
  fixed-size `shm_create` segments** [ each holding length-framed records ; the
  three-state slot lifecycle active/drained-and-erased-warm-spare/released with
  secure-erase-on-drain — **NOT the legacy ring** ] + **all three** Feedback atoms
  [ `create_notify_fifo`/`ding`/`watch_fifo` for notify ;
  `write_feedback`/`read_feedback` for the ack region, position value = slot
  index ; `compute_ntime`/`process_feedback` for freshness-guarded ordering ] + a
  generic key-echo confirmation step. uses the read-only `shm_open` mode for the
  slots [ already present, `SHM.pm:609` ], but still hits the **reader-write
  cross-user tension** [ doc #3 OQ1 ] because the reader must *write* its ack
  region into a possibly-other-user-owned channel — read-only-open does not
  resolve that.
- **`AMOS7::SHM::Mount`** [ shape 3 ] : composes a writer-keeps-content-current
  segment [ **either** `Page::create`/`write_page` with index-rewrite-on-change
  for large live state, **or** bare `substr`-at-512 for small fixed-size state —
  see the Page-mutation caveat ] + `shm_open` read-only [ readers ] + **only**
  `create_notify_fifo`/`ding`/`watch_fifo` [ optional change-ding ] + optionally
  `compute_ntime` [ freshness ]. **no ring, no position region, no ack, no
  key-echo handshake.** the read-only open makes it cross-user-clean trivially
  [ readers never write the segment ], so unlike shape 2 it has **no**
  cross-user-write tension at all — the simplest shape on the ack/ordering/security
  axes [ the one open mechanics question is Page-reuse-vs-bare-segment, OQ6 ].

### the read-only `shm_open` mode — present, used by shapes 1 and 3

**update [ 2026-06-22 ]: the read-only `shm_open` mode is now PRESENT, not a
gap.** verified this session — `AMOS7::SHM::shm_open` selects the open mode by
option: `my $open_mode = ( ( $options->{'mode'} // '' ) eq 'read' ) ? '<' :
'+<'` [ `SHM.pm:609` ]. so `{ mode => 'read' }` → `'<'` already exists ; the
default remains `'+<'` [ read-write ]. `shm_create` opens `'+>'` so the file
lands writable only by its owner UID ; `/dev/shm` is world-*readable* not
world-*writable*. consequence:

- **shapes 1 and 3** [ reader only reads ] both use the **read-only `'<'` open**
  [ `{ mode => 'read' }` ], which a world-readable `/dev/shm` file permits
  **cross-user** with no OS-perm tension. this is **no longer a prerequisite to
  build** — it is already landed ; just pass the option. [ this section and OQ2
  originally listed it as an absent API gap citing `SHM.pm:599` ; that drift is
  corrected here. ]
- **shape 2** [ reader *writes* its ack region ] cannot use read-only for that
  region and therefore inherits the genuine cross-user-write problem [ doc #3
  OQ1 — recommended fix: a separate p7-log-owned ack segment so each region stays
  single-owner-write ]. **this is the one place the shapes genuinely diverge on a
  security primitive, not just an atom subset.**

## the cross-host boundary — a hard architectural constraint, stated plainly

`AMOS7::SHM` is fundamentally a `/dev/shm` mmap mechanism — **same physical host
only.** this is **not a tuning detail ; it is a hard boundary.** the real case
the project owner raised: `httpsd` may run on a **remote** server [ separate host
from radio ], specifically so audio traffic does not compete with `protocol-7`
command traffic at high load. **for that case SHM cannot apply at all.**

the right answer for the cross-host case is a **different, separately-tracked,
not-yet-built** piece of architecture:
`data/ai-mem/claude/topic-hybrid-namespace-routing.md` describes a `tunnel` /
`route` connection type [ alongside the existing `unix` / `ip.tcp` transports ]
and **already names** "interconnecting a local/trusted core cube with a
DMZ-facing cube where externally-reachable zenki [ httpd, httpsd, etc. ] connect"
as its anticipated first consumer — the **command-relay zenka**
[ `data/tasks/command-relay-zenka.md`, confirmed present this session : "maps
input commands/routes to output routes, primarily for connecting two cube zenki,
where one is the local/trusted core and the other is externally-facing" ].

**therefore, stated as the binding rule:**

- **same-host** radio↔httpd / any same-host pair → `AMOS7::SHM::Channel`
  [ shape 2 ] or the relevant shape primitive.
- **remote httpsd** [ separate host ] → the **tunnel/route connection type**
  [ `topic-hybrid-namespace-routing.md`, not-yet-built, tracked there ], with
  **cube still gating who may establish either** connection.
- **do NOT attempt to make SHM solve the cross-host case** — that would be wrong,
  not merely unbuilt. recommend explicitly: this doc does **not** design the
  remote path ; it points at the tunnel/route work and stops.

**the long-term significance of this boundary, stated plainly [ project owner —
this is the capstone of the whole taxonomy, not a minor future footnote ]**:
the per-node ntime tree proposed under shape 3 ["freshness for tree-shaped
Mount content"] is a **structure**, not an SHM-specific mechanism — "check one
node's freshness, descend only where it moved" does not depend on mmap at all.
**that is exactly why this boundary matters**: the same idiom can be
instantiated **twice** — locally via `AMOS7::SHM` [ this doc's shape 3 ], and,
once `tunnel`/`route` exists, as a **protocol-level counterpart** riding that
connection type for the remote case. the two instantiations share one semantic
model and differ only in transport [ mmap vs network ]. **the result of having
both is not "two features" — it is one uniform interconnected namespace tree
spanning every node and zenka in the network**, local or remote, with the same
"watch a path, get told when it or any descendant changed, descend only where
it moved" behavior throughout — as flexible as an `event.add_var` watcher on a
single process's state hash [ `protocol-7-menu.menu-structure-init:16-22` is
the in-process precedent already in this codebase ], but **not bound to one
process, one host, or one cube's reach**. this is the same throughline as
`topic-network-as-computer` / `topic-namespace-tree-intelligence` in project
memory [ "the network IS the computer" / "the tree IS the intelligence" ] —
this doc's contribution is the concrete mechanism [ ntime-tree + SHM locally,
ntime-tree + tunnel/route remotely ] that makes that vision literally
buildable, not just aspirational. **still not designed here** — the protocol
counterpart depends on `tunnel`/`route` existing first, and that work is
tracked separately [ `topic-hybrid-namespace-routing.md` ] — but it should be
read as the reason the local shape-3 freshness design is worth getting right
now, not as an unrelated someday-idea.

## build order across all candidates

given everything now known:

1. **phase 4 of `amos7-shm-paging-feedback.md` first — it gates all three
   shapes.** cleanup/lifecycle [ segment + FIFO unlink on normal teardown, both
   zenka and standalone mode ] is a hard prerequisite for **every** shape — none
   may ship a `/dev/shm` leak. it is the common blocker, currently design-only.
   **do this before any shape-layer.**

2. **shape 3 [ `AMOS7::SHM::Mount` ] is the simplest and most-already-done —
   build it first among the shapes.** it needs **no new ack/ordering mechanics**
   — it is largely phases 1+2 as-landed, plus the **read-only `shm_open`
   mode** [ the one small shared API gap ] and **optionally** the already-landed
   notify-FIFO atom as a change-ding. it has **no** cross-user-write tension
   [ readers never write ]. caveat against overstating: "simplest" means "no new
   ack/ordering mechanics," **not** "free" — it still rides phase 4 like
   everything else, still needs the read-only open, and carries **one unresolved
   mechanics choice**: Page reuse with index-rewrite-on-change vs a bare
   `substr`-at-512 segment for small fixed-size state [ OQ6 — the Page-mutation
   caveat ; Page bakes announce-once `total_pages` + checksum into its index, so
   it is **not** as-landed-reusable for live mutation without index rewrites ].
   **the read-only `shm_open` mode is the highest-leverage single primitive to
   add** — it unblocks shapes 1 and 3 both.

3. **shape 1 [ `AMOS7::SHM::Transport` ]** — also read-only [ no cross-user-write
   tension ], composes Page + the read-only open + checksum verify, no Feedback.
   its own gating question is doc #2 OQ1 [ SHM vs generalizing the temp-file
   escape for the coding prompt path ] — that decision sets whether Transport
   gets built now or waits for the workspace use case. not blocked by anything
   shape 2 needs.

4. **shape 2 [ `AMOS7::SHM::Channel` ] is last — it is the richest shape and
   carries the only genuine cross-user-write problem.** **revised 2026-06-22**:
   the old framing here was "fix the ring's pre-existing bugs first." the ring is
   now **rejected, not fixed** [ doc #3 "ARCHITECTURE CHANGE" ] — its
   wrap-around data-corruption bug [ `data.channel.shm.write:26-45` ] is the
   *motivation* for the redesign, **designed out** by the segment-pool model
   rather than patched [ no shared free-space arithmetic → the bug class cannot
   exist ]. what shape 2 still needs: **pool management** [ create/seal/rotate/
   erase/retire of fixed-size slots, the three-state lifecycle ] ; **notify**
   [ doc #3 gap #1, composed from the landed Feedback FIFO atom ] ; the
   **reader→writer ack path** [ doc #3 gap #3, the Feedback position atom with a
   slot-index value ] ; and a real answer to the **cross-user reader-write
   ack-region ownership** [ doc #3 OQ1 — unchanged in force ]. it composes all
   three Feedback atoms + the pool + handshake + lossless fallback, and is most
   worth getting last, after the atom layer has been exercised by the two simpler
   shapes.

5. **speculative/future candidates gate nothing.** mpv stdin-pipe audio,
   graphics-matrix buffer-move, and future OSD zenki have **no code today** and
   must not block any of the above. name their requirements [ mpv's
   steady-ahead-fill backpressure especially ] but do not design to them.

## open questions [ for the project owner — do not decide unilaterally ]

1. **RESOLVED — build the thin shape-layers, do not leave the atom layer
   implicit.** the project owner confirmed: "three thin independent shape-layers
   over a shared atom set" is the right altitude. the false-unification trap is
   forcing the three shapes into one *interface* — already correctly avoided
   above — not the existence of `Transport`/`Channel`/`Mount` as actual packages
   encapsulating their own fixed choreography [ checksum → page → sign → grant on
   write ; open → verify → reassemble on read, etc. ]. reasoning for building
   them rather than leaving callers to re-derive the sequence by hand: the
   project's own "wait for two or three independent pressure points" bar
   [ `topic-hybrid-namespace-routing.md`'s meta-point ] is **already cleared per
   shape, not just overall** — shape 1 has `coding` + `web` ; shape 2 has `p7-log`
   + `radio`↔`httpd` ; shape 3 has `ticker` + `protocol-7-menu`. a thin wrapper
   around an already-fixed sequence of already-landed calls is not new mechanics
   — it is the same move as `lock_memory`'s self-detecting fork-guard
   [ `amos7-shm-paging-feedback.md` ]: cheap, mechanical, and converts "every
   caller must get the sequence right" into "every caller can't get it wrong."
   leaving it implicit just relocates that risk into 4+ separate call sites.
   **build lazily, one shape at a time, in the build order above** [ Mount →
   Transport → Channel ], each wrapper built when its shape's first real caller
   is actually implemented — grounded in that caller's real requirements, not
   speculated in advance of one.

2. **RESOLVED — the read-only `shm_open` mode is already present** [ `SHM.pm:609`,
   `{ mode => 'read' }` → `'<'`, verified 2026-06-22 ; an earlier draft of this
   doc mis-cited it as absent at `SHM.pm:599` ]. shapes 1 and 3 just pass the
   option ; no primitive change is needed to unblock them. nothing to confirm.

3. **shape 2's cross-user reader-write ack-region ownership** [ carried from
   doc #3 OQ1, restated here because it is the **one** place the shapes diverge
   on a security primitive, not just an atom subset ]. p7-log [ bare
   `protocol-7` ] must *write* the ack region of a segment possibly owned by a
   `taeki` sender ; `/dev/shm` is world-readable but not world-writable. doc #3's
   recommended fix [ a separate p7-log-owned ack segment, each region
   single-owner-write ] doubles the per-channel object count. this is shape 2's
   gating decision and does not affect shapes 1/3 — confirm before building
   `AMOS7::SHM::Channel`.

4. **the shape-3 primitive name.** `Mount` collides head-on with the existing
   `data.mount.shm.*` family and the `AMOS7::SHM` "mount a segment" concept
   [ a segment is already "mounted" in every shape ]. a clearer name might be
   `AMOS7::SHM::Live` / `::State` / `::Current` [ "live-mounted current state" ].
   flagging rather than deciding — the working name `Mount` is used above only
   for continuity with the conversation. which name?

5. **RESOLVED [ direction, not full spec ] — freshness is per-mount-shape, not
   one-size-fits-all.** flat shape-3 content [ ticker's scalar buffer ] keeps the
   single optional ntime stamp as described above. **tree-shaped** content
   [ `protocol-7-menu` branches, future multi-section OSD ] instead gets the
   **per-node ntime tree** [ see the new "freshness for tree-shaped Mount
   content" subsection under shape 3 ], which likely **replaces** the FIFO ding
   for those candidates rather than supplementing it — a reader checks the stamp
   at the path it cares about and descends only where it increased, which is
   strictly more precise than an undifferentiated ding. still open: the exact
   wire layout for the per-node tree [ packed `(path, ntime)` array vs serialized
   alongside content ] — not yet decided, left for whichever shape-3 caller
   [ likely `protocol-7-menu` ] is implemented first. **note these still
   cluster**: FIFO-ding [ flat content ], the per-node ntime tree [ tree-shaped
   content ], and Page's own index checksum [ OQ6 ] are three answers to "how
   does a shape-3 reader know what's current/valid," now scoped by content shape
   rather than chosen freely per mount.

6. **shape-3 mechanics: Page reuse with index-rewrite-on-change, or bare
   `substr`-at-512 for small fixed-size state?** the Page-mutation caveat [ see
   the shape-3 section ] : `AMOS7::SHM::Page` bakes announce-once `total_pages` +
   a 13-byte content checksum into its index at `create` time, built for shape 1's
   immutable announce — it is **not** as-landed-reusable for live mutation without
   rewriting the index [ + mount-header `data_size` ] on every change. for the
   small shape-3 candidates [ menu branch, ticker line, todo overlay ] a bare
   segment with `substr` at offset 512 [ the `data.mount.shm.test.basic` pattern ]
   needs no paging at all and sidesteps the issue. **which does Mount use —
   index-rewrite-on-change Page for large live state, bare-segment for small, or
   both behind a size threshold?** this is shape 3's one genuinely open mechanics
   question and the only place its "almost entirely phases 1+2 as-landed" framing
   needs qualifying.

## style

[ same binding list as the three prior SHM docs ]

- lowercase comments, `[ word ]` bracket annotations [ never `( word )` ]
- `$ARG` / `@ARG`, not `$_` / `@_`, where used implicitly
- dotted-data style `<mount.shm.segments>->{}`, not `$data{'mount'}{'shm'}{}`
- `.cmd.` / whitelisted routines return `{ mode => true|false, data => STRING }`
  — split raw-hash / scalar-ref helpers into separate non-`.cmd.` routines
- `<[base.logs]>->( N, fmt, args )` for logging, not warn / print
- config paths via `<system.root_path>/...`; never bare relative
- TRUE / FALSE / UNKNOWN constants, never literal 0 / 1
- standalone packages use the lib-path `BEGIN` + `$main::PROTOCOL_SEVEN` check
  [ mirror `AMOS7::CHKSUM` / `bin/amos-chksum` ]
- new SHM code stays under `data.mount.shm.*` / `data.channel.shm.*` /
  `AMOS7::SHM::*`, **never** `base.*`
- guard any timer with a fallback interval [ undef interval = max-rate loop ]

#,,,.,.,,,..,,..,,..,,,,.,,,.,,,.,,,,,,.,,..,,..,,...,...,...,,..,,,,,.,,,,.,,
#H447ZJPWJQG7LTKGR5QFTBJY6QM7GZEXXWCTRK64NLIBZQI6JR7KOX7I3BFR2OCF4OORRKG2EHTAE
#\\\|YTPBGV4L3NA3W5BUWLBEG65MHZG4YOXMXJZVKBOQA3Q3EGMGDVB \ / AMOS7 \ YOURUM ::
#\[7]GV5UUTFJG65UQYAVXH6XS33RK67R6G2BL64MFTIAGRL4BHA726AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
