---
name: coding-zenka-improvement-pipeline
description: root index for the coding zenka self-test/self-error/change-accounting pipeline; check here first for tier status before resuming this work
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0167cea8-7299-4bd1-b3b4-a507800e7687
---

File: `data/md/design/CODING-ZENKA-IMPROVEMENT-PIPELINE-INDEX.md`

Tier status as of last update (re-check the index file itself, this is
a point-in-time snapshot):
- tier 0 (LANDED): X-11 WM.update fix; coding.self_test.* core +
  http_inference_client — all confirmed live.
- tier 1 (DONE): switch-to-non-loaded-model + restore, async state
  machine, live-confirmed 2026-06-21.
- tier 1.5 (DONE): task-level model pinning (`:model:CHECKSUM:`).
- tier 2 (NOT READY): self-error-processing-cycle — 3 open decisions.
- tier 3 (GATED): change-accounting architecture.

**LANDED, commit `2bdc09631`** (was uncommitted as of 2026-06-21 handover;
confirmed committed by 2026-07-17): generic `result_constraint` + tiered
escalation (tier-0/1/2).

`src/coding.self_test.check_constraint` (round 1, tier-0 structural
checker) is already **COMMITTED as `a54280245`**.

All remaining files for this feature are **signed + staged by the user
right now** (confirmed via `git status --short` showing all `M`/`A`
with zero unstaged diff) — committing only awaits a clean final live
verification round, not a sign-off blocker:
- `src/coding.self_test.run` (M) — 2 calibration prompts now carry
  `result_constraint` (numeric/word_count types).
- `src/coding.self_test.evaluate` (M) — tier-0 check, then **tier-1
  reformat with up to TWO attempts**: attempt 1 uses a generic
  constraint-type hint; if it fails, attempt 2 uses a STRICTER hint
  built only from the constraint type + the prior violation (e.g. "you
  used 56 words, limit is 2") — **never from the expected answer**,
  scope explicitly confirmed with user 2026-06-21. Returns
  `needs_tier2=>TRUE` only if both attempts fail.
- `src/coding.self_test.apply_tier2` (NEW) — judges deferred
  `needs_tier2` results, re-archives, falls through to existing
  `follow_up` anomaly explainer on NO/ambiguous.
- `src/coding.self_test.tier2_judge` (NEW) — fresh one-shot YES/NO
  semantic judgment via `http_inference_client`; degrades to
  `verdict=>'ambiguous'` on inference failure (load-bearing for the fix
  below — never throws).
- `src/coding.self_test.cmd.self-test-run` (M) — no-switch fast
  path: same model judges its own deferred tier2 results in a fresh
  context.
- `src/coding.self_test.handler.poll_switch` (M) — cross-model
  case: tier-2 dispatch factored into a shared `$apply_pending_tier2`
  closure, called from **BOTH** the restore-success branch AND the
  restore-timeout/crash branch (this second call site is a same-session
  bugfix, see below).
- `cfg/zenki/coding/start` (M) — added
  `coding.cfg.switch_model_max_wait = 300` (was hardcoded 120).

**Real bug found+fixed same session**: `poll_switch`'s tier-2 dispatch
originally only ran in the restore-SUCCESS branch. If the restore timed
out (which it did, repeatedly, live), the deferred tier-2 judgment for
the just-tested model was silently dropped — `finish()` returned a
failure reply without ever reaching the tier2 block. Fixed by factoring
dispatch into `$apply_pending_tier2`, called from both branches;
`tier2_judge`/`apply_tier2` already degrade gracefully on a failed
inference call, so calling it even when the restore itself isn't
confirmed ready is safe. **Confirmed live 2026-06-21**: a restore that
hit `timeout` still logged `[poll_switch] tier2 : IXNBXVI:U2XBEXQ
judging 1 deferred result(s) for DVEAZIA:GPAKBLA` — dispatch fires
correctly. (The verdict outcome itself wasn't captured that run because
the user's manual v7/swap restart interrupted it mid-judgment — that's
an infra interruption, not a code bug.)

**Live verification status at this handover**: tier-0 and tier-1
(single-attempt) both confirmed firing correctly earlier in the
session, against real DVEAZIA verbose answers (cat/mouse riddle,
"## Solution... 91" style answers). The timeout-path tier2 dispatch fix
is confirmed firing (see above). **The tier-1 TWO-ATTEMPT retry (just
added) has NOT yet been exercised live** — the last 2-3 attempts to
re-run `p7c coding.self-test-run DVEAZIA:GPAKBLA` all hit a
switch/restore TIMEOUT before DVEAZIA's self-test even got to run (this
WSL system's model loads from `/mnt/ext-xfs-data` are intermittently
*very* slow — single loads have taken anywhere from ~15s to ~7 minutes
in the same session, even after the user did a swap thrash fix
`swapoff -a; swapon -a` mid-session). [[topic-model-load-time-statistics]]

**NEXT SESSION / NEXT STEPS** (in order):
1. Re-run `p7c coding.self-test-run DVEAZIA:GPAKBLA` (background it,
   poll via `p7c coding.self-test-status` + tail of
   `/dev/shm/.7/STDOUT/NIW7OAQ` — note: this log file's permissions
   have been flapping root/taeki-owned during this session's manual
   restarts, check `ls -la` first).
2. Look for `[self_test] tier1 reformat attempt 1 failed` followed by
   either a tier1 PASS (retry worked) or escalation to tier2 (already
   verified working). Confirm the constraint-violation-only stricter
   hint doesn't leak `expected` — re-read the hint text in the log if
   visible.
3. Once a clean DVEAZIA cycle completes end-to-end without an
   infra-induced switch/restore timeout swallowing the test, report to
   user and ask for final go-ahead to `git commit` (all 17 files are
   ALREADY signed+staged — do not re-stage, do not amend, do not push).
4. If switch/restore timeouts keep preventing a clean live run despite
   retries, that itself is evidence for prioritizing
   [[topic-model-load-time-statistics]] (adaptive per-model timeout)
   sooner rather than later — flag this tradeoff to the user rather
   than just retrying indefinitely.

[[resonance-field-emergence]]

## Active: task-zenka summary topic tree (started + phase 1 landed 2026-06-21)

See [[topic-summary-tree-phase1]] for full detail — architecture, three real
bugs found+fixed live, two known limitations. Design doc:
`data/tasks/task-summary-topic-tree.md`. Phase 1 committed (661d225bc); the
BMW-L13 checksum switch on top is also **LANDED, commit `932a539b8`**.

Read [[topic-summary-tree-phase1]] before touching this area again — don't
re-derive the architecture or re-hit the same bugs.

#,,,.,,.,,.,.,.,.,..,,,,.,...,.,.,,,.,.,,,,,,,..,,...,...,,..,,.,,.,.,,..,.,.,
#HRKOIWG5IBAPT5LPMGEUWJW3RTJ5A32EPAWYOQ35YBOQML75LMESU7N3QPEK33OYW7ZOHNNXEDAUQ
#\\\|JNEGJGY4ZDXVUUAZJIJK56B2RUTYLDRALWW65LMQZAUPLDJOF56 \ / AMOS7 \ YOURUM ::
#\[7]KZELSIDAVRVBNOCWM23UUTUULG2UL57EHUECQCQVUA7DPRUCZGDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
