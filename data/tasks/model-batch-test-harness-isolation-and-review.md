# model batch-test harness: worktree isolation, capture/revert, cross-model review

not started, investigation write-up only. written 2026-09-20 after two pieces of
same-day operational friction with the existing synthetic self-test machinery
(below). sibling scope to [[AUTONOMOUS-MODEL-MANAGEMENT]]'s benchmark harness
work — this doc deliberately does NOT re-design that vision; it covers the
three environment-control concerns a REAL-task batch run raises that the
synthetic self-test path never had to face.

## why this exists

the `coding` zenka dispatches real coding tasks — file edits, analysis,
module writes against THIS repo, not a sandbox. the existing batch-ish
mechanism (`coding.model_sweep.*`) only ever runs a fixed 3-prompt synthetic
self-test (`src/coding.self_test.run`: arithmetic, cat/mouse riddle ×2) that
touches zero files. the moment a batch harness runs REAL tasks against a
rotating cast of models, three properties become load-bearing that nothing
today provides:

1. **attributability** — if the tree is dirty when model A's batch starts,
   and model A's task runs also write files, nobody can say which changes
   were the model's and which were pre-existing uncommitted work. results
   become non-reproducible: re-running the same batch from "clean" gives a
   different starting state.
2. **identical baselines per model** — model B must start from the same
   tree model A started from, not from model A's debris. without an explicit
   capture-and-revert step, drift accumulates across the batch and
   cross-model comparison silently compares different environments.
3. **reviewability** — "model A passed, model B failed" on a synthetic
   3-prompt probe is already reviewable via `coding.model_status` /
   `coding.self_test` archives. real tasks need the actual outputs (the
   diffs!) captured and laid out side by side, with timing and failure
   detail, or the pass/fail signal is unactionable.

motivating friction, confirmed live 2026-09-20:

- a near-1-bit-quantized model (~2.5 tokens/sec) pushed one self-test past
  10 minutes, and separately fired the task-execution path's data-start
  timeout (`src/coding.async.http_client`: 47s base, scaled by estimated
  prompt tokens at `prefill_tokens_per_sec // 1200` + 5s margin — a large
  real-task prompt lands the effective budget near 120s; a 90s cold-start
  grace overlays it). retries exhausted → `src/coding.callback.http_error`
  marks the server `restart_needed` and respawns it via
  `coding.handler.spawn_servers_deferred` — **back to the configured
  default model, silently, mid-task**. a batch harness holding a candidate
  model on a backend must notice this class of swap or it keeps "testing"
  a model that is no longer loaded.

so the design constraints, beyond the three above: wildly varying model
speeds (2.5 t/s to 100+ t/s in the same batch), a model that never
terminates cleanly, and the existing auto-restart/timeout machinery
actively working underneath a long batch run.

## what exists to build on

**the sweep orchestration shape is the template.** `src/coding.model_sweep.
handler.poll_sweep` is exactly the state-machine skeleton a real-task batch
needs: one candidate at a time, checkpointed cursor persisted to
`state/model_sweep_cursor.yaml` (survives zenka restart), a per-backend
backend lock held for the ENTIRE candidate cycle (`sweep:$switch_id` via
`coding.async.backend_acquire`), yield-to-real-task gate with a
stream-aware ceiling (reuses `coding.async.stream_tps`'s `is_alive` to
distinguish slow-but-live from stalled), circuit breaker that auto-PAUSES
on repeated identical crash signatures (never cancel — the frozen cursor
is what the operator resumes from), and switch→test→**restore** semantics
via `coding.self_test.handler.poll_switch` (`original_model` captured
before the switch, restored after). a real-task batch is "same cursor, but
the per-candidate payload is N real tasks instead of one 3-prompt probe,
and the restore step includes the working tree."

**result-capture schema precedent.** `src/coding.self_test.archive` stores
per-run: ttft, tps, passed, answer, plus full per-prompt detail (prompt,
answer, reasoning, finish_reason, tier, structural_reason, failure_class,
tier1_attempts) and a durable cross-restart stats file (`self_test-stats.
yaml`) written through `file.zenka_dir.load/write` (atomic, 0640, under
the zenka state dir — NOT inside the git tree). `src/coding.model_status.
record` does the same for the coarse 5-state verdict into
`state/model_status.yaml`. a real-task run record is this shape plus diff +
files-touched.

**git-from-a-module precedent exists, but for another repo.** `src/coding.
tools.handler.git_restore_file` shells out to `git ls-files` / `git
status` / `git restore --source=HEAD` (per-file, refuses untracked files,
verifies with a post-status). `src/workspace-transfer.console.status-check`
already implements a clean-tree gate (`git status --short | wc -l` →
CLEAN/UNCOMMITTED report) and `workspace-transfer.console.checkpoint` does
`git add -A && commit && push`. caution: the workspace-transfer family
operates on the USER's workspace repo (`chdir_workspace`), not on the
protocol-7 tree itself — the pattern transplants, the code does not
directly.

**trash-based safety is the house religion for anything destructive.**
`models.cmd.delete-model` + `models.trash.*` (trash-list / trash-rescue /
trash-prune, root via `models.trash.root_path`), `note.trash.stash`
(xz+base32 the current content into a trash dir before ANY destructive op,
rescue afterwards — explicitly "shared backup primitive so any operation
that removes or overwrites leaves a recoverable copy"), `jobsite.cmd.
rescue` / `list-trashed`. nothing in the codebase today snapshots or
reverts a WHOLE working tree — the per-file git_restore_file and the
trash-before-destroy patterns are the two halves to combine.

**the interference machinery to design around:**

- `coding.async.http_client` data-start timeout (scaled, cold-start grace)
  → `coding.handler.http_data_start_timeout` → on_error →
  `coding.callback.http_error` retry loop (`max_retries`) → server
  `restart_needed` → respawn to DEFAULT model. also reduces
  `ctx_recovery_ceiling` as VRAM-pressure recovery — side effect a batch
  run should not accumulate unnoticed.
- `coding.handler.monitor_inference_startup`'s seed-restart-on-failure
  loop, hardcoded to synthetic prompt_id 2 — fires on respawns during a
  batch.
- the per-backend self-test in-flight guard `coding.self_test_probe_in_flight`
  and `coding.self_test_switch_in_progress` suppression flag (poll_sweep
  sets it to keep its own switch from triggering the monitor's
  auto-self-test) — the suppression-while-batch-runs pattern is already
  invented.

## concern 1 — clean-worktree gating

**option A. hard gate, refuse to start.** batch command runs
`git status --porcelain` (exactly workspace-transfer's check); any output
→ refuse with the file list, like `model-sweep`'s refusal to clobber an
active sweep. mirrors the codebase's existing "refuse clearly rather than
start something that will wedge" stance.

- pro: absolute — a dirty-tree run is impossible, so attributability is
  structurally guaranteed.
- con: this repo's tree is dirty most of the time in practice; the batch
  becomes unavailable exactly when the owner is mid-work. untracked files
  (`??` lines) are a judgment call — a stray log file is not the same as
  uncommitted source edits.

**option B. flag-only, record the tree state.** run anyway, but stamp every
per-run record with HEAD sha + porcelain output hash + dirty-file list, so
review can weight or filter contaminated runs.

- pro: never blocks; captures reality (sometimes the dirty files are
  exactly what the task is about).
- con: doesn't prevent conflation, only annotates it; depends on reviewer
  discipline; re-runs still aren't comparable.

**option C. harness-managed baseline.** harness commits or stashes the
current state itself before starting (workspace-transfer checkpoint's
`git add -A && commit` transplanted), runs from that known commit, and
restores after.

- pro: baseline exists in git; per-model `git reset --hard` to it is
  trivial (feeds concern 2 directly).
- con: a zenka auto-committing the owner's tree is intrusive and needs
  branch/commit-policy decisions; stash conflicts on restore; all the
  same destructive-op discomfort as A's implicit assumptions.

**lean: A with an explicit escape hatch + B always.** refuse on dirty
tree, with a single-colon override keyword (house convention — `:force:` /
`:re-test-failed:` style, substitutive-extraction parsing per
`sourcecode.console.update-signatures`) that downgrades to B and stamps
every record with the tree fingerprint. clean gate as the default keeps
the common case reproducible; the override keeps the tool usable on a
live repo; the fingerprint means even overridden runs stay attributable.
the check must run at batch start AND between models (a task run that
failed to revert is the same contamination class — see concern 2's
revert-verification step).

## concern 2 — capture + revert between models

the revert primitive itself is nearly free IF concern 1's gate held: the
baseline is a known commit, tracked files return via
`git reset --hard <baseline>`. the hard parts are (a) untracked files a
task run created — `git restore` can't touch them, `git clean -fd` is a
bare permanent delete this codebase's conventions explicitly reject, and
(b) capture must happen BEFORE revert, since revert destroys the evidence.

**option A. git-only.** baseline commit + `git reset --hard` tracked +
`git clean -fd` untracked.

- pro: minimal; git is the snapshot; nothing new to persist.
- con: `git clean -fd` violates the trash-based-safety norm; a model that
  wrote something valuable loses it permanently. untracked INPUT files the
  operator placed in the tree get eaten too.

**option B. git + worktree-trash (house-consistent).** tracked files via
`git reset --hard`; every untracked/new path first MOVED (not deleted)
into a batch trash dir — indexed by (batch_id, model, relpath), with
rescue/prune commands mirroring `models.cmd.trash-rescue` / `trash-prune`.
this is `note.trash.stash`'s contract ("any operation that removes or
overwrites leaves a recoverable copy") applied at tree scope.

- pro: matches the project's demonstrated safety philosophy; nothing is
  ever unrecoverable; rescue surface is a solved UI pattern here.
- con: most new code of the three options (trash index, retention policy,
  prune cadence); moving files with active fds / weird permissions has
  edge cases.

**option C. per-model git worktree (isolation instead of revert).** `git
worktree add` a fresh checkout per model; each candidate runs its task set
against its own tree; capture; delete the worktree. no revert in the main
tree at all — concern 1's gate only needs to protect the main tree from
the harness's own bookkeeping.

- pro: strongest isolation; models are even parallelizable on the task
  side; zero destructive ops anywhere the owner works.
- con: tasks and tools that resolve paths via `<system.root_path>` (e.g.
  `coding.tools.handler.git_restore_file` builds exactly that) or
  hardcode the real repo root in prompts will write to the WRONG tree;
  inference-server/model switching is global anyway, so the parallelism
  win is partial; per-model checkouts of a 6k-file tree add disk churn.

**lean: B now, C flagged as a later refinement.** B reuses the baseline
commit from concern 1, keeps the main tree as the single execution
environment (no path-resolution surprises), and extends an existing,
proven safety pattern rather than inventing one. C is the right answer if
task-side isolation ever needs to be stronger than process-level — note
it, don't build it.

capture-before-revert, concretely — per (model, task) the harness must
store, before any revert: the full `git diff` (the model's actual work
product), the porcelain file list (files touched), the task prompt/spec,
verdict + failure detail, timing. revert then: reset --hard tracked →
move untracked to trash → **re-verify clean** (`git status --porcelain`
empty) before the next model starts; a failed reverify is a hard stop with
the trash index as the recovery surface, never "continue anyway" — that is
exactly the drift concern 2 exists to prevent. (whether the per-run record
store lives in the zenka state dir like `self_test-stats.yaml` or in the
repo is itself an open question below — putting it in the repo would dirty
the very tree the harness keeps clean, which argues for the state dir.)

## concern 3 — review across models

**what a per-run record needs** (self_test.archive's shape, extended):

```
batch_id / batch_spec_version     ## which task set, which revision of it
model checksum + backend          ## AMOS7 id, same registry key as sweep
task id + prompt/spec reference   ## what was asked
baseline commit + tree fingerprint  ## from concern 1's gate
files_touched / porcelain list    ## scope of side effects
full diff                         ## the model's actual output — the
                                  ## thing a pass/fail bit can't replace
verdict + failure_class + detail  ## completed / error / timeout / crash,
                                  ## same vocabulary as model_status
timing                            ## ttft, total wall, tps (stream_tps
                                  ## already produces this per round)
finish_reason / crash detail      ## server_tail-style context on failures
```

**the verdict/quality signal is its own sub-decision.** real tasks rarely
have a literal expected answer like self-test prompt 1's "91". options:
criteria-based scoring via `iteration.score_result` (criteria list →
per-criterion verdict → 0.0-1.0 — directly reusable mechanics, and the
same engine MODEL-BENCHMARK-HARNESS.md already flags as the correctness
dimension); a per-task executable checker (each batch task ships a
verification command — strongest signal, most authoring cost); or human
review only (zero scoring infra, but the comparison table carries no
signal at all). lean: capture raw + optional criteria scoring initially —
`iteration.score_result` on the diff/result where the batch author wrote
criteria, nothing where they didn't. don't block review on a scoring
framework that MODEL-BENCHMARK-HARNESS.md owns separately.

**review surface options:**

- **A. console command** (`coding.cmd.*`-style, mirroring
  `coding.model_status.cmd.model-status` / `self-test-status`): models ×
  tasks grid — rows tasks, columns models, cells verdict + wall/tps,
  drill-down per cell to the captured diff. structured-text display via
  `base.format.inline-nested.encode` for the detail views.
- **B. file-based report** per batch: yaml/markdown under the state dir,
  following the model_status.yaml persistence pattern. diff-able,
  archivable, feedable into the dataviz/artifact conventions later if
  anyone wants to view outside the console.
- **C. both** — store structured records (B is needed anyway as concern
  2's capture target), console command as a pure reader over them.

**lean: C.** the store is not optional (capture requires it), so A built
as a reader over B costs no duplicated state. start with B + a minimal A
(grid + drill-down); a pretty artifact viewer is explicitly out of scope
until someone actually views these outside a terminal.

## the slow/hung/swap-underneath problems (batch-runner-specific, cross-cutting)

these sit under all three concerns but belong to the runner's execution
loop, worth pinning here since today's incident proved they're real:

- **per-task and per-model wall-clock budgets.** a 2.5 t/s model against a
  real task can run for hours. the codebase's existing stance (poll_probe's
  liveness-aware extension, 77s stall watcher) is "extend for live streams,
  kill hung ones" — the batch runner should adopt the same: budget =
  f(observed tps), not flat seconds, reusing `stream_tps is_alive` rather
  than new watchdog logic. a per-model budget also needs a policy decision
  (open questions).
- **detect the silent model swap.** before/after every task, the runner
  compares the backend's actually-loaded model id
  (`<inference.backend.gpu.model_id>` / server-reported model) against the
  candidate; on mismatch, abort the candidate with a recorded
  `model-swapped-mid-batch` failure class rather than scoring tasks
  against the wrong model. this is the direct generalization of today's
  silent loss. holding the sweep-style backend lock for the whole
  candidate cycle prevents most contention, but the `timeout_restart`
  respawn path (`restart_needed` from `coding.callback.http_error`) can
  still fire from INSIDE the runner's own tasks — that path respawns to
  the default model by design, so detection, not just locking, is
  required.
- **suppress the monitor's synthetic machinery while a batch candidate is
  in flight** — the `coding.self_test_switch_in_progress` flag poll_sweep
  already sets is the existing mechanism for exactly this class of
  suppression (keeps a switch from re-triggering the monitor's
  auto-self-test). decide explicitly whether the batch runner sets it or
  tolerates the extra synthetic probe per respawn.

## relation to the bigger vision

`AUTONOMOUS-MODEL-MANAGEMENT.md`'s "prerequisite: the testing harness"
section proposes `models.benchmark.runner` / `.suite` / `.store` /
`.compare`, and its implementation checklist is entirely unchecked.
`MODEL-BENCHMARK-HARNESS.md` (its spun-off topic 1) scopes itself tightly:
"one canonical workload, one model, one score record," with correctness
scoring via `iteration.score_result`-shaped criteria and ttft/tps/memory
as the other axes. its topic 6 is "shadow evaluation against real tasks"
— which is the closest neighbor to this doc.

this doc is the **environment-control and evidence layer underneath topic
6**, not a competitor to the benchmark harness: `models.benchmark.runner`
needs a tree it can run real tasks in without contaminating either the
repo or its own next measurement, and `models.benchmark.store` (topic 2)
needs to know what a real-task run record contains — both answered here.
conversely, scoring/aggregation, canonical workload design, and the
suite-version discipline stay with MODEL-BENCHMARK-HARNESS.md; this doc
imports `suite_version` as `batch_spec_version` rather than redefining it.

and relative to today's code: the synthetic sweep (`coding.model_sweep.*`)
is the wide, cheap filter (whole registry, 3 prompts, coarse 5-state
verdict); a real-task batch is the deep, expensive evaluation of a
shortlist. they compose — a natural trigger seam is "sweep says
functional → eligible for the real-task batch queue" — but the batch
harness must remain runnable standalone, same as `model-sweep-test` runs
one checksum without a full sweep.

## open questions, not yet investigated

- **record store location**: zenka state dir (file.zenka_dir pattern —
  outside git, can't dirty the tree, survives restarts) vs inside the repo
  (diffable/archivable, but the store itself would trip concern 1's gate).
  lean state dir; unresolved.
- **task source for batches**: hand-authored batch task files (deterministic,
  versionable, artificial) vs replaying real completed tasks mined from
  queue history (representative, but needs replay guarantees — a task whose
  answer is already in the tree is not the same task). probably both, with
  batch_spec_version distinguishing.
- **runner entry point**: drive real tasks through the normal
  `coding.submit` / queue machinery (inherits yield/priority coordination,
  risks interleaving with unrelated real traffic — the sweep's yield gate
  shows how the codebase handles this) vs direct `coding.async.request`
  calls (full control, but bypasses machinery that exists precisely to
  sequence load).
- **model-swap handling depth**: detect-and-abort-candidate (simple, loses
  the candidate's remaining tasks) vs a new cfg flag that makes the
  `timeout_restart` path respawn to the SAME model it killed (preserves
  batch semantics, touches the recovery path every other task type also
  uses — needs care that the default-model behavior stays default when no
  batch is running).
- **per-model budget policy**: flat wall-clock cap per candidate vs
  tps-relative budget (mirroring backend-aware-timeout-scaling's
  live-tps-derived cap philosophy). a 2.5 t/s model may legitimately need
  30× the budget of a fast one; a flat cap either starves it or wastes
  hours on a hung one.
- **partial-capture policy**: a task that crashes mid-round leaves the tree
  half-edited. capture the half-diff and mark `partial`, or revert without
  capture? (lean: always capture — the half-state is often diagnostic.)
- **trash retention/prune cadence** for the worktree-trash dir: mirror
  models.trash.prune's policy directly, or is batch trash (potentially
  many small files per run) different enough to need its own?
- **untracked input files**: an operator-placed untracked file in the tree
  at gate time — does the gate distinguish `??` from `M`/`A`/`D`, and does
  the trash-revert protect operator-placed untracked files from a task run
  that (wrongly) overwrote them? (git can't distinguish author of an
  untracked file; the trash index + rescue surface is the mitigation, but
  the policy call is open.)
- **multi-backend batches**: sweep runs gpu and cpu cursors independently.
  a real-task batch against both backends doubles side-effect surface —
  same tree, two models writing. sequential-only in v1, or is the
  cross-backend lock (`coding-sweep-cross-backend-lock` precedent) enough
  to make concurrent same-tree batches safe? (lean: sequential.)

## resolved spec (kimi decision-narrowing pass, 2026-09-20)

this section supersedes the open-questions section above for everything it
resolves; that section stays as the historical record. three groups:
the firmed concern verdicts first, then the open-question resolutions,
then a closing note. one scoping rule applied throughout: anything
whose blast radius touches the OWNER's live working tree destructively
or semi-destructively is written as a flagged recommendation with a
recommended default and tradeoffs — the owner signs off on those. the
rest are decided unilaterally and an implementation pass can start
from them without further design questions.

### concern 1 — DECIDED (unilateral): hard gate with escape hatch, always stamp

exact mechanics:

1. the gate runs `git status --porcelain` and splits the output into
two classes: tracked modifications (`M`/`A`/`D`/`R`/`T`) and untracked
(`??`).
2. any tracked modification → refuse to start, print the file list,
suggest commit or stash. the keyword `:force:` in the batch command
(house single-colon override convention) downgrades to flag-only mode
for that run.
3. untracked files NEVER block the gate. instead, at gate time the
harness records each untracked path + sha256 fingerprint and copies
the content into `state/model_batch/<batch_id>/gate-snapshot/`. this
snapshot is what makes operator-placed input files recoverable later
(see concern 2 and the untracked-input resolution below).
4. every per-run record is stamped with baseline HEAD sha, the
porcelain fingerprint, and the dirty-file list — in both clean and
`:force:` runs. attribution is a property of the record, not of
reviewer discipline.
5. the gate re-runs between models. additionally, before any revert
(concern 2), the harness compares the tree against the expected
post-task fingerprint; owner-made changes detected mid-batch → the
cursor freezes exactly like the sweep's circuit breaker, and the
batch refuses to revert over them. the operator resolves and resumes.
6. in clean-gate mode the baseline IS `HEAD` — the harness never
creates a commit. option C's harness-managed baseline commit is dead:
it was only ever a way to make revert addressable, and `HEAD` is
already addressable on a clean tree.

### concern 2 — NEEDS OWNER SIGN-OFF (reverts the live tree); recommended default: option B

this is the one decision in the doc whose blast radius is the owner's
actual working tree, trash net or no trash net. it is therefore a
recommendation, not a unilateral decision.

#### recommended default: option B (git + worktree-trash), exactly as follows

per (model, task), in strict order:

1. **capture BEFORE anything destructive.** full `git diff`, porcelain
file list, task spec reference, verdict + failure_class, timing —
into the state-dir record (concern 3's store). in `:force:` runs the
capture additionally includes the full pre-existing dirty diff, so
even revert over a dirty tree is recoverable by re-applying the
captured patch.
2. **tracked restore:** `git reset --hard <baseline HEAD>`. safe by
construction in clean mode (tracked files were at HEAD; nothing of
the owner's is lost). dangerous in `:force:` mode, which is exactly
why `:force:` capture (step 1) includes the pre-existing diff.
3. **untracked handling:** every untracked path NOT in the gate
fingerprint is task-created → moved (never deleted) into the batch
trash dir, indexed by (batch_id, model, relpath). an untracked path
IN the gate fingerprint whose content changed (task overwrote
operator input) → the modified version is moved to trash AND the
original is restored from the gate snapshot.
4. **re-verify:** `git status --porcelain` must show the tree in the
expected post-revert state before the next model starts. a failed
reverify is a hard stop — cursor frozen, trash index + gate snapshot
+ captured diff are the recovery surface, never "continue anyway".

#### why this is flagged, and the tradeoffs

- blast radius: `git reset --hard` and `mv` against the owner's live
tree. the nets are the trash dir, the gate snapshot, and the
capture-everything-first ordering — but nets are recovery, not
prevention. an owner hand-editing a file mid-revert, an fd held open
on a moved path, a permission edge case: all land on the owner to
rescue from.
- what prevents the worst case: the harness never auto-commits,
never reverts over owner changes (step 5 of concern 1 freezes
instead), and never deletes anything.
- for: reuses an existing proven safety pattern (`note.trash.stash`'s
contract at tree scope), keeps the main tree as the single execution
environment (no `<system.root_path>` path-resolution surprises —
`coding.tools.handler.git_restore_file` builds exactly that), and
composes directly with the concern-1 gate.
- against: it is still the harness running destructive git commands
in the owner's repo, and `:force:` mode makes that substantially
more dangerous (mitigated by the forced full-diff capture, but the
mitigation only exists if step 1 is implemented before step 2 — the
ordering must be treated as inviolable in code review).

#### fallback if the owner declines: option C (per-model worktrees)

zero destructive ops on the owner's tree: `git worktree add` per
candidate, run, capture, delete. costs: tasks/tools that resolve via
`<system.root_path>` write to the wrong tree, model switching is
global anyway so parallelism gain is partial, 6k-file checkout churn
per candidate. if the owner declines B and C both, the batch harness
does not run against the main tree, full stop — there is no third
option that keeps attributability.

### concern 3 — DECIDED (unilateral): C, state-dir store + console reader

- **store (the decided shape):** `state/model_batch/<batch_id>/<model_checksum>.yaml`,
  written via `file.zenka_dir.load/write` (atomic, 0640) — same
  durability contract as `self_test-stats.yaml`. per-task entries
  carry exactly the field list already given above (batch_spec_version,
  model checksum + backend, task id, baseline + fingerprint,
  files_touched, full diff, verdict + failure_class, timing,
  finish_reason).
- **verdict vocabulary:** model_status-compatible 5-state plus
  failure_class drawn from {error, timeout, crash, model-swapped-mid-batch,
  budget-exceeded, partial} — the batch runner's own classes, so
  `model_status` readers don't misread them.
- **scoring:** raw capture always; a batch task may carry an optional
  `criteria:` list, in which case the record also gets a 0.0-1.0 score
  via `iteration.score_result` mechanics. no criteria → no score, the
  reviewer reads the diff. no per-task executable checkers in v1 —
  strongest signal but too much authoring cost to gate the first
  harness on.
- **review surface:** a console command in the `coding.model_status.cmd`
  shape (`model-batch-status`): models × tasks grid, cells verdict +
  wall/tps, drill-down per cell to the captured diff via
  `base.format.inline-nested.encode`. pure reader over the store. the
  file-based "report" is a generated view from the same store, not a
  second persisted artifact — nothing outside the state dir.

### open-question resolutions

- **record store location — DECIDED: zenka state dir.** layout as in
  concern 3. a store inside the repo would dirty the very tree the
  gate protects and would need its own exemption logic; the state
  dir already has the atomic-write, 0640, survives-restart precedent.
  diffability/archivability of a repo copy is a generated-view problem,
  not a storage-location problem.
- **task source — DECIDED: hand-authored batch spec files only in v1.**
  one yaml per batch (versionable, deterministic, lives under
  `cfg/model-batches/`), `batch_spec_version` is an explicit field in
  the spec. mined replay of completed queue tasks is deferred: the
  replay-guarantee problem (task whose answer is already in the tree
  is not the same task) is unsolved and v1 should not gate on it.
  the spec field already anticipates a second source type later.
- **runner entry point — DECIDED: through the normal `coding.submit` /
  queue machinery.** inherits yield-to-real-task gating, priority
  coordination, the circuit breaker, and the stream-aware liveness
  ceiling for free; the runner additionally holds the sweep-style
  per-backend lock for the whole candidate cycle and sets
  `coding.self_test_switch_in_progress` for the batch's duration, so
  interleaving is controlled by the same mechanisms the sweep already
  uses. direct `coding.async.request` calls fork execution semantics
  and bypass machinery that exists precisely to sequence load —
  rejected.
- **model-swap handling depth — DECIDED: detect-and-abort-candidate in v1.**
  before/after every task, compare the backend's actually-loaded model
  id against the candidate; mismatch → record
  `model-swapped-mid-batch`, freeze the cursor, operator resumes. the
  same-model-respawn cfg flag is deferred: it modifies the
  `timeout_restart` recovery path every other task type also uses,
  and "default model stays default when no batch runs" is a subtle
  invariant not worth risking in v1. detection is sufficient because
  attribution is preserved either way.
- **per-model budget policy — DECIDED: tps-relative, mirroring
  backend-aware-timeout-scaling.** per-task budget = the task spec's
  `budget_hint` (seconds, authored at ~20 t/s reference speed) scaled
  by `reference_tps / max(observed_tps, 1)`, clamped to [1×, 30×] the
  hint; `stream_tps is_alive` extends the budget for live streams
  exactly like poll_probe's liveness-aware extension. per-model cap =
  Σ per-task budgets × 1.5 headroom; exceeded → abort the candidate's
  remaining tasks, record `budget-exceeded`, keep captured partials.
  a flat cap either starves a 2.5 t/s model or burns hours on a hung
  one — the codebase already settled this philosophy for timeouts.
- **partial-capture policy — DECIDED: always capture, verdict `partial`.**
  capture precedes revert on every path anyway, so capturing a
  half-diff costs nothing extra, and the half-state is routinely the
  most diagnostic artifact (where the model was when it died).
- **trash retention/prune cadence — DECIDED: mirror `models.trash.prune`
  directly, separate root.** a `model_batch.trash.root_path` alongside
  the models trash root, same retention knobs, same rescue/prune
  command shape mirroring `models.cmd.trash-rescue` / `trash-prune`.
  batch trash is many small files rather than multi-GB model weights,
  but that changes disk math, not retention policy — one policy in the
  codebase beats two.
- **untracked input files — DECIDED: gate distinguishes `??` from
  `M`/`A`/`D`; snapshot, don't refuse.** `??` never blocks (a stray
  log is not uncommitted source), but every `??` path is fingerprinted
  and content-copied into the gate snapshot at batch start. a task run
  that creates untracked files → those paths land in trash (not in the
  gate list). a task run that overwrites an operator-placed untracked
  file → original restored from the snapshot, overwritten copy kept in
  trash. git cannot attribute authorship of an untracked file, so the
  policy replaces attribution with recovery.
- **multi-backend batches — DECIDED: sequential-only in v1.** one
  backend's cursor active at a time; the other backend's batch waits.
  the hazard with concurrent same-tree batches is two models writing
  one tree, and the cross-backend lock only serializes switching, not
  writes. cross-backend concurrency is deferred to land together with
  concern-2 option C (per-model worktrees), which is the thing that
  would actually make it safe.

### what an implementation pass starts from

unilateral and ready: concern 1 gate mechanics, concern 3 store +
reader, all nine open-question resolutions above. blocked on the
owner: concern 2's revert-on-live-tree (recommended default: option B
with the capture-first ordering inviolable; fallback: option C
worktrees; no third option). nothing else in this doc requires a
design decision before code.

## related

- [[AUTONOMOUS-MODEL-MANAGEMENT]] — the 4-layer vision; this doc is the
  real-task environment-control substrate under its layer 2 / topic 6,
  and a complement (not a replacement) for its proposed
  `models.benchmark.*` harness. `data/md/design/AUTONOMOUS-MODEL-MANAGEMENT.md`
- [[MODELS-PATH-ADAPTERS]] — model storage/discovery adapter design; the
  batch harness consumes models through the same registry the sweep
  iterates (`<coding.model_metadata>`), not this layer directly, but the
  lmstudio discovery path is where batch candidates come from.
  `data/md/design/MODELS-PATH-ADAPTERS.md`
- [[MODEL-BENCHMARK-HARNESS]] — topic-1 scoring/workload design; owns
  criteria-based correctness scoring and suite-version discipline that
  this doc imports. `data/md/design/MODEL-BENCHMARK-HARNESS.md`
- [[MODEL-STATUS-TRACKING]] — the coarse 5-state status table the sweep
  writes; the batch harness should write a compatible verdict vocabulary.
  `data/md/design/MODEL-STATUS-TRACKING.md`
- `data/md/design/coding-backend-aware-timeout-scaling.md` — the
  live-tps-derived timeout philosophy the per-model budget question
  should mirror.
- `data/tasks/completed/coding-model-sweep-iterator.md` — the sweep's task
  file; documents the cursor/lock/yield decisions a batch runner mirrors.
- `data/tasks/completed/coding-self-test-true-parallelization.md` —
  per-backend guard-slot precedent.

#,,.,,,.,,.,.,,,.,..,,..,,..,,...,.,,,,.,,..,,..,,...,...,,,,,,,,,.,.,..,,,..,
#65X6ETLBERNAPQEPM6Q22HBT3UBJ5NWX3CZ6Y6FP5WTQUOTFE3HFEMRNCUZNC23W2PDA67GIHPU4I
#\\\|7W6OYY5BZMD7PT3WHDDRLINYJUVOJTU32IG2WFW64OEVOF5IS6P \ / AMOS7 \ YOURUM ::
#\[7]AFXUWU3SVLEAUOR2K7CP4DB3EPOAMYB6KDSY54QBBKGKJ5YVB6DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
