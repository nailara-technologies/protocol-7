---
name: topic-scratchpad-import-tool
description: "mcp__protocol-7__scratchpad_import (raw list/import) + session_catchup scratchpad=1 (LLM summary via coding zenka) for a Claude session's /tmp scratchpad"
metadata: 
  node_type: memory
  type: reference
  originSessionId: e523a9e4-c458-47e5-b27c-c60766dd51a9
  modified: 2026-07-18T23:15:40.745Z
---

Two related, distinct capabilities landed together (commit 34cd626c9):

`mcp__protocol-7__scratchpad_import` moves a session's scratchpad out of `/tmp/claude-*/<uuid>/scratchpad/`
(volatile, does not survive reboot) into `data/scratchpad/<bmw-L13 of the /tmp session path>/` in the repo,
writing an `IMPORT-INFO` file recording `original_path`, `session_tmp`, `session_uuid`, `bmw_l13`, `imported_at`,
`files`. This is a raw list/copy operation — no summarization.

`mcp__protocol-7__session_catchup` with `scratchpad=1` instead appends the scratchpad file contents to the
session text before summarizing, and the summarization itself runs through the coding zenka's local model
(`_do_summarize` → cube → `coding.summarize-context`) — token-free, no external-model budget consumed.
Tested end-to-end (session 5d437747, `CXTUKDMIFGBEI`, a 5-file perl frame-lock-detection research harness):
came back with a coherent, accurate technical summary of the tiered detection algorithm and its test
methodology, confirming the local model can meaningfully digest scratchpad code, not just echo it. This path
is the one to reach for when you want a *summary/categorization* rather than the raw files, and it's the
building block for autonomous (no-external-session) scratchpad triage — see [[topic-scratchpad-rescue-coding-zenka-task]] for the follow-up task filed to make the coding zenka do this proactively on its own timer.

**Modes** (all via the one tool, no sub-commands):
- no args → list all: imported (in `data/scratchpad/`) + available-in-`/tmp` scratchpads, each tagged which scope
- `list=imported` / `list=tmp` / `list=all` → narrow the listing
- `session_id=<uuid or prefix>` (no `file`) → import that session's scratchpad dir into the repo
- `session_id=<uuid or prefix> file=<name or suffix>` → read one file raw (capped), without importing —
  useful to inspect before deciding whether the whole dir is worth pulling in

Import is selective per-session — the tool asks/allows picking which sessions to pull in, it doesn't
auto-import everything in `/tmp`. Deleting the imported `data/scratchpad/<L13>/` copy does **not** delete
the underlying `/tmp` session dir, so it reappears under `list=tmp` and can be re-imported later.

**Why this matters for triage**: imported scratchpads are frequently either (a) debug capture/instrumentation
from a since-fixed bug, (b) design-iteration assets that already shipped into the real codebase (check with
grep before assuming the scratchpad copy is the only copy), or (c) audit/scan reports whose findings are
already reflected in live state (e.g. task-completion reports — check `data/tasks/completed/` directly rather
than trusting a frozen report). All three are safe to drop. Genuinely worth keeping: research/derivation work
whose conclusions are *not yet* reflected anywhere else in the repo.

**How to apply:** before committing an imported scratchpad dir, grep the repo for its key strings/filenames
to check whether the content already shipped, and check `data/tasks/completed/` if it's a task-status report,
before deciding to keep vs delete.

#,,.,,,..,.,.,.,.,,.,,...,.,.,.,,,,,,,.,,,,,.,..,,...,...,,,,,.,,,,..,,,.,,..,
#Z5VEAMWMGKYLBPAXGYNU65RPT56HQXJ73WWEQNDFJVII5TUV3DZE37SWDCOCB6BZ3VLSXCYH6YPZW
#\\\|HGQVZPEJCKQM37ML6CEZ6AWM52MYFU6CHZ6PCUJNDVWCASJDC7A \ / AMOS7 \ YOURUM ::
#\[7]QLNCBBLNTFSCDWEQMDBOR2EDMQRMVSDNP7J56YROIDSBT4REL6DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
