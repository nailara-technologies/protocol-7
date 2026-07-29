---
name: topic-ascii-minimap
description: planned ascii minimap for right terminal section — proportional density bars, anti-aliased gap encoding, glow-intensity colors, spotlight highlight, alternate frame templates
metadata:
  node_type: memory
  type: project
  originSessionId: 9ecacc19-6948-4beb-892e-5af7d7d24068
---

idea captured 2026-06-11, riffed right after the [[topic-cube-tree-dashboard]]
capture, in the same "psychedelic ascii dashboard" vein but scoped to a
concrete, smaller-grain feature: a **btop2-style ascii minimap** for the
right edge of a terminal pane.

## the idea

a minimap region:
- **always vertically maximised** — fills the full available terminal
  height regardless of how many sub-windows/panes are open
- represents the content of one or more terminal sub-windows /
  files at much lower resolution than the source
- each minimap row = one "bucket" of source lines. if the source has
  more lines than the minimap has rows, multiple source lines are
  **averaged** into one bucket (proportional line-length averaging)

## visual encoding

- **line-length -> dot density**: longest line in a bucket renders as
  a long run of dots [ e.g. `.......::`  ], shortest as a short run
  [ e.g. `::` with no leading dots ] — `::` itself may act as a
  fixed end-cap/marker rather than content
- **character-position -> anti-aliasing**: not just length but *where*
  characters/blocks occur within the line range can be represented —
  gaps in the dot run encode gaps in the source content (e.g. leading
  whitespace, blank columns, indentation blocks). this is literally
  anti-aliasing: low-resolution dot positions approximate
  high-resolution content shape
- **color = glow intensity**: protocol-7 color palette, but with a
  calculated "glow" intensity per cell — adds a second data dimension
  (e.g. recency, activity, match-strength) on top of the dot-density
  shape. claim: color precision lets the minimap pack *more* input
  precision than the dot-grid resolution alone would suggest
- **spotlight / highlight**: the dots nearest the viewport's current
  scroll position get a different highlight treatment — a "spotlight"
  effect, directly modeled on btop2's ascii art highlight, but in
  protocol-7 style/colors

## alternate frame templates + placeholder-character borrowing

minimap should support alternate ascii frame style templates the same
way frames already do ([[topic-ascii-frame-system]] /
[[topic-frame-plugin-slots]]). user pointed at `source.init_code`'s
`<source.sign_template>` heredoc as the precedent for the *mechanism*:
the template defines literal placeholder characters [ underscores in
the sign-template, e.g. `#_____...` and `#\\\|___...` ] that get
substituted, while all *other* characters in the template are passed
through verbatim. minimap templates would use the same
placeholder-vs-literal substitution convention to define where the
dot/glow cells go vs. fixed border/frame decoration.

## relation to existing work

- shares rendering substrate with [[topic-ascii-frame-system]]
  (reverse parser, elastic renderer, border-width detection) and
  [[topic-frame-plugin-slots]] (status-bar plugin slots, variable
  border width, density-heuristic gotchas already documented there —
  any minimap density calc should reuse/avoid the same traps)
- complements [[topic-cube-tree-dashboard]]'s "zoom and crop" goal —
  the minimap is plausibly the *navigation* affordance for that
  dashboard's branch-frame zoom/crop, not just a standalone file
  minimap
- proportional-averaging-into-buckets is conceptually similar to
  [[topic-incidental-signal-channels]]'s framing (statistical-shape
  signals from serialization/alignment choices) — worth a cross-check
  if/when this gets designed in detail

## status

idea only — not yet a design doc or task file. no urgency expressed;
captured for later. natural follow-up once a concrete minimap
consumer exists (per-zenka log/output panes, [[topic-cube-tree-
dashboard]] branch frames, or a generic "file minimap" for
console/editor-like views).

#,,,.,...,...,.,,,...,,,.,,,,,...,,,,,.,,,,,.,..,,...,...,,..,...,.,,,,..,..,,
#P5ZQHJ5FPHWVNZT4OXZVXDKELCSHBMPVXM4SX7GAPDMBO5SYYM5TMQBP7GLTTM4VDLWM6AETYZC42
#\\\|64JDPGXWU7UU5UQORXGJOQWDWKPCK5QMBRBS6NOSKBJGFHOA2Q5 \ / AMOS7 \ YOURUM ::
#\[7]G46E3ZNBYMEFLOEJNICRTD2OXERAJ2EAKZLQNYKOZIVBKD57KECI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
