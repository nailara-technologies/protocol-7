# session 72: topic-ascii-frame-system

## VERIFIED architecture (2026-06-08, against live code) —
## the sections below ("DRC validator", generic header/body/sidebar
## mockup types, width/height required fields) do NOT match the actual
## implementation; treat them as stale/possibly-hallucinated and prefer
## this section + direct code reading
- real pipeline: `ascii.frame.load` → `ascii.frame.parse` (reverse
  template parser: ascii-art mockup string → descriptor) →
  `ascii.frame.render` (descriptor + slot values → ascii string)
- `parse` finds border lines by structural-char density (`[:.,\[\]#=]`
  ≥ 50%), splits each border line into elements via
  `parse.border_line`/`parse.border_segment`/`parse.fill_anchor_text`:
  `anchor` (literal text incl. bracketed labels `[ word ]`), `fill`
  (runs of `:`/`.`/`=`, carries a `min` length), `slot` (`{{NAME}}` —
  inline in borders, or field/block/composed in content rows)
- `render.border_line` elasticity: exactly ONE spring per line — if a
  slot is present, the slot's value absorbs the slack (padded right,
  pins corners/separators rigid); if no slot, the LARGEST fill absorbs
  it (e.g. the dotted bottom rule stretches, `:` corners stay put).
  Assumes `min` is a true minimum — if `$fixed > $width`, slack clamps
  to 0 and the line renders OVERSIZED (no shrink-below-min path)
- `render`'s `required_width` is the max across: `min_width` (sum of
  TOP+BOTTOM anchor lengths combined — a latent quirk, not yet a
  observed bug), static rows, field/block/composed slot content widths,
  AND inline border-slot lines (must use the line's true fixed width =
  anchors + fill mins + slot value — see [[topic-credential-fabric-
  proxy-transport]] 2026-06-08 fix for the bug when this was
  under-computed as `min_width + val_len`)
- `frame_width = required_width + len(border.left) + len(border.right)`;
  corners/border chars auto-detected from first/last chars of content
  rows (most common = winner); `lpad`/`rpad` derived from min leading/
  trailing whitespace runs across static (non-slot) content rows

## VERIFIED trap : field-slot `suffix` double-counts a long substituted
## value against its own build-time placeholder width (2026-08-15, traced
## live via a debug dump of `render`'s own width computation, user-edit's
## user_keys detail-checksum row — see [[topic-user-edit-console-zenka-
## status]])
- a **field**-type slot's width formula is `prefix + value + suffix`,
  where `suffix` is whatever LITERAL text followed the `{{token}}` in the
  mockup line `parse` was given — for a generator like `user-edit.form.
  build_frame`, that's near-pure trailing whitespace, padding the SHORT
  unsubstituted `{{token}}` placeholder out to whatever width other
  fields' own literal text already established at build time
- that padding is only correct for values close to the placeholder's own
  length. once a caller substitutes in a value MUCH LONGER than the bare
  `{{token}}` text was [ e.g. `{{user_keys_scrollinfo}}`, 25 literal
  chars, holding a 23-char checksum plus a 42-char indent at render time
  ], the stale `suffix` gets added ON TOP of the real value at render
  time — `render`'s width computation has no way to know the suffix was
  only ever meant to cover the placeholder, not the eventual value, so it
  double-counts, silently widening the frame well past what the value
  itself needs. no error, no warning — just a wider-than-expected frame
  with unexplained blank padding on the affected row
- a **block**-type slot [ `{{name...}}`, three literal dots before the
  closing braces — `ascii.frame.parse`'s own trailing-dots syntax ] has
  NO suffix concept at all : its width formula is just `prefix + line`
  (`length($prefix) + length($line)` per line, since a block value
  `split`s on `\n`). safe by construction for this exact case, and
  correct even for an ordinary single-line value — `split "\n"` on text
  with no newline just yields the one line
- **how to apply**: before putting ANY dynamically-sized value [ not
  scanned/measured at build time, i.e. not covered by whatever
  `$display_length`-style static reservation the generator computes ]
  into a field-type slot, check whether its live length can plausibly
  exceed the literal `{{token}}` text's own length. if so, use a block
  slot instead of trying to out-guess the gap with a bigger or smaller
  static reservation — a static number can only ever match ONE specific
  live value length, and drifts wrong the moment that changes. reserving
  MORE width doesn't fix the suffix double-count, it just makes the
  static min_width big enough to dominate over the render-time overflow,
  hiding the bug behind a differently-wrong number instead of fixing it

## reverse parser
- Parse mockup YAML in REVERSE: children first, then parent
- Mockup structure: `mockup: { type: 'parent', children: [ { type: 'child', ... } ] }`
- REVERSE: iterate children, then process parent
- Key insight: topological sort of mockup tree, reversed
- Example: mockup -> child1 -> grandchild1, reversed = grandchild1, child1, mockup

## elastic renderer
- Dynamic width calculation: `width = base + content + padding`
- Content overflow: truncate with ellipsis `...` or wrap to next line
- Horizontal scrolling: enabled for wide content, disabled by default
- Line height: fixed 1.0em for predictability
- Character scaling: adaptive based on content density
- Mode switching: `compact` | `normal` | `expanded`
- Compact mode: hide metadata, show only content
- Normal mode: show metadata + content
- Expanded mode: show full context, breadcrumbs

## DRC validator
- DRC = Descriptor Resolution Check
- Validates: mockup type exists, all required fields present
- Mockup types: `header`, `body`, `footer`, `sidebar`, `container`
- Required fields: `type`, `width`, `height`, `content`
- Optional fields: `classes`, `id`, `data-*`
- Error codes: `DRC001` (invalid type), `DRC002` (missing field), `DRC003` (invalid value)
- Error output: `DRC[002]: missing field 'width' in mockup 'header'`

## validation rules
- Type must be lowercase alphanumeric with hyphens
- Width/height: positive integers, max 10000
- Content: string or reference to mockup
- Classes: array of lowercase strings, max 10
- Data attributes: any key-value pairs

## examples
### compact mockup
```
mockup:
  type: body
  width: 80
  height: 24
  content: "Hello World"
```

### elastic mockup with overflow
```
mockup:
  type: container
  width: 100
  height: 50
  content: "This is a very long piece of content that may overflow the container boundaries"
  classes: [overflow, scroll]
```

### hierarchical mockup
```
mockup:
  type: container
  children:
    - type: header
      content: "Title"
    - type: body
      children:
        - type: sidebar
        - type: content
```

## key insights
- Reverse parsing is critical for efficient mockup evaluation
- Elastic rendering enables responsive ascii frames
- DRC validation catches errors early in the pipeline
- All three components work together: parse -> validate -> render

#,,..,..,,,,.,..,,,.,,,,.,,..,..,,,,,,,,.,.,.,...,...,...,.,.,..,,.,.,...,.,,,
#NGDRDO6YYISSQNJBZ76FAYSPRXK2NKJXXOKDRHFIQT6ODV4NSR5ZJ2ACZQSFQ6Z7LLULYG26QXGLG
#\\\|4BXHY5KWCEFCNJ52PDFVEOAK7RETEKTCQEWDAN27PGCSQVJG4DG \ / AMOS7 \ YOURUM ::
#\[7]IF2LUBIRAALNCSIAQT446NPDHM3KGMLKL2FP3LW6CIM7CJSKWQBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
