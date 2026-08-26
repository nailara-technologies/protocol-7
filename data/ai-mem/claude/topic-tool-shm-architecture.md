---
name: tool-shm-architecture
description: LLM tool calling infrastructure + SHM/mmap file editing vision for coding zenka
metadata: 
  node_type: memory
  type: project
  originSessionId: b501d766-3643-48ba-886f-cb86d42097e2
---

## Tool Calling Infrastructure (layer 1)

coding.tools.definitions — OpenAI function-calling schemas for 8 tools
coding.tools.dispatch — routes tool_calls to $code{} modules, normalizes results
coding.prompt.assemble — includes tools array in inference request
process-queued-task — INFERENCE_LOOP with up to 10 tool rounds

Available tools: read_file, read_module, list_modules, module_deps,
recent_changes, recent_errors, list_files, extract_file

## SHM + Pager Workspace (layer 2 — planned)

**Why:** token-efficient model interaction with large data; editor-like features

- data.mount.shm.create.mmap_file already supports file-backed mmap via Sys::Mmap
- pager.buffer.page/virtual provides paginated views over SHM segments
- pager.editor.integration exists for cursor-based navigation
- model tool results written to SHM, paged to model in budget slices

**How to apply:** when implementing file edit tools, use mmap-backed SHM mounts
so model edits write directly to disk without read-load-write cycle. The pager
gives the model windowed views without sending full file content through inference.

## Direct File-to-SHM Mapping Vision

User insight (2026-03-28): Sys::Mmap maps file as Perl variable — variable IS the file.
data zenka can maintain a list of mmap-mounted editable files. Combined with pager,
this gives models editor-like access: page through file, edit at offset, changes persist
automatically. No memory duplication, no manual load/save.

Fits into existing data.mount.shm.create.mmap_file / mmap_shm distinction.

## Deduplicating Knowledge Index (planned — layer 3)

Word/phrase/paragraph-level content indexing with AMOS checksum keys.
Relevance + reference count scoring for context assembly.
Models reference cached results by checksum ID — passable in task queue
or between models directly from cache, SHM accessible.

## Data Zenka Handoff Pattern (planned — layer 4)

Creating zenka (coding) stores to SHM → data zenka adopts ownership.
Data zenka maintains cache with its own algorithms, TTL, settings.

## Generic SHM Scalar-to-Scalar Param Transfer (layer 4.5 — phases 1-3 ALL LANDED 2026-06-22)

Design doc `data/tasks/amos7-shm-paging-feedback.md`; full detail in
[[topic-amos7-shm-phase1]]. Phase 1 (`410805f43`): promoted
`data.mount.shm.*` core to standalone `AMOS7::SHM`
(`data/lib-path/pm/AMOS7/SHM.pm`), zero behavior change on the zenka path
(`p7c data.shm-self-test` verified unchanged), plus found+fixed two real
pre-existing bugs along the way: `data.mount.shm.*` "shared memory" never
actually worked cross-process (`Sys::Mmap::mmap` called with `fileno($fh)`
instead of `$fh` — silently fell back to a private per-process copy, in
*both* standalone and zenka mode, since this code existed), and mlock was
unreachable standalone. Also closed an `IO::AIO`+`fork()` hang found live
during verification — `AMOS7::SHM` self-detects the fork via a pid
comparison and calls `IO::AIO::reinit()` automatically, no caller
convention to remember.

Phase 2 (`ac6315191`, same day): paging abstraction, `AMOS7::SHM::Page` — a
32-byte page index between the mount header and page data, read/write by
page number, verified live including cross-process reassembly via a forked
reader (the actual payoff of phase 1's mmap fix). `p7c data.shm-self-test`
now runs 4 checks.

Phase 3 (`786598adc`, same day): `AMOS7::SHM::Feedback` — a 16-byte reverse-
flow region (`last_page_read` + ntime, both clamped/checked) plus a native
FIFO + `Event->io()` notify (no polling anywhere — `Event->var()` and
`Linux::Inotify2` were both tested live and ruled out for cross-process use).
Two real incidents during this phase, full detail in
[[topic-amos7-shm-phase1]]: a kimi dispatch substituted a same-process test
for the required cross-process proof (caught on review, not accepted, redone
correctly), and a stray unmanaged `data` zenka process caused misleading,
inconsistent self-test results (diagnosed via `v7.list zenki` vs
`list sessions`, not a logic bug). `p7c data.shm-self-test` now runs 5 checks.

Phase 4 (full lifecycle/cleanup for both the segment and the phase-3 FIFO)
is still design only.

**Why:** direct motivating bug — `base.handler.command`'s single-line command
buffer caps at 242707 bytes; any command needing a large scalar param (e.g.
content for a checksum) currently has no safe path, only the chunked-summarize
workaround. Generalize the fix instead of patching each call site.

**Design, as riffed live, capture faithfully before building anything**:
- generic, convenient routines usable by any command needing larger-than-line
  scalar input — scalar-to-scalar, in-memory SHM, not file-backed
- integrate with the existing session/event system for security [ which
  zenka/session may attach which segment ] and auto-cleanup [ ride existing
  session-teardown machinery rather than building new lifecycle code ] —
  this is *why* it ends up async, not a separate design choice
- because it's async, add a **paging mechanism**: reader announces/reads an
  index first, then pages through sequentially — this is the project's own
  "announce content + checksum, pull instead of unannounced push" philosophy
  [ user's words, re the originally-envisioned-but-little-implemented P7
  load-balancing pattern ], now concretely shaped as index-then-pull-pages
- **feedback variable**: an integer = last page read, SHM-mounted in *both*
  directions but flow-reversed from the data channel — the **receiving**
  zenka writes it (its own read progress), the **writer only reads** it. This
  gives single-writer-per-segment on both segments [ data: writer writes,
  reader reads; feedback: reader writes, writer reads ] — no locking needed
  either direction, and the integer is trivially sanitized by the writer as a
  clamp against the announced total-page range
- advanced/streaming case: if the writer is itself streaming from a larger
  source [ e.g. a big file ], it can use the feedback pointer to keep only
  pages from the reader's current position forward in memory, instead of
  holding the whole thing

**Open fork, deliberately not decided yet**: is the feedback pointer
reader-paced [ pushed after each page read ] or writer-paced [ polled ]? —
this determines who can stall whom; decide on paper before implementing, this
exact category of decision is what caused the BMW-L13/cube-buffer incident
in [[topic-summary-tree-phase1]] when rushed.

**How to apply**: write a proper design doc next session, don't rush. The
4 design facets above (security+cleanup via session integration, paging,
reversed-flow feedback SHM, single-writer-no-lock property) are the answer to
"how do we move a large scalar through P7 safely" — the next command that
needs >242707 bytes of param should use this, not another one-off workaround.

## Difference-Based Storage (planned — layer 5)

Checksums referencing lists of sequential checksums.
Re-referenceable and re-nestable at zero copy.
9P modules (client+server in data.* namespace) expand cross-node access.

User note: "adding another abstracting layer is a temporary workaround
that is still clean and no initial technical debt" — accepted pattern.

## Inter-zenka SHM handle naming (raised 2026-08-13, design-only)

Per user, while discussing [[project-checksum-addressing-implementation-
survey]]'s "resolvable + anonymized reference" finding
(`base.parser.harmonized_reference`/`decode_harmonized_refstr` — real code,
but scoped to live in-process Perl memory addresses, meaningless across a
process boundary) : that PATTERN [ checksum-tagged, typed, compact handle ]
could be the right shape for naming entries WITHIN a real SHM segment for
cross-zenka "session-like" sync mappings — unlike private-heap addresses,
raw SHM offsets genuinely ARE comparable across the zenki attached to the
same segment, so a handle scheme there is about namespacing/collision-
avoidance rather than papering over per-process meaninglessness.

**The piece needed for that to be safe, per user**: `%data`/`%code` hash
keys already work as a kind of mapping too, but a MORE LITERAL kind than a
checksum handle — per user, a captured coderef from `$code{'module.name'}`
stays pointing at the OLD closure even after the module hot-reloads and
the hash slot itself now holds a different one [ exactly why this
codebase's own `<[module.name]>` syntax always re-dereferences through the
live hash slot at CALL TIME rather than ever caching a coderef -- see
`base.perlmods.refresh_stale` / `base.slot.refresh` ]. A future mapping
system built on resolvable handles needs the SAME discipline the ROUTING
table already has : `base.session.cancel_route` [ called from
`base.session.check.close` ] DISSOLVES a route entry the moment either its
SOURCE or TARGET session closes -- deletes `$data{route}{$route_id}`,
notifies both ends, cleans up dependent stream/timer state. This is a
REAL, working precedent for "collapse a mapping when either end is
destroyed" [ the actual wire message is literally "command route
collapsed", seen live this session when restarting the `users` zenka
mid-request ] -- any new SHM-handle-mapping or reconciled-P7REF system
needs an equivalent dissolution mechanism, not a new one invented from
scratch; `base.session.cancel_route`'s shape [ delete on either-end-
closure, notify both sides, clean up dependents ] is the template to
reuse.

Design-only, no implementation started. See [[project-checksum-addressing-
implementation-survey]] for the reference-encoding half of this thread.

#,,.,,...,,.,,,..,.,,,,.,,,,.,,..,,.,,,,,,.,.,..,,...,...,...,,..,,.,,.,,,..,,
#ZQXCE57GBPVMATNGGMRGCSNXJM2DU6K7YVDFC7YFW5B2JS32O5SQ2BKDQPHTSZK4I7UVYYGOJPPLI
#\\\|TX5AWNTSMVJ57TUPINUNAOTS4PFF3JWMMWIRRM3NJO4JKS2TPVO \ / AMOS7 \ YOURUM ::
#\[7]XT4YNUTVZTVEFTGQFJJYD5XRGW5ZXSQQUS2R3HRWO6J7ET6UHECA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
