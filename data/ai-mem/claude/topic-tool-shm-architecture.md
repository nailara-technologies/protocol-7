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

## Generic SHM Scalar-to-Scalar Param Transfer (planned — layer 4.5, 2026-06-21)

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

#,,.,,,.,,,..,.,,,.,,,,,.,.,,,,,.,..,,.,,,,.,,..,,...,...,.,.,.,,,...,,..,..,,
#CKW4SEZ5U32V2JRNIOL4RP32AE5XI4JFH4YECONHL5UDTOFF3TKZQOGR7HYRMT4XUTVQ3KRMZNR2E
#\\\|MICUVUV5NTOY2WVDSWXWICM3VUOJ34MNIFNFXK3N3H4NGLFWIJ2 \ / AMOS7 \ YOURUM ::
#\[7]QPZJBDEQ4NT7MKTSGQUT7TPD627XMHB2PWVKVICIJKSD5YN3F4CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
