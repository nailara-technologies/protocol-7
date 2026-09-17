## [:< ##

# name  = task: system zenka oom watchdog -- dynamic poll rate, restart-loop
#         escalation, v7-zenki reverse pid lookup
# descr = three real gaps found while scoping this, after the 2026-09-17
#         coding-zenka cpu OOM incident (see bug-coding-cpu-context-oom-
#         forced-wsl-reboot-2026-09-17.md): a flat 7s poll interval in
#         system.process.handler.collect_table that can miss a fast RSS
#         spike, an unconditional restart-on-match with no memory of a
#         prior restart so a genuinely crash-looping child would get
#         restarted forever, and a missing v7-zenki command to resolve a
#         pid to {instance_id, zenka_name} in one call for logging

## why now

2026-09-17: a coding-zenka `llama-server-cpu` child spiked from a few
hundred MB to >12GB RSS in well under a minute (confirmed live via
direct `/proc/<pid>/status` polling during incident response, see the
bug file above). The existing watchdog's single `<mem.max_used>=97%`
threshold (`cfg/zenki/system/zenka.v7:22`) triggers both the log
warning and the autokill decision off the exact same check in
`system.process.handler.collect_table:130-170` -- there is no earlier
signal, and the poll interval powering all of it
(`<process.poll.interval> //= 7`, armed once in
`system.process.post_init:37-43` via `event.add_timer` and never
touched again) is flat regardless of how close to the edge memory
already is. A 7s-granularity check cannot reliably catch a spike that
crosses from safe to 97%+ inside that same window -- this task doesn't
claim to fully solve that (a poll-based watchdog fundamentally can't
guarantee catching an instantaneous spike), but catching it one or two
polls earlier by accelerating under rising pressure is a real,
cheap improvement over a flat interval either way.

**important, so this doesn't get re-investigated**: the "look the pid
up against v7-zenki's managed-process registry before killing, and
restart it instead if it's managed" part of this idea is **already
built and already live**, not new work:
`system.process.autokill` (`src/system.process.autokill`) sends
`cube.v7-zenki.pid-instance` for the target pid, which
`v7-zenki.zenka.cmd.pid-instance` (`src/v7-zenki.zenka.cmd.pid-instance:15-27`)
resolves against BOTH a managed instance's own process id and its
children (`v7-zenki.sub-process.get_children`) -- exactly the
coding-zenka-owns-llama-server-child case. If matched,
`system.process.handler.pid-instance_response:15-25` requests
`cube.v7-zenki.restart` for that instance instead of killing; only an
unmatched pid falls through to `system.process.callback.send_kill`.
Confirmed by reading all three files, not from memory of how it might
work -- do not re-implement this lookup, only extend what already
calls it.

## scope

**1. dynamic/accelerating poll interval**

`system.process.handler.collect_table` already computes
`$mem_used_pct` every cycle. Extend it to re-arm
`<system.process.status_timer>` (same cancel+recreate pattern already
used once at startup in `post_init:37-43`) with a shorter interval as
`$mem_used_pct` rises past a new, lower soft threshold -- and relax it
back toward the flat `<process.poll.interval>` default as usage drops
back below that threshold, so idle/low-memory systems keep the cheap
7s cadence and only pay the tighter polling cost when it's actually
warranted. Needs:
- a new config key (e.g. `mem.accel_threshold`, suggest well below
  `mem.max_used`'s 97 -- something like 80-85% as a starting point,
  not derived from any real data yet, tune after landing) below which
  polling stays at the flat interval
- an interval floor (don't poll faster than some minimum, e.g. 1s --
  polling has its own cost, `Proc::ProcessTable`'s full table walk
  every cycle is not free) and a curve between the two thresholds
  (linear is fine to start; this doesn't need to be exact, just
  monotonic)
- re-arming only when the interval actually needs to change, not
  every single cycle (cancel+recreate on every poll would itself add
  overhead defeating the purpose)

**2. restart-then-terminate escalation memory**

`system.process.handler.pid-instance_response` currently asks
v7-zenki to restart an owned/child process unconditionally on every
match, with zero state carried between calls. Add:
- a per-instance-id (or per-pid, needs a decision -- an instance's
  *pid* changes across a restart, but its *instance_id* doesn't, so
  instance_id is almost certainly the right key) last-restart
  timestamp, likely `<system.process.oom_restart.last>->{$instance_id}`
  or similar, set whenever a restart is actually requested
- on a subsequent match for the same instance_id within some short
  window (needs a number -- suggest starting conservative, e.g. 60s,
  since a real restart-then-immediate-reOOM is the signature of a
  genuine leak/loop, not a legitimate independent memory spike so soon
  after a fresh process start) escalate to
  `system.process.callback.send_kill` (a hard terminate) instead of
  another `cube.v7-zenki.restart`, and log clearly that this was an
  escalation, not a normal autokill, so it's distinguishable later
- decide whether the escalation state should ever self-clear (e.g.
  after some longer quiet period with no further OOM match) so a
  transient double-trigger years apart doesn't permanently pin an
  instance to terminate-only -- likely yes, needs a number

**3. new reverse pid -> {instance_id, zenka_name} lookup command**

Needed so escalation logging (item 2 above) can name the zenka/child
it's acting on without a second round-trip. The data already exists --
`v7-zenki.zenka.instance.add:15-21` stores `zenka_name` on every
instance at creation (`<v7-zenki.zenka.setup>->{$zenka_id}->{'name'}`)
-- this is purely about exposing it.

**Do NOT extend `v7-zenki.zenka.cmd.pid-instance`'s existing reply.**
Its one current caller, `system.process.handler.pid-instance_response:11-13`,
explicitly asserts the reply is pure-numeric
(`$cmd_rep_str !~ m|^\d+$|`) before treating it as an instance id to
restart -- changing that reply shape breaks that caller. Add a
separate new command instead (suggest `v7-zenki.zenka.cmd.pid-lookup`,
mirroring `pid-instance`'s own pid-resolution logic in
`src/v7-zenki.zenka.cmd.pid-instance:15-27`, including the
`v7-zenki.sub-process.get_children` child-pid check, not just the
parent pid):
- input: a pid (same numeric validation as `pid-instance`)
- reply on match: `{ instance_id => ..., zenka_id => ...,
  zenka_name => ... }` (all three -- `zenka_id` is the stable
  zenka-type identifier already in the instance record, `zenka_name`
  the human-readable one, `instance_id` the numeric id `restart` /
  `terminate` already accept)
- reply on no match: same "not managed" signal `pid-instance` already
  uses, so callers can share the same not-found handling

Restart (`cube.v7-zenki.restart`) and stop
(`v7-zenki.zenka.cmd.terminate`) by instance_id are already fully
implemented and don't need anything new -- this item is only the
lookup's reply shape.

## not in scope

- Changing `mem.max_used` (97%) or `mem.kill_min` (11%) themselves --
  those are the existing, working action thresholds; this task only
  adds an earlier *polling-rate* signal and a *how to act* escalation,
  not new action thresholds.
- A true sub-poll-interval spike guard (e.g. a kernel-level cgroup
  memory pressure notification instead of userspace polling) -- raised
  as the real fix for "doesn't fully protect against fast spikes" in
  the bug-file discussion, explicitly not attempted here; poll
  acceleration is a cheaper partial mitigation, not a replacement for
  that if it's ever wanted.
- Re-implementing or auditing the existing v7-zenki pid-instance
  lookup -- see the "already built" note above.

## status [ 2026-09-17 ] — DONE, live-verified, committed `f138268e4`

all three scope items landed via kimi (k2.8) dispatch, same session:
dynamic poll acceleration (`collect_table`), restart-then-terminate
escalation memory (`pid-instance_response`), and the new
`v7-zenki.zenka.cmd.pid-lookup` reverse pid->{instance_id,zenka_id,
zenka_name} command. Live-verified against real pids. See
[[bug-v7-zenki-get-children-registry-gap-2026-09-17]] for a separate,
deeper bug found while live-verifying this (the underlying
`get_children` resolution mechanism itself, fixed same session) and
the access-control gap (`v7-zenki.gone_child` missing from
`access.cmd.usr.coding`) found + fixed one task later.

#,,,.,...,,,.,,,,,,.,,,,,,.,.,.,,,,,,,...,,.,,.,.,...,..,,.,,,..,,,,,,,.,,...,
#OHGCAIZM7ILI6PQI3R3N2BAG7TVVYFS2OM64BTUGFLCJKYAMRYMTLFT7BU57YNX4XIYGDQ3G67QY4
#\\\|B26BEOKFZTYAGNMNK3IJQZYDT367DS3IUMVIQX6IY6QLPXY26UM \ / AMOS7 \ YOURUM ::
#\[7]YO474XMPZVQTFU2HTH75HOOGCUFIDOEPIWXIZF7IUJ6TJFSTUKCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
