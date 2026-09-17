---
name: bug-v7-zenki-get-children-registry-gap-2026-09-17
description: v7-zenki.sub-process.get_children fails to find a coding-zenka llama-server child even though it is genuinely registered via base.zenki.report_child_pid at every spawn -- undermines the restart-instead-of-kill escalation feature's flagship use case, root cause not yet found, stopped investigating deliberately to respect token-budget pacing
metadata:
  type: project
---

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

**Root cause NOT found.** Candidate directions, none confirmed: the
registration reply legitimately racing/failing for a specific spawn; some
cleanup-on-respawn path clearing `<v7-zenki.child>`/the instance's
`process.child` sub-hash without the next spawn's registration actually
landing after it; or a `<v7-zenki.instance_ids>`/timing edge specific to
this session (the coding zenka's cpu backend was killed and respawned via
`coding.switch-model` many times during tonight's OOM incident response --
worth checking whether a FRESH single spawn, never previously respawned
this session, resolves correctly, which would point at something respawn-
specific rather than the registration path itself).

**Deliberately stopped investigating here** rather than chasing this
further, per [[feedback-token-budget-pacing-early-week]] -- this is
exactly the shape of rabbit hole that ate the entire step budget of the
kimi_dispatch session that surfaced it (session `87bd49f9-8324-4f97-8e3b-
47033bd03286` hit its 100-step ceiling chasing an UNRELATED command,
`system.cmd.pid_autokill`, apparently while trying and failing to
understand why ITS OWN new pid-lookup command couldn't find a live pid --
never correctly diagnosed the real gap documented here).

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

#,,,.,..,,.,,,,,,,,.,,..,,..,,,.,,,,.,.,.,..,,.,.,...,...,,..,.,,,,,.,,,.,...,
#6J7YBTDNRD572Y6F6LGRMJ4PRS7LCV2B7RDBGXQ6YWWGQ7YJFYESTFCZY6LJX4WYI2C4UVPHVOXRW
#\\\|QNGZXCL5PMBPZO5KNQZGTXGRJAJ4X3DH2VJLYUOG7QGNPVTT4RZ \ / AMOS7 \ YOURUM ::
#\[7]TUXUWAZWIYEUDDBNJRMGPSIRMHB2UIJ4WAAV63YYEXEE6FZLPUAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
