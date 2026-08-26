---
name: topic-zenka-restart-intent-propagation-resumption
description: "vision: true crash resilience needs intent propagation across a zenka restart boundary, not just state serialization -- a zenka's in-flight goal (including an outstanding kimi/claude dispatch) should survive its own process's death and resume automatically, with a crash report attached, rather than silently starting fresh"
metadata:
  node_type: memory
  type: vision
  originSessionId: 16c8ce74-d9e2-429d-bafb-25fae9c0c30f
---

## origin

surfaced during the 2026-07-26 v7 crash incident ([[feedback-v7-reload-init-live-swap-subs-crash]]):
a `kimi_dispatch` (K3) session survived the entire zenka network going down
mid-task (all 19 sub-processes SIGTERM'd by `v7`'s own shutdown) and its
result was recovered cleanly via `session_catchup` after a manual restart.

## the distinction that matters

what actually happened was **incidental, not designed**: `kimi-legacy`'s
session transcript lives in its own on-disk store, entirely outside the
protocol-7 process tree the MCP server manages independently — so it
survived by not being part of what crashed, not because protocol-7 has any
mechanism for surviving a crash. it would just as easily not have
survived if the *MCP server itself* had been restarted, or if the same
work had been running as a zenka-managed process instead of an
externally-dispatched one.

## what real resilience would look like

not raw state serialization/restore (dump memory, reload memory) — the
sharper framing is **intent propagation**: what a zenka *meant to be
doing* — its in-flight goal, not just its current variable state —
crosses the restart boundary, and **resumption** is the act of picking
that intent back up on the other side automatically. a zenka's process
dying is not the same as its purpose ending; the two are currently
conflated (per the 2026-07-26 incident: "no zenki to start found, giving
up" — the goal-lessness of the restart, not just the state loss, is the
gap).

concretely, this reframes an in-flight kimi/claude dispatch as **one
instance of intent that should propagate through a zenka restart**, not a
special external thing that happens to survive by accident: the zenka
that dispatched it would, on resumption, know it had an outstanding
dispatch, reconnect to it (via the same `session_catchup`-style recovery
already proven to work), and — the added piece neither today's incident
nor the existing recovery mechanism provides — **attach a crash report**
explaining what interrupted it, rather than resuming silently as if
nothing happened.

## open

purely design-stage — no implementation started. would need: (1) a
notion of "intent" as a first-class, persisted thing per zenka (not just
its data-tree state), (2) a restart path that reads and acts on that
intent rather than just re-running init from a static config, (3) a
crash-report mechanism that attaches to the resumed intent rather than
just logging the crash separately. relates to existing zenka lifecycle
concepts (`v7.zenka.instance.track_handover`,
`v7.zenka.instance.handover_cleanup` — see handover/restart infra already
in `src/v7.zenka.*`) but those handle *zenka* handover between
instances, not *intent* surviving an actual crash.

#,,.,,,.,,,,,,,,,,,..,.,.,,..,.,,,..,,.,.,...,..,,...,...,...,,.,,,.,,.,,,,.,,
#WVRW7R5HM6FHAUUN4V2SNR5STCYX6GEZ4N44CVAQYGGQAOF4ICG7V4IMEBJQTLDAFZMBSLUP2F754
#\\\|OX6WTWBBBUR5KQPGAY7IRYTZO35REBIGMW42UTAMYOQC5BTKFPR \ / AMOS7 \ YOURUM ::
#\[7]CDNGOUFJHPGFWF3MTDV5TIZXHJ33OKNBKLN6JBDX5MYIJEHLU2CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
