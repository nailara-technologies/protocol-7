---
name: feedback-coding-timeout-restart-loop
description: coding zenka data-start-timeout restart loop — flat 13s timeout too short for large prompts + context "reduction" on recovery was a no-op (floor vs ceiling confusion)
metadata:
  type: feedback
  originSessionId: 160f5f01-69ac-4634-90a3-e23e9a7a38ce
---

Found + fixed 2026-06-08 (staged, commit pending): the coding zenka was
looping on `Data start timeout` → scheduled GPU restart → same timeout again,
forever. Two independent bugs compounded:

1. **`coding.http-timeouts.data-start = 13` is too short for large prompts.**
   Lowered from 77→13s in commit `1a5ce1c82` on the assumption "first token
   arrives in <2s on local GPU" — true for *small* prompts with no queue
   contention, false once `est_tokens` (see `<T:N:ctx:left>` in
   `send_request` logs) climbs past ~15K: prefill alone can exceed 13s,
   especially with two tasks contending for one GPU backend (visible in logs
   as `backend_acquire: X queued behind Y`). Fix: `coding.async.http_client`
   now scales the timeout — `est_prompt_tokens / prefill_tokens_per_sec +
   margin` — and uses whichever is larger than the configured floor. New
   keys: `coding.cfg.prefill_tokens_per_sec` (1200), `coding.cfg.prefill_margin_sec` (5).

2. **The timeout-recovery context-size "reduction" was a complete no-op** —
   a *floor vs ceiling* confusion. `coding.callback.http_error` reduced
   `<inference.model.context_length>` (e.g. 36000→29000) intending to relieve
   VRAM pressure, logging "reducing context X → Y [timeout recovery]". But
   `coding.spawn_inference_server` treats that exact key as a **floor**:
   `$ctx_size = max($auto_calc, $configured)`. So whenever VRAM auto-calc
   exceeded the "reduced" value (it almost always did — log showed
   `context expanded to 39777 [auto > configured floor 29000]`), the
   reduction was silently discarded and the server respawned with the same
   (or larger) context — same slow prefill, same timeout, forever. Fix:
   added a separate runtime-only `<coding.cfg.ctx_recovery_ceiling>` that
   `spawn_inference_server` clamps `$ctx_size` *down to* unconditionally
   (after auto-calc), which `http_error` now sets/steps alongside the floor.

**Why this matters generally**: a config key whose role is "minimum, can be
overridden upward" and one whose role is "maximum, must win outright" look
identical at the call site (`<key> // default`) — only by reading the
*consumer* logic do you see which one you're dealing with. Lowering a value
that the consumer treats as a floor has zero effect and produces exactly the
"I fixed it but it keeps happening" symptom the user hit.

**How to apply**: when a "recovery"/backoff mechanism writes a config value
to influence a subsequent restart/respawn, verify the consumer actually
treats that key as a hard limit in the direction you need — grep for how it's
combined with auto-calculated values (`max`/`min`/ternary), don't assume
"floor" and "ceiling" are interchangeable just because both clamp a number.

Related: this is a *separate* mechanism from the
[[feedback-config-reload-clobber]] bug (also fixed 2026-06-08, commit
`89a6817c7`) that was suspected as the queue-stall root cause — both can
independently put the coding zenka into a restart loop. Worth re-testing
`data/tasks/archive/coding-zenka-restart-queue-stall.md`
(see [[topic-coding-state-machine]]) now that *three* restart-loop causes
are fixed.

#,,,.,,..,.,,,...,.,.,,,,,.,,,,..,,,,,...,..,,.,.,...,...,,,.,.,,,,,.,,,.,,.,,
#Y366VPOSYSZ3CQEAT3VY73JZXC244MPXRQJ4OD2ENUB5BOHE4L7THPI7YGCHOAQ5XMFQOTDNIL3XQ
#\\\|5XMO55LIQ7BAYD3CANH3FNDQ6ZXTXOLPO4LIYCARZ7W6QAI52QO \ / AMOS7 \ YOURUM ::
#\[7]TSFIFBCHZQ4AFP3RCBJ62GTSEWXVXNJ5H255WPR6RLB4XLJVZMBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
