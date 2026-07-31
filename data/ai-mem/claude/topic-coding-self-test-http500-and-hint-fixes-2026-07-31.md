---
name: coding-self-test-http500-and-hint-fixes-2026-07-31
description: coding zenka cat-riddle self-test — spurious-pass bug, restart-race dedup, riddle wording redesign, mismatch_hint content-correctness guard, server-tail diagnostic, open http_500/timeout question
metadata:
  type: project
---

Session 2026-07-31 on `base` branch: long back-and-forth debugging the coding zenka's
`ZDMAPAY:AR3OCKQ` (Qwopus3.5 9B v3) self-test cycle (`coding.self_test.*`), triggered by the
cat/mouse "cat-test" (prompt_id 2) failing and looping the seed-retry/restart cycle. Many small
bugs found and fixed along the way; one real architecture question left open at context limit.

## Fixed, staged/committed (verify before trusting the file list — signing happened live,
## piecemeal, across many small edits)

- **`coding.handler.verify_inference_startup`**: idempotency guard (`verify_confirmed_pid`) —
  multiple restart paths (`spawn_servers_deferred`, `inference_crash_restart`, `http_error`'s
  restart) each scheduled their own 10s fallback verify timer with no cancellation of earlier
  ones. Stacked restarts (eg seed-retry loop) caused the same pid to get "verified ready" +
  "task queue resumed" logged/executed multiple times.
- **`coding.spawn_inference_server`**: bounded reap poll (~3s, WNOHANG-polled, NOT a blocking
  `waitpid`) after killing the old server's process group — an *unbounded* blocking `waitpid`
  was tried first and **hung the entire zenka event loop** when the old process was slow to
  release its CUDA context (confirmed live: unresponsive to `coding.heart`, session stayed
  connected but nothing processed). Bounded polling balances the real VRAM-release race
  (nvidia-smi sanity check right after kill can false-positive "insufficient vram" if the old
  process isn't reaped yet) against not risking a permanent wedge. Also: orphan-pid-file scan
  now skips a pid already handled by the in-memory group-kill (was causing a double-kill/
  double-log for the same pid); `fuser -n tcp $port`'s stderr header line was leaking
  uncolorized straight to the terminal (fuser writes PIDs to stdout, the `<port>/tcp:` header to
  stderr) — fixed via `base.stderr_redir`/`base.stderr_restore` (the project's existing pair,
  same one `image2html.child.init_code`/`melt.init_code` use — NOT a hand-rolled dup/restore;
  first attempt at that broke with a real Perl gotcha, `open(my $x,...) or undef $x` doesn't see
  `$x` on the right side of `or` in the same statement).
- **`base.handler.session_error`**: guards against `$_[0]->w->data` (session id) being undef for
  some exception-watcher paths — was producing "parameter 2 not defined", "undef value $id in
  hash element", and "shutdown() on closed socket" warning cascade on certain disconnects (eg
  during a coding zenka restart). Now logs `%s`/`'unknown'` instead of `%d`, guards the session
  hash lookup on `defined $id`, and only calls `shutdown`/`close` if `fileno($fd)` shows the fd
  is still actually open.
- **`coding.self_test.run`**: `evaluate` was being called even when the *initial* inference call
  outright failed (eg `http_500`) — ran tier1 reformat against an EMPTY prior answer, which could
  fluke a standalone correct answer back and report a spurious PASS for a prompt that never got a
  real reply (confirmed live: `"tier1 reformat PASS :  -> cat"` straight off an http_500, `2/2
  passed` when only 1 prompt actually ran). Now hard-fails immediately when the initial call
  didn't succeed, skipping `evaluate` entirely. Also added a 1.5s `<[base.sleep]>` gap before
  prompt 2 (self-test is the only caller that fires two requests back-to-back with zero gap;
  suspected — and partially confirmed — cause of http_500s that never occur during normal
  session use).
- **`coding.self_test.evaluate`**: tier1's own reformat inference call now retries once on a
  transient 5xx (previously had no retry at all, unlike the initial call — a substantively
  CORRECT answer that only needed word-count compression was being thrown away as a hard FAIL
  purely because the *follow-up* call hit a transient 500). **Also**: `mismatch_hint` (see
  below) was being appended to EVERY tier1 attempt regardless of whether the original answer's
  *content* was actually wrong — confirmed live, it second-guessed an already-correct verbose
  answer ("The cat. Because it ate the mouse.") during pure word-count compression and flipped
  it to a wrong reformatted answer. Added `$content_already_correct` (checks independently
  whether the original answer already contains every `must_contain` token, since tier0's
  word_count check short-circuits on `over_word_limit` *before* ever testing `must_contain`, so
  `structural_reason` alone can't distinguish "wrong content" from "right content, wrong
  format") — `with_mismatch_hint` now skips the challenge hint entirely when content is already
  right. **Not yet verified live** — this was the last change made before running low on
  context.
- **Server-output visibility for http_500s**: previously *zero* server-side context was ever
  visible for a self-test http_500 — once `ready`, a server's stdout/stderr are only drained to
  prevent pipe-blocking (`coding.handler.drain_pipe`), never retained. New
  `coding.self_test.helper.capture_server_tail` does a direct non-blocking `sysread` on the
  backend's `io_stdout`/`io_stderr` pipes (already opened non-blocking at spawn time,
  specifically for this reason) right when a 500 is detected — bypassing the event-loop
  dependency entirely, since the bytes are already sitting in the OS pipe buffer regardless of
  whether `drain_pipe`'s watcher has had a turn yet. First attempt (reading
  `$srv->{tail_output}` populated by `drain_pipe`) was empty every time because
  `http_inference_client`'s blocking LWP call never yields to the event loop, so `drain_pipe`
  never got a chance to run *during* the failure — this was the actual fix. Output truncated via
  `base.parser.ellipse_center` (800 chars) before ever hitting a log line or the archived record
  (llama-server's own cache/checkpoint chatter can run to several KB per request).
- **New command `coding.self-test-detail [model_id]`**
  (`coding.self_test.cmd.self-test-detail`, registered in `configuration/zenki/coding/start` +
  `subroutines.load-early`): shows full per-prompt detail — question, answer vs expected, tier,
  every tier1 attempt's exact hint text + response, and (new) server-tail output on failure.
  Needed because `coding.self_test.archive` previously overwrote its flat top-level fields on
  every prompt within an epoch (prompt 1's detail got clobbered by prompt 2's) — now also stores
  a `prompts` hash keyed by `prompt_id` alongside the unchanged flat fields (back-compat with
  `self-test-status`).
- **Riddle prompt redesign** (`coding.self_test.run`, prompt_id 2): dropped the `"reply with only
  the animal name"` trailing instruction — confirmed live it was suppressing this reasoning
  model's `<think>` pass into a pattern-matched guess (empty `answer`, huge `ttft`, all budget
  spent on reasoning with `finish_reason` never reaching content — see `max_tokens` note below).
  Per `data/tasks/completed/coding-model-self-test-cycle.md`, the original design never had this
  instruction and *explicitly* expected substantively-correct-but-verbose answers ("the cat is
  the remaining animal" not "cat") to be handled by tier1's reformat step, not suppressed at the
  source. `"who is the remaining animal?"` itself was deliberately kept as-is — do NOT reword to
  "which animal is still alive" or similar; it's a recurring intentional motif across
  `data/md/design/NETWORK-RESOURCE-TOKEN-ARCHITECTURE.md` ("the remaining animal: the cat.
  always the cat.") and other design docs, not an accidental ambiguity.
- **`mismatch_hint`** (tier1 follow-up-only, never in the base prompt): went through two
  wordings — a longer explanatory one ("Consider: when one animal eats the other...") confirmed
  live to do nothing (model just reformats "mouse" to "mouse" again), then a shorter Socratic one
  ("Are you certain? \"Remaining\" can only be one, by definition.") — **also confirmed live to
  not reliably correct a genuine wrong answer** once the model has committed to "mouse" in its
  own reasoning trace. This is now understood as expected — the test's whole point is
  seed-to-seed reasoning-coherence variance, not something a tier1 nudge should paper over. tier1
  is structurally a format-restate step; the model treats anything appended there as another
  format instruction, not an invitation to actually reconsider.
- **`coding.tools.http_inference_client`**: now captures the reasoning trace (either a separate
  `reasoning_content` field or inline `<think>...</think>` stripped from `content`, matching the
  pattern `coding.async.chunk_handler` already uses for the streaming path) and `finish_reason`,
  returned alongside `data`. `max_tokens` bumped 1024→4096 for self-test's initial call
  specifically (comment at `coding.tools.http_inference_client:11-14` already documented the
  128-was-too-low version of this exact bug from 2026-06-21 — recurred at a higher budget once
  the terseness instruction was dropped and reasoning got deeper).

## Open / unresolved at context limit

- **`http_500` root cause is still not fully nailed down.** Confirmed NOT simply "context size
  too large" (an earlier session had reduced 37777→35777 to "fix" it, but that was likely just
  dodging the *real* cause below). Confirmed the self-test's request-spacing (1.5s gap) and the
  spurious-pass bug were real, separate issues, now fixed. But raising the client timeout alone
  (30→60→90→120→240, tested live at each step) never fully eliminated it — one run passed clean
  at `ttft=69.27s` while another still 500'd past 120s in the same session, meaning **duration
  alone doesn't explain it**. Leading hypothesis (from advisor consult, not yet tested): the
  proven-stable async path (`coding.async.http_client`, used for real task inference) sends
  `stream: true` and defends with a **stall/idle timeout** (77s, resets on each chunk) rather
  than a flat total-duration timeout — because streaming keeps bytes trickling in, no single
  silent gap gets long. Self-test's client uses `stream: false` (one silent read for the whole
  generation), so it may be hitting some silence/idle cutoff (server-side or network-side,
  independent of total duration) that streaming would avoid. **Next step, if picked back up**:
  test switching just the request body to `stream: true` in `coding.tools.http_inference_client`
  and read/accumulate the SSE response synchronously (still blocking, no event-loop conversion) —
  before considering the much bigger rewrite below.
- **Considered and explicitly rejected (for now)**: converting self-test to use the real async
  path (`coding.async.request`/`coding.async.http_client`) instead of the blocking
  `coding.tools.http_inference_client`. User initially asked for this after realizing the
  blocking-LWP design mismatch (self-test can block the zenka's entire event loop for the whole
  timeout duration — confirmed dangerous once, when an *unbounded* `waitpid` did this for real,
  see `coding.spawn_inference_server` fix above). Advisor-consulted before starting: the actual
  scope is much bigger than "swap the client" — it's a protocol change (blocking JSON response →
  SSE streaming) plus three call-site inversions (`coding.self_test.run`,
  `coding.self_test.evaluate`'s tier1 reformat, `coding.handler.monitor_inference_startup`'s
  decision logic, `coding.self_test.cmd.self-test-run`'s reply path — all currently
  direct-return, would need to become callback/continuation-style). Recommended testing the
  `stream: true` hypothesis first since it might explain the actual problem without the rewrite.
  Not started. If a future session decides to do it anyway: heartbeat/restart is confirmed NOT
  enabled for ondemand zenki yet (see below), so the blocking-freeze risk is currently inert, not
  urgent — but will become live once ondemand heartbeat support lands.
- **`$content_already_correct` guard in `coding.self_test.evaluate`** (prevents `mismatch_hint`
  from being appended to a pure format-compression reformat) — implemented, believed correct,
  **not yet exercised live**. Next restart-and-fail cycle where the original answer already
  contains "cat" but is over the word limit should confirm it no longer flips to wrong.
- **Timeout currently 90s** (`coding.self_test.run` + `coding.self_test.evaluate` defaults) — a
  deliberately-chosen middle ground, not a converged-on value. Don't read "90" as anything more
  than "not obviously too short, not needlessly long given the real fix is probably elsewhere."
- **Confirmed**: heartbeat/restart is not enabled for on-demand zenki yet (why the coding zenka
  can go fully unresponsive without v7 restarting it — this is BOTH why the `waitpid` hang was
  bad [nothing would recover it] and why blocking timeouts aren't an *active* supervisor-conflict
  hazard today).

## Files touched this session (for reference, not all may be staged/committed by session end)

`coding.handler.verify_inference_startup`, `coding.spawn_inference_server`,
`base.handler.session_error`, `coding.self_test.run`, `coding.self_test.evaluate`,
`coding.self_test.archive`, `coding.self_test.cmd.self-test-detail` (new),
`coding.self_test.helper.capture_server_tail` (new), `coding.tools.http_inference_client`,
`coding.handler.drain_pipe`, `coding.handler.monitor_inference_startup` (passes `backend` through
to `self_test.run`), `configuration/zenki/coding/start`,
`configuration/zenki/coding/subroutines.load-early`.

#,,..,.,.,..,,,.,,,,.,...,.,.,.,.,,,.,,,.,,..,..,,...,...,...,...,,,,,,,.,...,
#X4HRSHC2JIX2MYW2N2VXW2IFNXPX2Q3M5ANYO7J7EDSEYGVWZUGQRTDQQL7PV5WJXX2XWYBPNZJZK
#\\\|OR2JQSVCZAODVXWSDBP4CEBRZVJW2TFCHAYNMBBYDMPEZ3N6OQB \ / AMOS7 \ YOURUM ::
#\[7]UCCQ2NXAWATTRGOK4LRCRN2MI3MZPF5TAZSZ57V2KPP2OQ4QUYCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
