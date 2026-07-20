---
name: dependency-restart-reconnect-primitive
description: "new generic v7.notify_restart + base.zenka.on_restart primitive lets a running zenka detect when a dependency it already has a stateful relationship with (STRM subscription, SHM handshake) restarts and re-establish it automatically; Opus's first pass used instance_id as the restart signal, which is wrong (v7.zenka.instance.restart reuses the same instance_id in place) -- corrected to cube_sid, which changes on every restart, both in-place and idle-shutdown-then-fresh-start"
metadata:
  node_type: memory
  type: project
  modified: 2026-07-21
---

## background

Two unrelated subsystems had the same gap: a zenka establishes a stateful relationship with
another zenka (a STRM subscription via [[ondemand-idle-timeout-active-streams]]'s
`base.strm.subscribe`, or an SHM handshake for `protocol-7-menu`'s mouse-pointer read from
`powershell`'s `pointer-stream`), the *other* zenka restarts while the first keeps running, and
nothing re-establishes the relationship. `base.strm.subscribe`'s own docs flagged this explicitly
as "deliberately left open." Found independently for the SHM case this session: `protocol-7-menu`
stops reflecting pointer movement after `powershell` restarts, with no reconnect.

## design (dispatched to claude_dispatch model=opus, `data/tasks/dependency-restart-reconnect-primitive.md`)

- `modules/v7.zenka.cmd.notify_restart` — persistent (not one-shot, unlike `v7.zenka.cmd.
  notify_online`) restart-notify request; records a baseline identifier at registration time,
  fires once a *different* value shows up on the next online transition for that zenka name.
- `modules/v7.handler.zenka_status` — fires all pending registrations for a zenka whenever it
  transitions to `online`/`extbin`, comparing against the recorded baseline; deletes fired
  entries (caller must re-register to keep watching).
- `modules/base.zenka.on_restart` + `.reply-handler` — consumer-facing wrapper, mirrors `base.
  strm.subscribe`'s registration shape: `<[base.zenka.on_restart]>->({publisher=>..., handler=>
  ...})`. The reply-handler fires the registered `%code` sub(s) then **immediately re-registers
  itself** — this is what makes the primitive persistent across unlimited future restarts, not
  just the first one, without the caller having to do anything after the initial registration.
- `protocol-7-menu.pointer-stream-init` migrated as the pilot: registers itself
  (`{'publisher'=>'powershell', 'handler'=>'protocol-7-menu.pointer-stream-init'}`) so the exact
  same function that does the initial handshake also serves as its own reconnect handler.

## the bug in Opus's first pass, found by live-testing (not just code review)

Opus's design tracked `instance_id` as the restart-detection baseline (`at_iid` field) — matching
the intuition "a restart should get a new instance_id," and matching how this session's earlier
`present since` / session-id checks worked for identifying *fresh starts*. Live-tested twice with
`v7.start powershell` after a full idle-shutdown (instance fully removed from `<v7.zenka.
instance>` first) — worked both times, hash ref and shm_ptr both changed as expected.

Then tested `v7.restart powershell` (the actual common case, restarting while running) — **did
not fire**. Confirmed via `git`-style live inspection: `modules/v7.zenka.instance.restart` (called
by `v7.zenka.cmd.restart`) operates on the *same* `$instance_id` throughout — it's an in-place
restart of the existing tracked instance slot, not a remove-and-recreate. So `instance_id` never
actually changes across a `v7.restart`, and the whole "fire when instance_id differs" check
silently never fires for the single most common restart path.

**What does reliably change on every restart**, live-confirmed directly (`v7.list zenki` /
`list sessions` before and after a `v7.restart`): `cube_sid` (the cube session id tracked per
instance) changes every time, both for in-place `v7.restart` and for idle-shutdown-then-fresh-
`v7.start`. Fix: swap the tracked baseline from `instance_id` to `$instance->{'cube_sid'}`
(renamed `at_iid`→`at_sid` throughout `v7.zenka.cmd.notify_restart` and `v7.handler.zenka_status`)
— same architecture, corrected identifier. `cube_sid` is set early in `v7.zenka.set_cube_sid`
(during instance verification, before the `online` transition that triggers our firing check), so
it's reliably populated by the time the comparison runs.

## live verification (both directions, repeated)

Two consecutive `v7.restart powershell` cycles, each independently confirmed via direct MCP
`p7_command` state inspection (not just visual/log observation): `v7.zenka.notify_restart.
powershell`'s hash reference changed each time (fired + re-armed), and `protocol-7-menu.pointer.
shm_ptr`'s scalar reference changed each time (fresh `shm_open`/mmap). User confirmed visually
that translucency-from-pointer-position resumed immediately after each restart, with log evidence
showing the full chain firing within the same second as `powershell`'s `[initialized]` line:
`pointer-stream-path : shm open : ...` → `pointer-stream : started [pid ...]` → `granted read`.

## STRM side (base.strm.subscribe's own "still open" gap) — NOT wired this session

Only the SHM/`protocol-7-menu` pilot got migrated. `base.strm.subscribe`'s publisher-restart
re-affirm case is still open — the new `v7.notify_restart`/`base.zenka.on_restart` primitive
could close it the same way, but that wiring wasn't attempted here. Worth a follow-up if/when a
concrete STRM-side symptom shows up (same pattern as this session: `base.strm.subscribe`'s
persistent registry entry already keeps everything needed to re-issue the subscribe attempt
as-is, per its own doc comment).

## process note

This dispatch (`claude_dispatch model=opus`) hit the same MCP-bridge-timeout-≠-failure pattern
documented for kimi dispatches ([[topic-kimi-dispatch-infra-hardening]]) — the tool call reported
`status=failed` after ~1800s, but the underlying `claude` subprocess was still alive and had
already written real, correct code to disk. Confirmed via `ps -p <pid>` + `git status` directly
rather than trusting the failure label — same lesson, now confirmed to apply to `claude_dispatch`
as well as `kimi_dispatch`, not just a kimi-specific quirk.

## related

[[ondemand-idle-timeout-active-streams]] · [[topic-kimi-dispatch-infra-hardening]]

#,,,,,.,.,,,.,...,,..,...,.,.,.,,,,..,,,.,,..,..,,...,..,,...,.,.,.,.,...,..,,
#I3JFQJKJIQAMTYKDOFH2CWTDXX3JAG3QQXU4NQJEUVJNEKFWENXUNBSQ6SN4L4D54ZN3G67SLOSZY
#\\\|XQSCISW7UOSZ6BLGUTNICRZK3JJ4MIM7GKI3HT772MZLCTLFW7S \ / AMOS7 \ YOURUM ::
#\[7]UGTMZUWLUYCFJO42VXLU4LEGFENK2UHQW5JN2HKVN7TVUIGZBQDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
