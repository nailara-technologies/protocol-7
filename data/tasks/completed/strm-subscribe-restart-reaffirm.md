# task: wire base.strm.subscribe's publisher-restart re-affirm using the new primitive

## background

`src/base.strm.subscribe` (generic offline-safe STRM subscription wrapper,
`data/tasks/completed/strm-generic-subscribe-wrapper.md`) has always had one gap, documented in
its own header comment:

> the publisher-restart re-affirm case is deliberately left open ... the persistent
> `<base.strm.subscribe.registry>` entry keeps the full subscription description around after
> success, so a future re-affirm hook ... can re-issue the attempt as-is.

That hook now exists: `src/v7.zenka.cmd.notify_restart` + `src/base.zenka.on_restart` /
`.reply-handler` (`data/tasks/completed/dependency-restart-reconnect-primitive.md`,
`data/ai-mem/claude/project-dependency-restart-reconnect-primitive.md` — read both for full
context and the live-verification methodology already established). It's a persistent
(self-re-arming), restart-detecting registration primitive: a zenka calls
`<[base.zenka.on_restart]>->({'publisher'=>..., 'handler'=>...})` once, and the named `%code` sub
gets invoked every time that publisher zenka restarts, forever, with zero further action needed
from the caller. Already live-verified working across repeated `v7.restart` cycles for a
different pilot case (`protocol-7-menu`'s SHM pointer-stream handshake).

**Important, hard-won correctness note**: the primitive's restart-detection is keyed on
`cube_sid`, not `instance_id` — `v7.zenka.instance.restart` reuses the same `instance_id` in
place across an explicit `v7.restart`, only `cube_sid` reliably changes on every restart (both
in-place `v7.restart` and idle-shutdown-then-fresh-`v7.start`). This was found and fixed by
live-testing, not code review — the first implementation (tracking `instance_id`) looked correct
and passed a narrower test (restart-after-full-idle-shutdown) but silently failed on the far more
common `v7.restart` case. **Do not re-derive this from scratch — trust the existing primitive as
already correct**, this task is purely about wiring `base.strm.subscribe` to use it, not about
re-verifying or redesigning the primitive itself.

## the actual task

When a subscription in `base.strm.subscribe` successfully reaches `subscribed = TRUE`
(`src/base.strm.subscribe.reply-handler`, the `$reply->{'cmd'} eq 'TRUE'` branch), also
register a `base.zenka.on_restart` hook for that subscription's publisher, whose handler resets
`$state->{'subscribed'} = FALSE` and re-issues the subscribe attempt
(`<[base.strm.subscribe.attempt]>->($key)`), as if the publisher had just been detected online
again (mirroring exactly what `strm.subscribe.wait-online`'s reply path already does for the
first-time-not-up-yet case — read that file too, the re-affirm path should look the same, just
triggered by a restart instead of an initial online-wait).

Design questions left to your judgment (the task file for the original primitive left similar
things open, use the same "get it right rather than rush" approach):

- One `base.zenka.on_restart` registration per subscription `$key`, or one per publisher zenka
  shared across all of that publisher's subscriptions from this same subscriber zenka (a zenka
  could have multiple different subscriptions to the same publisher, e.g. different commands/
  handlers) — dedupe sensibly, don't register the same publisher-restart hook redundantly if
  `base.strm.subscribe` gets called multiple times for the same publisher.
- Whether the re-affirm handler needs any different reply-handling than a fresh subscribe (e.g.
  does the publisher need to be told this is a re-subscribe, or is it transparent from the
  publisher's side — check what the actual subscribe commands on the publisher side, e.g.
  `graphics-matrix.cmd.orbital-sync`'s `subscribe` branch, do when called again for an
  already-known-then-dropped subscriber — should just work identically to a first-time subscribe).
- Where exactly to call `<[base.zenka.on_restart]>` from — inline in the reply-handler's success
  branch, or factored into a small helper shared with the initial-subscribe path.

## don't

- Don't touch `src/v7.zenka.cmd.notify_restart`, `src/v7.handler.zenka_status`, or
  `src/base.zenka.on_restart`/`.reply-handler` — those are the already-correct, already-
  live-verified primitive. This task only *calls* it from `base.strm.subscribe`, nothing there
  should need to change.
- Don't touch `protocol-7-menu.pointer-stream-init` or the SHM/pointer-stream pilot — different,
  already-closed case.
- Don't touch the STRM producer-side `base.stream.close` push-fail cleanup
  (`graphics-matrix`/`nodes`/`discover`/`external`/`radio`/`X-11`/`ticker`, commit `a4fdfa300`) —
  unrelated, already-closed problem from a different investigation.

## verification

- live-test with the wrapper's own existing tested pair: `cred-mesh` (publisher) / `proxy`
  (subscriber) — `data/tasks/completed/strm-generic-subscribe-wrapper.md` has the full original
  test sequence and command shapes to reference.
- restart `cred-mesh` (`v7.restart cred-mesh`) while `proxy` stays running and continuously
  subscribed; confirm via direct state inspection (same methodology as the pointer-stream pilot —
  check `<base.strm.subscribe.registry>`'s `subscribed` flag drops then recovers, or whatever
  observable state changes across the reconnect) that the subscription re-establishes without
  manual intervention.
- test at least twice in a row (not just once) — the pointer-stream pilot's first fix attempt
  looked like it worked on paper and needed a second live pass to actually catch the instance_id
  bug, so don't stop at one successful cycle.
- regenerate whitelists for any zenki touched (`bin/dev/gen-sub-whitelist <zenka>`).

## signatures note

module files have a 4-line AMOS7 signature footer — do not reproduce or invent these. leave
edited files without a footer; the signing tool adds it. existing signatures on files you don't
touch must not be modified.

## dispatch notes

- dispatch to `kimi_dispatch model=k3` — this touches subscription/correctness-sensitive logic
  (matches the "permission models, concurrency, protocol design" tier), even though it's wiring
  two already-built pieces together rather than fresh design
- read `data/tasks/completed/strm-generic-subscribe-wrapper.md` and
  `data/tasks/completed/dependency-restart-reconnect-primitive.md` in full before starting
- root-cause trail: `base.strm.subscribe`'s own doc comment flagged this gap when it was built;
  the primitive to close it was built and live-verified in the same session as this task file,
  for a different (SHM) pilot case

#,,,,,,..,.,.,,,.,,,.,...,,,,,,,,,,..,...,,..,..,,...,..,,...,.,,,..,,,,.,,..,
#I6TKFCJXGK34GXDA43ED6EPVEGBBVNO4HD7DU4C6LG6EARLLPKGXJG7UD3IO3OCOEGE7MUFNL24GW
#\\\|5M6KK4RFOHJ6INSXWB7DFKQ75QPQBHT5EMNDKEKJIV55UHNUGNT \ / AMOS7 \ YOURUM ::
#\[7]PEN4LJ236ZJTWMX5YKREX2SJAWDJM6UDVWXEF3OSSI3UK7MSREDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
