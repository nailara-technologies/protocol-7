# Kimi Development Memory - Protocol-7

> ⚠️ **CRITICAL COMMIT POLICY**: Never commit without valid version number (run `./bin/dev/update-version`) and proper signatures (run `bin/Protocol-7 sourcecode update-signatures`). Use `--no-verify` only in emergencies.

> 📖 **BEFORE STRUCTURAL WORK**: Read `data/md/development/STYLE-PHILOSOPHY.md` alongside
> `data/yaml/code-style/CONVENTIONS.yaml` and `data/md/development/CODE-STYLE-AND-LLM-INTEGRATION.md`.
> The philosophy doc covers *why* the conventions are load-bearing, not just *what* they are.
> Update it if you arrive at refined perspectives after reading it.

> 🗂️ **INDEX SPLIT**: older entries live in sibling files (same directory, links stay valid) —
> explicitly-completed work in `MEMORY-completed.md`, stale chronological session log in
> `MEMORY-archive.md`. this file stays slim (critical rules + active work) so it loads clean.

## Memory Update Tool — Length-Aware Routing (June 2026)
`p7_memory_update` enforces ~180/200 line limits on `MEMORY.md`, supports `target` for external topic files, and auto-routes `UPDATE FILE:` directives. see [topic-memory-update-tool.md](topic-memory-update-tool.md)

## base.strm.subscribe — generic STRM subscribe wrapper (July 2026)
offline-safe/restart-clean subscription wrapper, six modules swapped to
`strm.subscribe`; verified live vs cred-mesh. usage, `<a.b.c>`-splits-on-every-dot
gotcha, runtime-load marker side effect, adoption steps: see [strm-subscribe-wrapper.md](strm-subscribe-wrapper.md)

## %code Presence/Call Primitives + Rename Grep Caveat (July 2026) [ CRITICAL ]

new cross-namespace call pattern from commits b674ecd80/ae6b1f79b: never
write `exists $code{'literal.name'}` inline [ the referenced-sub scanner
flags it ] and never use `<system.zenka.name> eq 'v7'` as a proxy. use
`base.code.exists` / `base.code.call_expected` / `base.code.call_optional`
/ `base.mod.exists` [ ground truth: `<base.p7_mod.loaded>` ]. undef subs
land in the `undef-subs` buffer [ `show-buffer undef-subs` ]. also: before
any module rename, grep for `sprintf`-resolved names, not just literal
calls — two dynamic-dispatch renames broke silently in one session.
full details in [coding-style.md](coding-style.md) "code presence checks"
section and `data/yaml/code-style/CONVENTIONS.yaml`
`code_presence_and_cross_namespace_calls`.

## Module Name Swaps via `base.swap_subs` (July 2026) [ CRITICAL ]

some module families are renamed at runtime (`base.event`→`event`,
`base.file`→`file`, etc.). the file on disk does not match the post-init
`%code` key; calling the long form after init crashes. see the
swapped-module-families note in [coding-style.md](coding-style.md).

## fork-child Critical Gotchas (Mar 2026)

`access.cmd.usr.child` keeps `cube.` prefix (post-hop form). `event.add_signal` hashref form only.
`route-send` for cube-routed commands; not for `child.*` aliases.
see `data/ai-mem/claude/critical-patterns.md`

## Project Workflow Rules (CRITICAL)

- signature updates require user passphrase — ask user to run signing command, never skip hooks
- version file: `configuration/protocol-7.src-ver` — update with `./bin/dev/update-version`
- pre-commit checks: permissions, version, signatures, source integrity

## MCP session_catchup + Self-Test Verification (June 2026)

MCP timeout bumped, `session_catchup` now does direct UUID/prefix lookup and supports `tail_chars` for large sessions. Coding self-test tier-0/1/2 verified live; tier-1 retry confirmed on DVEAZIA:GPAKBLA.
see [2026-06-21-session-catchup-mcp-and-self-test-verification.md](2026-06-21-session-catchup-mcp-and-self-test-verification.md)

July 2026: `session_catchup` gained subagent transcript support for claude + kimi via `subagents` param (0=exclude, 1=append, 2=only), `subagent_id` filter, and claude `scratchpad` param for volatile /tmp artifacts; new `scratchpad_import` tool imports them to `data/scratchpad/<bmw-L13-of-session-tmp-path>/`; list mode shows `[+N sub]`/`[+N scr]` markers.
see [2026-07-18-session-catchup-subagent-support.md](2026-07-18-session-catchup-subagent-support.md)

July 2026: coding zenka got native scratchpad-rescue tools (`scratchpad_list_all` / `scratchpad_categorize` / `scratchpad_rescue` + hourly `coding.handler.scratchpad_sweep` timer) — same capability without any external LLM. imports go through the chmod child [ taeki-owned ]; mcp-server-p7 grants scoped group read on /tmp scratchpad dirs opportunistically.
see [2026-07-19-coding-zenka-scratchpad-rescue-tools.md](2026-07-19-coding-zenka-scratchpad-rescue-tools.md)

## Command Return Style — Deferred Replies (June 2026)

`qw| deferred |` returns keep the route open and reply later via the remembered route id.  They must **not** include a `'data'` key.  Args must always default with `// ''`.  See [topic-cmd-style-notes.md](topic-cmd-style-notes.md).

## bin/chat — Multi-Model Conversation Script (May 14 2026)

phase 1 operational (~950 lines); file-backed history at `data/chat/channel/*/history`; `data/ai-mem/handover.txt` retired.
open: kimi zenka state machine upgrade (backend reconnect), coding zenka as third dispatch target, phase 2 channels zenka.

## Jobsite/Web Jobs Pipeline Fixes (2026-06-28)

`skipped` status restored across all index scanners, reassessment now protects manual stages, web sync carries `assertions`, UI delete actions wired, and orbital subscriber `.cmd.` syntax corrected. Assessed jobs now map to the `review` UI stage. See [jobs-pipeline-2026-06-28.md](jobs-pipeline-2026-06-28.md). Open: bulk-delete pending search/filter UI.

#,,..,.,.,...,,,,,,.,,,,.,,..,,.,,.,,,.,,,,,,,..,,...,...,,..,,,.,...,.,.,.,,,
#LEN7SPMRCV6PKNIZLCC6RRS7INR7CAOGTIELIKYC752S2M2QCIA2RDDGIMXARX7BCZ4ELJJJYFGHC
#\\\|4HPV36Y7OCEMUCVFDCNYL6ZK6SJMIXYMPZPKZZKZEKQZ3FHSPLK \ / AMOS7 \ YOURUM ::
#\[7]GD3TKCWD7S4MSEGZRMVGJFM6TOILP4PE5CRODFPOJ3PUWVI3TQCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
