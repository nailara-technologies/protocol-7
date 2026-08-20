---
name: coding-self-test-async-transport-2026-07-31
description: coding zenka self-test converted from blocking LWP client to async SSE transport; step-1 gate CONFIRMED stream:true kills http_500s; full state-machine rewrite landed + verified live
metadata:
  type: project
---

Session 2026-07-31 (kimi, afk): implemented
`data/tasks/coding-self-test-async-http-client-rewrite.md` end-to-end.
Background: `data/ai-mem/claude/topic-coding-self-test-http500-and-hint-fixes-2026-07-31.md`.

## step-1 gate result [ the load-bearing finding ]

- Flipped `coding.tools.http_inference_client` to `stream => JSON::PP::true`
  with synchronous SSE accumulation in an LWP `:content_cb`, plus a hand-enforced
  wall-clock deadline (`die` in the callback; LWP's own timeout is INACTIVITY
  and can never fire while streaming).
- **LWP 6.83 gotcha verified live**: `die` inside `:content_cb` does NOT
  propagate — LWP swallows it into the `X-Died` response header and can still
  report `is_success` with partial content. Must check `X-Died` after `->post`
  and rethrow (done; maps to `request_failed`).
- **Gate: CONFIRMED.** Across 3 full readiness self-test cycles: zero
  `http_500`. The old 500s were LWP's inactivity-timeout disconnect surfacing
  server-side as cancelled-task 500. Failures changed class to (a) genuine
  >90s cold/long generation hitting the settled 90s ceiling [ do NOT tune —
  settled ], (b) genuine wrong answers. Streaming alone was the 500 fix;
  steps 2-6 were hygiene (event-loop-freeze risk), done deliberately.

## what was built

- `coding.self_test.async_probe` [new] — one non-blocking SSE probe via
  `coding.async.http_client` directly (task-queue bypass, `task_id => ''`
  degrades shared handlers to no-ops). Own minimal delta accumulator, `<think>`
  stripping identical to http_inference_client, error translation
  `HTTP error: <code>` → `http_<code>` else `request_failed`. `$settled` guard;
  releases backend lock in `$finish` on every terminal path.
- `coding.self_test.handler.poll_probe` [new] — 0.5s timer state machine,
  poll_switch-style: gap → probe → evaluate → record → done (+1200s watchdog;
  watchdog synthesizes on_error through the probe's own pipeline so the lock
  is always released). Backend lock: acquire ONLY when free, never enqueue
  (queued pseudo-id would be handed to send_request by backend_release).
  1.5s inter-prompt gap as `gap_until` timestamp, never a sleep. Retry-once on
  5xx/request_failed with 0.5s backoff, same class match as before.
- `coding.self_test.run` — now only STARTS the test: requires `on_done`
  coderef, `<coding.self_test_probe_in_flight>` idempotency guard, returns
  `{ mode => 'deferred' }`; result delivered to continuation with the same
  shape as the old sync return.
- `coding.self_test.evaluate` — step API (`step => init|tier1_done`),
  transport-free. tier0 sync unchanged; `$content_already_correct` guard,
  `$base_hint`/`$strict_hint`/`$with_mismatch_hint`, `@attempts` bookkeeping
  carried across verbatim. Final eval payloads byte-identical in shape.
- `coding.handler.monitor_inference_startup` [6a] — cat-fail/seed-retry
  decision moved into `on_done` (re-fetch server + pid staleness bail);
  dependency reset + jobqueue.check_dependencies + watcher cancel still run
  IMMEDIATELY. New `coding.handler.defer_seed_restart` [new] defers the
  respawn while backend lock held / queue non-empty (2s × 120s ceiling,
  stale-pid abandon).
- `coding.self_test.cmd.self-test-run` [6b] — already-loaded fast path now
  deferred-reply (`reply_id` + `base.callback.cmd_reply`), run-refusal falls
  back to an immediate formatted failure.
- `coding.self_test.handler.poll_switch` [6c] — new `testing` phase:
  switch→ready starts async run, `on_done` stores result + initiates restore
  (guarded on phase still == testing); testing has own max_wait window,
  timeout falls through to restore with `$state->{'error'}`.
  `$start_restore` helper dedups the restore-initiation block.
- Registered in `cfg/zenki/coding/subroutines.load-early` via
  `bin/dev/gen-sub-whitelist coding`.

## verified live [ one restart-and-observe per step ]

- async_probe standalone: `mode=true data=[91] finish=stop reasoning=215`,
  lock acquired+released, queue empty.
- full async run: 2/2 pass; **heart 0.0012s DURING an in-flight probe**
  (was: whole zenka frozen for the request duration).
- `$content_already_correct` guard confirmed live for the first time:
  verbose correct answer got pure format hint, no mismatch challenge.
- 6a: readiness → cat-fail → seed-retry decision in callback → defer handler
  → respawn → re-test → … → "giving up after 2 seed retries" — whole tree OK.
- 6b: `p7c coding.self-test-run` → real deferred reply (no hang, no HASH()).
- 6c: `p7c coding.self-test-run SJCPFAQ:AGKY7YQ` → full
  switch→test→callback-restore→tier2-judge→reply round trip, 2/2 after
  tier2 YES verdict. All state hashes empty afterwards.

## cold-boot confirmation [ final, same session ]

After a final `v7.restart coding` with ALL modules loading from disk [ no
runtime-loading involved ] : clean compile, auto-cycle ran the full
cat-fail -> defer -> respawn -> 2/2 PASS chain [ fresh seed ], heart
0.0012s mid-probe, 6b refusal branch [ "self-test already in progress" ]
and a real deferred-reply run [ 2/2 ] both from disk, and all runtime
state drained [ switch/probe flags 0, state hashes empty, seed-retry
counter reset ].

## left for the user

- `bin/Protocol-7 sourcecode update-signatures` needs the passphrase key —
  not possible afk. Files edited: the 6 modules above + 3 new + load-early.
  Also `./bin/dev/update-version` + commit deliberately left undone.
- `/tmp/p7mod_syntax_check.pl` — ad-hoc module syntax checker (preprocesses
  `<[sub]>`/`<var>`/signature blocks, then perl -c). Worth adopting into bin/dev.
- ZDMAPAY cat test currently fails on >90s generation right after cold spawn
  (chunks flowing the whole time — model/seed behavior, not transport;
  warm runs pass in ~18s). Settled: 90s stays.
- `follow_up` + `tier2_judge` still use the blocking client — deliberately
  out of scope (post-test disposition path), separate lower-value task.

#,,,,,.,,,...,...,,,.,..,,..,,,.,,,..,,..,,,,,..,,...,..,,...,..,,,,,,,,,,,..,
#VPPDEGP32WEVP6WHCRV2CU3O4Z6G4Q6PDDJVR6TDP2YORYU745FOS3LYKHE4XQG5AGX224OWN4622
#\\\|IIHP65JJ3KDWCJHQDCCOBLHSWANZE5CEF7ZLWUQW2VIUR3VTAA3 \ / AMOS7 \ YOURUM ::
#\[7]XMB73SU4QD4BBSYV2ZWB3GVMUDELXI6AXIUIJRT3CL7CXCADG4BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
