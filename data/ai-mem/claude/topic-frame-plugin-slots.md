---
name: topic-frame-plugin-slots
description: ascii frame status-bar plugin slots + context-aware selector; variable border width
metadata: 
  node_type: memory
  type: project
  originSessionId: ef566d51-6cd0-48bd-8a82-e0fdb240d898
---

the ascii-frame bracket is now a live, context-aware status region (the top-bar
`[ ... ]`). built 2026-06-04 (session 2). see `data/md/design/PLUGIN-SLOT-SELECTOR.md`
and handover `data/md/handover/CLAUDE-CATCHUP-2026-06-04.md`.

**parser:** `ascii.frame.parse` detects border WIDTH (min consistent run of the
border char across rows) → `::` multi-char borders first-class. fixed the +1
spacer drift + a latent pure-whitespace-row padding bug. this unlocks the future
vertical-scrollbar-by-inversion idea (thumb = opposite border width).

**foundation (generic):** `ascii.frame.slot.select` (interest-max selector:
providers `{value,label,interest}`, earliest-wins tie, broken-skip, all-fail
empty) + `ascii.frame.bar` (ptd-style fill bar, `bin/ptd` show_progress ref).

**integration is via `%values`, NOT a render-path change** — border slots read
`$values->{name}` in `ascii.frame.render.border_line`; `render.color` is a
post-processor over already-rendered lines. `memory.tree.node.render` (root
variant) builds `$ctx`, runs the selector, sets `$values{PROGRESS}/{STATUS}`.

**providers** `memory.status.provider.*` (value padded to width=23, no jitter):
branch_count (0.05 resting default), weight_captured (0.5*frac, surfaces on
skewed trees only), focus_saturation (0.7+ when focus set, 0 else), rebuild_age
(0.6 flash <10s). composed via `memory.cfg.status_providers`. yaml top border:
`..[{{PROGRESS}}]..[ memory tree ]:.`

gotcha that bit us: `base.ntime.b32` does NOT round-trip through
`base.ntime_BASE32_to_numerical` — store timestamps as raw numerical `base.ntime`
and compute `(now-built)/4200`. reinforces [[feedback-ntime]].

next: vertical slots (per-row border state in `ascii.frame.render` = renderer
change), bottom-right mini scrollbar echo, cleaner double-colon pass. related:
[[topic-ascii-frame-system]] [[topic-memory-tree-zenka]].

#,,.,,..,,,.,,.,.,,,,,,,.,.,.,.,,,.,.,,.,,,.,,..,,...,...,,..,,,.,.,,,.,.,,,,,
#ASGXOUDIXW6H6T33OGWDX75E3OIBVVFEUALCRSSW64VBLLAQNJOZZS5S7DSTUBLBCHTP5RCDHZWLE
#\\\|QPDPQIOIITFQMHKZ24AJQLCLVO4RNXNKCQ7GO4UJDWSPHVFQVHF \ / AMOS7 \ YOURUM ::
#\[7]YQPOXN4HOSZYTXUZM7MOUO5CH4SECQEQYJ56HXK6ZGV5AJCVRSAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
