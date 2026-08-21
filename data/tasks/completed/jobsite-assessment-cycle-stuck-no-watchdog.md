# jobsite : assessment cycle can stick on 'assessing' forever, no watchdog

## status

fixed. a per-job watchdog timer now covers the whole
task.create/task.wait-done round trip (and, separately, the repair leg),
armed in `jobsite.dispatch.next`/`jobsite.dispatch.repair` and cancelled at
every point that releases the job's `pending_count` slot
(`jobsite.handler.task-created`, `jobsite.handler.assess-done`,
`jobsite.handler.repair-created`, `jobsite.handler.repair-done`). on
timeout, `jobsite.handler.assess-timeout` marks the job `repair_failed`
(mirrors the existing "hard infra failure" convention — no score
information, so status/stage untouched beyond clearing the in-flight
marker), releases the slot via `jobsite.dispatch.consume_slot`, and calls
`jobsite.dispatch.next` so the queue keeps draining instead of wedging on
`cycle=assessing`. clearing `stage` away from `assessing` also makes the
job reachable again by the next rescan (`jobsite.dispatch.assessments`
only skips `queued|assessing|assessed|done`).

a monotonically-bumped per-job `attempt` token (threaded through
`route-send`'s local-only `reply.params`, confirmed not wire-transmitted)
disambiguates a genuinely-late reply arriving after the watchdog already
gave up and moved the job on — compared at the top of
`assess-done`/`repair-done`/`task-created`/`repair-created` against the
job's current `attempt`, mismatches are dropped without touching
`pending_count` a second time. discovered along the way:
`jobsite.job.load_all` (re-entrant, called from `dispatch.assessments` on
every scan) was already unconditionally rebuilding
`<jobsite.tasks>->{$id}` from scratch, carrying forward only `stage` and
`queue_gen` — `attempt` needed the same carry-forward treatment (added),
and `task_id`/`repair_task_id` turned out to have always been silently
wiped there too (a pre-existing, separate latent gap — fixed as a
byproduct, not a regression).

new config: `jobsite.cfg.assess_timeout` (default 600s), in
`cfg/zenki/jobsite/zenka.v7`.

## status (superseded, kept for history)

not started — root-caused from code inspection + log correlation, not
yet fixed. captured from conversation so it isn't lost.

## what happened

user observed `jobsite.status` reporting `cycle: assessing` for an
extended period (left running for debugging) with nothing actually
being assessed or dispatched, followed by the zenka auto-shutting down
(on-demand idle timeout) before it could be investigated live.
`jobsite.status` now reports `cycle: idle` again, consistent with the
zenka having restarted since and `jobsite.state.load`'s existing
reset-on-restart logic clearing the stale state (see
`jss.load: cycle=assessing had pending=N, unrecoverable across
restart, resetting` in `/var/log/protocol-7/<host>.jobsite.zenka.log`
— confirmed this exact recovery path exists and has fired before, just
not proactively while the zenka keeps running).

## root cause (from code, not directly observed live)

`jobsite.dispatch.next` drives the assessment queue by routing each
job through `task.create` on the **coding zenka**
(`<[protocol-7.route-send]>` with `reply => { handler =>
'jobsite.handler.task-created' }`) — same dispatch/inference backend
independently observed the same session to get stuck reprocessing
stale content indefinitely (see
`feedback-session-catchup-round-buffer-grounded-but-mislabeled.md`'s
"sharper case, 2026-07-27" section). confirmed via `kimi -r <uuid>`
directly on the last real dispatch session: it was genuinely the
`crop_wide.v1` test-harness task, with nothing dispatched after it —
independently corroborating that a dispatched task's reply chain can
go quiet/never resolve on this backend.

`jobsite.dispatch.assessments`'s own code comment explains the exact
failure mode: when a new scan finds `<jobsite.cycle>` already
`'assessing'` (not idle), it deliberately does NOT call
`dispatch.next` itself — it appends the new jobs to
`<jobsite.assess_queue>` and trusts that "an in-flight chain already
re-invokes `dispatch.next` via `assess-done`". if that in-flight
chain's `task.create` reply is ever lost (network hiccup, coding-zenka
task silently dropped, or the same reprocessing-stuck behavior
observed elsewhere tonight), `jobsite.handler.assess-done` never
fires, so `dispatch.next` never gets called again — the queue just
accumulates forever, `cycle` stays `'assessing'`, and every subsequent
scan makes it worse by adding more jobs to a queue nobody is draining.

**there is no watchdog timer on the `task.create` round-trip at all**
— unlike, say, `audio.decode_to_pcm`'s explicit `decode_timeout` /
`audio.handler.decode_timeout` pattern (spawn + timer + timeout
handler that kills and cleanly fails the operation), jobsite's
dispatch has no analogous timeout/kill/retry path. the only recovery
mechanism is `jobsite.state.load`'s reset-on-restart logic, which only
runs at zenka startup, not while the zenka is already running and
stuck.

## proposed fix (not implemented)

add a per-dispatch timeout to `jobsite.dispatch.next`, mirroring
`audio.decode_to_pcm`'s `event.add_timer` + timeout-handler pattern:
if `task.create`'s reply hasn't arrived within some deadline, treat
the dispatch as failed (log it, mark the job appropriately — retry?
skip and requeue?), and critically **call `dispatch.next` again**
regardless, so the queue keeps draining instead of permanently
stalling on one lost reply. exact retry/failure semantics (does a
timed-out job get requeued, marked failed, or blocked?) need deciding
— not obvious from the existing code which of those jobsite already
has conventions for.

## open questions

- how often does this actually happen in practice? only one incident
  observed/reported so far — worth checking historical logs for other
  `cycle=assessing ... unrecoverable across restart, resetting`
  occurrences to gauge frequency before deciding how urgent a fix is.
- should the coding-zenka dispatch backend itself get a more general
  fix (task-level watchdog / dead-task detection) rather than, or in
  addition to, jobsite-side timeout handling? the same underlying
  backend issue surfaced twice independently in one session (jobsite's
  stuck assessment, and the coding zenka's own stuck session_catchup
  reprocessing) — a backend-level fix might address both instead of
  patching each consumer separately.
- confirm the exact recovery semantics wanted: retry the same job,
  skip it and move on, or mark it failed/blocked pending manual review?

#,,,,,...,.,.,...,...,..,,.,.,...,...,,..,..,,..,,...,...,,..,...,,,.,,,.,...,
#SF5IOW6XPBWEXIUW7IYPSEIROHWFHO5MCQQ5ZZ6TAJ37SCBR5RUNR5IBTAOUDWBKGYQBUHHCMQUQ4
#\\\|6JHAL4Y52JCPPJNPEKL4FASB4HHJPKJPA2BDNXGTXBSJ6ZXPSZ3 \ / AMOS7 \ YOURUM ::
#\[7]MBTBOH5DTI5S2PBEOY2EALBEP6KEKBVKPIOPJOBUBNMPYU4Z56CY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
