---
name: tool-shm-architecture
description: LLM tool calling infrastructure + SHM/mmap file editing vision for coding zenka
type: project
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

## Difference-Based Storage (planned — layer 5)

Checksums referencing lists of sequential checksums.
Re-referenceable and re-nestable at zero copy.
9P modules (client+server in data.* namespace) expand cross-node access.

User note: "adding another abstracting layer is a temporary workaround
that is still clean and no initial technical debt" — accepted pattern.

#,,,,,,..,,,,,,,.,.,.,..,,,..,,,.,.,,,,.,,,,.,..,,...,...,,.,,...,,,.,,.,,.,.,
#EMLPK2DN5A2JBEUDUUMFOMFYRX62TRKWOFWIVVU3MC4QGYO3B5XFC67AX6TLQWQ73T4CQOYIYSR64
#\\\|3IBWFTQMQOB7I53ZOSCJH7TUZGDV2GCQO3LVXW2AKRBFJNWYSWA \ / AMOS7 \ YOURUM ::
#\[7]WQPYYLIK6BROXQZFQ2ACD2H6TTOLOKKURCP74SSM25W4DGYPSKAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
