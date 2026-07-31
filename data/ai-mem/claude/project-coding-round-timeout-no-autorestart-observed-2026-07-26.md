---
name: project-coding-round-timeout-no-autorestart-observed-2026-07-26
description: "RESOLVED 2026-07-31 (for real this time) -- coding-zenka round 9340727's apparent 175%-of-ceiling hang was a reasoning-only stream (no finish_reason) falling into http_complete's dead 'clean close after N bytes processed' no-op branch, exactly as first diagnosed. A mid-investigation 'refutation' of that diagnosis was itself wrong -- based on a substring grep that didn't isolate the log's level field, when the real issue was that this logfile's verbosity is 1 and NEVER records level-2 lines at all, so the absence of that log string was not evidence the branch didn't fire. Live tracer + reproduced incident confirmed the original theory correctly; no exception, no timeout-system bug. Fix: bounded answer-nudge retry (not reasoning-trace injection), then visible failure. Staged and signed."
metadata:
  node_type: memory
  type: project
  originSessionId: 16c8ce74-d9e2-429d-bafb-25fae9c0c30f
  modified: 2026-07-31
---

**Original observation (2026-07-26)**: `coding.round-progress` climbed to
175% of its displayed 777s ceiling (task `9340727`), no auto-restart,
manually aborted.

**First pass, 2026-07-31**: read the real log
(`/var/log/protocol-7/DESKTOP-FP4OP26.coding.zenka.log`, decoded via
`base.ntime.B32_2_unix` — pass the full B32 token, a truncated substring
fails validation harmlessly). Found the HTTP round actually completed in
69s with a 421KB pure-reasoning response and `finish=undef`. Correctly
diagnosed: `coding.callback.http_complete`'s streaming-branch falls into
the `elsif (($http_state->{'bytes_received'} // 0) > 0)` "clean close
after N bytes processed" no-op (verbosity 2) because it never checks
`chunk_context->{'reasoning'}` — task orphans in `sm_state='streaming'`
forever, no timer left.

**Self-inflicted detour**: tried to confirm this via
`grep -ac ' 2 ' $LOG` (2449 hits) as "proof level-2 logging generally
works in this file," then grepped for the specific sub-branch log
strings and got zero hits for any task ever — concluded the no-op branch
theory was **refuted** and redirected to a "find the real mechanism,
maybe an uncaught exception" investigation.

**That refutation was invalid, and here's the exact methodological
mistake, worth remembering**: `grep -ac ' 2 '` matches the **literal
substring " 2 " anywhere in the line** — timestamps, byte counts, "2
chunks", etc. — not the log format's actual level field (`<id> <pid>
<level> <message>`). It never actually checked whether level-2 messages
specifically reach this logfile. The real, correctly-verified fact
(confirmed by the K3 dispatch via `awk '{print $3}' $LOG | sort | uniq
-c` across the full ~396K-line log): **zero level-2 lines exist in this
logfile's entire history** — `logfile_v=1`, and level-2 messages
structurally never get written to it. So the absence of the "clean
close" log string was never evidence the branch didn't fire — it's
exactly what you'd see whether it fired or not. This is the same class
of mistake as `feedback-combined-grep-conflated-caller-counts.md`: a
crude substring grep standing in for a field-aware check, producing a
confident-sounding but wrong conclusion. **Always anchor on the actual
field structure (`^id pid level message`) when grep-verifying a log
claim like this, not a bare substring.**

**Final resolution, confirmed live via K3 dispatch
(`data/tasks/coding-http-complete-reasoning-only-silent-death.md`,
`kimi-code/k3-256k`)**: wrapped the real `%code` entry with an
enter/exit/`$@` tracer via `coding.eval-code`, stood up a mock SSE
server streaming 120KB of `reasoning_content` deltas then closing
without `finish_reason`, and drove it through the **real**
`coding.async.request → http_client → http_io EOF → on_complete` path
(not a bypassed unit-test shortcut). Result: **clean function exit, no
exception** —

```
http_complete: task-DIAG002 sm_state=streaming seq=1/1 finish=undef tools=0 bytes=124356 chunks=60
http_complete: task task-DIAG002 clean close after 124356 bytes processed   ← THE BRANCH (level 2, confirmed firing)
backend_release: task-DIAG002 released cpu lock
DIAG-TRACE: http_complete exit clean task=task-DIAG002
```

The original diagnosis was correct. The "uncaught exception in an
un-eval'd callback" theory (my second-pass replacement guess) is now
**refuted** with live tracer evidence — there's no exception anywhere in
this path.

**Fix, staged and signed**: bounded "answer-nudge" retry, mirroring
`chunk_handler`'s own unparseable-tool-call retry discipline —
`coding.cfg.reasoning_only_retry_max` (default 2). On a reasoning-only
close: push a short user-role nudge message (NOT the reasoning trace
itself — confirmed the existing content-branch retry path also never
injects raw content into `messages`, only a nudge/re-send), increment
round, re-enqueue. After retries exhausted, transition to a visible
`error` state via `state_machine` instead of vanishing.

**Live-verified, both directions**:
- DIAG003 (reasoning-only, retries exhausted): `enqueue_round: task-DIAG003
  round=2 [backend cpu: acquired]` → after 2 nudge attempts,
  `http_complete: task-DIAG003 reasoning-only close persisted across 2
  nudges : failing task` → `async.state_machine: task task-DIAG003
  streaming --error→ error` → `async.complete: task task-DIAG003 failed:
  model closed stream with reasoning-... [ answer-nudge retries
  exhausted ]` — bounded, visible failure instead of an infinite silent
  hang.
- DIAG004 (normal path, real `finish_reason`): `async.state_machine: task
  task-DIAG004 streaming --finish_stop→ complete` →
  `backend_release`/`task completed`/`task result saved to disk` — no
  regression.

Dispatch cleaned up fully after itself: tracer wrapper removed via
`coding.reload source`, `<system.zenka.verbosity.logfile>` restored to
1, `<inference.backend.cpu.port>` restored to 8001, all DIAG task/state
entries deleted, mock server killed, backend locks all clear.

## related

[[topic-coding-round-timeout-adaptive]] — the escalation system this was
never about; still correctly designed and un-regressed.
[[project-2026-07-30-gap-audit]] — tracked this as an open item, now
closed.

#,,..,.,.,,.,,,..,,,,,,,,,,..,...,.,.,,..,.,,,.,.,...,...,...,..,,,,,,..,,,.,,
#QWSJDBGQ323AFVGFHX4WHK6TP2FKFNVBLTED4VH2N3MPMF3CTGPNVMUDOICZNRET5D3EMQJBFJ2R4
#\\\|ZLCNFDPMWXD4SHFHLNPDON5BRHBN4XQI323VXJKSZ2APEMYU2ES \ / AMOS7 \ YOURUM ::
#\[7]7JFAD7N2JERIZTAJEZYDIEYANMVK64Y27WWGICPFGNDWJIOCNECQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
