---
name: bug-jobsite-pending-count-leak-nonassessing-cycle
description: FIXED 2026-08-19 — jobsite.state.load only zeroed a stale pending_count when the persisted cycle was itself scanning/assessing, so a stray positive count under any other persisted cycle survived a restart and permanently wedged the assessment cycle on 'assessing' once real work drained
metadata:
  type: project
---

**Symptom**: `jobsite.status` stuck `cycle: assessing` for 2.5+ hours,
`new: 1` (one job permanently un-rescanned), even though the log showed
the job's own 777s watchdog (`jobsite.handler.assess-timeout`) fired
correctly and the rest of that batch (31 jobs) all resolved normally. The
periodic rescan (`jobsite.handler.rescan-timer`) is gated on
`cycle eq 'idle'`, so once wedged it never re-fires on its own.

**Root cause**: at jobsite process start, the log showed
`jss.load: cycle=idle, pending=1` — a `pending_count=1` persisted
alongside an already-`idle` cycle from some earlier session (root cause of
*that* leak not chased — a separate mismatched increment/decrement
somewhere). `src/jobsite.state.load`'s existing reset logic only
zeroes `pending_count` when the *persisted* `cycle` was itself
`scanning`/`assessing` — a stray positive count under any other persisted
value (idle, reviewing) survives untouched into the fresh process. From
there, `jobsite.dispatch.assessments`/`dispatch.next`/`assess-done` all
correctly increment/decrement around real work, but the leaked `+1` means
`pending_count` can never truly reach 0 again — it settles the cycle on
`assessing` forever the next time real work fully drains, exactly matching
the "assessment queue empty, waiting for results" log line (not "all
assessments complete, cycle=idle") that appeared once the batch finished.

**Fix**: added a sanity check right after the existing reset branch —
`if (<jobsite.cycle> ne 'assessing' and <jobsite.pending_count>)` resets it
to 0 with a warning log. Deliberately checks `ne 'assessing'`, not
`eq 'idle'`, since the real invariant is "pending_count only means
anything while a batch is actually being dispatched" — a narrower
`eq 'idle'` check would miss a stray count persisted under `reviewing`.

**Live recovery used before the fix took effect** (source fixes don't
apply to an already-running process): `jobsite.clear-tasks` (wipes only
runtime dispatch bookkeeping — `<jobsite.tasks>`/`cycle`/`pending_count`/
`assess_queue`, confirmed safe: job status/scores live on disk under
`jobsite/jobs/<status>/`, indexed via `jobsite.job.index`, not in this
runtime hash) followed by `jobsite.scan` to kick a fresh cycle
immediately rather than waiting for the periodic timer.

**How to apply**: if jobsite (or any zenka using the same
persist/reset-on-restart pattern) wedges on a non-idle cycle forever with
no new dispatches, check `jss.load: cycle=%s, pending=%d` in the log right
after the most recent process start — a nonzero pending under a
non-assessing cycle at that exact line is the fingerprint.

#,,,,,.,.,,,,,...,..,,...,.,.,..,,,..,...,..,,.,.,...,..,,...,,..,.,,,,..,.,,,

#,,,.,.,.,.,,,,,,,,,.,,..,,..,.,,,..,,,,.,,,,,..,,...,...,...,,..,..,,..,,.,,,
#FMQAARHC4FFYIOQEDPXNJSOQUHNAXJOQTTFDVEGLUHAN4IIDYU6BL7DVWSFKZHGJIOA3A7P4YSJH4
#\\\|LHJ23JT5QUWFSW2TJBNMUJI4TFW44C4F27VH5X5DW7FLQV5HXAC \ / AMOS7 \ YOURUM ::
#\[7]NWLO4AO6GVVZDYXYWEXMS3V6QKKI2Z7YVDQYM74J7MWTE7IAZSDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
