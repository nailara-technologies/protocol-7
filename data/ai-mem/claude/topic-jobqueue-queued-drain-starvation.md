---
name: topic-jobqueue-queued-drain-starvation
description: "jobqueue.handler.queue_counter drained only 1 job per 'queued' counter firing — bulk dependency resolution starved the rest until unrelated jobqueue traffic; fixed by bounded per-tick drain"
metadata:
  node_type: memory
  type: project
---

## symptom (reported 2026-08-09)

mpv startup log showed ~9 deferred `send_command` jobs move into `depending`
during startup, then `player startup successful` / snapshot restore, but the
deferred commands themselves never visibly drained afterward — looked like a
regression on top of [[topic-jobqueue-check-dependencies-splice-bug]].

## root cause

separate bug from the splice-skip fix (which is correct and untouched).
`jobqueue.event.register_job_queues` watches each queue's counter via
`Event->var` (`poll => 'w'`) — edge-triggered on the *next event-loop tick*,
not per-write. `mpv.startup.handler.socket_poll` calls
`<[jobqueue.check_dependencies]>` once when the IPC socket becomes ready,
which synchronously bulk-moves *all* resolved `depending` jobs into `queued`
in one tight loop — N counter increments in one synchronous pass. The watcher
only fires once for that burst, and the old `jobqueue.handler.queue_counter`
pulled exactly **one** job per firing (`get_next_job` + single move). Only
the first job (mpv's own `finalize` job) got promoted to `running`; the rest
sat parked in `queued` indefinitely, waiting on unrelated future jobqueue
traffic to leak them out one at a time.

Same shared module (`jobqueue.handler.queue_counter`), loaded by mpv, coding,
models, vision-batch, X-11, v7 — any zenka that bulk-resolves several
dependencies in one synchronous pass (anything calling `check_dependencies`
directly rather than waiting for the natural per-job counter tick) hits the
same starvation.

## fix (landed)

`src/jobqueue.handler.queue_counter`: the `queued`-queue branch now
drains up to `$$counter_ref` jobs per firing instead of one, via a bounded
`while` loop (snapshot the counter into `$drain_budget` first — do NOT use
`while ( my (...) = <[jobqueue.get_next_job]>->(...) )` as the loop
condition, since `get_next_job`'s `return undef` is a one-element list in
list-context boolean, so the condition never goes false; use `last if not
defined $job_id` inside the loop instead). Bounding to the snapshot means a
job that itself re-queues more work via `exec_job` mid-drain gets picked up
on the *next* tick, not spun through unbounded in this one — avoids turning
the fix into an unbounded synchronous-execution hazard for zenki that queue
hundreds of jobs.

Live-verified: restarted mpv after the fix, `mpv.is-idle` / `mpv.get-volume`
both responded correctly post-restart (previously the deferred commands
would have stayed silently stuck in `queued`).

**Why:** `Event->var` watches are edge-triggered per event-loop tick, not
per-assignment — any code path that increments/decrements a jobqueue counter
multiple times synchronously (a bulk `move_job` loop) will only be observed
as a single change by the watcher, so a handler that processes "one job per
firing" silently under-drains whenever more than one job resolves at once.

**How to apply:** any handler driven by a `base.event.add_var` counter watch
that assumes "one firing = one queue change" should snapshot the counter and
drain the full delta, not just pull a single item — the same edge-trigger
hazard applies to any future queue/counter pair built on this same
`event.add_var` pattern, not just `jobqueue`.

[[topic-jobqueue-check-dependencies-splice-bug]] [[topic-mpv-jobqueue-startup]]

#,,.,,,,,,,,,,,.,,.,.,..,,,,,,.,.,.,,,.,,,..,,..,,...,...,.,,,...,..,,,,.,,.,,
#JUG2LWUYTRK6YIVQCVPTQ77FHIRRDRNXGJ6IALGCML6QPPS72YIRYPYFZGWBOIZ4YYF6ZJZCYZ4ZS
#\\\|ZSBMPQAJQT4Q4CYOJ7SGZNIJERZMW6UDMLYL7JX74BA7H4KQFAW \ / AMOS7 \ YOURUM ::
#\[7]PRTVQXF7TVDTV4HWVGWKJIQO7PJE3OFQAGFOMCBBPZDJBMU63ODI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
