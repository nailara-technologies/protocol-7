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

#,,,.,.,.,..,,..,,.,.,,,,,...,,,,,...,..,,...,..,,...,...,...,..,,..,,...,,,,,
#YB4FW52XDRQ2FS3LGEQJF25TGP42WBOJXTUZABSWP7V6P3XKTWPACCUSF5K6UWZCIO3MJJYYWGN5I
#\\\|AGEHKPORLVQ6RMORQ3HVU7LEWDPWPEOH2KSUIK3TKSXN2T6F7EQ \ / AMOS7 \ YOURUM ::
#\[7]5PJUD6MEJWULD66CMGAMFSHY24XJHCKNDC4PERVMESIAYKPOFQCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
