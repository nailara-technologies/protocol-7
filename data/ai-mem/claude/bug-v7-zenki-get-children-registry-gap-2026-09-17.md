---
name: bug-v7-zenki-get-children-registry-gap-2026-09-17
description: FIXED -- v7-zenki.sub-process.get_children's waitpid-based liveness check could only ever see v7-zenki's own direct children, never a grandchild like a coding-zenka llama-server; fixed with a scoped pid_alive helper for just that one loop, leaving the security-relevant waitpid check and its 18+ other callers untouched, plus a real ppid-ancestry-walk distinction that mattered for a self-report-spoofing concern the user caught before the first fix attempt shipped
metadata:
  type: project
---

**STATUS: FIXED + live-verified, same session.**

Found live-verifying [[project-system-oom-watchdog-dynamic-poll-and-restart-escalation]]'s
kimi-dispatched implementation: `v7-zenki.zenka.cmd.pid-lookup` (the new
command) returned "found no matching instance" for a real, live
`llama-server-cpu` pid (7766) that is a genuine, confirmed direct child of
the coding zenka (`/proc/7766/status` `PPid: 2311`, coding zenka's real
pid). **Confirmed NOT a regression from the new code** -- the existing,
unmodified `v7-zenki.zenka.cmd.pid-instance` command fails identically
against the same pid, and both share the same underlying resolution call,
`v7-zenki.sub-process.get_children`.

**Traced the registration path, confirmed it SHOULD work**:
`coding.spawn_inference_server:726` calls
`<[base.zenki.report_child_pid]>->($pid)` unconditionally on every spawn
(cold start and every crash-restart respawn alike) -->
`base.zenki.report_child_pid` pushes onto `<system.report_children>` and
fires `base.callback.report_children` --> sends `v7-zenki.register_child`
with `"$child_pid $parent_pid"` --> `v7-zenki.zenka.cmd.register_child`
matches `$parent_pid` against a registered instance's own pid (2311 IS
present in `<v7-zenki.zenka.instance>`, confirmed via
`v7-zenki.instance_pids` listing it), then sets
`<v7-zenki.child>->{$child_pid}` and
`<v7-zenki.zenka.instance>->{$id}->{'process'}->{'child'}->{$child_pid}`.
Every step in this chain looks correct on read-through. Yet
`get_children`'s "old method" walk (`v7-zenki.sub-process.get_children:20-28`)
requires `defined <v7-zenki.child>->{$proc->{'pid'}}` to even consider a
live `Proc::ProcessTable` pid as a candidate, and 7766 fails that check
live.

**ROOT CAUSE FOUND + FIXED, same session, after the user picked this back
up via live debugging (manual `v7-zenki.register_child` call returned "was
known" -- proving the registration data was genuinely already correct, not
racing/missing at all -- which pointed straight at the retrieval side).**

`base.exists.sub-process` (`src/base.exists.sub-process:16-22`) checks
liveness via `waitpid($pid, WNOHANG)` -- a real POSIX syscall that, by
kernel design, can ONLY succeed for a process's own DIRECT children.
`get_children` runs inside v7-zenki's own process, and a coding-zenka
spawned `llama-server-cpu` is v7-zenki's GRANDCHILD (child of coding, not
of v7-zenki) -- so this check could never succeed for it, full stop,
regardless of whether the registration was honest or stale. Not a race,
not a config issue: a structural mismatch between the liveness primitive
used and what the caller actually needed to check.

**User confirmed this specific limitation was known/intentional at
design time** (not an oversight) -- the waitpid-based check was a real,
deliberate security property for its actual purpose, just never extended
to cover the grandchild case, which was a known, accepted gap until now.

**The real security nuance, caught by the user before I shipped a naive
fix**: `v7-zenki.zenka.cmd.register_child` trusts a reporting zenka's own
claim of `$parent_pid` with NO independent OS-level check (by design, to
sidestep a real race -- see its own module comment). So a compromised or
buggy zenka could `report_child_pid()` an arbitrary FOREIGN pid that isn't
really its child at all, and the registry would just believe it. My first
proposed fix (swap the liveness check for `kill(0,$pid)` everywhere
`base.exists.sub-process` gates `get_children`) would have let a spoofed
foreign pid sail through on the "new method" path
(`v7-zenki.instance_child_pids`-based), which has ZERO independent
ancestry verification of its own -- it just trusts the self-report + a
liveness check. That would have been a real security regression.

**Actual fix, scoped precisely once the two paths' real properties were
understood**:
- The "old method" (`Proc::ProcessTable` walk, `get_children:13-42`)
  ALREADY has the real security boundary : `$ppids{$pid} == $chk_pid`,
  built from `Proc::ProcessTable`'s genuine kernel `ppid` field, which a
  reporting zenka cannot fake. The self-reported `<v7-zenki.child>` hash
  only gates which pids are even CONSIDERED (a candidate list), never
  proves ancestry by itself -- the ppid walk does that. Its ONLY bug was
  the liveness pre-filter excluding real grandchildren before they ever
  reached that already-correct walk. Fixed by adding a new, narrowly-
  scoped helper, `v7-zenki.sub-process.pid_alive` (`-d "/proc/$pid"`,
  same pattern this file's own sibling `get_ppid` already uses), used
  ONLY inside this loop -- `base.exists.sub-process` itself, and its
  other 18+ callers (several security-relevant, `sessions.*`/
  `cred-mesh.*`), are completely untouched.
- The "new method" (`instance_child_pids`-based, `get_children:68-94`)
  has NO independent ancestry check at all -- for `$chk_pid`'s OWN direct
  children (what it's actually for), `waitpid`'s kernel-enforced "really
  my own child" property WAS the real protection, not incidental.
  Deliberately left untouched, still `base.exists.sub-process`-gated --
  it still can't resolve grandchildren (same waitpid limit as before),
  and that's fine: the old method now handles that case correctly with
  its real ppid-walk intact. Activating this path for grandchildren
  would have reopened exactly the self-report-spoofing gap above.

**Live-verified, both positive and negative cases**: `v7-zenki.pid-lookup`
AND the original, untouched `v7-zenki.pid-instance` both now correctly
resolve a real, live `llama-server-cpu` grandchild pid (confirmed via
`/proc/<pid>/status` PPid) to the coding instance;
`v7-zenki.instance_pids <coding-instance>` now correctly lists all three
real children (the zenka's own pid + both gpu/cpu llama-server pids).
Negative case: an unrelated, genuinely-alive-but-never-registered pid
(this session's own `claude` process) still correctly returns "found no
matching instance" -- the registration gate alone excludes it before
liveness/ancestry are even considered, confirming the fix didn't make
`get_children` promiscuous.

**Impact**: this directly undermines
[[project-system-oom-watchdog-dynamic-poll-and-restart-escalation]]'s
motivating scenario -- the restart-instead-of-kill (and now also
restart-then-terminate-escalation) path only fires for a pid `v7-zenki`
can actually resolve to a managed instance. For coding-zenka's own
llama-server children specifically, right now, that resolution silently
fails and any OOM-triggered match on such a pid would fall through to a
plain kill instead of the intended restart/escalation path -- exactly the
kind of gap the original three-part idea was meant to close, still open.
The new code kimi wrote is not at fault: it faithfully mirrors
`pid-instance`'s existing (equally affected) resolution logic, syntax-
valid, live-loads cleanly, config keys landed with sensible defaults --
this is a separate, deeper, pre-existing defect in `get_children` itself.

#,,.,,,.,,.,.,,.,,..,,,..,...,.,.,,.,,,,,,,..,.,.,...,..,,,,.,,..,,,,,,..,...,
#5C5CK33M2EMBRESPD4X4OG3FRQHYVVVLCQPCDU5BD7PUX3Y7Y5U3WC5HUIVR57VCUPUAOV4ZDW72K
#\\\|ES6IE2VMSWX2EV3Q7NLCOH5L23MLXLBTQ6J444XNP2FPSRVNTGD \ / AMOS7 \ YOURUM ::
#\[7]DG22RASWNJMESVU2UU6YA33BAG4KZ5E2C3V3EEN7NL4E5GTM3CAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
