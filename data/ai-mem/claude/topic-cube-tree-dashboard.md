---
name: topic-cube-tree-dashboard
description: planned cube/v7 ascii-frame tree-view dashboard — per-zenka command/state trees, capability interrogation, push-registry watcher cache, zoom/crop psychedelic ascii dashboard
metadata:
  node_type: memory
  type: project
  originSessionId: 9ecacc19-6948-4beb-892e-5af7d7d24068
---

idea captured 2026-06-11, immediately after [[topic-os-command-zenka]]
(the cube zenki-groups stage in particular). user: "we will soon also
need a ui or ascii frame template for a tree view from the v7 zenka
perspective or above even down".

## the idea

a tree view spanning three directions from a v7 zenka's perspective:
- **above**: concurrent v7 zenki, addressed via the cube socket id of
  their cube zenka
- **here**: the local v7's managed zenki (commands, status/state-machine
  values)
- **below**: into individual zenka internals

cube maintains a **native cached command-tree per zenka** so the tree
view doesn't pay round-trip latency per branch.

## supporting mechanisms needed

1. **exclusion map / decision logic** — which zenki NOT to query after
   connection (some zenki shouldn't be interrogated, e.g. for cost,
   privacy, or stability reasons)
2. **optional "zenka client interrogation" phase** at session start-up —
   cleanly integrated, queries a connecting zenka's capabilities
   (command lists + descriptions + param tags, and/or status/state-
   machine values)
3. **cache refresh strategy** — two options raised:
   - timer-based self-refreshing polling (simpler, baseline)
   - **preferred**: automatic **push-registry** — the queried zenka
     installs variable watchers (per [[feedback-watcher-state-
     machines]] — IO::Async variable watchers only) for the values cube
     cares about, and pushes updates so cube already has them cached
     without any round-trip
4. **unified tree view** — one tree showing commands + states of all
   zenki, with branch-specific UIs reachable directly from tree nodes

## end goal (user's words)

"a giant fine ascii art dashboard in psychedelic colors with zoom and
crop features for information [branch] frames of interest."

## relation to existing work

- elaborates the **cube zenki-groups** stage of [[topic-os-command-
  zenka]]'s 3-stage migration path — that stage was about per-admin
  *visibility* filtering of the zenka topology; this dashboard is the
  *UI* for viewing that topology (filtered or not)
- builds on [[topic-ui-show-security-levels]] field-map + caller-level
  machinery — per-zenka command/state trees would naturally be levelled
  the same way `ui.fields` maps are
- relates to [[topic-global-ui-menu-tree]] (addressable stdio slots +
  menu tree) — this dashboard is plausibly the "menu tree" rendered at
  cube/v7 scope rather than per-zenka scope
- closely related existing task: `data/tasks/v7-console-per-zenka-tree-
  view.md` — "alternate tree-grouped view of v7 console" per
  `data/md/design/STDIO-RELAY-FOLD-APPLICATION.md` worked usage example
  B; depends on `data/tasks/v7-stdout-foldable-relay.md`; uses existing
  `src/v7.handler.process_output_line`'s `instance_id -> zenka_name`
  mapping (`v7.zenka.instance` / `v7.zenka.setup`); addressed as
  `v7.console.view.by-zenka`, bound via `base.slot.bind_content`. that
  task is scoped to a single v7's local zenki — this idea generalizes it
  to multi-cube ("above") and intra-zenka ("below") scope, plus the
  push-registry capability-interrogation layer.
- ascii rendering substrate: [[topic-ascii-frame-system]] (reverse
  parser, elastic renderer) and [[topic-frame-plugin-slots]] (status-bar
  plugin slots, variable border width) are the likely frame primitives
  for "zoom and crop" of branch frames.

## status

idea only — not yet a design doc or task file. natural follow-up once:
- `v7-stdout-foldable-relay.md` / `v7-console-per-zenka-tree-view.md`
  (single-v7 scope) land, proving the per-zenka tree rendering locally
- [[topic-os-command-zenka]] step 2/3 (v7 fine-grained command control,
  cube zenki-groups) gives the multi-cube/"above" dimension something
  real to query

## next step when picked up

write `data/md/design/CUBE-TREE-DASHBOARD.md` covering: capability-
interrogation handshake format, exclusion-map config shape (likely
`access.zenki`-adjacent), push-registry watcher protocol (variable
watcher -> cube cache), and the ascii-frame tree+zoom+crop rendering
spec. then split into task files following the
[[topic-ui-show-security-levels]] precedent.

#,,.,,.,.,..,,,,.,,..,,.,,...,,.,,..,,...,,,.,..,,...,...,...,,,,,.,.,,..,,.,,
#BZYBQ4AO7WEECNPJQKOHB3RVIFKRUKUFD5HZGKBKMWBH4AKBQTUFDGZEKXNG6TO4VGLX5NMD7S6I6
#\\\|M4J4UNCYMJES2JFRULBHTGBWQN2IUQNKE6R2YFXP2GQJACCKQEP \ / AMOS7 \ YOURUM ::
#\[7]B5B6ZBREU4TBUH5GEB7NLQZLLIXGYX6LY7ND6OBP6CW6SC2PVWDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
