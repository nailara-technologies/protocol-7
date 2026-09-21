# Topic — model batch harness + self-test seed-restart findings (2026-09-21)

session findings from implementing the model-batch-test harness live and chasing
the "lost" self-test restart protocol. all three fixes committed:
`0a6762348` (raw candidates, filesum warn split, manifest `-r` guard),
`8540de968` (honest context-exhausted reporting, iteration-scorer guard,
module-level submit pipeline), `de8ef5afb` (seed gate covers prompt 3,
verify timer `params`→`data`, prompt 3 mismatch_hint).

## failure classes worth remembering

- **Event.pm silently suspends a repeat watcher on an uncaught callback
  exception** — the zenka keeps running, the cursor/state freezes mid-phase,
  and NOTHING lands in any log buffer. bit us twice in one night: the batch
  runner dying on `<[iteration.score_result]>` (not loaded in the coding
  zenka — `deps/src-used` has no `iteration` namespace; the load-early
  whitelist entry is a FILTER, not a search path), and
  `verify_inference_startup` dying on `undef->{'backend'}` after a
  mis-keyed reschedule. when a timer-driven state machine "just stops",
  fire one tick manually via `p7c coding.eval-code` with a fake
  `w/data` object and catch `$@` — that is how both were caught.
- **`event.add_timer` only forwards `'data'` to `Event->timer`** — a
  reschedule passing `'params'` produces a watcher whose `w->data` is undef;
  the next fire dies (see above). timing-dependent: masked whenever the
  server became ready within the first 10s window.
- **the loader registers `base.*` modules under FLAT names** — invoke
  `<[chk-sum.bmw.filesum]>`, `<[format.inline-nested.encode]>` (house style),
  never `<[base.chk-sum...]>`. `reload source` masks the mistake by
  registering full-name keys for changed files; only a fresh restart exposes
  it (found live 2026-09-21). verify spellings against a booted instance,
  never a reloaded one.
- **cmd modules read the ambient global `$call`, not their argument** —
  calling `coding.cmd.submit` from a timer submits whatever the last command
  dispatch left in `$call` (live: eval-code probe strings became work
  requests). from non-command context, drive the pipeline modules directly
  (`coding.task.intake` → `analyze` → `routing.decide_service` →
  `coding.task.enqueue`).
- **`qw| multi-word |` silently splits** into separate list elements
  (`catfile($dir, qw| new file |)` makes `new/file`). burned once in a test,
  caught by assertion, not code review.

## self-test seed-restart protocol — how it actually works now

- gate: `coding.helper.trigger_backend_self_test` on_done, failure of
  **prompt_id 2 OR 3** (extended 2026-09-21; was prompt-2-only since its
  introduction 2026-07-21 `94fe245d2`). cap `coding.cfg.self_test_seed_retry_max`
  (default 2) per model_id, reset on any clean pass.
- restart is deferred via `coding.handler.defer_seed_restart` until backend
  lock free + queue empty (bounded 120s); a fresh seed derives automatically
  per spawn (`seed=0`, ntime+fortuna) — no forcing needed.
- recovery layers per riddle prompt: local reformat → tier1 round (format
  nudge) → tier1 strict round WITH the Socratic `mismatch_hint` (prompt 3
  gained the hint 2026-09-21; without it `'mouse'` survived both rounds,
  25x content_mismatch in durable stats) → seed restart for persistent misses.
- the perceived "protocol disappeared" was a coverage gap, not a dropped
  feature: prompt 3 (added 2026-08-08 `b73e33876`) was outside the gate, and
  the sharpened mismatch_hint (`c3c5c36a3`, 2026-09-17) drove prompt-2
  content failures to zero (14 fails ever, all empty_answer/transport).

## context-overflow messaging

`coding.async.send_request` fails tasks when generation headroom drops below
1000 tokens; the old message claimed "exceeds n_ctx by 0" even when the
estimate fit. now two honest classes: true overflow (`exceeds n_ctx by N`)
and `context exhausted: estimated X of n_ctx=Y tokens in use, leaving Z for
generation [ below 1000-token floor ]`. same fix in the blocking twin
`coding.task.execute` (`<= 0` gate, clamps to ≥200 and proceeds).

## open thread — batch harness environment blockers

`live-test-1` batch is resumable-paused (`reverify-failed`). reverts cannot
succeed until: (a) the `protocol-7` zenka user can WRITE the tree (taeki-owned
files → permission denied), and (b) the pre-baseline `README.md` drift is
resolved (unrecoverable-by-design under `:force:` — baseline blob never
packed). cleanest reset: `model-batch-cancel` + delete
`state/model_batch/live-test-1/baseline-manifest.yaml` + fresh start after
committing tree state. blob store, records, and gate machinery all verified
working; stub suite `bin/test-scripts/test-model-batch-harness.pl` (49
checks) covers the full cycle.

#,,,,,.,,,..,,,..,,,.,.,.,..,,..,,,.,,,..,..,,..,,...,..,,...,,,,,.,.,,..,.,.,
#6NMX65XUYRVR7QD2CCNWM3QFYDQ7EA7XONEFNDMLBIGCUIKDYKJMDYVUZFFBL4L5CNCFEDTIH5ROE
#\\\|5GWV6QQFHFKXADBKIPYABHCNJSOU36AEB3LA5C3REQFOI67YWG6 \ / AMOS7 \ YOURUM ::
#\[7]HBGFBR6SLK6PJMXMIWELVVGVNFNI34AHWJ5STT2VD3PR5Q3M7QAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

## addendum 2026-09-21 (late) — queue discipline + first real batch

- **orphaned enqueued tasks poison lock releases** : a task enqueued then
  abandoned (routing mismatch) sits in the backend queue; the next release
  dispatches it into whatever window is open (e.g. a respawn dead socket).
  any settle path that abandons a submitted task MUST dequeue it first.
- **routing names live in service-name space** : this deployment routes gpu
  inference as 'single-llm'; send_request maps it to the gpu server key.
  compare in physical-backend key space (`cpu` : everything-else-is-gpu),
  never raw routed_to.
- **batch start drain gate** : refuse while the backend queue non-empty or
  lock held [ committed ca807c1b7 ].
- **owner commits mid-batch drift the tree** -> harness freezes (by design);
  reset = cancel + delete baseline-manifest.yaml + fresh start. do not
  resume a batch whose baseline predates tree commits.
- first real 3-candidate x 2-task batch completed cleanly : verdicts
  completed / error(loop detector) / timeout(budget-exceeded) with wall+tps
  per cell, tree byte-clean, model restored. commits 535b4a584 etc.

#,,..,..,,,..,...,...,.,,,,,.,,,.,,.,,...,,,.,..,,...,...,..,,...,,.,,,.,,,..,
#5BMAASPPILIIV2NYKTOKC36XARP6GHWRGM47FYBDMW23VBMPALLURQQBQZA4QNOUY4G4WT2DI3HCI
#\\\|7ULGTZNGUUHDS3YWHRBM77TXWBGFVPG4OGJOMVHWYEDTZKGZKFN \ / AMOS7 \ YOURUM ::
#\[7]LYTLZFPWXOK3FYGAA75KKKCBLJWMMGH73KNRDIWV3FQ6TRRPRSBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
- tool-layer context for the '1'-byte wipe (2026-09-21): the coding zenka
  tools had a bugfix sweep on 2026-09-16 [ B5FD7886 -- history/diff tools:
  ownership chain, wrapper parser bug, FFI landmine ] after regressions;
  residual tool bugs are a live hypothesis for write anomalies (a model tool
  call writing bare '1' into src/coding.helper.trigger_backend_self_test).
  NOTE: write path ref-handling is guarded [ base.file.write_encoded has an
  explicit SCALAR-ref branch ]; audit the tool handlers themselves first.

#,,,.,..,,..,,,..,,,.,...,.,.,..,,..,,..,,,.,,..,,...,...,.,.,,.,,,.,,,..,,,,,
#YSAV5TRFBJ3Q4NTXEIZQ3HX3D73DFSAFWLWGKQ2DFEV4EDXEJR4YWEASS4GEJL3SCRGQNFZX2ZCCU
#\\\|YDM3J2CR7V62T734M3MOZVAQCORTHJXUNQXJ7LCZOXDE2JIXZXH \ / AMOS7 \ YOURUM ::
#\[7]7PXDQPZNGDWKDJH5DRTDZPABVBTYPK3XTRKIANWY6APBHSEE24BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
