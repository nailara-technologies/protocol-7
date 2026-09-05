# Session Handover — 2026-09-05

## Completed This Session

### Task-backlog archiving sweep
`data/tasks/` had ~115 active `.md` files, many long since landed but
never archived. Built `bin/dev/task-scan-candidates` (directory +
extension agnostic — `task-scan-candidates [dir] [ext]`, defaults to
`data/tasks md`) as a lightweight shortlist tool: combines direct
`data/tasks/<file>` mentions in commit bodies (strongest signal —
authors here often write "Implements data/tasks/x.md" directly) with
stopword-filtered filename-token matching against the full
commit-subject corpus as fallback. It is a shortlist tool, not a
verdict — both signals produced confirmed false positives this session
(a task's own creation commit paraphrasing its title; generic 2-token
overlap with an unrelated commit), so every hit still needs the
matched diff and the task's own status section actually read before
moving anything.

Archived 21 tasks from `data/tasks/` -> `data/tasks/completed/`
(commit `4dcf3a19f`) and 4 from `data/yaml/coding-tasks/` ->
`data/yaml/archive/completed-coding-tasks/` (commit `ba570179d`), each
cross-checked against its real landing commit's diff, not just
title/filename matching. Full list and evidence in those two commit
messages. Several plausible-looking token matches were deliberately
**left in place** after reading the actual file, because they
self-report partial/open work right next to what looked like a
completion commit — worth remembering as a general caution before
trusting this class of scan: `cred-mesh-rotation-subscription-cross-
zenka.md`, `sub-bit-element-definition.md`,
`x11-xvfb-start-async-refactor.md`,
`coding-cpu-and-hybrid-offload-path.md`, `web-auth-plugin.md`,
`ptd-extensions-and-p7-perl-translator.yaml`,
`models-discover-cleanup.yaml`, `base-handler-command-
modularization.yaml`, and the `phase-2`..`phase-6` roadmap chain
(each explicitly gated on the previous phase).

Not exhaustive: only the most-recently-created ~20 of the 86 files
still active in `data/tasks/` got a full read this session, plus all
31 files in `data/yaml/coding-tasks/`. The older `data/tasks/` backlog
(pre-2026-08) has not been swept yet — good candidate for the next
archiving pass with the same tool + discipline.

### Prioritized next-dispatch queue (drafted from what was actually read this session)

Ranked by how dispatch-ready the remaining work is, per
`data/yaml/context-templates/kimi-dispatch-workflow.yaml`'s own bar
(objective/context/steps/acceptance already legible, not something
needing fresh design work first):

1. **`cred-mesh-transport-subscription-and-base32-gap.yaml`** (NEW,
   written this session, ready to dispatch) — extracted from the tail
   of `data/tasks/cred-mesh-rotation-subscription-cross-zenka.md`.
   That doc's bugs 1-4 and the leaked-timer self-permission-denial bug
   are all FIXED and live-verified (confirmed by re-reading the file
   in full before writing this task) — do not re-touch those. What's
   actually still open: transport's rotation-subscription vanishes
   somewhere between `send.local`'s successful queue and cred-mesh's
   `.cmd.subscribe_rotation` wrapper (proxy's identical path works
   fine), and `transport.cmd.cred-rotated`'s `base.base32.decode`
   resolves undef in transport only. Both symptoms may share one root
   cause (transport's `modules.load` token expansion vs proxy's,
   untested theory) — the task file says to check that, not assume it.
   Test harness already exists: `bin/dev/cred-mesh-test`, scenario 4.

2. **`research-knowledge-base-extraction.md`** — lowest-risk dispatch
   in the backlog ("do NOT implement anything, research and extract
   only"). Only topic 10 of ~11 roadmap topics has been extracted to
   `data/tasks/research-findings/`; the rest already have their search
   terms and output paths spelled out in the task file itself. Good
   for a bulk kimi pass since a bad extraction just gets re-read, never
   touches live code.

3. **`ptd-extensions-and-p7-perl-translator.yaml` — the `-diff` flag
   only**, not the whole file. The bidirectional p7<->perl translator
   described in the same file is a much bigger, fuzzier deliverable —
   don't dispatch that part yet. The `-diff` piece already has literal
   implementation notes (tempfile, strip `-b`/`-bext`, `system('ccdiff',
   $file, $tmp)`, flag name `-diff`) — one function added to
   `bin/dev/ptd`, cleanly separable.

4. **`models-discover-cleanup.yaml`** — fully specified: unified
   `models.discover` interface, 6 numbered implementation steps,
   explicit deprecation path for the 3 commands it replaces
   (`models.cmd.discover`, `.discover_files`, `.clear-registry`).
   Medium risk only because it touches 3 callers across zenki
   (`coding.*`, `lm-vision.*`, `image-quality.*`) — worth a human diff
   review before any live test.

Lower-confidence picks (only skimmed, not vetted the way 1-4 are):
`coding-cpu-and-hybrid-offload-path.md` (the hybrid/partial-GPU-offload
piece specifically — its stale opening framing was already flagged for
a separate small correction pass first, do that first), and
`x11-xvfb-start-async-refactor.md` bug 2 (diagnostic timing logs
already placed at the two suspected stall points, but the file itself
says not to test live without a clear plan — keep the live-
verification step human-supervised).

Explicitly **not** ready for direct dispatch without a scoping pass
first: `queue-intelligence-and-event-loop-safety.yaml` (critical
priority but self-described as touching three interconnected systems
— needs decomposition into sub-tasks before it's kimi-sized), and the
`phase-2`..`phase-6` roadmap chain (only phase-2 is even eligible,
not read closely enough yet to vouch for it as dispatch-ready).

## Open Items — Not Started / Not Finished

1. **Dispatch `cred-mesh-transport-subscription-and-base32-gap.yaml`**
   via `kimi_dispatch` — it's written and ready, just needs sending.
2. **Sweep the older `data/tasks/` backlog** (pre-2026-08, ~65 files
   not yet read this session) with `bin/dev/task-scan-candidates` +
   the same read-the-actual-diff discipline.
3. Everything in the previous handover's "Open Items" section
   (`v7-zenki` rename follow-ups, `p7-`-prefix ambiguity, dead `p7`
   command references, the `v7-stdout-foldable-relay` task cluster,
   `LYE`/`QP3`, the duplicate tmp-paths cleanup warning) was not
   touched this session — see git history (`988cc51f1`, `f4c295824`)
   for that content if it's still relevant; this file no longer
   carries it forward verbatim since it's a different work-stream than
   this session's task-archiving focus.

## Verified Live

Nothing in this session touched a running zenka — this was a pure
git-history/file-archaeology + archiving pass, no live testing was
needed or performed. `bin/dev/task-scan-candidates` was run and its
output spot-checked by hand against real commit diffs, not against a
live process.

Commits this session: `4dcf3a19f`, `ba570179d`. Not yet pushed (check
before assuming pushed).
