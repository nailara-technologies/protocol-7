# session 72: topic-ascii-frame-system

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

#,,,.,,.,,,,,,,..,.,,,..,,.,,,.,.,.,.,,,,,,,,,...,...,...,,.,,,.,,..,,,.,,.,.,
#3GAEEMUVK6PDJGJPRAF3LGIQ4LNDTEJYUU2FLLLOMOLO2FMCLGQ3CZ34QBCSXKHICGILXZ5XEDUA4
#\\\|IFS2Q436NHIVVBQ3LEWEST4ASJAPTNBGQ3A7FU5HFV26FT3II7Z \ / AMOS7 \ YOURUM ::
#\[7]HZGXUWYZOIH26SR464F7EM3QFYJEWHD2XUUEGMORMJTOBIPJUCCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
