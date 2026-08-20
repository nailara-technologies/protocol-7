---
name: coding-zenka-session9
description: May 2/3 2026 session — reasoning_content fixes, 3-tier task buffers, sub-agent infrastructure, model config roadmap
type: project
originSessionId: 52ad77e6-5a2e-46a3-8178-ddcc1f410e55
---
## Session May 2-3 2026 — Major coding zenka work

### reasoning_content separation (Qwen3 thinking models)
- `chunk_handler`: `reasoning_content` goes to `context->{'reasoning'}`, never mixed into `content`
- Prevents double-output in model_output buffer (was showing thinking trace + answer twice)
- Fallback at finish: if content empty, copy reasoning → content, stripping tool XML first
- XML tool call detection also searches `context->{'reasoning'}` (Qwen3 puts them there)
- `reasoning` field passed through all state_machine transitions

### per-task three-tier ring buffers
- `coding.buffer.task_write`: new module, buffer names `T-<id>` / `T-<id>-T` / `T-<id>-F`
- Buffer name constraints: max 24 chars, `[\w\-_]` — strip `task-` prefix before naming
- **compact**: assistant text + tool summaries only (no thinking)
- **thinking**: compact + full reasoning traces (truncated at 200 chars/line)
- **full**: everything untruncated — tool outputs, full reasoning, full assistant text
- Hooked in `state_machine` (assistant/thinking) and `tool_executor` (tool_call/tool_result)
- `model_output` kept as rolling cross-task live monitor

### buffer lifecycle
- 77m idle timeout (`zenka-startup.v7`: 4620s)
- `on_task_complete`: arms 47m save timer + 63m drop timer; `task.enqueue`: cancels both
- `coding.task.save_buffers`: xz-compresses all 3 buffers, writes to
  `/var/protocol-7/coding/completed-task-backups/<timestamp>-<id>/` + `meta.yaml`
- `handler.task_buffer_save` / `handler.task_buffer_drop`: timer handlers
- v7 pause-idle mechanism planned for save-failure case (future)

### single-shot inference sub-agent infrastructure
- `task->{'system'}`: custom system prompt, skips template selection in `prompt.assemble`
- `task->{'no_tools'}`: empty tools list in `send_request` (no inference overhead)
- `task->{'max_rounds'}`: per-task round cap overriding global 777
- `coding.cmd.oneline-summary`: first sub-agent command — inference-backed ≤74 char summary
  with optional `focus=<perspective>` param; heuristic fallback for short inputs
- `coding.filter.summarize_oneline`: used in `task_complete` log line (heuristic only)

### bin/coding-task improvements
- `-template NAME`: prepends `:name:\n` into prompt before B32 encoding (self-contained blob)
- `-wait` is script-level only, NOT forwarded to p7c (p7c rejects `-` args except `-d`)
- `exec @cmd` list form avoids shell quoting issues with long B32 strings

### planned: model config and per-task model selection
- Add to `cfg/zenki/coding/start`:
  - `coding.cfg.base_work_model = <amos-id>` — default task model
  - `coding.cfg.base_compaction_model = <amos-id>` — faster model for compaction
- Per-task model via `:model:<amos-id>:` keyword at start of prompt/task file
  - e.g. `:integrate-recent: :model:WZIZD6Y:2BIZKWY:` in task file
  - Model present → use it; absent → fall back to base_work_model
- `bin/coding-task -model <amos-id>` prepends `:model:...:` into B32 payload
- Makes task files self-describing and portable across sessions

### planned: inference-backed compaction
- Current `coding.async.compact_context` is heuristic only (no LLM call)
- Use `no_tools + max_rounds=1 + system` sub-agent pattern with base_compaction_model
- Enables cross-model compaction: fast CPU model summarizes for large GPU model

**Why:** buffer names hit max 24 chars — always strip `task-` prefix when naming.
**How to apply:** use `coding.show-buffer T-<id>` / `T-<id>-T` / `T-<id>-F` to observe tasks.

## rescue procedure when the zenka dies mid-batch-scan (2026-07-16)

Confirmed live: when the coding zenka hits idle-shutdown mid-task, its
`task_buffer_save` handler still fires first (this is a *graceful*
shutdown path, not a crash) — every in-flight task's buffers land in
`completed-task-backups/<ts>-<id>/{compact,thinking,full}.xz` + `meta.yaml`
before the process dies. Nothing is lost, it's just not auto-resumed —
grepped the whole modules tree, there is no `buffer_load`/`buffer_restore`
code path. Recovery is manual:

- `compact.xz`/`thinking.xz`/`full.xz` are `0640`, group `protocol-7` —
  readable directly via `xz -dc <file>.xz` as `taeki` (in the
  `protocol-7` group), **no sudo needed**.
- `meta.yaml` is `0600` owner-only — NOT group-readable, needs the
  `protocol-7` user itself (or `sudo -u protocol-7`) to read it.
- The coding zenka's own `read_file` tool can't reach these paths even
  from inside a task — `context.file` strips leading `/` and resolves
  everything relative to `<system.root_path>`, by design (sandboxes the
  LLM to project files). Use direct shell `xz -dc`, not the zenka's tools.
- To find the exact backup dirs for one shutdown event: they share an
  epoch-timestamp prefix within a ~1-2 second window (the drain loop runs
  fast) — `ls completed-task-backups/ | grep 'Jul 16'` or glob the epoch
  prefix once you know it from the shutdown log line.

[[coding-zenka-improvement-pipeline]]

#,,,,,,,,,...,..,,.,,,,..,.,.,..,,.,,,,,.,..,,..,,...,...,..,,,..,,..,.,.,,.,,
#4TVYQTYLVG67SSWCYYW6RQUBLG6NJJJPBMTHOK7RGW7JLQZUOHGC25JIYJVB4MQKKAL3IIL5HHHDA
#\\\|5FOJ3KKZKBMGGKRUQZWHLC4MAXRWAI3NHDNF6RA6YMA2CJA36E7 \ / AMOS7 \ YOURUM ::
#\[7]HTMVJ24L24KMGWEMHBVXXETXMOU5BJVQZBB26JGSL6553VRGOKBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
