## [:< ##

# name  = task: wire up v7-zenki.zenka.cmd.gone_child -- notify on real child exit
# descr = v7-zenki.zenka.cmd.gone_child is implemented and loadable but has
#         ZERO callers anywhere in the tree -- the registration side
#         (report_child_pid/register_child) has no matching "child is gone"
#         notification, so <v7-zenki.child> and each instance's
#         process.child hash only ever grow, never shrink

## why now

scoped immediately after landing
[[bug-v7-zenki-get-children-registry-gap-2026-09-17]] (fixed same
session) -- while that fix makes `get_children` correctly resolve a
grandchild pid via a real kernel ppid-ancestry walk regardless of
registry staleness, the registry itself still accumulates dead pids
forever with nothing to prune them. `gone_child` already exists to do
exactly this cleanup and already re-verifies liveness itself via
`v7-zenki.sub-process.get_ppid` before acting (refuses with "child
still here" if the pid is, in fact, still alive) -- it just has no
caller.

## scope -- ONE hook point, nothing else

`src/coding.handler.inference_server_sigchld` already reaps EVERY
dying child of the coding zenka in its `while ( ( my $pid =
<[base.waitpid]>->(-1) ) > 0 )` loop (`inference_server_sigchld:4`) --
this single loop catches every pid coding ever registers via
`report_child_pid` (confirmed: `report_child_pid`'s only callers
anywhere in the tree are `coding.handler.register_server_children`,
`coding.inference.spawn-server`, `coding.lora_train_spawn`,
`coding.spawn_inference_server` -- all coding-zenka code, nothing
else in the codebase registers a child this way, so this is genuinely
scoped to one zenka).

Add ONE new call inside that reap loop, right after `$reaped++` (or
wherever it makes sense once you're reading the actual current file --
don't assume the exact line number is still 4, re-read it first):

```perl
<[protocol-7.command.send.local]>->(
    {   'command'   => qw| cube.v7-zenki.gone_child |,
        'call_args' => { 'args' => $pid },
    }
);
```

That's the entire functional change. Mirror the existing
`report_child_pid` call's style (same file uses
`<[protocol-7.command.send.local]>` extensively already for other
things -- match existing conventions in the file, don't invent a new
pattern).

## explicitly out of scope -- do not investigate or touch these

- Any OTHER zenka's spawn/reap code. `report_child_pid`'s callers are
  ALL in `coding.*` -- confirmed via `grep -rn report_child_pid src/`
  before this task file was written. Do not go looking for other
  zenki that might also want this; that's a separate task if it ever
  comes up.
- `v7-zenki.sub-process.get_children`, `base.exists.sub-process`,
  `v7-zenki.sub-process.pid_alive`, or anything else touched by
  [[bug-v7-zenki-get-children-registry-gap-2026-09-17]] earlier this
  session -- that's DONE, committed, working. Don't re-investigate it,
  don't re-verify it, don't touch it.
- `v7-zenki.process.instance_cache` (set by `gone_child` itself,
  marked "require clean-up" in its own source) -- what consumes that
  cache, if anything, is out of scope. Don't chase it.
- `system.cmd.pid_autokill` or ANY command whose name you don't
  recognize from this task file. A previous dispatch this session
  burned its entire step budget investigating an unrelated command it
  stumbled onto while trying to verify something -- if you find
  yourself reading a file not named anywhere in this task file, stop
  and reconsider whether you've drifted off scope.

## verification

Live-test it: after landing the change, `coding.reload`, then trigger
a real cpu-backend respawn (`coding.switch-model "<any known amos_id>
backend=cpu"` -- check `state/model_status.yaml` or ask if you need a
candidate checksum) to get a real pid registered, note that pid, kill
it (or let a normal respawn cycle replace it), and confirm via
`v7-zenki.pid-lookup <the now-dead pid>` that it correctly returns
"found no matching instance" afterward (not because the ppid-walk
naturally excludes a dead pid -- that would happen either way -- but
check `v7-zenki.instance_pids <coding's instance id>` no longer lists
it, confirming actual de-registration happened, not just correct
resolution of a still-registered-but-dead entry). Also confirm nothing
broke: the coding zenka's own crash-restart behavior (already working,
tested extensively earlier this session) should be unaffected --
`gone_child` failing or not existing was never fatal before, so this
is purely additive, but confirm no new errors appear in coding's logs
after a normal respawn cycle.

`bin/format-code -c` the touched file before finishing, same as every
other module in this repo. Leave the working tree uncommitted --
report back with what changed and how you verified it.

## status [ 2026-09-17 ] — DONE, live-verified, committed `b73f67e83`

kimi (k2.8) landed the single hook-point call exactly as specified.
Live-verifying it same session surfaced a real access-control gap
(`v7-zenki.gone_child` missing from `access.cmd.usr.coding` --
`cube` was silently rejecting every call) -- fixed separately,
committed `757477f66`, and confirmed end-to-end: killing a real cpu
server pid now correctly de-registers it (`v7-zenki.instance_pids`
no longer lists it), a fresh respawn correctly re-registers.

#,,,,,,.,,..,,,,,,.,.,,.,,,,,,,,.,,,,,,.,,.,,,.,.,...,...,.,,,..,,.,,,.,,,,,.,
#65BKHWJJNDYKWAZHURREXP4VBD4BELKBBPXSDBITETZLSWEUQ7AOQGKQ6OHPGXHXPFSSNYR7ZVLL6
#\\\|7R62TFDELSGL2G7F5LCMPHII3RCULXJMJ7J3DK5WRLP7D2LD4LV \ / AMOS7 \ YOURUM ::
#\[7]SE4T3VOMXOIEDNBRGY4D6CVUKVB2FLGANKU74CTL4GKTNNIXX2AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
