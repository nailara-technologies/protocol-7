---
name: coding-zenka-session10
description: May 3 2026 session — inference-backed compaction implemented + verified, :model: keyword, extract-inline-subs work, model hallucination patterns
type: project
originSessionId: c1117ac8-6abc-4bfb-87da-871e78f681bc
---
## Session May 3 2026

### inference-backed context compaction — IMPLEMENTED AND VERIFIED
- `coding.async.compact_context`: when `compaction_inference=yes`, enqueues a
  `no_tools/max_rounds=1` sub-task to summarize middle messages; returns `'pending'`
  to suspend parent in `STATE_SUBTASK`; falls back to heuristic if enqueue fails
- `coding.async.complete`: detects `compaction_pending` flag on parent; splices
  summary into messages instead of appending user message; resumes parent round
- `coding.async.send_request`: checks compact_context return; early-exits if pending
- Key bugs fixed during implementation:
  - `coding.task.enqueue` returns a hash — extract `->{'task_id'}`, don't use hash as id
  - enqueue requires `id`, `type`, `analysis.routed_to`, `execution.status`, `created_at`
    — use `coding.helper.task_id_generator` for the id
- **Verified working in production**: child `task-UDBRCXQ` summarized 14 msgs → 1,
  parent `task-WW6X44Q` resumed at round 10, context dropped from ~53% to 17%
- Config: `coding.cfg.compaction_inference = yes` (now enabled)
- Config: `coding.cfg.base_work_model`, `coding.cfg.base_compaction_model` added
  (both default to `start_model`; swap compaction model later for faster inference)

### :model: keyword and -model flag
- `coding.prompt.assemble`: strips `:model:AMOS:ID:` from prompt, overrides
  `parsed->{'model'}` without affecting explicit `GPU:M:` prefix
- `bin/coding-task -model AMOS:ID`: prepends `:model:...:` into B32 payload
- Makes task files self-describing; model-switch upgrade path ready for when
  a second backend is available (model-switch dependency state machine designed
  but not yet implemented — same-model compaction covers common case)

### extract-inline-subs template work
- Naming convention rules added to template + memory:
  1. No leading `_` in module filename: `sub _foo` → `namespace.util.foo`
  2. No `.cmd.` inheritance in util namespace: subs from `storage.cmd.visual`
     go to `storage.visual.util.*` not `storage.cmd.visual.util.*`
  3. No `cmd_` prefix in module name
- Template updated with all three rules + examples
- Modules extracted: ncode.regex.expand.util.{process_candidate,find_duplicate,
  merge_duplicate,evict_and_replace}, ncode.transform.wave.util.build_llm_prompt,
  storage.visual.util.{extract,proximity,list_workflows}
- Common model failure pattern: model fabricates completion summary without doing
  the actual file edits; always verify with grep after task completes

### model hallucination / task reliability
- Local 9B model reliably hallucinates multi-module extraction tasks — reports
  success without making file changes
- "verify after each step" prompt instruction not sufficient to prevent it
- More reliable: one module per task, or add mandatory search_code verification
  step in template between extractions
- Qwopus (ZDMAPAY:AR3OCKQ) not actually tested — switch didn't propagate in time
- 9B Claude distilled v2 (WZIZD6Y) remains default; keep for now

### open: remaining inline sub extractions
- src/kimi.handler.approval_request: sub flush_on_acquisition (line 81)
- src/letsencr.child.continue_challenge_processing: sub _cleanup_challenge (line 11)
- src/plugin.web.space.orbital.json.context: sub _synthetic_zenka_node (line 34)
- src/graphics-matrix.cmd.cell: sub cell_output (line 148) — may warrant cmd split
- src/AMOS7.key-32-safeguard: sub key_32_safe (line 24) — dead code, delete it

#,,.,,,..,,,,,,..,..,,,.,,,,,,,.,,,,.,,,,,,,.,..,,...,...,...,,..,,,.,.,,,,..,
#OWLCAXAGHIGSK5ENNDIJZ53G7ALMOBSQWWL6OIZBAYITUIGZ5UR2KFWE33CD2TZKONKMUAVUUVXKS
#\\\|5KSD73YC774FKAXNTLMHFYS7MDXHCF44LUYNGT5OLG3NKV2RYNG \ / AMOS7 \ YOURUM ::
#\[7]3YP5E5DRIVIS2LL6VUZJSTX4JE263JKFJO3J23OXLEXXVV63P2AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
