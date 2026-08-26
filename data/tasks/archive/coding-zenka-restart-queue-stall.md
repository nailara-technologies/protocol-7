## task: coding-zenka-restart-queue-stall

## dispatch
analyze and fix the coding zenka task queue stall after two consecutive
data-start timeouts trigger backend auto-restarts. read first:
`src/coding.handler.http_data_start_timeout`,
`src/coding.callback.http_error`,
`src/coding.handler.monitor_inference_startup`,
`src/coding.async_spawn_inference_servers`,
`src/coding.handler.spawn_servers_deferred`.
do NOT touch signatures or unrelated logic.

## problem
after two back-to-back data-start timeouts the coding zenka stops picking up
tasks from the queue. a single timeout + restart recovers fine. two in a row
leaves the zenka idle with pending tasks and no error visible.

## the intended flow (working case, one timeout)
1. `coding.handler.http_data_start_timeout` fires → calls on_error → goes to
   `coding.callback.http_error`.
2. http_error detects "timeout", sets `$srv->{'status'} = 'restart_needed'`,
   schedules `coding.handler.spawn_servers_deferred` via a 2s timer, requeues
   the task as pending.
3. spawn_servers_deferred kills the old process, calls
   `coding.async_spawn_inference_servers` which starts a fresh backend.
4. `coding.handler.monitor_inference_startup` watches stdout; on readiness it
   calls `<[jobqueue.check_dependencies]>` which picks up the requeued task.

## where it likely breaks (two timeouts)
the stale-watcher guard at the top of `monitor_inference_startup` cancels and
returns early if `$server` was replaced by a newer spawn. if the second timeout
fires WHILE the first restart is still starting up, the monitor for the FIRST
spawn is already registered; the second restart installs a NEW server entry
under the same backend key, causing the first monitor's stale guard to fire on
the next I/O event — the first monitor exits without calling
`jobqueue.check_dependencies`. the second monitor then runs, but:
- if it exits via the stale guard too (a third spawn arrived?), same problem.
- or: the second spawn succeeds and calls `check_dependencies` — but the task
  was requeued TWICE (once per timeout). check if the double-requeue corrupts
  the task status or leaves it in a non-pending state that check_dependencies
  skips.

## what to look for
- does `coding.callback.http_error` guard against double-requeue on the same
  task_id? (if task is already 'pending' does it skip the requeue path?)
- does `monitor_inference_startup` always call `jobqueue.check_dependencies`
  on the happy path, even after the stale guard rejects a prior monitor?
- does `spawn_servers_deferred` clear `$srv->{'status'}` from `restart_needed`
  before spawning, or can a second timeout see 'restart_needed' and skip the
  restart entirely (line 123: only restarts if status eq 'ready')?
- are there any logs printed in the two-timeout scenario that would identify
  which guard fires? add targeted log lines to narrow it if needed.

## fix
patch the exact gap found. likely options:
- if the guard is the problem: ensure `jobqueue.check_dependencies` is called
  from the NEW monitor's ready path even when a prior stale monitor was
  cancelled, OR call it from `spawn_servers_deferred` after confirming the
  backend is up.
- if double-requeue corrupts state: guard the requeue in `http_error` with a
  check that the task is not already pending before re-setting it.
- if `spawn_servers_deferred` skips a second restart because status !=
  'ready': explicitly reset status to 'ready' before the second timeout triggers
  OR add a 'restart_needed' → allowed restart path.

module style: lowercase comments, `[ word ]` annotations, `## [:< ##` headers,
NO manual signature stubs. minimal change — do NOT refactor surrounding logic.

## acceptance
- reproducing the two-timeout scenario (or tracing the code path) shows the
  exact guard or condition that drops the `jobqueue.check_dependencies` call.
- after the fix, requeued tasks resume processing after two consecutive
  data-start timeouts without requiring a manual `v7.restart coding`.
- no regressions to the single-timeout recovery path.
- no manual AMOS7 signature stubs in edited files.

#,,.,,,..,..,,,..,.,,,,..,.,.,,..,,..,.,.,,..,..,,...,...,.,.,,,.,,..,..,,.,.,
#HWAUP72LNYKHIOI4SAOJOJ5SMXWUZL57OLSMODLFPQQOTQYIAAWJN6CAQDO4DUMHLJ4BG3ZTMYDYE
#\\\|MT3B7FNYYHOCYOUPYZADKQVHHBNEL2GM5F3WVJHW6UGJEACJ6SG \ / AMOS7 \ YOURUM ::
#\[7]HX5QAPLDHLNW6RSHW3GBREP5TBS42KMKX7DSUYMRDELXKP2UFSDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
