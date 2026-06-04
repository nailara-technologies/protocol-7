## [:< ##

# name  = task: coding zenka — drain-pipe + data-start-timeout restart robustness
# descr = clean pipe-watcher teardown on gpu server restart + transparent retry of in-flight requests

## objective

harden the coding zenka's async inference path against gpu server restarts.
two related defects surface when a server hits a data-start timeout and gets
respawned: (1) stale pipe watchers churn the event loop with warnings, and
(2) an in-flight request fails hard instead of being transparently retried.

do NOT change model/context tuning — `inference.model.context_length` was
already nudged 37777 → 37000 as a mitigation; that is not the fix.

## reasoning level

medium-high — async IO::Async event-loop lifecycle. be careful with watcher
teardown ordering; a wrong fix trades warnings for a hang.

## symptoms — observed log evidence

### issue A — stale pipe watcher churn on respawn

repeating, after a gpu server is killed and a new one spawned:

```
warn : event : 'coding.handler.drain_pipe' was unexpectedly closed
warn : event : cannot restart 'coding.handler.drain_pipe' because there is nothing to watch
```

the old server's stdout/stderr pipe fds (e.g. `stdout=13 stderr=15`) are closed
when the server process group is killed, but their drain watchers are not torn
down first — so the loop keeps trying to restart a watcher on a dead fd.

### issue B — in-flight request fails hard during restart window

```
async.http_data_start_timeout: no streaming data after 77 seconds
http_error: timed out after 1 retries : scheduling gpu server restart
http_error: reducing context 37777 → 30777 [timeout recovery, floor=16000]
http_error: requeued <id> as pending — retries after server restart
...
async.request: inference complete for task-LRTVH2Y [0 bytes, 0 chunks]
http_complete: task task-LRTVH2Y connection closed with no data
async.complete: task task-LRTVH2Y failed: connection closed with no data
```

note the split: request `<id>` (3953573) was correctly **requeued** for retry,
but `task-LRTVH2Y` came back `0 bytes / connection closed with no data` and was
marked **failed** rather than requeued. understand why these two in-flight
requests were handled differently — one recovered, one lost.

## investigation leads — modules

- `coding.handler.drain_pipe` — the watcher that warns. who registers it, and is
  it deregistered when the server it drains is killed ?
- `coding.handler.drain_check` — companion drain logic.
- `coding.spawn_inference_server` — kills the old server group and spawns the
  new one [ logs `killed old gpu server group` ]. this is the natural place to
  also remove the old stdout/stderr pipe watchers BEFORE closing their fds.
- `coding.handler.http_data_start_timeout` — emits the data-start timeout and
  schedules restart; check the requeue-vs-fail decision path.
- `coding.handler.monitor_inference_startup` — watches new-server readiness.

## fix sketch [ verify against the code, do not assume ]

1. **issue A:** on server kill/respawn in `coding.spawn_inference_server`,
   explicitly remove the drain_pipe / drain_check watchers for the old fds
   [ deregister from the event loop ] before/at fd close, so no orphan-restart
   attempts occur. confirm there is no double-close.
2. **issue B:** ensure a request that hits data-start-timeout OR closes with
   0 bytes during a known restart window is requeued [ same path that already
   requeued 3953573 ], not failed. find why `task-LRTVH2Y` took the failure
   branch and route it through retry instead.

## constraints

- protocol-7 module conventions: bare-code modules, `<[module]>->()` calls,
  `<a.b.c>` data access, TRUE/FALSE constants, lowercase `[ word ]` comments.
- do NOT append an AMOS7 signature stub — leave edited files unsigned.
- the event-loop watcher API is IO::Async-based; reuse existing add/remove
  patterns already in the coding handlers rather than inventing new ones.

## verification

- reproduce by forcing a data-start timeout [ or a manual gpu server kill ] and
  confirm: no `nothing to watch` churn, and the in-flight task is retried and
  completes against the restarted server rather than failing.

## dispatch

dispatch to kimi with reasoning level medium-high. read the four handler
modules above + `coding.spawn_inference_server` first; produce a short plan
[ which watchers, which requeue path ], confirm, then implement issue A and
issue B as separate edits. syntax-check; operator signs + restarts coding zenka
to verify [ unsigned modules will not load ].

#,,.,,..,,,,.,,,,,.,,,.,.,..,,,,,,,,.,.,,,.,,,..,,...,..,,.,.,,..,.,,,..,,,..,
#X6LAPQVL5BGZEJY5BULJYYZ32A6LWNWCWCFZNB4H465TDVTJ5L54QEQGGQFJ3HDEVYJXHGFTMUVH4
#\\\|V4PIMAWCILPL64MHIDLU5MN4Z5IUSTKNRMI6UO3URA7TRSORCCL \ / AMOS7 \ YOURUM ::
#\[7]BBTYSPQGFLJF3SE7YWQT7RWAU3X57KWII3AM52BSKKHR7SDEPKDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
