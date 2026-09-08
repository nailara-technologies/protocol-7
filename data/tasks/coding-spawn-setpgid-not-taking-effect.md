## [:< ##

# name  = task: coding.spawn_inference_server's setpgid does not take effect
# descr = old-server group-kill is a silent no-op; real kill happens later,
#         unprotected, via the port-based fuser scan -- causes a VRAM-read
#         race right where spawn's own vram check runs

## context

found 2026-09-08 while live-testing the hybrid/partial-offload feature in
`data/tasks/coding-cpu-and-hybrid-offload-path.md` (scope #3, now done).
not fixed there on purpose -- flagged by reviewer as a separate concern
with real blast radius (a wrong process-group signal can hit unrelated
zenki), out of scope for that change.

`coding.spawn_inference_server` calls `POSIX::setpgid( $pid, $pid )` right
after spawning a new llama-server, intending to make it its own process
group leader so a later `kill('KILL', -$pid)` can reach the whole group
(the server plus any worker it forks on first request). confirmed live
that this is not taking effect in this environment: a freshly-spawned
llama-server's real pgid stays the shared session pgid (`ps -o pid,pgid`
showed pgid=713573 for a process with pid=1234657 -- 713573 is the pts/9
session's original pgid, shared by the ENTIRE zenki fleet: cube, system,
p7-log, coding itself, etc, not anything specific to this one child).

practical consequence: every "kill the old server" call at the top of
`coding.spawn_inference_server` does `kill('KILL', -$old_pid)`, which
targets process group `$old_pid` -- a group that doesn't exist (since the
real pgid is 713573, not $old_pid), so it silently kills nothing. return
value isn't checked. the immediately-following bounded reap loop
(`waitpid($old_pid)` x30 polls @0.1s) then always exhausts all 30 polls
(confirmed live, `reaped_polls=30`) because the process never actually
died -- 3 wasted seconds on every single spawn, every time, not just
when something has genuinely gone wrong.

the process only actually dies later in the same function, via the
UNRELATED "scan for stale llama-server processes on same port" fuser
block, which kills by literal pid (not group) and works correctly as far
as actually terminating the process -- but has no waitpid/reap of its own
afterward. that's what created the VRAM-read race documented in the
hybrid-offload task file: the vram sanity check's nvidia-smi query runs
moments later, before the driver has necessarily finished releasing the
just-killed process's VRAM, on an environment where a SECOND, independent
bug (nvidia-smi's own units-format flakiness) had already been masking
this along with everything else. the units bug is fixed; this one isn't.

## why setpgid might not be taking effect -- not yet root-caused

candidates, none confirmed:
- classic `setpgid`-after-open3 race: the child may already have called
  `exec()` (or further) by the time the parent's `setpgid($pid,$pid)`
  runs, and depending on how IPC::Open3 sets things up, that can lose the
  race in either direction. the standard fix is to ALSO call
  `setpgid($$, $$)` (or `setpgid(0,0)`) in the CHILD right after fork,
  before exec -- IPC::Open3 doesn't offer a hook for that directly [ would
  need a manual fork/exec instead of open3, or open3 with a pre-exec
  callback if the installed IPC::Open3 version supports one -- check
  before assuming it doesn't ].
- pts/9 being a real controlling terminal: job-control semantics can
  restrict setpgid in ways they wouldn't for a daemonized/setsid process.
  worth checking whether the whole zenki fleet sharing one controlling
  terminal's pgid (713573) is itself intentional/expected for this
  deployment, or an artifact of how this dev instance happens to be
  started -- changes the right fix.
- `POSIX::setpgid`'s return value is never checked anywhere in
  `coding.spawn_inference_server` -- first step of any real fix is to
  check it and log failures, rather than fixing blind.

## why this has real blast radius (per reviewer, why not fixed inline)

if `-$old_pid` group-kill somehow ever DID start working while the
underlying pgid-sharing problem (whatever it turns out to be) isn't
actually fixed, a wrong pgid resolution could send SIGKILL to a process
group containing OTHER zenki (cube, v7-zenki, everything else running
under the same shared session). any fix needs to positively confirm the
child's actual pgid before trusting a negative-pid kill against it, not
just re-enable the call and assume it now targets the right group.

## scope (next time this is picked up)

1. check `POSIX::setpgid`'s return value at the call site, log on failure
   -- turns this from silent to visible, no behavior change, safe first
   step.
2. root-cause WHY it fails here (the three candidates above, or something
   else) before attempting a fix -- don't guess-fix a process-group bug.
3. once the mechanism is understood, fix so the old-server kill path
   reliably reaches the right pgid alone, and add a real reap/wait after
   the fuser-based fallback kill too (currently has none) so downstream
   vram/state checks aren't racing a not-yet-reaped process regardless of
   which kill path actually terminated it.
4. re-verify the 3-second-per-spawn waitpid timeout this causes today is
   actually gone once fixed (cheap, visible regression check).

## independent live confirmation, 2026-09-08 (unplanned, real production trigger)

happened on its own, unrelated to any deliberate test of this task: a
cat-test failure triggered `[monitor_startup]`'s normal seed-restart
respawn. The old gpu server was killed via the (working) fuser-based
fallback path this task describes, but the very next spawn attempt's vram
check ran before the driver had actually released its VRAM — reported
`free=363 MB` against a 12GB card that should have had most of it free.
`coding.spawn_inference_server`'s new hybrid-offload logic (landed the same
day, see `data/tasks/completed/coding-cpu-and-hybrid-offload-path.md`)
correctly computed `0/32 layers fit` and fell through to the proper
hard-fail rather than attempting a bogus partial spawn — the new code
handled the race correctly, this task's underlying cause is what produced
the race in the first place. Confirming detail: the old pid's SIGCHLD
(`exit=9`, i.e. genuinely SIGKILLed) was logged via
`[inference_server_sigchld]` only AFTER the failed spawn attempt, not
before — direct evidence the reap notification lagged behind the vram
check, exactly the mechanism this task describes. The scheduled 5s retry
succeeded once VRAM had actually settled. No user or test action triggered
this — it is what today's normal restart path already does under
production conditions, not a synthetic reproduction.

## validation

- confirm a spawn's "kill old server" phase no longer burns the full 3s
  timeout when the old process is healthy and killable.
- confirm, live, that the new server's real pgid (via `ps -o pid,pgid`)
  equals its own pid after the fix.
- confirm a kill of an old server does NOT affect any other zenki's pid
  (the actual risk this task exists to avoid).

#,,,.,,..,..,,,,.,,,,,,..,.,.,..,,,..,,.,,,..,..,,...,...,,.,,,,.,,,.,,..,.,,,
#D7QZQN2BW6YTXJTLUQW3TPW6UWEAZB5EDBHW3DJYBGIOAX3U4D3SYKBGF7P4FLSUJK4NBCXNYDX2E
#\\\|MGFRHD52J4ADNGRDCRSGEQOBBESJ3WNSV4U3EKPOOLQ744HHMTI \ / AMOS7 \ YOURUM ::
#\[7]PGGNBHZ2AARYPORFGFTD7POMG5JLA5MULI5OZILJNIQIKULZ4ADY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
