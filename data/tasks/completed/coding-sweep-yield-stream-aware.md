## [:< ##

# name  = task: make model-sweep's yield gate stream-aware
# descr = poll_sweep's yield-to-task-activity escalation uses a flat 300s
#         wall-clock cap with zero awareness of whether the real task
#         activity it's waiting on is actually healthy -- make it check
#         the same live-stream signal the HTTP layer already tracks for
#         every real task, not just self-test probes

## why now

confirmed live 2026-09-18, repeatedly this session (see
`reference-model-sweep-yield-300s-cap-not-stream-aware`, already known
before tonight): a genuinely healthy, actively-streaming real task
(chunks climbing steadily into the thousands, `async.http_timeout`
correctly extending its own ceiling in place: `ceiling [127s] hit but
stream is alive [chunks=545] : extending to 904s in place [cap=5400s]`)
still trips `poll_sweep`'s yield gate into a hard `paused [yield-timeout]`
after a flat 300s, needing a manual `model-sweep-resume <backend> :force:`
-- happened at least twice tonight, once again literally right after a
`:force:` resume, immediately mid-session. Blindly re-forcing past this
every time is not a fix; the escalation itself needs to know the
difference between "the queue never goes idle" (genuinely stuck, should
pause) and "one real task is still healthily streaming" (should keep
waiting, exactly like the HTTP layer already does for that same task).

## existing infra to reuse -- read all of these before writing anything

1. **`coding.model_sweep.handler.poll_sweep`**, the yield gate itself
   (current lines ~294-372): calls `coding.helper.backend_idle` (whole-
   queue-generic active-task-count + lock check, zero liveness
   awareness), and when not idle, accumulates wall-clock time in
   `$state->{'yield_since'}` until `$now - yield_since > 300`, then
   escalates to a persisted `paused [ yield-timeout ]` state requiring
   `:force:` to resume (lines 338-357). This escalation logic itself
   (the persisted-pause mechanics, the `:force:` gate) is CORRECT and
   stays -- only the "has 300s of wall-clock genuinely passed with
   nothing happening" judgment needs to change.
2. **`coding.cmd.round-progress`** is the exact pattern to mirror --
   it already does precisely the lookup this task needs, for a REAL task
   (not self-test-specific):
   ```perl
   ## find the task actually holding a backend lock right now ##
   my $backends = <coding.state.backend> // {};
   my $lock = $backends->{$backend_name}->{'lock'};
   ## $lock is a task_id (or undef) ##
   my $state = <[coding.async.state_machine]>->( qw| get |, $task_id );
   my $http_state = $state->{'http_state'};
   my $alive = <[coding.async.stream_tps]>->( qw| is_alive |, $http_state )
       if !defined $state->{'round_tools_started'}
       and ref $http_state eq qw| HASH |;
   ```
   `poll_sweep` already knows `$backend` directly (no need for
   `round-progress`'s cross-all-backends scan -- just read
   `<coding.state.backend>->{$backend}{'lock'}` for this one backend).
3. **the two-phase distinction, already an established design decision
   elsewhere, not something to relitigate**: a task's HTTP/streaming
   phase (`http_state` set, `round_tools_started` NOT yet set) is
   liveness-checkable via `stream_tps`'s `is_alive`. A task's TOOL-
   EXECUTION phase (`round_tools_started` set) has NO ceiling anywhere
   else in this codebase (`round-progress`'s own comment: `"tools: %ds
   (no ceiling)"`) -- there is deliberately no liveness signal to check
   there. Do not invent one; inherit the same "no ceiling" stance for
   this gate too when the locked task is in its tools phase.

## scope

modify `coding.model_sweep.handler.poll_sweep`'s yield-gate block
(current lines ~302-372): when `!$idle->{'idle'}`, before accumulating
toward the 300s cap, look up the task actually holding *this backend's*
lock (`<coding.state.backend>->{$backend}{'lock'}`, mirroring
`round-progress`'s pattern above but scoped to this one backend):

- **no task holds this backend's lock** (queue has active tasks but
  none locked on THIS specific backend -- e.g. the other backend is
  busy): fall back to the existing flat-300s behavior unchanged. Nothing
  to check liveness against.
- **a task holds the lock and is in its tools-execution phase**
  (`round_tools_started` defined on its state): no ceiling anywhere else
  in this codebase for that phase -- don't escalate the sweep pause on
  the flat 300s timer either. Decide (and clearly log/comment why)
  whether this means "never escalate while a task is in tools phase" or
  "use a much longer bound matching whatever other tools-phase guard
  exists elsewhere, if any" -- check whether `coding.helper.
  self_test_guard_watcher` or anything else already bounds a stuck
  tools-phase task before assuming there is truly no limit anywhere.
- **a task holds the lock and is in its HTTP/streaming phase**
  (`http_state` set, `round_tools_started` not yet set): check
  `<[coding.async.stream_tps]>->( qw| is_alive |, $http_state )`.
  - alive: do NOT accumulate toward the 300s cap for this tick --
    either reset `$state->{'yield_since'}` to now every tick while
    alive (simplest, matches "the whole point is real task activity
    wins"), or track differently if resetting loses useful diagnostic
    info (e.g. total-yielded-so-far for logging) -- your call on which,
    but the sweep must never escalate to a hard pause while genuinely
    streaming, no matter how long that stream runs (mirrors
    `async.http_timeout`'s own "extending in place, no upper wall-clock
    bound below its own 5400s cap" stance for the SAME stream).
  - not alive (stalled): keep the existing flat-300s-since-first-
    detected-non-idle accumulation exactly as today -- a stalled stream
    is exactly the "genuinely stuck" case this escalation exists for.
- keep the existing low-verbosity "still yielding" progress log
  (current lines 359-368), but note in it whether the yield is
  currently backed by a live stream or plain wall-clock accumulation --
  this is a real operator-visible diagnostic improvement, include it.

## explicitly out of scope

- the persisted-pause mechanics themselves (`$persist_cursor`, the
  `:force:` resume gate in `coding.model_sweep.cmd.model-sweep-resume`)
  -- untouched, still correct, still required to resume a genuine
  escalation.
- `coding.helper.backend_idle` itself -- stays as the first-pass idle
  check (active-task-count + lock), untouched. This task adds a SECOND,
  more precise check only when that first check says "not idle", it
  does not replace it.
- the spawn_smart async conversion, the v7-zenki max_concurrency race
  fix, the heartbeat.timeout config changes, the usage.* footer cleanup
  -- all separate, already landed this session, don't re-investigate.
- the model sweep should be left PAUSED during this task's live-testing
  (same reasoning as the spawn_smart task -- don't fight background
  sweep activity while verifying the new gate logic). Pause both
  backends before starting if either is currently running.

## verification

`bin/format-code -c` on every touched file. Live-test: with the sweep
paused, manually submit or trigger a real task on one backend that will
genuinely stream for well over 300s (or synthesize the condition some
other way if a real 300s+ task isn't practical to arrange), start/resume
the sweep on that same backend, and confirm it does NOT escalate to
`paused [yield-timeout]` while that stream is genuinely alive -- watch
the log for the new liveness-aware yield message instead of a flat
300s-later pause. Separately confirm the OLD behavior is preserved for a
genuinely stuck case: if practical, arrange (or reason carefully through,
if not practical to arrange live) a case where the lock is held but the
task is stalled/not-streaming, and confirm the sweep still correctly
escalates to `paused [yield-timeout]` after 300s in that case -- this is
the regression to avoid: don't accidentally make the sweep un-pausable
forever behind a genuinely hung task. Leave the tree uncommitted, report
back with exactly what changed, the decision made for the tools-phase
case, and the verification evidence for both the live-stream and
stalled-task scenarios.

## status [ 2026-09-18 ] — DONE, live-verified, signed + staged

kimi (k2.8) landed cleanly in one pass, needed one `kimi_continue` for a
verification methodology refinement (initial attempt tried to manufacture
an artificial CPU-pinned test task and burned time on that instead of
using the already-live sweep; redirected to a simpler approach). Only
`coding.model_sweep.handler.poll_sweep` touched. Independently
re-verified this session: read the full diff directly, confirmed the
ordering claim by hand (yield_hold/yield_why determined before the
`!yielding` init block, reset happens in the right place, the escalation
`elsif` branch is byte-for-byte untouched), ran `bin/format-code -c`
myself, and cross-checked the reported final sweep state
(`gpu paused idx=17/63`, `cpu paused idx=50/90`) against live status.

- **positive case** (live stream, no escalation): confirmed via
  `coding.eval-code` against a real live `http_state` (cpu sweep's own
  probe, 35.1 t/s, 3911+ chunks) that `stream_tps is_alive` returns TRUE
  and the gate's exact branch logic resolves to `hold=1, why='task
  stream alive'`, making the `>300` escalation unreachable. Honest
  caveat surfaced during verification: the sweep's OWN candidate
  self-test can never itself produce the "yield: task stream alive" log
  line, because its probe releases the backend lock before `poll_switch`
  transitions phase to idle (confirmed live) -- the gate only ever
  matters for real external task-queue activity holding the lock, which
  is exactly tonight's actual incident shape.
- **negative case** (stalled/no-lock/fake-holder still escalates):
  confirmed via read-only `coding.eval-code` spot-checks against live
  data structures -- no lock on backend, a fake/nonexistent task_id
  (state_machine returns `{}`), and a stale `http_state` through the
  real `is_alive` (returns FALSE) all correctly fall through to the
  unchanged flat-300s accumulation and escalation path.
- **tools-phase decision**: never escalate while the lock-holding task
  is in its tools-execution phase, matching the established "no ceiling"
  stance already used by `round-progress`/`round-time` for that same
  phase (checked `self_test_guard_watcher` first and confirmed it only
  bounds self-test probe guard slots, not real task tool execution --
  no other component bounds this phase, so a new 300s ceiling here would
  make this gate the only tools-phase killer in the codebase).
- small follow-up polish this session: both new log lines' `task(s)`
  literal replaced with `<[base.cnt_s]>->($idle->{'active'})` for
  correct pluralization.

**Separate bug noted, not fixed here** (surfaced during kimi's first
verification attempt): backend pinning via a `CPU: ` prompt prefix is
dead on the live path -- `coding.intake.parse_command_string` consumes
"CPU:" as the task type, and `coding.prompt.assemble`'s `metadata.
raw_request` fallback that would read it is fed from a field `coding.
intake.work` never populates, so every task silently routes `auto` ->
gpu preferred regardless of the prefix. Worth its own task file.

#,,,,,.,.,.,.,,.,,,..,..,,,,.,..,,,.,,..,,...,..,,...,..,,...,,,.,..,,,.,,...,
#IX2WJ47RVN7YWJLWERSX4NOE5W55NZKEESGNJRCNPNLLAME3XG3COLI475F2A575FZJFW3BULKTOU
#\\\|JWURZCS56O4FKXCSDWQAZCXEK6QXWMF7KPHGKOCOQ7MJ6VYBHYU \ / AMOS7 \ YOURUM ::
#\[7]AQ2R5SFX4HZGJUDQACDDLOTWVP6KHSZGXF37F7GEU7276MNKSSCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
