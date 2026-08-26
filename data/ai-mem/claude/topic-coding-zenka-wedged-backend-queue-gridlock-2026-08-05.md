---
name: topic-coding-zenka-wedged-backend-queue-gridlock-2026-08-05
description: coding zenka's task queue gridlocked behind one stuck head-of-line task after verify_inference_startup's 120s fail-open ceiling; root cause traced but not fully pinned, resolved via v7 zenka restart
metadata:
  type: project
---

Three concurrent kimi_dispatch tasks (an SHM-streaming-pipeline implementation
and two archive-file audits) all failed with a 30-minute idle timeout and zero
output on 2026-08-05. Traced live, in order:

1. `coding.dump <task_id>` on the head-of-line task showed
   `state=streaming, round=0, chunk_context={}` for ~93 minutes — the async
   task had been "streaming" the entire time with literally zero bytes ever
   received.
2. Direct health probe against the GPU backend (`curl .../health`,
   `no_proxy=localhost,127.0.0.1` required — the shell env has a proxy that
   otherwise intercepts localhost) showed the backend (`llama-server`,
   `ik_llama.cpp` fork) was fully healthy and **idle** (`slots_processing:0`) —
   ruling out a wedged/deadlocked backend process. If the stuck task's request
   had actually reached the server, `slots_processing` would show it; it
   didn't, meaning the request never left the coding zenka's own async
   dispatch path (`coding.async.send_request`) — exact line not pinned down.
3. Log grep found the actual trigger: `coding.handler.verify_inference_startup`
   has a 120s fail-open ceiling (added 2026-07-31, [[project-coding-self-test-http500-and-hint-fixes-2026-07-31]]-adjacent
   work) — if `<coding.self_test_probe_in_flight>` is still true after 60×2s
   retries, it logs "self-test still in flight after 120s defer ceiling -
   resuming queue anyway" and force-resumes the task queue regardless of
   whether the reasoning-sanity self-test (prompt 2, the open-ended cat/mouse
   riddle designed to trigger a full `<think>` reasoning trace, unlike prompt
   1's trivial one-token arithmetic check) ever actually confirmed the model
   works. The log showed this same 120s-ceiling message firing 3 times across
   2 different sessions before this incident — a recurring pattern, not a
   one-off.
4. **Fix applied**: `p7c v7.restart coding` — restarted the coding zenka
   process itself, NOT the GPU backend (which was healthy, so reloading a 9B
   GGUF model would have wasted time for no reason). Queue drained clean
   (`progress:0, failed:0`), backend re-verified via a fresh self-test cycle on
   a new PID — **both prompts passed cleanly this time**, prompt 2 in 25.56s
   (well under any ceiling), confirming the queue-resume path works correctly
   when self-test actually completes in time.

**Root cause is NOT fully pinned**: since a fresh backend instance passed
self-test cleanly on the identical prompt 2, this doesn't look like a
deterministic bug in the self-test prompts or the async probe path itself —
more likely the specific backend process instance that triggered the 120s
ceiling had gotten into some bad state across the several restarts visible in
that log stretch (possibly GPU/CUDA context degradation, possibly something
else). The exact line in `coding.async.send_request` where a request can go
missing (idle backend + a task stuck at round 0 forever) was never located —
worth chasing if this recurs, since **`verify_inference_startup`'s fail-open
design has no health-check before resuming the queue past its 120s ceiling**
— it only checks `kill 0, $pid` + `status eq 'ready'`, neither of which
detects a backend that's alive but not actually able to serve. A real fix
would add a short-timeout health probe (like the one used to diagnose this
live) inside that 120s-ceiling branch before declaring the queue safe to
resume, and route a failed probe into the existing `restart_count`/`failed`
path instead of "resuming queue anyway."

**How to apply**: if kimi_dispatch/coding-zenka tasks go silent with zero
output again, check `coding.dump <task_id>` for `chunk_context={}` at
round 0 first (cheap, immediate signal), then probe the backend directly
(`no_proxy=localhost,127.0.0.1 curl .../health`) before assuming the model
itself is slow — an idle-but-healthy backend with a permanently-stuck task
means the gridlock is in the zenka's dispatch path or the verify/self-test
gate, not the model. `v7.restart coding` is a safe, fast, non-destructive fix
that doesn't touch the (possibly perfectly fine) backend process.

## related

[[topic-coding-self-test-http500-and-hint-fixes-2026-07-31]] — the prior,
now-fixed bug in the same neighborhood (LWP inactivity-timeout mid-generation
surfacing as http_500); this incident is a different failure mode in the same
subsystem, post-fix.

**UPDATE 2026-08-19 — the exact line IS found and fixed, see
[[bug-coding-async-send-request-enqueue-round-timer-mismatch]]**: a
DIFFERENT stuck task (jobsite assessment, task stuck at `round=0` for 2.5+
hours, `chunks_received=0`) traced to `coding.async.send_request`'s
`queue_paused` branch (the exact spot flagged as unlocated on 2026-08-05) —
it armed its 5s retry via `event.add_timer` with a `'params'` key
`base.event.add_timer` never reads, targeting `coding.task.enqueue_round`
as if it were a timer-handler when every other call site invokes it
directly with positional args (`my ($task_id, $round) = @ARG`). Any task
retried while `queue_paused` was set got silently dropped forever after
one reschedule attempt — this is the general mechanism, not specific to
this incident's `verify_inference_startup` 120s-ceiling trigger. Live
devmod test (`coding.set coding.task.queue_paused 1`, then
`eval-code $code{'coding.async.send_request'}->('<task_id>')`, watch the
log) confirmed the fix: the reschedule loop now correctly repeats every 5s
instead of dying after one shot, and resumes cleanly once unpaused.
`verify_inference_startup`'s fail-open design (still no health-check before
its 120s ceiling) is unrelated and still stands as a separate, lower-value
improvement if this recurs.

#,,..,,.,,,.,,,,,,,.,,.,,,,..,..,,..,,,.,,.,.,..,,...,...,.,,,,.,,.,.,,,,,...,
#NDZSWBITFUNICI4SV7QBOBOANFKF4ALKJ3PZF5TUTFRVFMNERYZSNESVMMDIQP7MWM5DDJFY4JSM4
#\\\|TSNSKMBKSWLIFNDF6ACXVR2IPNGK4O7A5YPRD2R7HZSF4EDHUB4 \ / AMOS7 \ YOURUM ::
#\[7]ZAQGCMZBPY7UELUWWJ4ODEZU35AQXUMRSFSBCUZXMZY7LCTFVQBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
