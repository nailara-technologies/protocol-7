## [:< ##

# name  = task: model-sweep candidates must hold the backend lock while testing
# descr = the two per-backend sweeps (gpu/cpu) currently run fully
#         concurrently with zero mutual awareness, because a sweep
#         candidate's own switch+self-test cycle never acquires
#         coding.state.backend's lock the way a real submitted task
#         does -- make it acquire/release that lock so the ALREADY-
#         EXISTING global idle check naturally serializes the two
#         sweeps instead of always racing in parallel

## why now

confirmed live 2026-09-18: right before yet another coding-zenka
heartbeat kill tonight, the log showed BOTH backends genuinely mid heavy
self-test activity at the same time -- cpu's candidate failing through
multiple full retry cycles, gpu's candidate mid-test with a slow
ttft=26.58s, simultaneously. This is real concurrent load, not a code
bug in the sense of the two bugs already fixed tonight (spawn_smart's
blocking kill-wait, poll_sweep's flat-300s false-pause) -- but it
shouldn't be POSSIBLE given `coding.helper.backend_idle` is
deliberately global (its own doc comment: "loops both gpu and cpu"),
specifically so one backend's real activity makes the OTHER backend's
sweep yield too.

Root cause, confirmed by grep: `coding.async.backend_acquire` /
`coding.async.backend_release` are never called anywhere in
`coding.model_sweep.handler.poll_sweep`, `coding.self_test.handler.
poll_switch`, or `coding.self_test.run`. A sweep candidate's own
switch-test-restore cycle never sets `<coding.state.backend>->
{$backend}{'lock'}` at all -- so `backend_idle`'s global check can only
ever see REAL external task activity, never a sweep's own. gpu-sweep and
cpu-sweep have been running with zero mutual exclusion this entire
session; every "both backends busy at once" incident tonight (including
ones that predate today's other two fixes) is this same gap.

## existing infra to reuse -- read all of these before writing anything

1. **`coding.async.backend_acquire`** (`task_id`, `backend`): sets
   `<coding.state.backend>->{$backend}{'lock'} = $task_id` if free,
   returns `{acquired=>TRUE,queued=>FALSE}`. If NOT free, pushes
   `$task_id` onto `<coding.state.backend>->{$backend}{'queue'}` and
   returns `{acquired=>FALSE,queued=>TRUE}`.
2. **`coding.async.backend_release`** (`task_id`, `backend`): only
   releases if `$task_id` actually holds the lock; on release, shifts
   the next queued task_id off `queue` and calls `<[coding.async.
   send_request]>->($next)` to auto-resume it. **This auto-dispatch
   assumes `$next` is a real task_id `coding.async.send_request` knows
   how to resume -- a sweep placeholder id passed through this path
   would break it.** This is the one real hazard in this task: the
   sweep's placeholder id must never end up sitting in a real queue
   waiting for `send_request` to fire on it.
3. **`coding.helper.backend_idle`**: already correctly global, already
   correctly used by both sweeps' yield gates. Untouched by this task --
   it will start working correctly for sweep-vs-sweep contention purely
   as a SIDE EFFECT of this task making the lock visible to it. Do not
   modify this file.
4. **`coding.model_sweep.handler.poll_sweep`**'s own candidate lifecycle
   (read the whole file, but specifically): `start_candidate` (current
   lines ~183-261) generates a per-candidate `$switch_id` via
   `<[base.gen_id]>` (line ~215), sets `<coding.self_test_switch_state>
   ->{$switch_id}` with `phase=>'switching'`, sets this sweep's own
   `$state->{'phase'} = 'waiting'`. The `if ( $phase eq qw| waiting | )`
   block (current lines ~453-469) is where a terminal phase in
   `self_test_switch_state` is detected and the log line "candidate
   %d/%d finished, advancing" fires, resetting `$state->{'phase'} =
   'idle'`. These two points -- candidate start and candidate-finished-
   detected -- are the natural acquire/release boundary: the lock
   should be held for exactly the span of one candidate's switch+test
   (+restore), matching what `switch_id`'s own lifecycle already
   tracks.

## scope

in `coding.model_sweep.handler.poll_sweep`:

1. **acquire, in `start_candidate`**, right after `$switch_id` is
   generated (or right before, either is fine as long as it uses the
   same id): call `<[coding.async.backend_acquire]>->( "sweep:
   $switch_id", $backend )` (or any similarly-distinctive, obviously-
   not-a-real-task-id string -- `sweep:` prefix is a suggestion, pick
   whatever's clearest). Because `poll_sweep` only ever calls
   `start_candidate` when its own idle-gate already confirmed
   `backend_idle`'s global idle==TRUE moments earlier, this acquire
   should always succeed immediately (`acquired=>TRUE`) in the normal
   case. **Handle the abnormal case defensively**: if it ever comes back
   `queued=>TRUE` (a real task raced in between the idle-check and this
   acquire), do NOT proceed with starting this candidate and do NOT let
   the sweep's placeholder id sit in that queue waiting for
   `send_request` to fire on it -- instead, immediately call
   `coding.async.backend_release` again with the same id to pull it back
   out (acquire's queueing only happens by pushing to an array; releasing
   a lock you don't hold is a safe no-op per `backend_release`'s own
   guard, but removing yourself from the QUEUE is not the same as
   releasing a LOCK you don't hold -- check `backend_acquire`'s queue-
   push code path and figure out the correct clean way to un-queue
   before assuming a release call handles it; worst case, splice your
   own id back out of `<coding.state.backend>->{$backend}{'queue'}`
   directly), log a clear warning, and just let this poll_sweep tick
   fall through to "stay idle, try again next tick" instead of starting
   the candidate.
2. **release, where the "finished, advancing" terminal-phase detection
   already fires** (current lines ~461-469): call `<[coding.async.
   backend_release]>->( "sweep:$switch_id", $backend )` using the SAME
   id string built from the same `$switch_id` that was current for the
   candidate that just finished (`$state->{'switch_id'}`, read BEFORE
   it gets reset to `''` a couple lines later in that same block).
3. **also release on any abnormal exit from a candidate's lifecycle**
   that leaves `$state->{'phase'}` reset without going through the
   normal "finished, advancing" path -- read the whole file for every
   place `$state->{'phase'}` gets forced back to `idle` or the sweep
   gets aborted/paused/cancelled mid-candidate (the "unknown phase"
   defensive-cleanup branch at the bottom, `model-sweep-cancel`'s own
   handling if it touches in-flight state, circuit-breaker trips,
   etc.) and make sure none of them can leave a lock held forever with
   no matching release. A held-forever lock would make BOTH backends'
   sweeps (and any real task on that backend) hang permanently, which
   is a strictly worse regression than tonight's contention -- treat
   this as the primary correctness risk of the whole task, more
   important than the acquire/release happy path itself.

## explicitly out of scope

- `coding.async.backend_acquire` / `coding.async.backend_release` /
  `coding.helper.backend_idle` themselves -- untouched, already correct,
  this task only adds a new CALLER of the first two.
- the spawn_smart async conversion, the stream-aware yield gate, the
  v7-zenki max_concurrency race fix, the heartbeat.timeout config
  changes, the usage.* footer cleanup, the `CPU:` prefix routing bug --
  all separate, already landed or already noted this session, don't
  re-investigate.
- both sweeps are currently in a post-crash `resumable [not running]`
  state (gpu idx=22/63, cpu idx=58/90) from the incident that surfaced
  this gap -- resume them yourself if needed for testing, but the model
  sweep should be treated as expendable test material for this task
  (that's the whole point), not left running unattended in the
  background while you're not actively watching it.

## verification

`bin/format-code -c` on every touched file. Live-test: resume both
sweeps (`model-sweep-resume gpu :force:` / `cpu :force:` as needed) and
watch the coding zenka log for a sustained window. Confirm via log
evidence that the two backends' candidate self-tests no longer overlap --
when one backend's candidate is actively mid self-test, the other
backend's `poll_sweep` should show a yield log line (now correctly
triggered by `backend_idle` seeing the other backend's sweep-held lock,
not just real task activity) rather than starting its own candidate at
the same time. Confirm a full sweep cycle (acquire at candidate start,
release at candidate finish) repeats cleanly across several consecutive
candidates with no lock leaks -- spot-check `<coding.state.backend>` via
`coding.eval-code` between candidates to confirm both backends' locks
are `undef` whenever neither sweep is actively mid-candidate. Confirm a
real submitted task (if one happens to run during your testing window,
or synthesize one) still queues and resumes correctly behind a sweep-held
lock -- this is the scenario that would break if the placeholder id ever
leaked into `send_request`'s path, so treat it as the critical negative
case. Leave the tree uncommitted, report back with exactly what changed,
the chosen placeholder-id format, and the verification evidence for both
the cross-sweep-serialization positive case and the lock-never-leaks /
real-task-still-works negative case.

#,,,.,...,,.,,.,.,,..,,,,,,..,.,.,...,..,,,..,..,,...,..,,,,,,,,,,...,.,.,.,.,
#L6G7HU5NSORO7E6LEEGLJIQA5XPWQGOWJEDE4HWKNBIZTO5Y4J4Z2PX5C7PLRM2QX6PJ2GBFWWWQQ
#\\\|KP77KTLNIIOF2I3RVA76XWJGEZCDBSV3TSZT2MQCNNTZPNT5UOA \ / AMOS7 \ YOURUM ::
#\[7]4BU4URW3ZLDGATZAAS52CTDX6BDLU3R42FNECLLOUYYZKUK2NUBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
