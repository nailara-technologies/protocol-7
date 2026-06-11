---
name: topic-frame-idiom-convergence
description: "ascii.frame new base features (margin / vertical padding / self-invalidating cache / corner-pinning spring) + the in-progress idiom convergence of all frames to the .:[ ]::[ ]:. reference look"
metadata: 
  node_type: memory
  type: project
  originSessionId: c3c1be56-d87b-4049-b5f6-0b91e40f1696
---

session 3 (2026-06-04) converged the ascii-frame system toward the reference idiom
`/tmp/frame.asc`: `.:[ value ]::[ title ]:.` corners pinned, single `:` sides, dotted
`:….:` bottom, optional outer margin. handover:
`data/md/handover/CLAUDE-CATCHUP-2026-06-04-s3-frame-idiom.md`. builds on
[[topic-frame-plugin-slots]] and the vision in [[topic-ascii-desktop-domains]].

**four new reusable frame features (yaml-declared, verified live):**
- `margin: {left,right}` — space OUTSIDE the border (parent-plane breathing room; 0
  when nested). applied in `ascii.frame.render` as a final wrap; `render.color`
  preserves it by splitting per-line leading whitespace before classifying.
- `padding: {top,bottom}` — blank content rows INSIDE the border (vertical analogue of
  lpad/rpad). [ padding = inside the border, margin = outside it — they compose. ]
- **self-invalidating frame cache** — new module `ascii.frame.init_code` does
  `<ascii.frame.cache> = {}`. `base.init_modules` auto-runs every `*.init_code` on each
  source reload, so edited frame yaml takes effect on `reload` (was: needed a COLD
  restart — cache was never invalidated). creating the file IS the registration. do NOT
  leak frame specifics into generic `base.cmd.reload` (user correction).
- **corner-pinning spring** (`ascii.frame.render.border_line` rewrite) — a border line
  stretches at exactly ONE spring: if a SLOT is present the slot is the spring (value
  padded right to fill, all fills rigid → pins `.:` `::` `:.`, widens the bracket); else
  the largest fill is the spring (dotted bottom: dots stretch, `:` corners pin). the
  status provider's width-23 is now just a FLOOR.

**converted + verified:** `memory-tree-root` (matches reference, width 56),
`feedback` (headline-promotion: `{{RULE}}` moved INTO the top bracket as the spring).

**REQUIRED remaining work** — the border_line spring change is global, so any frame with
a slot-less / decorative top now BLOWS its leading corner (slack lands on the largest
fill). must convert: `project`(→FACT), `user-profile`(→ROLE?), `task-queue`(block-only),
`session-catchup`(block-only), `memory-tree-node`(idiom cleanup), `memory-composite`
(idiom cleanup); skip `memory-tree-compact` (borderless). open Qs for user: task-queue /
session-catchup → separator-stretch vs a count/age headline; and whether the
`==[ why & apply ]==` content-separator should stretch.

**gotchas:** File::stat overrides built-in `stat` → use `File::stat::stat($p)->mtime`
(see [[feedback-ntime]] sibling caution); `stat _` trips strict-subs; mtime is
1-second-resolution (same-second edits poison an mtime cache — why we use reload-clear);
`memory.startup` has an idempotent guard so can't host cache-clears; `context.provider.frame`
is NOT loaded in the memory zenka — render other frames via eval-code calling
`ascii.frame.load` + `ascii.frame.render` directly.

next layer after convergence = role-vs-glyph descriptor / box-drawing typer
([[topic-ascii-desktop-domains]]) — that one IS kimi-shaped; this pass was taste-laden.

**asymmetric anchor / "handheld" alignment principle** (2026-06-11, from
`coding.list buffers` realignment in `base.init_code` — `name` column → center,
`data`/`size` columns → right-3): under PAGING (vertical rolling-window scanning of
a long list, e.g. coding zenka's growing `T-NNNNNNN*` buffer list), a global
left-anchor assumes you see the whole table — false once it exceeds the viewport.
Instead: give the table ONE rigid linear edge (here, the right-aligned numeric
columns — needed anyway for digit-place magnitude comparison) and let the other
edge(s) (here, `name`) flow proportionally/centered per-row. The rigid edge
"catches"/anchors the flowing edge, so the table reads as balanced rather than
unanchored — cross-mapped curves (one straight, one proportional) interacting per
row, not two independent rules. Analogy: a handheld device that's asymmetric but
uses its battery as a structural+visual "handle" on one side — the heavy/bold
rigid element on one edge gives the whole object its balance, freeing the other
edge's shape. Generalizes beyond this table: "one rigid alignment edge anchors one
or more proportional/curved edges in the same row."

**addendum — center vs edge picks the comparison mode, not just the anchor:** the
`lines` (data) column centers values of wildly different magnitude (`2`, `5`,
`2287`). centering doesn't align digit-places — it groups values by SHAPE/EXTENT:
short numbers read as compact tokens floating in their own space, long numbers
fill the column, and similar-magnitude values cluster visually against dissimilar
ones. right-alignment (the `bytes`/`of_bytes` columns) instead shares one edge so
digit-places line up for fast absolute comparison. so within ONE row, two adjacent
numeric columns can deliberately serve two different reading tasks — "which class/
size-group is this" (centered) vs "what's the exact relative value" (right-
aligned) — and the rigid right edge of the latter still anchors the former.

right-alignment also gives a free pre-attentive diagram: with the right edge
fixed, the column's RAGGED LEFT EDGE is literally a bar-chart of digit-count
(magnitude class) per row — readable before parsing any digit. echoes
`base.sort`'s default of using length as the last tiebreak: digit-count/length is
itself a coarse, near-zero-cost comparison signal that both sorting and alignment
exploit ahead of (or instead of) reading exact values.

#,,,,,,..,,.,,..,,,..,,.,,...,.,.,.,.,,.,,...,..,,...,...,.,.,...,.,,,.,,,.,,,
#RG2YD2HIDCALVTYHEVRVTMFULW4DEKDW5UNJZFS3XKIAYAONMFNFKSPP3CKCNVUTXVMYKYPKFHFSC
#\\\|ZFKVJW7RK4QEFIZBLUJ77ALIW3LUM4PHKDVKBDDL7TO2JETG5FL \ / AMOS7 \ YOURUM ::
#\[7]7LS6QYGCBXBET3RYEN5L6KU6DEIN46KLGHWPZ5ZJS3YP4DYGWYBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
