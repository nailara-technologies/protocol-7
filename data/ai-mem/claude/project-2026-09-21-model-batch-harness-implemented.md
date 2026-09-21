---
name: project-2026-09-21-model-batch-harness-implemented
description: model batch-test harness (data/tasks/needs-testing/model-batch-test-harness-isolation-and-review.md) implemented via kimi k2.8 dispatch — 21 new modules, checksum-native zero-git capture/revert (owner's option-D design), 49/49 stub tests passing, independently re-verified; NOT yet live-exercised against a real inference backend
metadata:
  type: project
---

implemented 2026-09-21 via two chained `kimi_dispatch`/`kimi_continue` calls
(session `a8a8213c-e355-4137-9036-7aabd4921740`, model k2.8) against the
fully-resolved spec in
`data/tasks/needs-testing/model-batch-test-harness-isolation-and-review.md`.
first dispatch hit its 100-step cap mid-debug (a real phase-transition bug
it had correctly diagnosed but not yet fixed, plus a `StrReplaceFile` call
that silently applied only 1 of 2 edits); `kimi_check_status` reporting
`status=completed` on that first call meant only that the dispatch wire
closed, NOT that the task finished — caught before reporting this done,
resumed with `kimi_continue` to actually finish both fixes.

**independently re-verified, not just trusted from kimi's summary:**
`bin/format-code -c` clean on all 21 new files; re-ran
`bin/test-scripts/test-model-batch-harness.pl` directly — 49/49 passing;
manually grepped both flagged-risky spots — the `backend_acquire` test stub
is a clean `{ acquired => 1 }` (the qw-bug from the first pass is gone), and
the `task_idx >= scalar @$tasks ? 'restore' : 'task_start'` phase decision
is applied consistently at all four advance sites in
`src/coding.model_batch.handler.poll_batch` (normal settle, budget-exceeded
abort, swap-detected, and one more), not just patched around the test.

**what exists now** (see the task doc for full design): content-addressed
blob store (`model_batch.blob.*`, reuses `note.trash.stash`'s xz+base32
pack keyed by BMW filesum checksum instead of ntime), tree manifest +
manifest-diff gate replacing git status/HEAD entirely (`model_batch.
manifest.*`, `model_batch.gate.check`), capture/revert/reverify
(`model_batch.baseline.pack` / `.capture.task` / `.revert.to_baseline` /
`.verify.clean`), the concern-3 store + `coding.model-batch-status` reader,
and the full runner (`coding.model_batch.handler.poll_batch` +
`cmd.model-batch`/`-resume`/`-cancel`) mirroring `coding.model_sweep`'s
cursor/lock/yield/circuit-breaker shape, wired into
`cfg/zenki/coding/subroutines.load-early` + `zenka.v7`. batch trash dir
from the doc's pre-option-D resolution was correctly skipped as redundant
(option D's CAS already makes everything recoverable by checksum) —
flagged by kimi, confirmed correct, not a missed requirement.

**why this sits in `needs-testing/` not `completed/`**: no live exercise
against a running `coding` zenka / real inference backend yet — only the
stub-runtime test (`test-coding-liveness-deferral.pl` pattern) is
verified. per [[feedback-use-format-code-not-perl-c]] and this project's
`completed/` vs `needs-testing/` convention (`6e89af9ba`), that's the
right bucket until someone watches a real `coding.model-batch` run.

**open correctness questions from kimi's own report, worth checking before
or during the first live run:**
1. `:force:` mode + paths already dirty BEFORE the batch's first gate:
   their baseline content was never packed (it left disk before the
   harness ever saw it), so a revert touching one hard-stops with
   `revert-failed` rather than silently losing data — a real gap in the
   doc's "baseline always already stored" claim, only true for clean-mode
   baselines. resolved conservatively (hard stop, recoverable by hand from
   the blob store) rather than guessed at.
2. resume semantics differ by pause class: gate-dirty/reverify-failed
   pauses require `:force:` to resume; budget-exceeded/model-swap pauses
   don't. not sanity-checked against actual intent yet.
3. `model-batch-status` grid keys models by a 12-char checksum prefix;
   an ambiguous prefix in drill-down picks the first match silently.
4. nothing was committed — working tree holds all 21 modules + the test +
   `cfg/model-batches/example-batch.yaml` + the two `cfg/zenki/coding/*`
   registration edits, staged for owner review.

related: [[project-2026-09-20-model-sweep-unresolved-bucket-and-bzpo73q-final]]
(the model-cleanup session that motivated wanting this harness);
`data/tasks/needs-testing/model-batch-test-harness-isolation-and-review.md`
(full spec, including the owner's option-D zero-git design this
implementation follows).

#,,,,,..,,.,,,,,,,.,.,...,.,.,,,,,.,,,,.,,.,.,..,,...,...,...,,,.,,,,,,,,,.,.,
#RODZYFWVBB6OGWBCJLDOPJ3H3DUUHGWR44Q5MALGX4IGQS4AEM6SVAAHHLVPS3TDCZ6ZQCCF7LMS2
#\\\|LVJKVP3A66HHUO4YGK5KPTBJKL4E3G5QUT3DBSGPRYTD7R7ZQOH \ / AMOS7 \ YOURUM ::
#\[7]BCN36WOQJXOQ4DVYHPRPELMNUTYLCZ6O3RYDPYYR7JIMGK6IA4CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
