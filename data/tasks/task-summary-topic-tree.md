# task: task-zenka semantic topic tree for self-improving summaries

## status [ 2026-06-21 ]

**phase 1 is implemented and live-verified.** the relay mechanism described
below is real, working code, not a plan — see "phase 1 — actual
implementation" for the file list, what was verified, and two known
limitations [ collision risk on the cache key, cross-zenka path unexercised ].
phases 2-4 [ tree structure/routing, formal delta storage, idle integration ]
are still design only.

**the relay origin split below is the as-built architecture**, not the
original design. the original draft put cache-query/notify entirely in the
coding zenka. that broke for the actual motivating case — large sessions are
chunked by `bin/mcp-server-p7`'s `_do_summarize` rolling-window loop, so the
coding zenka never sees the whole session text and never holds the final
summary to relay from. the fix: relay from whichever side actually owns the
finished content. read "why the relay differs by origin" below before
touching either path.

## signatures note

do NOT add the single-line `#,,.,,,...` stub at end of new files.
leave files clean — signatures are added by the signing system automatically.

## objective

give the **task zenka** ownership of a persistent, self-improving **semantic
topic tree** of summaries. the tree is fed from two sources:

  1. MCP-triggered session/memory summaries — `bin/mcp-server-p7`'s
     `session_catchup` (and the other memory/summary tools) dispatch
     summarization to the **coding zenka**, which runs an llm and returns text
  2. the coding zenka's own top-level task summaries

today source [1] is one-shot and stateless — every `session_catchup` call
re-summarizes from scratch, nothing is cached, and repeated catch-ups on the
same session never accumulate precision. the goal is a tree of small,
subtopic-bound summary files that absorb only the deltas relevant to each
subtopic, with **lazy deduplication**, so repeated catch-ups stop regenerating
from scratch and precision rises over time without unbounded linear growth.

## why a tree, not one merged summary

an earlier draft of this design used a single combined "main" summary that
absorbed all deltas via periodic merge passes. rejected: repeatedly merging
into one summary degrades precision over many iterations [ each pass risks
losing detail or drifting ] and the file grows without bound.

the revised design is a **semantic tree of small, subtopic-bound files**. each
subtopic file only absorbs deltas relevant to its own topic, so per-topic
growth is bounded and merges stay high-precision [ small focused inputs to each
merge, never one ever-growing blob ]. this mirrors the topic-file + index
pattern this project already runs for its own ai memory
[ `data/ai-mem/kimi/MEMORY.md` + per-topic `.md` files ] — give the task/coding
zenka pair the architecture that already works, rather than inventing a new one.

## why the relay differs by origin

two earlier drafts were tried and rejected in sequence before landing here —
both rejections came from reading the actual code, not preference:

**draft 1**: `bin/mcp-server-p7` itself notifies the task zenka via a new
`task.summary-reference` command + a note-based correlation registry, after
dispatching a summarize job to the coding zenka. rejected: that correlation
problem is already solved. `src/task.cmd.summarize` already dispatches to
`src/coding.cmd.summarize-context` with a `callback_id=$task_id`, and
`src/coding.handler.deferred_reply` already routes the completed result
back to `task.cmd.summarize-done` by that id [ task-context case ]. a parallel
note-prefix registry would duplicate working, tested infrastructure instead of
extending it.

**draft 2**: make the **coding zenka** the relay for every caller, including
`session_catchup` — extend `coding.cmd.summarize-context` with a `tree=1`
flag and have `coding.handler.deferred_reply` do the query/notify. rejected
for the `session_catchup` case specifically: `_do_summarize`
(`bin/mcp-server-p7:2242+`) chunks any session past the local model's
VRAM-safe context size into a rolling-window loop — *N separate*
`coding.summarize-context` calls, each seeing one chunk + a running summary,
with the **final summary assembled in the MCP server itself**. the coding
zenka never receives the whole session text and never produces "the session
summary" as a single task to relay from. for the case that motivated this
whole feature [ large sessions ], draft 2 structurally cannot work.

**the landed design**: relay from whichever side actually holds the finished
content, two origins:

  - **`session_catchup` → `bin/mcp-server-p7`'s `_do_summarize` itself.** it
    already assembles the full content and the final summary, so it computes
    `chk` over the full instruction+text, does a **synchronous**
    `cube_command("task.summary-tree-query ...")` *before* any chunking or
    inference at all [ hit → return cached, skip the entire chunking loop ],
    and on miss, notifies *after* assembling the final result. both calls are
    best-effort [ short `alarm()`, any failure is treated as a miss / silently
    skipped ] — a down task zenka never breaks or delays catch-up. this is
    *simpler* than the coding-relay version: a synchronous query needs no
    timer/continuation dance, since the MCP server already blocks on
    `cube_command` for everything else it does.
  - **coding-zenka-native top-level tasks → `coding.cmd.summarize-context` +
    `coding.handler.deferred_reply`.** here the coding zenka genuinely owns
    the whole task and summary [ no chunking involved ], so the `tree=1`/
    `origin` flag + dual-action `deferred_reply` design is correct as
    originally drafted. **this mechanism is built [ phase 1 ] but nothing
    triggers it automatically yet** — wiring an auto-trigger into
    `coding.task.queue` completion needs its own design pass [ which tasks
    qualify, what "origin" means for a task with no session/focus ] and was
    deliberately left out of phase 1 rather than bundled in underspecified.

no separate cache lives in the coding zenka, and none lives in `mcp-server-p7`
either. single source of truth is the task-zenka-owned tree; both origins
query it. a second store would only buy invalidation bugs [ which one wins
when they disagree ] for no benefit.

## what to read first

```bash
sed -n '1,104p' data/tasks/valued-tree-task-zenka-integration.md  ## format + tone twin
grep -n 'session_catchup\|store_summary_focus' bin/mcp-server-p7  ## summarize dispatch + cube_command
cat src/coding.cmd.summarize-context     ## existing dispatch : focus/store/callback_id parsing
cat src/coding.handler.deferred_reply    ## existing coding->task relay : extend this, don't replace it
cat src/task.cmd.summarize                ## existing task->coding dispatch pattern [ task-context case ]
cat src/task.cmd.summarize-done           ## existing coding->task callback receiver
head -60 src/task.init_code               ## task data layout to match
ls src/task.cmd.*                         ## existing .cmd. command shape
ls src/coding.self_test.*                 ## tier-0/tier-1 escalation to mirror
```

## context

### what exists

- MCP server: `bin/mcp-server-p7` — `session_catchup` etc. call
  `coding.summarize-context` via blocking `cube_command`, unchanged by this design
- existing coding<->task relay for the task-context case [ the pattern this
  design extends, not replaces ]:
  `src/task.cmd.summarize` -> `src/coding.cmd.summarize-context`
  [ `callback_id=$task_id` ] -> `src/coding.handler.deferred_reply`
  [ cross-zenka route-send ] -> `src/task.cmd.summarize-done`
  [ stores `$task->{'summary'}`, fires original caller's reply ]
- task zenka: `cfg/zenki/task/`, `src/task.init_code`,
  `src/task.cmd.*` [ create/claim/complete/result/summarize/... already
  present ]
- coding self-test tiered escalation: `src/coding.self_test.*`
  [ tier-0 local / tier-1 / tier-2 ] — the classification step below mirrors
  this escalation shape
- ai-mem precedent: `data/ai-mem/kimi/MEMORY.md` + per-topic files — the exact
  index + small-topic-file pattern this tree reproduces
- design precedents to follow rather than re-derive:
  `topic-checksum-addressing.md`, `topic-checksum-tree-wire.md`
  [ content-addressed, not sequential ids ],
  `topic-checksum-parenting-namespace-trees.md` [ collision-protected
  classification / parenting ]

### what is needed

  1. `coding.cmd.summarize-context`: new tree flag + origin params; store
     origin in the `deferred_replies` record at submit time
  2. `coding.handler.deferred_reply`: best-effort cache query before inference
     [ skip inference on hit ], fire-and-forget notify-to-task after completion
     — dual action [ reply-to-caller AND notify ], not callback-XOR-local-reply
  3. new task-zenka commands: a content-checksum-keyed cache query, and a
     delta-receive [ phase 1 stores deltas flat; phase 2 adds routing ]
  4. topic-tree on-disk structure + routing/classification of a delta to a
     subtopic
  5. checksum-indexed focus-variant deltas [ same checksum doubles as cache key
     and dedup key ]
  6. idle-detection + integration-pass merge

## namespace

topic files are addressed via a **dot-separated semantic namespace**,
mirroring the project's module dot-notation [ e.g. `src/base.init_code` ]
— but purely as a *semantic topic subtree*, never a literal module/file path.
proposed scheme:

```
  task.summary.<area>.<subtopic>        ## task-zenka-native task summaries
  coding.session.<session-key>.<topic>  ## mcp-triggered session catch-ups
```

`<area>` / `<topic>` are semantic labels chosen by the classifier [ phase 2 ],
not filenames typed by a caller. on disk these map under a tree root, e.g.:

```
  data/topic-tree/<namespace-as-path>/<subtopic>.md   ## the merged subtopic file
  data/topic-tree/<namespace-as-path>/deltas/<chksum>.md  ## raw focus-variant deltas
  data/topic-tree/INDEX.md                             ## tree index, ai-mem style
```

the namespace is the addressing key; the path is one rendering of it. keep them
consistent so the index can list a subtopic by its dotted name.

## the cache key is content-aware — this is the part that must not be skipped

session files grow day to day. a cache keyed on `(session_id, focus)` alone
would hand back yesterday's summary for a session that has grown since —
silently defeating "catch up". the cache key [ and the delta dedup key, same
value ] must be:

```
  checksum( focus . content )    ## as built: bmw-L13 [ 13-char base32,
                                  ## ~65 bits — src/base.chk-sum.bmw.* /
                                  ## the harmonize_L13 division-by-13 loop ],
                                  ## switched from the original 7-char
                                  ## amos_chksum [ ~35 bits, project-wide
                                  ## 7-char ceiling ] for materially lower
                                  ## collision risk
```

content grows -> checksum changes -> cache miss -> fresh summary, automatically.
each relay origin computes this checksum itself, at the point it has both the
final content and the moment to check before spending an inference call — the
coding zenka for the coding-native case, `_do_summarize` for the
`session_catchup` case [ see "why the relay differs by origin" above ].

**how each origin computes bmw-L13 — this is load-bearing, read before
touching either side**: the coding zenka calls `<[chk-sum.bmw.L13-str]>`
**in-process** [ no cube command line involved ]. `bin/mcp-server-p7`
[ a standalone script, no zenka `%code` ] does **not** call the cube-exposed
`bmw-L13` command for this — that command's single-line input goes through
`base.handler.command`'s buffer, hard-capped at **242707 bytes**. tail-
truncated session content can run to ~400KB, so shipping it as one command
line either errors or — what we actually hit live — leaves the connection in
a bad state with no clean error in the log. `bin/mcp-server-p7` instead
ports the harmonize_L13 loop standalone [ `Digest::BMW::bmw_512` +
`AMOS7::Assert::Truth` + `AMOS7::TEMPLATE`, all reachable via the same
lib-path `BEGIN` block `bin/amos-chksum` uses ] and computes the checksum
**locally** — verified byte-identical to the live cube command's output for
the same input, and ~0.13s for a 400KB string. **never route content-sized
input through a cube command line** — short values [ the 13-char `chk`
itself, used for the actual cache query/notify ] are fine.

**known limitation, not yet fixed**: the two origins are not guaranteed to
produce the *same* `chk` for byte-identical content. the coding zenka hashes
`$content` directly [ raw bytes, decoded from its own `:B32:` input ].
`bin/mcp-server-p7`'s `_tree_chk` builds its input from `$instruction`/`$text`
which are perl-decoded character strings [ from JSON::XS decode and
`utf8::decode` respectively ] — same logical text, not necessarily the same
byte sequence fed into `Digest::BMW::bmw_512`. invisible in phase 1 [ the two
origins' cache entries never need to match each other — coding-native
auto-trigger doesn't exist yet, session and task-context caches don't
overlap ], but it **will** silently defeat cross-origin dedup the moment
phase 2's shared tree assumes `chk` is a true content-address across origins.
unify deliberately in phase 2 — don't rush it, the byte-vs-char mismatch that
caused the UTF-8 double-encode bug above lurks in any unification attempt too.

## coding.cmd.summarize-context: new params

```
  tree=1                 ## opt the calling context into the summary tree
  origin=<B32 JSON>       ## { session_id|client|focus|memory_path, source }
```

when `tree` is absent: behavior is unchanged from today, byte for byte.

when `tree=1`:

  1. before enqueueing the inference task, compute
     `chk = checksum(focus . content)` and issue a **best-effort** query to the
     task zenka for an existing tree entry under `chk` [ short timeout; on
     timeout or miss, fall through to inference exactly as if `tree` were
     absent — never block the caller on a slow/unreachable task zenka ]
  2. on cache hit: skip the inference enqueue entirely, reply immediately with
     the cached text [ same reply shape as a fresh summary, caller can't tell
     the difference ]
  3. on cache miss: proceed with the existing enqueue, but store `chk` and
     `origin` in the `deferred_replies` record alongside the fields already
     stored there [ `reply_id`, `callback_id`, `task_id`, ... ] so they survive
     to completion

## coding.handler.deferred_reply: dual action, not XOR

today this routine is callback-XOR-local-reply [ `if length $callback_id ...
else ...` ]. the tree case needs **both**, run in this order on completion:

  1. **reply to the original caller** exactly as today [ local reply via
     `base.callback.cmd_reply`, unchanged code path — the MCP caller never
     waits on the task zenka ]
  2. **then**, if this deferred record carries `chk`/`origin` [ i.e. `tree=1`
     was set and this was a cache miss ], fire a **non-blocking** notify
     [ `protocol-7.route-send`, not a call that waits for a reply ] to the task
     zenka with `chk`, `origin`, and the result text, so the task zenka can
     record it as a pending delta. this happens after the caller already has
     their answer — it must never delay or risk the caller's reply.

## notification default policy [ asymmetric, same intent as before, new mechanism ]

- **mcp-server-triggered tasks** [ `session_catchup` etc. ]: `tree=1` is passed
  **by default, automatically**, for every newly-dispatched summarize call.
  exceptions [ `tree` omitted / no notify ]:
    - the caller explicitly passed a parameter disabling it
    - note: a cache *hit* still counts as tree-aware — it's not "no
      notification", it's "no new delta", which is correct: nothing changed
- **coding-zenka-native tasks** [ the zenka's own internal task tree —
  subtasks, tool-call loops, self-test polling, vastly outnumbering anything
  worth indexing ]: default is **off**. only an explicit opt-in [ `tree=1` on
  submission of a *top-level*, user-meaningful task ] enables it.
  rationale: auto-notifying on every internal subtask floods the tree with
  noise; only whoever creates a top-level task can judge whether its outcome is
  summary-worthy.

## focus-variant indexing

when a different summarization focus/instruction is requested for what is
otherwise the same session/topic, store it as an **additional indexed delta**,
never an overwrite. the checksum `chk = checksum(focus . content)` [ same value
used as the cache key above ] means:

- the same focus+content combination dedupes naturally [ same checksum = same
  cache entry / same delta file, write is idempotent ]
- a different focus, or grown content, produces a distinct checksum and a
  distinct delta — lookups stay consistent with how the rest of the project
  addresses content

deltas live at `data/topic-tree/<ns-path>/deltas/<chksum>.md` and carry a small
header [ source, origin context, focus, ntime, integrated-flag ].

## idle-triggered integration pass

when **both** the task zenka and the coding zenka have been idle for a
configurable threshold, an integration pass runs:

- it walks pending, not-yet-integrated focus-variant deltas grouped by topic
- for each topic, it merges that topic's pending deltas into the topic's
  subtopic file via an **actual llm synthesis call** — NOT naive concatenation
  [ concatenation is exactly the precision-degrading failure mode being
  avoided ]
- because each merge is scoped to one small subtopic file at a time, growth
  stays bounded and precision *increases* per pass instead of degrading
- raw focus-variant deltas are **retained** [ checksum-indexed ] even after
  integration — mark them `integrated`, do not delete — so nothing is lost if a
  later pass needs to re-derive or audit

idle detection should reuse whatever idle/heartbeat signal the task and coding
zenki already expose; the threshold is a config value [ `<system.root_path>/...`
relative if file-backed ]. guard any timer with a fallback interval [ undef
interval = max-rate loop ].

## topic routing / classification

deciding which existing subtopic a new delta belongs to [ or whether it warrants
a brand-new subtopic file ] reuses the classification / parenting approach from
`topic-checksum-parenting-namespace-trees.md`:

- **tier-0**: a cheap local-model [ coding-zenka locally-loaded model ]
  classification step — given the delta plus the current INDEX of subtopic names
  + one-line descriptors, pick the best-fit subtopic, or signal "new subtopic"
- **escalate** to a stronger model only when the tier-0 result is ambiguous
  [ low confidence / tie ], mirroring the existing tier-0/tier-1 self-test
  escalation in `src/coding.self_test.*`
- a brand-new subtopic gets a checksum-parented name under its parent namespace
  to avoid collisions [ per the checksum-parenting design ]

## model assignment for actual file writes

the final subtopic-file synthesis/write — both **initial creation** and
**idle-pass integration merges** — is performed by the **Opus model** [ or
whichever the project's strongest configured model is ] so quality and style
best match project requirements. the cheaper routing/classification decision
[ above ] uses the coding zenka's locally-loaded model. route the write through
the coding zenka's model-pinning path [ tier-1.5 model-pinning is already
landed ] so the strong model is selected deterministically for the write step.

## phased implementation

### phase 1 — DONE, live-verified 2026-06-21

**task zenka** [ flat storage, no routing/classification yet — that's phase 2 ]:
- `src/task.cmd.summary-tree-query` — lookup by `chk`. two call shapes:
  direct synchronous reply [ `mode=>size|false` ] for `cube_command` callers,
  and a `callback_query_id=` cross-zenka fire-style variant that route-sends
  the result to `coding.tree-query-reply` instead
- `src/task.cmd.summary-tree-notify` — upsert-by-`chk` store; decodes
  B32-wrapped `result`/`origin`/`focus` [ focus is free text, must be
  B32-wrapped by every sender — seeBug note below ]
- `src/task.persist.summary_tree.{save,load}` — yaml persistence,
  mirroring `task.persist.{save,load}`; wired into `task.init_code`
- `cfg/zenki/task/zenka.v7`: whitelisted both new commands; added
  `format.json` to `modules.load` [ needed for `format.json.decode` ]
- `cfg/zenki/cube/access.zenki`: `access.cmd.usr.coding` can call
  both task commands; `access.cmd.usr.task` can call `coding.tree-query-reply`

**coding zenka** [ mechanism for the coding-native origin; not yet triggered
by anything — see "why the relay differs by origin" ]:
- `src/coding.cmd.summarize-context`: `tree=1` + `origin=` params; on
  `tree=1`, computes `chk`, fires the cross-zenka query with a 3s fallback
  timer [ `src/coding.handler.tree_query_timeout` ], registers a pending
  entry in `$data{'coding'}{'tree_query_pending'}`
- `src/coding.cmd.tree-query-reply` — receives the async query result;
  hit → reply directly, skip inference; miss → proceed to enqueue
- `src/coding.tools.handler.summarize_enqueue` — the original inference-
  enqueue body, extracted into a shared helper so the tree-absent path, the
  query-miss path, and the timeout path all call the identical code
- `src/coding.handler.deferred_reply`: dual action — reply to caller
  first [ unchanged ], then fire-and-forget notify to the task zenka when
  `chk` is present
- `cfg/zenki/coding/zenka.v7`: whitelisted `tree-query-reply`

**mcp server** [ the actual `session_catchup` relay — see status note at top
of this doc for why it ended up here instead of the coding zenka ]:
- `bin/mcp-server-p7`: added `AMOS7::CHKSUM` [ standalone lib-path BEGIN
  block, same pattern as `bin/amos-chksum` ]; `_tree_chk`/`_tree_query`/
  `_tree_notify` helpers; `_do_summarize` takes an optional `$origin` param —
  query before chunking, notify after assembling the final result, both
  best-effort with a short `alarm()`; `tool_session_catchup` builds `$origin`
  by default [ `{session_id, client}` ] unless the new `no_tree=1` tool param
  is set; `no_tree` added to the tool's `inputSchema`

**bug found + fixed during verification, worth keeping in mind for phase 2+**:
a double-UTF8-encode bug — `Encode::encode('UTF-8', $x)` was being called on
`$x` that was already a raw UTF-8 byte string [ everything `cube_command`
returns in this codebase is unflagged bytes, never perl-decoded chars ].
calling `encode()` on already-encoded bytes treats each byte as a separate
Latin-1 codepoint and re-encodes it — classic mojibake [ "—" became "â" ].
fixed in `_tree_notify`. rule going forward: only `Encode::encode()` text that
is *known* to be real perl character data [ e.g. MCP JSON-RPC args, which
*are* decoded by `$json->decode` ] — never something that already came back
from `cube_command` or `$json->encode`.

**known limitations** [ not blockers, but real ]:
- chk now uses bmw-L13 [ 13-char, ~65 bits ] — switched from the original
  7-char amos_chksum for materially lower collision risk. see "the cache key
  is content-aware" above for why `bin/mcp-server-p7` computes it locally
  rather than via the cube-exposed `bmw-L13` command [ a real incident during
  this work : a single command line near the tail-truncation cap (~400KB)
  hit `base.handler.command`'s 242707-byte buffer ceiling, with no clean
  error in the log — the connection was just left in a bad state ]
- the two relay origins do not yet guarantee the same `chk` for identical
  content [ byte-string vs perl-character-string input — see "how each
  origin computes bmw-L13" above ]. invisible in phase 1, blocks cross-origin
  dedup in phase 2 if not unified deliberately first
- the cross-zenka tree path [ `callback_id` branch of
  `coding.cmd.tree-query-reply` / `coding.handler.deferred_reply`'s
  `task.summarize-done` route ] is built but **not yet exercised** — every
  live test used the direct/local-reply branch [ no `callback_id` ]. nothing
  currently calls `coding.summarize-context` with both `tree=1` and
  `callback_id` set, so this path has no live confirmation yet
- `data/ai-mem`-style topic routing [ phase 2 ] doesn't exist yet — all
  entries currently live flat in `<task.summary_tree.entries>`, addressed only
  by `chk`, with no subtopic/namespace structure
- the debug session used to verify this (`e5968ecb...`) has a handful of test
  entries in the live `summary-tree.yaml`, including two corrupted ones from
  the focus/UTF-8 bug hunt before the fix landed — harmless [ unique test foci
  won't collide with real use ] but worth clearing before considering this
  fully clean

acceptance — all confirmed live:
- with `tree` absent, `coding.summarize-context` behaves exactly as before
  [ regression check — confirmed ]
- with `tree=1` and no prior entry: cache query misses, inference runs, caller
  gets their reply first, task zenka receives the delta-notify afterward
  [ confirmed, direct/local-reply branch only ]
- a repeated identical call [ same focus, same content ] produces a cache hit
  and skips inference entirely [ confirmed — 27ms repeat vs full inference ]
- a query timeout / unreachable task zenka falls through to inference, caller
  is never blocked or errored by it [ confirmed by stopping the task zenka
  mid-test ]
- `session_catchup` cache-hits and skips the entire chunking loop on repeat
  [ confirmed, identical text returned instantly ]
- `.cmd.` replies are always strings, never raw hashes [ confirmed by code
  review of all new modules ]

### phase 2 — tree structure + routing/classification

- on-disk layout under `data/topic-tree/` [ subtopic file, deltas/, INDEX.md ]
- `task.*` routine that, given a pending flat delta from phase 1, classifies the
  content [ tier-0 local, escalate on ambiguity ] to an existing subtopic or a
  new checksum-parented one
- INDEX.md maintained ai-mem style [ dotted subtopic name + one-line descriptor ]

acceptance:
- a routed delta lands under the correct dotted namespace
- an unrelated delta opens a new subtopic without colliding names
- INDEX lists every subtopic by its dotted name

### phase 3 — checksum-indexed focus-variant deltas

- deltas already carry `chk` from phase 1; this phase formalizes on-disk
  storage at `deltas/<chksum>.md` with header [ source, origin, focus, ntime,
  integrated:0 ]
- identical focus+content re-writes are idempotent [ same checksum ]

acceptance:
- two different foci on the same session produce two distinct delta files
- the same focus+content twice produces exactly one delta file

### phase 4 — idle detection + integration-pass merge

- detect both-zenki-idle over a configurable threshold [ reuse existing idle
  signals, fallback-guarded timer ]
- group pending deltas by topic; per topic, llm-synthesize them into the
  subtopic file using the strong [ Opus ] model
- mark merged deltas `integrated:1`, retain them; update INDEX
- never concatenate; never delete a delta

acceptance:
- after a pass, each touched subtopic file is a coherent synthesis [ not a
  concatenation ] and its pending deltas are marked integrated, not removed
- a second `session_catchup` on the same session reuses the integrated subtopic
  instead of regenerating from scratch
- repeated passes do not grow a subtopic file without bound

## style

- lowercase comments, `[ word ]` bracket annotations [ never `( word )` ]
- `$ARG` / `@ARG`, not `$_` / `@_`, where used implicitly
- `<task.summary.tree>->{}` for dotted data keys, not `$data{'...'}{}`
- `.cmd.` / whitelisted routines return `{ mode => true|false, data => STRING }`
  — split raw-hash helpers into separate non-`.cmd.` routines + thin wrapper
- use `<[base.logs]>->( N, fmt, args )` for logging, not warn/print
- config paths via `<system.root_path>/...`; never bare relative
- TRUE/FALSE constants, never literal 0/1
- check `src/task.init_code` for the existing task data layout before
  writing — match the keys it already uses
- never let a task-zenka query/notify block or fail the MCP caller's reply —
  every new task-zenka touchpoint in phase 1 is best-effort with a fallback

## acceptance [ overall ]

- [ ] `coding.summarize-context` is unchanged when `tree` is absent
- [ ] `session_catchup` passes `tree=1` + origin by default; explicit opt-out
      suppresses it
- [ ] coding-zenka-native tasks record nothing unless top-level opt-in is set
- [ ] cache queries and notifies are best-effort and never block/break the
      caller's reply, even when the task zenka is unreachable
- [ ] deltas are checksum-addressed [ `focus . content` ] and dedupe on
      identical focus+content; growing content produces a fresh checksum
- [ ] routing places deltas under correct dotted semantic subtopics; new topics
      get collision-safe checksum-parented names
- [ ] idle pass merges per-subtopic via the strong model [ synthesis, not
      concatenation ], retains raw deltas, and bounds per-topic growth
- [ ] a repeated catch-up on the same session reuses the integrated subtopic
      rather than re-summarizing from scratch
- [ ] no regression in `task.init_code` loading or existing `task.cmd.*` /
      `coding.cmd.summarize-context` task-context behavior

### dispatch

model: opus
reasoning: high

prompt: |
  Phase 1 of data/tasks/task-summary-topic-tree.md is DONE and live-verified
  (see "phase 1 — DONE" section for the full file list, what was verified,
  and known limitations). Implement phase 2 (tree structure +
  routing/classification) next.

  Read the "phase 1 — DONE" section first to see what already exists:
  src/task.cmd.summary-tree-query, src/task.cmd.summary-tree-notify,
  src/task.persist.summary_tree.{save,load}, the coding-zenka relay
  mechanism (coding.cmd.summarize-context, coding.cmd.tree-query-reply,
  coding.tools.handler.summarize_enqueue, coding.handler.tree_query_timeout,
  coding.handler.deferred_reply), and the mcp-server-p7 relay (_tree_chk,
  _tree_query, _tree_notify, _do_summarize, tool_session_catchup). Phase 2
  extends task.cmd.summary-tree-notify's flat storage into the dot-separated
  namespace + on-disk tree under data/topic-tree/ described in "namespace"
  and "topic routing / classification" above — it does not replace phase 1's
  wiring. Also read src/coding.self_test.* for the tier-0/tier-1
  escalation shape the routing/classification step reuses.

  Before writing tree-routing code, be aware of two phase-1 limitations
  that phase 2 inherits unless addressed: chk now uses bmw-L13 (13-char,
  ~65 bits) but the two relay origins compute it from different input
  representations (byte string vs perl character string) and are not
  guaranteed to produce the same chk for identical content — see "how each
  origin computes bmw-L13" above before assuming cross-origin dedup works.
  Also, the cross-zenka tree path (callback_id branch) has never been
  exercised by a live caller. Follow the project's lowercase-comment,
  dot-notation style exactly. No signature stubs — the signing system adds
  them.

#,,,.,,,.,,.,,.,,,,,,,,,.,..,,..,,,,.,.,.,,..,..,,...,...,.,,,..,,.,,,,.,,,,.,
#7K4DKL2IDDJ36ZDKG2L2C3BWIY7LKVHJUJUJEYZGLXAOW3KPWSZBQ625N63SWZP4IA66266YRFAOQ
#\\\|EX5R5J66VYK5EVQFJSKXG5CLW5FFUMJA3OTWQD67WJJJDJIR775 \ / AMOS7 \ YOURUM ::
#\[7]V2WBZFE4RX6JVUW6AQZLAXHAJK6NZZUKLBSCNQBBIQ6YBKIFTSDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
