# Kimi Development Memory - Protocol-7

> ⚠️ **CRITICAL COMMIT POLICY**: Never commit without valid version number (run `./bin/dev/update-version`) and proper signatures (run `bin/Protocol-7 sourcecode update-signatures`). Use `--no-verify` only in emergencies.

> 📖 **BEFORE STRUCTURAL WORK**: Read `data/md/development/STYLE-PHILOSOPHY.md` alongside
> `data/yaml/code-style/CONVENTIONS.yaml` and `data/md/development/CODE-STYLE-AND-LLM-INTEGRATION.md`.
> The philosophy doc covers *why* the conventions are load-bearing, not just *what* they are.
> Update it if you arrive at refined perspectives after reading it.

## Memory Update Tool — Length-Aware Routing (June 2026)
`p7_memory_update` enforces ~180/200 line limits on `MEMORY.md`, supports `target` for external topic files, and auto-routes `UPDATE FILE:` directives. see [topic-memory-update-tool.md](topic-memory-update-tool.md)

## Module Name Swaps via `base.swap_subs` (July 2026) [ CRITICAL ]

some module families are renamed at runtime (`base.event`→`event`,
`base.file`→`file`, etc.). the file on disk does not match the post-init
`%code` key; calling the long form after init crashes. see the
swapped-module-families note in [coding-style.md](coding-style.md).

## Round-Based Scheduling & Subtask Spawn — COMPLETE (April 2026)

complete — full subtask round-trip verified. 4 post-handover fixes (double-spawn VRAM starvation, stale-process kill race, subtask backend lock deadlock, timeout recovery).
see [topic-round-scheduling-subtasks.md](topic-round-scheduling-subtasks.md)

## Coding Zenka Infrastructure Commands (March 2026)

`coding.inject-message <task_id> <msg>` injects user message into active task. `coding.wait-done <task_id> [timeout]` blocks until done.
see [topic-coding-zenka-massive-cleanup.md](topic-coding-zenka-massive-cleanup.md)

## MCP session_catchup + Self-Test Verification (June 2026)

MCP timeout bumped, `session_catchup` now does direct UUID/prefix lookup and supports `tail_chars` for large sessions. Coding self-test tier-0/1/2 verified live; tier-1 retry confirmed on DVEAZIA:GPAKBLA.
see [2026-06-21-session-catchup-mcp-and-self-test-verification.md](2026-06-21-session-catchup-mcp-and-self-test-verification.md)

## Coding Zenka Fixes (April 2025)

major fixes to tool dispatch, error handling, context management, loop detection, pagination.
see [topic-coding-zenka-massive-cleanup.md](topic-coding-zenka-massive-cleanup.md) and [topic-coding-zenka-subtask-fixes.md](topic-coding-zenka-subtask-fixes.md)

## May 1 2026 Session — Regression, Revert, and nshell (0) Bug

regression in `base.log.send-buffer.send-idle-callback` reverted in commit `3b01d2e81` — cube-only guard restored.
nshell cmd_id (0) bug **FIXED** 2026-06-02 — orphaned route handler in `base.handler.command` generated `(0)!TERM!` for prefix-less replies; added `$cmd_id > 0` guard.

## NShell Ctrl+O Cycle Fixes (February 2025)

ctrl+o cycle: index calculated after `history_add()`, not before; `ctrl_o_start_position` stays constant; `shift = ctrl_o_entries_added`.
see [topic-coding-zenka-massive-cleanup.md](topic-coding-zenka-massive-cleanup.md)

## fork-child Critical Gotchas (Mar 2026)

`access.cmd.usr.child` keeps `cube.` prefix (post-hop form). `event.add_signal` hashref form only.
`route-send` for cube-routed commands; not for `child.*` aliases.
see `data/ai-mem/claude/critical-patterns.md`

## Project Workflow Rules (CRITICAL)

- signature updates require user passphrase — ask user to run signing command, never skip hooks
- version file: `configuration/protocol-7.src-ver` — update with `./bin/dev/update-version`
- pre-commit checks: permissions, version, signatures, source integrity

## No-TTY Debug Infrastructure (February 2025)

extended key syntax (`[Up,Down,Ctrl+o]` / `:Up,Down,Ctrl+o:`) and debug state tracking for nshell.
see [topic-coding-zenka-massive-cleanup.md](topic-coding-zenka-massive-cleanup.md)

## SSH Zenka Recovery (February 2025)

auto-user-creation race fix in `register_*_deps` — early return if deps already registered. commit `6a2d76206`.

## Terminal Color Consistency (February 2025)

always set `$C{T}` (teal) on everything first, then layer specific colors — never use `$C{R}` mid-string.

## Research: Dynamic Harmonic Color Templates

vision doc: `data/md/design/CONCEPT-DYNAMIC-HARMONIC-COLOR-TEMPLATES.md` — multi-buffer mask approach (TEXT/TYPE/COLOR/OUTPUT).

## VTERM Buffer System (Mar 2 2026)

22 modules committed — 5-of-7 consensus rendering, 23-byte cell structure, SHM-backed. see `data/ai-mem/claude/topic-vterm.md`

## Data Directory Structure Reorganization (March 2026)

see [topic-data-directory-reorganization.md](topic-data-directory-reorganization.md)

## Coding Tasks Audit (March 3 2026)

6 completed task files identified for archive. full audit: `data/yaml/CODING-TASKS-AUDIT-REPORT-2026-03-03.md`

## Dynamic Context Templates — Integration Complete (March 3 2026)

see [topic-context-template-system.md](topic-context-template-system.md)

## Coding Zenka Event Loop Stability (March 2025)

`return TRUE` bug (non-1 value in protocol handlers) and blocking I/O fix (`blocking(0)` on Unix sockets).
see [topic-coding-zenka-massive-cleanup.md](topic-coding-zenka-massive-cleanup.md)

## Registry Consolidation (March 2025)

JSON to YAML migration; `models.resolve.entry` for shared model lookup; `mmproj_path` in registry entries.

## Multiline Command Protocol (March 2025)

`+`/`++` suffix spec for `p7c` — implementation pending; task: `data/md/coding-tasks/add-multiline-command-support-to-clients.md`

## Zenki Profile Configuration (March 2025)

subname→profile mapping, resolution cascade — task: `data/md/coding-tasks/zenki-profile-configuration-interface.md`

## Task Execution Quality Patterns (March 2025)

structured context prep, handler chains, module decomposition, todo list state machine.
see [topic-coding-zenka-massive-cleanup.md](topic-coding-zenka-massive-cleanup.md)

## amos-term Window Management Fixes (March 2026)

`//=` invalid with typeglobs; `'immediate'` not a valid return mode; set handle mode before `base.session.init`; `shift` gives `$call` not args.
see [topic-coding-zenka-massive-cleanup.md](topic-coding-zenka-massive-cleanup.md)

## Coding Zenka Massive Cleanup — March 30 2026

see [topic-coding-zenka-massive-cleanup.md](topic-coding-zenka-massive-cleanup.md)

## Context Template System — April 2026

see [topic-context-template-system.md](topic-context-template-system.md)

## Zenka Creation Guide — April 2026

see [topic-zenki-creation-guide.md](topic-zenki-creation-guide.md)

## Footer Cleanup Template (April 2026)

template at `data/yaml/context-templates/footer-cleanup.yaml` — duplicate sigs, fragments, wrong format, stale white-list entries.

## Zenki Routing Analysis (April 2026)

kimi vs coding: both use dynamic system messages + base32r encoding; task queue + tool calling are coding-only; session persistence is kimi-only.

## Command Return Style — Deferred Replies (June 2026)

`qw| deferred |` returns keep the route open and reply later via the remembered route id.  They must **not** include a `'data'` key.  Args must always default with `// ''`.  See [topic-cmd-style-notes.md](topic-cmd-style-notes.md).

## Kimi + Kimi-Web Integration (April 2026)

local agent spawn via `kimi-web.bridge.ensure_local_agent`; `kimi.cfg.use_local_agent = 1` in `configuration/zenki/kimi/start`.

## 2026-04-02 — Bug #5 Fixed: Empty Task Result

`coding.async.complete_task` uses `||` not `//` for result fallback — `||` checks truthiness so empty `''` falls through.

## Algorithm Profile System — April 2026

see [topic-algorithm-profile-system.md](topic-algorithm-profile-system.md)

## Async Round-2+ Timeout Bug (2026-04-29)

RESOLVED — n_ctx floor raised to 13500; root cause was KV cache limit.
see `data/ai-mem/claude/topic-async-round-2-timeout.md` (archived, resolved)

## Session 2026-05-05 — UTF-8 Encoding, Git Diff Tools, Timeouts, Crash Restart Fixes

utf-8 file tools, git diff tools (`Git::Wrapper`), data-start timeout (47s), `verify_inference_startup` dependency recheck.
commits `bb1a60bfa`, `9d81d4f83`

## Coding Zenka Subtask Queue & Tool Fixes (May 5 2026)

see [topic-coding-zenka-subtask-fixes.md](topic-coding-zenka-subtask-fixes.md)

## UTF-8 Buffer Handling + Large-Stream Write Fix (2026-05-07) — COMPLETE

`bytes::length`/`bytes::substr` for protocol logic; `base.handler.write` write-ready watcher on EAGAIN; STRM-SIZE stream cleanup.
see `data/ai-mem/kimi/SESSION-2026-05-07-UTF8-STRM-SIZE.md`

## Job-Site-Scan Major Refactor — May 12 2026

see [topic-jobsite-scan-refactor.md](topic-jobsite-scan-refactor.md)

## Language Detection System — Three-Layer Architecture (May 12 2026)

see [topic-language-detection.md](topic-language-detection.md)

## bin/chat — Multi-Model Conversation Script (May 14 2026)

phase 1 operational (~950 lines); file-backed history at `data/chat/channel/*/history`; `data/ai-mem/handover.txt` retired.
open: kimi zenka state machine upgrade (backend reconnect), coding zenka as third dispatch target, phase 2 channels zenka.

## Web-Browser Input Capture/Replay — COMPLETE (July 2026)

all 6 steps landed + live-verified on the running zenka. steps 4-6 added `wait-state-poll`, `replay_template.dispatch_js`, `replay.dispatch`, `cmd.replay-synth`; wait-for-state/replay-play refactored onto the shared modules; whitelist regenerated, signatures pending. see [topic-web-browser-replay-verify-synth.md](topic-web-browser-replay-verify-synth.md) and webkit quirks in [coding-style.md](coding-style.md).

## Web-Browser State-Play + Waypoints — COMPLETE (July 2026)

value-injection replay landed + live-verified: `cmd.state-play`, `cmd.waypoint-set`, `cmd.goto-waypoint`; `__p7SetState` hook in visualization.html [ zoom hook pins manualZoom — updateCamera eases zoom->manualZoom every frame ]; `replay.dispatch` gained force_set [ FORCED exact-landing label ]. gotchas: $1/$2 clobbered by second regex test [ save captures immediately ]; pipe alternation inside m|..| breaks at runtime load [ use m{..} ]. see [topic-web-browser-state-play-waypoints.md](topic-web-browser-state-play-waypoints.md).

## Jobsite/Web Jobs Pipeline Fixes (2026-06-28)

`skipped` status restored across all index scanners, reassessment now protects manual stages, web sync carries `assertions`, UI delete actions wired, and orbital subscriber `.cmd.` syntax corrected. Assessed jobs now map to the `review` UI stage. See [jobs-pipeline-2026-06-28.md](jobs-pipeline-2026-06-28.md). Open: bulk-delete pending search/filter UI.

#,,.,,,,,,,,,,,,.,,.,,,,.,,..,,..,...,,,.,.,,,..,,...,...,,,.,.,,,,,.,.,,,..,,
#WVXHPO5NBOV4RXIYCQD664T2RH2OJB5VL6IX7GUIZNHI57M4ZS2BHLONY657UVJY7WAOKQ3C4UF5Y
#\\\|HCV6P5VIZLT6WZLOG7AE7Q7O3CZOYRCWN5B2YAAHAKTNH5JJUJC \ / AMOS7 \ YOURUM ::
#\[7]OOHVNXCAYWVNL23SKV4J562ZYWKUPNX3D5BLX4NS6XD3QAHGMYBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
