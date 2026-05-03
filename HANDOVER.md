# Session Handover — 2026-05-03

## Completed This Session

### Inference-backed context compaction — implemented and verified
- `coding.async.compact_context`: when `compaction_inference=yes`, enqueues a
  `no_tools/max_rounds=1` sub-task to summarize middle messages; suspends parent
  in `STATE_SUBTASK`; falls back to heuristic on enqueue failure
- `coding.async.complete`: detects `compaction_pending` flag; splices summary
  into parent messages (not appended as user message); resumes parent round
- `coding.async.send_request`: returns early with `compacting=1` if pending
- Bugs fixed during implementation:
  - `coding.task.enqueue` returns a hash — must extract `->{'task_id'}`
  - enqueue requires `id` (from `coding.helper.task_id_generator`), `type`,
    `analysis.routed_to`, `execution.status`, `created_at`
- **Verified in production**: child task summarized 14 msgs → 1, parent resumed
  at round 10 with context at 17% (was heading toward overflow)
- `coding.cfg.compaction_inference = yes` (enabled in coding/start)
- `coding.cfg.base_work_model` and `coding.cfg.base_compaction_model` added
  (both alias to `start_model`; separate compaction model is future work)

### :model: keyword + bin/coding-task -model flag
- `coding.prompt.assemble`: strips `:model:AMOS:ID:` from prompt, overrides
  `parsed->{'model'}` (doesn't override explicit `GPU:M:` prefix)
- `bin/coding-task -model AMOS:ID`: prepends `:model:...:` into B32 payload
- Task files are now self-describing; model-switch dependency state machine
  designed but not implemented — same-model compaction covers the common case

### extract-inline-subs template + naming rules
- Three naming rules codified in template + memory:
  1. No leading `_`: `sub _foo` → `namespace.util.foo`
  2. No `.cmd.` inheritance: subs from `storage.cmd.visual` → `storage.visual.util.*`
  3. No `cmd_` prefix in module name
- Modules extracted and wired:
  - `ncode.regex.expand.util.{process_candidate,find_duplicate,merge_duplicate,evict_and_replace}`
  - `ncode.transform.wave.util.build_llm_prompt`
  - `storage.visual.util.{extract,proximity,list_workflows}`

### Model hallucination pattern identified
- Local 9B model reliably fabricates completion summaries on multi-module tasks
  without making actual file changes — always `grep -n 'sub '` to verify
- "verify after each step" instruction insufficient; one-module-per-task is reliable
- Optional post-task review round (ptd_check on modified files) worth adding to template

## Open / Next

### Remaining inline sub extractions (all single-sub, straightforward)
- `modules/kimi.handler.approval_request`: `sub flush_on_acquisition` (line 81)
  → `kimi.handler.approval_request.util.flush_on_acquisition`
- `modules/letsencr.child.continue_challenge_processing`: `sub _cleanup_challenge` (line 11)
  → `letsencr.child.continue_challenge_processing.util.cleanup_challenge`
- `modules/plugin.web.space.orbital.json.context`: `sub _synthetic_zenka_node` (line 34)
  → `plugin.web.space.orbital.json.context.util.synthetic_zenka_node`
- `modules/AMOS7.key-32-safeguard`: `sub key_32_safe` (line 24) — dead code, just delete it
- `modules/graphics-matrix.cmd.cell`: `sub cell_output` (line 148) — may warrant
  splitting the cmd into multiple commands rather than extracting to util

### Model-switch dependency (future)
- For `base_compaction_model != base_work_model`: need a `STATE_MODEL_SWITCH`
  waiting state + spawn monitor signaling waiters when new model is ready
- Round detects required model mismatch → triggers switch → suspends in new state
- Same mechanism handles return trip (switch back to work model after compaction)
- Design: pin `required_model` to task; round checks on each fire

### llama-server tip rebuild
- ik_llama.cpp #1369-related Jinja crash still open upstream
- When fixed, rebuild from tip to get VRAM improvements from builds 4268-4447
- Toggle already set: `coding.jinja.enable = yes`

### nshell first-command (0) prefix bug
- Pre-existing: cube sends `(0)clear` on first command
- Best theory: `01b6be26e` removed trailing space from cmd_id formatting
- Proper fix: cube raw mode + VTerm line session buffers (large feature, deferred)
- Documented: `data/yaml/coding-tasks/nshell-session-protocol-tunneling.yaml`
