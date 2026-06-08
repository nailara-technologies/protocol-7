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

#,,,.,..,,.,.,,,,,,,.,.,.,.,,,...,,.,,.,,,.,,,...,...,...,,..,...,,.,,,.,,.,,,
#NNRNUR7BQ2Y4TQQ37EVNPE7GYJ7OC5PW55MYA5ISCWVR2G5MPTWCHRTARWK54D26WWEHCVPH2FEBA
#\\\|G5YOZQ33AITSIHYSOCTXLD2EDXWMKSNOZRUVHZLAZBHMCWMPX47 \ / AMOS7 \ YOURUM ::
#\[7]EZ57J6ELRDN33JAXRX2AXPF2ULE2N5PNJVCA7SSLEUSODO7PBEBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
