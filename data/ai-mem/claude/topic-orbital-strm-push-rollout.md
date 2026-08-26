---
name: orbital-strm-push-rollout
description: "replaced web's unconditional 13s poll-everyone orbital fetch with per-producer STRM push (discover/external/nodes/graphics-matrix) — LANDED commit 139cacef2, 2026-06-25"
metadata: 
  node_type: memory
  type: project
  originSessionId: a008f26d-1eb1-47a2-812d-5559b055844c
---

Started from "fix httpd before enabling, re: its timer-based requests" —
traced to `plugin.web.space.orbital.fetch`, a 13s repeating timer in `web`
that unconditionally `route-send`s to `nodes`/`discover`/`external`/
`graphics-matrix`/`nameserv` every cycle regardless of whether the target
is even running. Real-world impact (confirmed by taeki): the resulting
"offline" spam in cube's console was bad enough that **taeki kept stopping
the zenka because of it** — a recurring restart-cycle annoyance, not just
log noise.

**Fix**: each producer now pushes data to `web` via a STRM subscribe
channel instead of being polled:
- `discover`/`external` push from real mutation points (`discover.orbital.
  store_remote`; `external`'s 4 connection-state-change sites).
- `nodes`/`graphics-matrix` have no discrete mutation event (time-derived /
  recomputed-on-demand respectively), so each runs its own 45s
  listeners-gated timer — a no-op when nobody's subscribed.
- `web` subscribes once per producer at init, with exponential backoff
  (mirrors `v7.handler.zenka_status`'s `restart_delay *1.2`/capped/
  reset-after-stable shape) if a producer is offline at subscribe time —
  never a fixed-interval retry.
- Real STRM consumption mechanism (verified via `coding.handler.
  gpu_stats_update`'s existing subscription to `X-11.gpu_load`, not
  assumed): `reply.handler` fires once on `STRM open`, registers a
  `base.strm.local.register` watcher keyed by `cmd_id`; `base.handler.
  command.process_reply` feeds the watcher's buffer as chunks arrive. This
  is the correct cross-zenka pattern — a separate older "STRM" label in
  `cred-mesh.handler.rotation_strm` is NOT this; it actually
  `YAML::XS::Dump`s a payload into a single `route-send` `call_args.args`
  string, the same line-oriented-wire-corruption bug already found+fixed in
  `X-11.emit.screen-change` — NOT fixed here (out of scope), flagged for a
  future pass.

**Side quest**: `external` zenka was found completely unwired (not in v7's
`zenki.enabled`, no cube access grant to call out to `nodes`/`discover`,
missing `discover` dependency declaration, no disconnect/retry support,
stray devmod wildcard) — dispatched to kimi via `data/tasks/
external-zenka-completion.md`, landed in the same commit. One gap
deliberately left OPEN: who should be allowed to call `external.
connect-orbital`/`disconnect-orbital` — taeki wasn't sure of the intended
trigger (nodes-as-decision-maker vs. manual) and there's no second P7 node
to test against anyway (see `data/tasks/completed/
nodes-orbital-second-node-setup.md` — only a visualization-only fake
node-injection exists, not a real connectable endpoint), so granting
access now would be ungrounded guessing. Revisit once there's an actual
use case or a second node.

**Result confirmed live 2026-06-25**: console log went from repeating
`nodes`/`discover`/`external`/`graphics-matrix` "offline" spam every 13s to
clean — `discover`/`external` silent immediately after reload, `nodes`/
`graphics-matrix` were the last to go quiet (converted in a follow-up round
same session). taeki: about to re-enable `graphics-matrix`'s startup block
now that the offline-spam problem (the reason it got disabled) is solved.

**Pattern is now the template** for any future "zenka X polls zenka Y on a
timer regardless of online state" cleanup in this codebase: real mutation
hook where one exists, listeners-gated own-timer where it doesn't, and
v7-style backoff on the subscribe side — never a fixed-interval retry.

## related

[[topic-httpd-route-arg-parsing-fix]] · [[feedback-no-unsolicited-cross-zenka-push]] · [[topic-async-window-startup-transition]]

#,,,.,,,,,,.,,,.,,,,,,...,,,.,..,,,.,,.,,,...,..,,...,...,...,,..,,.,,...,...,
#IIJS2FH3JDFSVLIK62A4UIMB3QL7DSBVUH5O22TMY7NBVVBWOFKRS6DPIYRTUXOUUO47LYQMTXJME
#\\\|BLJPOQQHVCB5Y7YUHJ6S52KXGP2LROIX5ZDLYFNN3LB2EZHTOYW \ / AMOS7 \ YOURUM ::
#\[7]KRU26WXS5KF2OC4SMYCXE5TJ2BLOLJPJUMWGQRYX52VUCULY7SDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
