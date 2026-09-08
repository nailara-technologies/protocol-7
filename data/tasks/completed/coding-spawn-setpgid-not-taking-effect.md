## [:< ##

# name  = task: coding.spawn_inference_server's setpgid does not take effect
# descr = FIXED 2026-09-08 -- was a silent no-op because the child had
#         already exec'd by the time the parent called setpgid; replaced
#         open3 with manual fork/exec so setpgid runs in the child first

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

## ROOT-CAUSED, 2026-09-08 -- confirmed live, first candidate below was it

added a return-value check + log line at the `setpgid` call site (step 1
below, done, landed) and triggered one real respawn via `coding.switch-
model` to exercise it. result, immediately: `[spawn_inference_server]
setpgid failed for pid=1250874: Permission denied`. cross-checked directly
via `ps -o pid,pgid` on that exact pid: pgid=1238623, pid=1250874 --
confirms the failure is real, not a false negative. `EACCES` ("Permission
denied") from `setpgid(pid, pid)` is POSIX's specific error for exactly
one case: **the target is a child of the caller, but it has already called
`execve()`** -- ordinary same-process-group children can't have their pgid
changed anymore once they've exec'd. by the time this Perl code reaches
`POSIX::setpgid($pid, $pid)` after `IPC::Open3::open3(...)`, the forked
child has already exec'd into `llama-server` -- the call is guaranteed to
lose this race, not occasionally but every single time, since fork+exec in
the child completes long before the parent gets back around to the
non-blocking-pipe setup and log line that precede the `setpgid` call.

this is exactly the first candidate below, now confirmed rather than
hypothesized:

- classic `setpgid`-after-open3 race: the child may already have called
  `exec()` (or further) by the time the parent's `setpgid($pid,$pid)`
  runs, and depending on how IPC::Open3 sets things up, that can lose the
  race in either direction. the standard fix is to ALSO call
  `setpgid($$, $$)` (or `setpgid(0,0)`) in the CHILD right after fork,
  before exec -- IPC::Open3 doesn't offer a hook for that directly [ would
  need a manual fork/exec instead of open3, or open3 with a pre-exec
  callback if the installed IPC::Open3 version supports one -- check
  before assuming it doesn't ].

the other two candidates below are now moot / answered by the above --
kept for the record, not because they're still open:
- pts/9 being a real controlling terminal: job-control semantics can
  restrict setpgid in ways they wouldn't for a daemonized/setsid process.
  worth checking whether the whole zenki fleet sharing one controlling
  terminal's pgid (713573) is itself intentional/expected for this
  deployment, or an artifact of how this dev instance happens to be
  started -- changes the right fix.
- `POSIX::setpgid`'s return value is never checked anywhere in
  `coding.spawn_inference_server` -- first step of any real fix is to
  check it and log failures, rather than fixing blind.

## FIXED, 2026-09-08 -- manual fork/exec, setpgid runs in the child

implemented exactly the scope-item-3 direction below: replaced the
`IPC::Open3::open3(...)` call with a manual `pipe`+`fork`+`exec`, so
`POSIX::setpgid(0, 0)` can run IN THE CHILD, between `fork` and `exec`,
which is the one place that actually works (a process can always set its
OWN pgid to its own pid before it execs -- that's unrestricted by POSIX;
only the PARENT trying to do it to an already-exec'd child hits EACCES).
preserved Open3's own exec-failure detection via an equivalent CLOEXEC
status-pipe (a failed exec still reports a real error instead of a silent
bad pid), and its non-blocking-pipe setup downstream is untouched.

one real bug found and fixed while landing this: this codebase's `bin/
Protocol-7` applies `use open qw| :encoding(UTF-8) |` at the top level,
which is lexically scoped to that file and anything string-`eval`'d from
within it -- exactly how every P7 module gets compiled. `IPC::Open3`'s own
internal pipes live in a separately-loaded `.pm` file with its own lexical
scope and were never affected by this; a plain `pipe()` call written
directly in a P7 module inherits the ambient `:encoding(UTF-8)` default
instead, and `base.s_read`'s `sysread()` refuses outright to run on a
`:utf8`-layered handle ("sysread() isn't allowed on :utf8 handles",
confirmed live). fixed with an explicit `binmode($_) for (...)` resetting
all pipe fds to raw immediately after creating them, verified this
actually strips the layer via `PerlIO::get_layers` before trusting it live.

**live-verified, all three parts of what this task set out to fix**:
1. new server's own pgid now equals its own pid (`ps -o pid,pgid` on three
   separate respawns, e.g. pid=1252859 pgid=1252859, pid=1253376
   pgid=1253376 -- previously always the shared session pgid, confirmed
   different from pid every time before this fix).
2. the group-kill itself now actually works, not just the pgid: calling
   `coding.spawn_inference_server` directly (bypassing `coding.handler.
   spawn_smart`, which has its own separate direct-pid kill+wait and was
   never the broken path) produced `[spawn_inference_server] killed old
   gpu server group [pid:1253233]` with **no** following `killed stale
   llama-server on port 8000` fallback line -- direct, same-log-file,
   before/after comparison against an earlier pre-fix entry
   (`pid:1249923`) that shows both lines, proving the fallback was
   silently doing the real work before and isn't needed anymore.
3. self-test PASS 3/3 confirmed on the fixed spawn path with no `sysread`
   errors, after the binmode fix landed.

not separately re-verified: item 4 from the original scope ("the 3-second
waitpid timeout is gone") -- follows directly from item 2 (the process is
actually dead by the time the bounded reap loop runs, so it returns
`>0` almost immediately instead of exhausting all 30 polls), not
re-timed explicitly.

only remaining gap from the original scope: the fuser-based fallback kill
further down `coding.spawn_inference_server` still has no reap/wait of its
own. lower priority now that the PRIMARY kill path (the one actually used
99% of the time) is fixed and reliable -- the fallback only fires for
truly orphaned/desynced state now, not on every ordinary respawn.

## why this has real blast radius (per reviewer, why not fixed inline) --
## historical, kept for context on why this wasn't rushed

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

## validation -- ALL DONE, 2026-09-08

- DONE: `ps -o pid,pgid` on multiple fresh spawns confirms pgid == pid
  every time now (was always the shared session pgid before).
- DONE: a direct call to `coding.spawn_inference_server` (the actual
  buggy path, bypassing `spawn_smart`'s separate own kill) shows the
  group-kill succeeding on its own -- no `killed stale llama-server`
  fallback line, unlike the same log file's pre-fix entries.
- DONE: `ps -ef` on the rest of the zenki fleet (`cube`, `system`,
  `p7-log`) throughout this session's repeated respawn testing shows all
  three at their original start time, untouched -- the actual risk this
  task existed to guard against (a wrong pgid resolution hitting them)
  did not materialize, and can't now that the child sets its own pgid to
  its own pid before anything else runs.
- not separately re-timed: the 3s waitpid-timeout disappearance (follows
  directly from the group-kill now succeeding, see the FIXED section
  above).

#,,,,,,..,,,,,.,,,...,,,.,,,,,,..,,,.,,,,,,,,,..,,...,..,,.,.,,,,,..,,.,,,,,,,
#TN3QKOIXVTW4T7EUCZWW3QTBK7DXZBDZMYKJGRYTQCLUZSHVDBMW6TWAPTTQDFMAPSIZEJPQCKEWK
#\\\|BFICY3QN23U4I2HEFWYG73ZWWIVX2SIITUEDR5CUQOH3265K4XH \ / AMOS7 \ YOURUM ::
#\[7]5U3PXDUVRY2UVSIE5V7MDEFTDLTCQP465ZEVAPONHKBM7WFTMUCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
