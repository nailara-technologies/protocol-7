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

#,,,,,,,.,,,.,...,...,,,.,...,,,.,..,,,.,,,,,,..,,...,...,...,..,,,..,.,.,.,.,
#2OABRIFIUAUQNL6QDVR5JYGXHWX77PH6GTB2IMSV5HFGHA4OYEHYXWELRI3PP2KHEEUGXSKUQVAHS
#\\\|UIDZIJN45OOOC7GJD3XQEZNEBHVTLLK7O6OCSEVL3HKUP7PSDZF \ / AMOS7 \ YOURUM ::
#\[7]HLHYVYGPVKLQUA3T7PTH2VEQXRVW6C53R4YF5RKSM52245YMOUBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
