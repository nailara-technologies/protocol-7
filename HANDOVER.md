# Session Handover — 2026-05-08 (session 13)

## Completed This Session

### Task zenka completions
- `task.cmd.start` — claimed→in_progress transition (written by hand after model crash)
- `task.cmd.create` — now stores `iteration`, `acceptance_criteria`, `node_id`, `max_attempts`
- `task.end_code` — auto-saves `handover.txt` via `callbacks.end_code` on clean shutdown
- `valued.cmd.query` — network wrapper around `valued.tree.top_n` (n/parent/type params)

### Coding zenka bug fixes
- `coding.tool.detect_loop` — slice bounds crash (`-8` index on short history array)
- `coding.async.request` — `retry_timer_pending` flag stops stacking retry timers
- `coding.callback.backend_busy_retry` — clears `retry_timer_pending` before retry
- Line-edit tools (delete/insert/replace_line):
  - `base.file.slurp` → `file.read` (correct swap_subs name + returns scalar not ref)
  - `base.file.write_encoded` → `file.write_encoded`
  - `(stat $path)[2]` → `File::stat::stat($path)->mode` (shadowing fix)
  - `@lines` → `\@lines` (arrayref for write_encoded)
  - Staging messages now say `SUCCESS:` + explicit "do NOT verify with read_file"

### Iteration loop e2e
- `test.iteration.hello` — minimal verified module, `mode => 'true'`
- Task criteria fields now stored on task record (needed for `models.handler.task-result`)

### Template improvements
- `system-tools.yaml` — `search_code` non-empty query note
- `feature-impl.yaml` — `write_new_file` trailing newline warning

### Memory / feedback
- `feedback-file-io-api.md` — file.read/slurp/write/write_encoded/append param order,
  `base.file.*` namespace warning, `File::stat::stat` shadowing
- `feedback-list-return-format.md` — `mode 'true'` (single-line) vs `mode 'size'` (multi-line)

## Next Steps — Task Tree Functional Path

### 1. Wire task.cmd.start into models dispatch (HIGHEST PRIORITY)
`models.handler.task-poll-step` flow: `claim → show → enqueue → execute`
`task.cmd.start` (claimed→in_progress) is never called — `in_progress` status never set.
Fix: after `step: claimed` succeeds, route-send `task.start <task_id>` before proceeding to `show`.

### 2. Load task tree seed into valued tree at startup
`data/yaml/task-tree/` YAML files define the eternal root + 5 category branches.
They need to be loaded into `<valued.index>` at task/valued zenka init.
Without this the gradient is empty and `task.cmd.next` always returns priority 0.

### 3. First real e2e pipeline test
Create a real task via `p7c task.cmd.create` with `iteration:true` and watch it flow:
  pending → claimed → in_progress → models.task.execute → iteration.loop → done
Verify `task.cmd.next` returns it gradient-sorted, `task.end_code` saves handover.

### 4. task.cmd.show — display iteration fields
Currently doesn't show `iteration`, `acceptance_criteria` on task records.
Minor but useful for debugging iteration tasks.

### 5. valued.cmd.query and task.cmd.next network tests
Both written but not yet tested via `p7c`. Quick sanity check after #2 (seed load).

### 6. meta-session-summary template wiring
Task tree has a `meta-workflow/session-summary` node. Wire it so `task.cmd.handover`
output feeds into a coding zenka task at session end (or via a Claude Code Stop hook).

## Model Config
- Default: Qwen3.5-9B sushi coder, reasoning=high, context=87777
- SLERP 4B: low reasoning only, good for style/format tasks
- 9B deepseek reasoning: untested, queue for comparison

## Known Issues
- `write_new_file` can produce duplicate `## [:< ##` headers if model retries insert_line
  on a staged file (original path unchanged, model doesn't see its own write)
  → staging message now says "do NOT verify with read_file" — monitor if it recurs
- `chmod child` requires root — line-edit tools fall back to staging when unavailable
- `models.handler.task-result` reads `iteration` from `<task.queue>` (task zenka),
  but `models.task.execute` reads it from jobqueue callback params — two separate paths,
  both wired but only the task-result path uses the task record's `acceptance_criteria`
