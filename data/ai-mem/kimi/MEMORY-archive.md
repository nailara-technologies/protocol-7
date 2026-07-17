# Kimi Development Memory — Archive (Protocol-7)

> stale chronological session log, moved wholesale out of `MEMORY.md` to keep
> the auto-loaded index slim. timeline / original order preserved — do not
> re-sort. entries here are historical context; links remain valid.

## Coding Zenka Infrastructure Commands (March 2026)

`coding.inject-message <task_id> <msg>` injects user message into active task. `coding.wait-done <task_id> [timeout]` blocks until done.
see [topic-coding-zenka-massive-cleanup.md](topic-coding-zenka-massive-cleanup.md)

## Coding Zenka Fixes (April 2025)

major fixes to tool dispatch, error handling, context management, loop detection, pagination.
see [topic-coding-zenka-massive-cleanup.md](topic-coding-zenka-massive-cleanup.md) and [topic-coding-zenka-subtask-fixes.md](topic-coding-zenka-subtask-fixes.md)

## NShell Ctrl+O Cycle Fixes (February 2025)

ctrl+o cycle: index calculated after `history_add()`, not before; `ctrl_o_start_position` stays constant; `shift = ctrl_o_entries_added`.
see [topic-coding-zenka-massive-cleanup.md](topic-coding-zenka-massive-cleanup.md)

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

## Kimi + Kimi-Web Integration (April 2026)

local agent spawn via `kimi-web.bridge.ensure_local_agent`; `kimi.cfg.use_local_agent = 1` in `configuration/zenki/kimi/start`.

## Algorithm Profile System — April 2026

see [topic-algorithm-profile-system.md](topic-algorithm-profile-system.md)

## Session 2026-05-05 — UTF-8 Encoding, Git Diff Tools, Timeouts, Crash Restart Fixes

utf-8 file tools, git diff tools (`Git::Wrapper`), data-start timeout (47s), `verify_inference_startup` dependency recheck.
commits `bb1a60bfa`, `9d81d4f83`

## Coding Zenka Subtask Queue & Tool Fixes (May 5 2026)

see [topic-coding-zenka-subtask-fixes.md](topic-coding-zenka-subtask-fixes.md)

## Job-Site-Scan Major Refactor — May 12 2026

see [topic-jobsite-scan-refactor.md](topic-jobsite-scan-refactor.md)

## Language Detection System — Three-Layer Architecture (May 12 2026)

see [topic-language-detection.md](topic-language-detection.md)

#,,..,,,.,.,,,...,,.,,..,,...,,,,,..,,,,,,..,,..,,...,...,,,.,,,.,..,,.,,,.,,,
#6HAOCSRFXZQCO4QYWMQDTDTU266PTKO6QIC5SUNB23HYCN453E6OIRULNGVG3453W2GHCBGYVYUTM
#\\\|D7LJHBI3DZIW6ZZ3GKARBHK6QPIOBOZHC2A626YNNYQKXQEOT4M \ / AMOS7 \ YOURUM ::
#\[7]OSWOVGJDJGV4764MWPMAAGA7P55HJR2PXHVSTLOPTFNAZY7EOGCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
