---
name: feedback-check-existing-safety-nets-before-adding-new-one
description: this codebase already has multiple overlapping, deliberately-tuned async watchdogs/fallback-resume timers in the coding zenka — grep for an existing one covering the same failure before writing a new independent timer, especially around coding.task.queue_paused / self-test / backend-restart machinery
metadata:
  type: feedback
---

While chasing [[bug-coding-async-send-request-enqueue-round-timer-mismatch]]
(coding-zenka task silently dropped while `queue_paused`), I wrote a whole
new watchdog module (`coding.handler.queue_pause_watchdog`) with its own
hardcoded `1500`-second ceiling before checking whether one already
existed. The advisor caught it: `coding.handler.verify_inference_startup`
lines 49-79 is already a deliberately-tuned fallback-resume for exactly
this, scheduled in parallel by `coding.handler.spawn_servers_deferred` on
every spawn, and its own comments cite a specific past incident
(`4c3cf0e73`) where an independently-recomputed ceiling caused a
premature-resume race — the precise mistake my new module would have
repeated with a different literal (`1500` vs the derived
`self_test_max_total`-based value). I reverted it.

**Why this matters here specifically**: the coding zenka's async/self-test
machinery has been iterated on heavily and has several of these
deliberately-layered timeouts (`coding.self_test.handler.poll_probe`'s own
`self_test_max_total` watchdog, `verify_inference_startup`'s fallback,
`http_timeout`'s soft→hard ceiling escalation) — the comments in each one
routinely reference the *other* ones by name and cite prior live incidents
where they drifted out of sync. This is not generic advice to be cautious
everywhere; it's specific to this subsystem's actual history of the exact
failure mode of "two safety nets, two independently-derived ceilings, one
fires too early."

**How to apply**: before adding any new `event.add_timer`-based fallback,
ceiling, or watchdog anywhere in `coding.*` (or any subsystem showing the
same layered-timeout pattern), grep for existing timers touching the same
flag/state (e.g. `grep -rn 'queue_paused\|self_test_max_total'
modules/coding.*`) and read their surrounding comments before writing new
code — they will usually say outright whether one already covers the case,
and derive any new ceiling from the same config knob rather than a fresh
literal if one is genuinely still needed.

#,,.,,,.,,..,.,,,,,,.,,,.,,..,,,,,.,,,,,,.,.,.,.,,,,,,,,,.,.,,,..,.,,,,.,,,,,.

#,,,,,..,,..,,,,,,,..,,,.,..,,,,,,,,.,,,,,,..,..,,...,..,,...,...,,,.,,.,,..,,
#OMDQ3K5A5QWDP4UELBSE7N7UYHQXIEHEZ5ZD6Y6FQD5V2TDPMQI3CPJ6NWUQ3MFNAM2SCTDBBDUSK
#\\\|ENYPQBAVO7WINSOAECJZXDMBFUYTLVUDFPOWNIKQ7UOI3DFI7ZY \ / AMOS7 \ YOURUM ::
#\[7]IR6GQGUWY6BLUM4XVLFSRYKXZPDBLBBP6JULFD227LDBPBIB2SAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
