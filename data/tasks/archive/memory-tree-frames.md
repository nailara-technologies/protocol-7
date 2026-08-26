## task: memory-tree-frames

## dispatch
write the three new ascii frame YAML files for the memory tree, plus the
`memory.tree.node.render` module that renders one node into the right variant.
read first: `data/md/design/MEMORY-TREE-SYSTEM.md` sections B and E;
`data/yaml/ascii-frames/user-profile.yaml`,
`data/yaml/ascii-frames/memory-composite.yaml` (frame YAML structure);
`src/ascii.frame.load`, `src/ascii.frame.render`,
`src/ascii.frame.slot.bind`, `src/ascii.frame.compose` (the render API).
this is the rendering-leaf layer — it has no dependency on scoring or sources,
so it can be built and demoed standalone with a hand-built node hashref.

## prompt
implement the visual layer of the memory tree.

write three frame YAML files in `data/yaml/ascii-frames/`, matching the exact
structure of the existing frames there (`name`, `title`, `descr`,
`border_style`, `modes`, a `mockup` with `{{SLOT}}` placeholders, and a `slots:`
map). DO NOT append an AMOS7 `#,,..` signature stub — the signing process adds
it; a manual stub blocks signing. leave the files unsigned.

1. `memory-tree-compact.yaml` — single-line dense node. one line:
   `{{GLYPH}} {{TITLE}}  [{{N}}/{{TOTAL}}] {{PREVIEW}}`. GLYPH is a score band
   glyph; N/TOTAL is visible-vs-total child count; PREVIEW is a short snippet.
   intended as a borderless single row. `border_style: none` is a proposed value
   NOT seen in the existing frames (they use `single`/`double`) — verify the
   parser (`ascii.frame.parse`/`ascii.frame.load`) supports a borderless mode;
   if it does not, render the single row without a frame box (a plain template
   string) rather than forcing a box. document the choice in the task notes.

2. `memory-tree-node.yaml` — expanded card, `border_style: single`. slots:
   TITLE, SCORE_BAR, CURVE, N, TOTAL, and a CHILDREN block slot. layout like
   `user-profile.yaml` (top label bar, body rows, bottom `#:::` rule).

3. `memory-tree-root.yaml` — root container, `border_style: double` (double `::`
   bars like `memory-composite` expanded mode). a single BRANCHES block slot
   enclosed in the double border.

then write `src/memory.tree.node.render`:
- module header: `## [:< ##` then `# name = memory.tree.node.render` and a
  `# descr =` line (lowercase, under 55 chars).
- takes a params hashref: `{ node => \%node, variant => 'compact'|'card'|'root' }`.
- selects the frame YAML by variant (compact→memory-tree-compact,
  card→memory-tree-node, root→memory-tree-root); if no variant given, derive it
  (root type→root, leaf→compact, branch→card).
- maps node fields to slots: TITLE←title, derive SCORE_BAR / GLYPH from
  `node->{score}` quantized to a 13-step band (use the same idea as
  `base.curve.eval('quantized')` — int(score*13) → glyph from a band string like
  `' ░▒▓█'` or `▁▂▃▄▅▆▇█`), N←scalar visible children, TOTAL←scalar all children,
  CURVE←curve_type, PREVIEW←first ~40 chars of body.
- loads + renders via `<[ascii.frame.load]>` then `<[ascii.frame.render]>` (or
  the slot-bind + render path the existing frames use — follow whatever
  `ascii.frame.render` expects). return the rendered string.
- lowercase narrative comments, `[ word ]` annotation style, no `( word )`.

demo: a tiny standalone snippet (in the task notes, not a committed file) that
hand-builds a node hashref and prints all three variants, to prove rendering.

## acceptance
- three YAML files exist in `data/yaml/ascii-frames/`, parse cleanly with the
  existing `ascii.frame.load`/`ascii.frame.parse` path, and carry NO manual
  signature stub.
- `memory.tree.node.render` returns a non-empty rendered string for each of the
  three variants given a hand-built node hashref.
- score → 13-step glyph band mapping is implemented and visibly differs across
  low/mid/high scores.
- compact variant is a single line; card has a single-bar box; root has double
  `::` bars.
- comments are lowercase narrative; annotations use `[ ... ]` not `( ... )`.

#,,,.,...,.,,,,,,,,.,,..,,.,.,,..,,,.,.,.,,,,,..,,...,...,..,,,,.,.,.,,,.,,,.,
#QGMEECQB7CV3KC3GSI3UBWYZXOYUYXUXPE54OTLWTLDFBZSU7JDIKLAY4LH37AREI4PL4QQCC2JCY
#\\\|L6CGD3NJIWL4LKSZAKZBPVQIGXZ2HK6GHJOS4666FBHFCHJGDRD \ / AMOS7 \ YOURUM ::
#\[7]F3RXLGOKGM4T6JQKHWNH5LSF7GYXL54WQDH6XWK7EU7ZBU5ZNKAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
