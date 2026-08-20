# task: generic "my dependency restarted, reconnect" primitive

## background

Two unrelated subsystems in this codebase have the same unsolved gap: a zenka establishes a
stateful relationship with another zenka (a STRM subscription, or an SHM handshake), that
*other* zenka later restarts while the first one keeps running, and nothing re-establishes the
relationship. Found in the same session, independently:

**1. STRM subscriptions** — `src/base.strm.subscribe` (generic offline-safe subscribe
wrapper, `data/tasks/completed/strm-generic-subscribe-wrapper.md`) already handles "subscriber
restarts, publisher already up" and "publisher not up yet, comes up later via backoff retry" —
both tested and working. Its own doc header says explicitly:

> the publisher-restart re-affirm case is deliberately left open ... the persistent
> `<base.strm.subscribe.registry>` entry keeps the full subscription description around after
> success, so a future re-affirm hook ... can re-issue the attempt as-is.

**2. SHM handshakes** — `protocol-7-menu` reads mouse pointer coordinates from a shared-memory
segment that `powershell.pointer-stream` creates. The handshake
(`protocol-7-menu.pointer-stream-init` → `powershell.pointer-stream` starts the hook + creates
shm → reply → `protocol-7-menu.handler.pointer-stream-start` → requests the path →
`protocol-7-menu.handler.pointer-stream-path` → `AMOS7::SHM::shm_open` + mmap) runs exactly once,
at `protocol-7-menu`'s own `init_code`. If `powershell` restarts later, its
`<powershell.pointer.pid>` state resets, presumably the old shm segment gets unlinked, and
`protocol-7-menu` (still running) keeps holding a stale `<protocol-7-menu.pointer.shm_ptr>` into
now-orphaned memory. Nothing re-triggers the handshake since only `powershell` restarted, not
`protocol-7-menu`.

## what's already available to build on

- `src/v7.zenka.cmd.notify_online` — reply-once-when-online request. Confirmed this session:
  strictly one-shot, the registration is `delete`d the moment it fires
  (`src/v7.handler.zenka_status:287,386,422`). It tells you "X just came online" but by
  itself can't distinguish first-ever-startup from a restart of something already running, and
  doesn't persist for future restarts unless the caller re-registers after every fire.
- Zenka instance restarts already get a fresh `instance_id` (used throughout this session's own
  `present since` / session-id checks to distinguish "same process, still running" from "this
  restarted"). A `notify_online` fire where the returned/associated `instance_id` differs from
  the last-known one for that zenka name is a reliable restart signal — a same-instance
  "already online" fast-path reply (see the early-return branches in
  `v7.zenka.cmd.notify_online`) is NOT a restart.
- `AMOS7::SHM.pm`'s header format (`pack_shm_header`/`unpack_shm_header`,
  `data/lib-path/pm/AMOS7/SHM.pm:66-132`) embeds a `created` timestamp in every segment. A
  consumer that recorded `created` at open-time can detect a segment replacement by comparing
  against a *fresh, independent* open+header-read later (not through the already-held mmap —
  once a segment is unlinked and recreated, an existing mmap keeps pointing at the orphaned old
  pages and will never see the new header).
- `base.zenka.push` (`src/base.zenka.push`, referenced as the shape `base.strm.subscribe`
  mirrors) is a third existing "push-with-backoff-and-restart-awareness" pattern in this
  codebase — read it too, it may already have solved pieces of this for its own use case.

## the actual task

Design and build a generic "notify me when zenka X restarts" primitive, then wire it to close
both gaps above. Suggested shape (not prescriptive — use judgment, this is exactly the kind of
design decision worth getting right rather than rushing):

1. **Core primitive**, likely `v7`-side (it already tracks instance_id/status transitions
   authoritatively): a persistent (not one-shot) registration — "call this handler whenever
   zenka X's instance_id changes while X remains known" — as opposed to `notify_online`'s
   one-shot "tell me once it's up." Consider whether this belongs in `v7.handler.zenka_status`
   directly (it already has all the instance-id/status-transition information at the exact
   moment a restart is detected) or as a wrapper around repeated `notify_online` registration
   with instance-id-diffing built in.
2. **STRM side**: wire `base.strm.subscribe`'s persistent registry entries to the new primitive
   — on a detected publisher restart, re-issue the subscribe attempt as-is (the registry already
   keeps everything needed, per its own doc comment).
3. **SHM side**: build the consumer-facing piece, likely as a `base.shm.*` wrapper mirroring
   `base.strm.subscribe`'s registration shape (a zenka calls it once with
   `{ publisher, path/command-to-refetch, on_stale handler }`), using the new restart-notify
   primitive to trigger a re-handshake. Migrate `protocol-7-menu`'s pointer-stream handshake onto
   it as the pilot/proof case.
4. Decide whether `AMOS7::SHM.pm` needs its own staleness-detection helper (comparing `created`
   via a fresh independent read) as a defense-in-depth check, or whether the v7-level
   restart-notify primitive alone is sufficient signal and polling the segment itself is
   unnecessary belt-and-suspenders. Use judgment — don't build both layers if one demonstrably
   covers the real failure mode.

## don't

- Don't build a SHM-specific polling mechanism as the *only* signal if the v7-level
  restart-notify primitive can be made to cover it generically — the whole point is one shared
  mechanism, not two parallel ones for STRM vs SHM.
- Don't touch `graphics-matrix`/`nodes`/`discover`/`external`/`radio`/`X-11`/`ticker`'s STRM
  producer code from this session's earlier fix (`a4fdfa300`) — that's a different, already-
  closed problem (producer-side push-fail cleanup), not the publisher-restart re-affirm gap this
  task addresses.

## verification

- live-test both directions: `powershell` restart while `protocol-7-menu` stays running should
  now re-establish the pointer stream automatically (no manual re-trigger needed) — this is the
  concrete bug that started this investigation.
- if the STRM re-affirm wiring is completed too, live-test a publisher restart (e.g. `cred-mesh`,
  the wrapper's original tested pair with `proxy`) while the subscriber stays running.
- regenerate whitelists for any zenki touched (`bin/dev/gen-sub-whitelist <zenka>`).

## signatures note

module files have a 4-line AMOS7 signature footer — do not reproduce or invent these. leave
new/edited files without a footer; the signing tool adds it. existing signatures on files you
don't touch must not be modified.

## dispatch notes

- this is real architecture/design work, not mechanical implementation of an already-decided
  fix — dispatch to `claude_dispatch model=opus`, not kimi, given the cross-cutting design
  judgment required
- read `data/tasks/completed/strm-generic-subscribe-wrapper.md` in full before starting — it has
  the full context on `base.strm.subscribe`'s existing design, testing methodology, and exactly
  what was left open and why
- root-cause trail: found this session while live-testing the STRM idle-shutdown fix
  (`a4fdfa300`) prompted a broader check of restart-resilience, which surfaced the
  `protocol-7-menu`/`powershell` pointer-stream gap as a second, independent instance of the same
  underlying architectural hole

#,,,.,,,.,.,.,.,.,..,,,.,,,,,,..,,,..,,,.,,.,,..,,...,...,.,.,..,,,,,,,,.,.,,,
#ZREZEKUNIA7PQROHTPDM2PNW6QEPN3GHTYGRQNV7L4PHV3T7Y7CQOFXJPT6XWTA2NZIEORQUZKMEE
#\\\|DJZTOTPSQ6BLAF7FGFFSY7LOYFYO5KD53RVHHYPVQOVF4M4V27V \ / AMOS7 \ YOURUM ::
#\[7]QTQV43BUZQ66BTSF7E5ESKH7557BKCLSM5KK4KBMVPHIGFNRL6AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
