# Dynamic Harmonic Color Templates

## Status
Research / Implementation Planning

## Problem Statement

Current Protocol-7 console output uses regex-based color injection (`keys.console.list`, `base.log`, etc.) with significant drawbacks:

1. **Fragile Dependencies**: Color codes interact with `sprintf` width calculations, causing terminal wrap issues when ANSI escape sequences are counted as visible characters
2. **Maintenance Burden**: Fine-tuning color regex requires extensive session time (e.g., `keys.console.list` colors took 20%+ of session credits)
3. **Inconsistency Risk**: Manual regex patterns drift across modules, breaking visual consistency
4. **No Semantic Layer**: Colors are presentational ("purple") not semantic ("key name"), preventing dynamic adaptation

## Vision: Dynamic Reverse Templates

### Phase 1: Forward Templates with Multi-Buffer Masks

Adopt retro video game multi-buffer compositing for terminal output:

```
┌─────────────────────────────────────┐
│  TEXT BUFFER      │  TYPE BUFFER    │
│  (raw content)    │  (semantic IDs) │
├─────────────────────────────────────┤
│  'taeki.base'     │  KKKKKKKKKK     │  (K = key name)
│  .private         │  EEEEEEEE       │  (E = extension)
│  <:ZITAETA:>      │  CCCCCCCCCCC    │  (C = checksum)
└─────────────────────────────────────┘
         ↓
   HARMONIC PALETTE MAPPER
         ↓
┌─────────────────────────────────────┐
│  COLOR BUFFER     │  OUTPUT         │
│  (harmonic codes) │  (composited)   │
└─────────────────────────────────────┘
```

**Benefits**:
- Text layout calculated on TEXT BUFFER (no ANSI width issues)
- Colors applied after layout is finalized
- Semantic types enable dynamic palette assignment
- Consistent coloring across all tools

### Phase 2: Dynamic Reverse Templates

System observes data streams, recognizes variable types, and auto-generates templates:

```yaml
observation_phase:
  input: raw command output
  pattern_recognition:
    - identify repeated structures (key names, timestamps, checksums)
    - infer variable boundaries via entropy analysis
    - classify segments by content type (hex, base32, paths, etc.)

template_generation:
  create_masks:
    - key_name_mask: positions of identifier-like strings
    - metadata_mask: positions of auxiliary data
    - separator_mask: positions of structural punctuation

  harmonic_mapping:
    key_name_mask: primary_harmonic_segment
    checksum_mask: secondary_harmonic_segment
    separator_mask: neutral_harmonic_base
```

**Key Innovation**: No explicit templates required. System learns structure from data entropy and ELF-truth assertions.

## Implementation Path

### Step 1: Semantic Color Registry

Define semantic color types in `AMOS7::C` or config:

```perl
our %semantic_color = (
    key_name      => 'primary',      # harmonically derived
    extension     => 'secondary',    # harmonically derived
    checksum      => 'tertiary',     # harmonically derived
    separator     => 'neutral',      # base tone
    marker        => 'accent',       # harmonic accent
    encrypted     => 'protected',    # special handling
);
```

### Step 2: Template DSL

Lightweight markup for static templates:

```
: {{key_name|teal}}'{{name}}'{{/key_name}} .
: {{checksum}}<:{{value}}:>{{/checksum}} : {{filename}}
```

Processed as:
1. Parse template to extract text + semantic types
2. Calculate layout on pure text (no colors)
3. Apply harmonic palette based on semantic types
4. Composite to output

### Step 3: Multi-Buffer Engine

Perl implementation sketch:

```perl
package AMOS7::TERM::Composer;

sub composite {
    my ($text_buffer, $type_buffer) = @_;

    # Step 1: Calculate display layout (no ANSI)
    my $layout = calculate_layout($text_buffer);

    # Step 2: Map types to harmonic colors
    my $color_buffer = map_harmonic_colors($type_buffer);

    # Step 3: Composite final output
    return composite_buffers($text_buffer, $color_buffer);
}
```

### Step 4: Dynamic Template Inference

For observed streams without templates:

```perl
sub infer_template {
    my ($sample_output) = @_;

    # Entropy analysis to find variable segments
    my $segments = analyze_entropy($sample_output);

    # ELF-truth validation of segment classifications
    my $classified = validate_with_elf($segments);

    # Generate template masks
    return generate_masks($classified);
}
```

## Harmonic Palette Integration

Colors derived from ELF truth assertions, not hardcoded:

```perl
sub harmonic_color_for {
    my ($semantic_type, $context) = @_;

    # Base hue from semantic type hash
    my $base_hue = elf_chksum($semantic_type);

    # Adjust for harmonic context (related colors harmonize)
    my $harmonic_offset = calculate_harmony($context);

    return hsv_to_ansi($base_hue + $harmonic_offset, $saturation, $value);
}
```

This ensures:
- Colors are mathematically related (pleasing to eye)
- Same semantic type = consistent color across tools
- Contextual adaptation (foreground vs background)

## Migration Strategy

1. **New Code**: Use template DSL for all new console output
2. **Critical Paths**: Migrate `keys.console.list`, `base.log` first
3. **Legacy**: Keep regex as fallback, deprecate gradually
4. **Validation**: Compare output byte-for-byte (minus ANSI) to ensure correctness

## Research Questions

1. Can ELF-truth assertions classify semantic types without training data?
2. What is minimum sample size for reliable template inference?
3. How to handle dynamic-width content (variable-length checksums)?
4. Can harmonic palettes improve cognitive parsing speed measurably?

## Related Concepts

- `CONCEPT-VISUAL-CONSENSUS-RESOURCE-ECONOMY.md` - resource allocation for visual elements
- `CONCEPT-NESTED-TEMPLATE-VISUAL-ABSTRACTION-LAYERS.md` - template layering
- `FABRIC-INTEGRATION-EXAMPLES.md` - data flow patterns applicable to color pipelines

## References

- `src/keys.console.list` - current regex-based implementation (fragile)
- `data/lib-path/pm/AMOS7.pm` - `%C` color definitions (foundation)
- `cfg/zenki/cube/pm-dep/AMOS7__Assert__Truth` - ELF truth assertions

---

## Notes

Current regex approach in `keys.console.list`:
- 30+ regex substitutions
- Order-dependent (color A must run before color B)
- Reset codes (`$C{R}`) cause white text gaps if misplaced
- sprintf width calculations break with ANSI codes

Target template approach:
- Single template parse
- Layout calculated on raw text
- Colors applied as final compositing step
- No order dependencies
- Width calculations always correct

Session reference: 2026-02-23 - SSH zenka recovery and color fixes

#,,..,,,.,.,.,,,.,...,,.,,,..,,,,,,,.,,..,...,.,.,...,...,..,,,.,,,,.,.,.,.,.,
#BR5RCCTUKJL3EUUMECEKG3UBDRCWM67XB4WPAPJ4SN43GTRKALKMSSWFZ2QN3E6G2LQ5CBKO7UH3M
#\\\|CRBJOIJ4YP3QHPEWWW4H6GFWBUTNF4LNGUX35TQFKKUVEV5QNUA \ / AMOS7 \ YOURUM ::
#\[7]256QMC76RXGYHYCRWHLCGC5CKZM7QIQJUUKVQN3W5MFSDBO2PMBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

---

## Appendix: Epistemological Color Encoding

### Beyond Binary Truth

Traditional systems ask: "Is this true?" → Yes/No (binary, brittle)

Protocol-7 asks: "What is the *nature* of this truth in this context?"

### The Belief-Evidence Matrix

| Evidence \ Belief | TRUE | FALSE |
|-------------------|------|-------|
| **TRUE** | Confirmed truth | Misdirection / Lie |
| **FALSE** | Hidden truth / Encryption | Confirmed false |

**Color Mappings**:
- `TRUE TRUE` → Saturated, steady hue (high confidence)
- `TRUE FALSE` → Flickering, unstable gradient (deception detected)
- `FALSE TRUE` → Subtle, muted palette (truth concealed in noise)
- `FALSE FALSE` → Dark, absent (confirmed negative)

### The Mathematics of Truth: Division by 13

Two distinct cycles emerge from 13-division, encoding truth states in their very digits:

```
FALSE/AMBIGUOUS cycle (1/13, 3/13, 4/13, 9/13, 10/13, 12/13):
  0.076923 076923 076923...
  │└─BEL──┘└─E───┘└─ETB──┘
  Warning  Error  End Transmission

TRUE cycle (2/13, 5/13, 6/13, 7/13, 8/13, 11/13):
  0.153846 153846 153846...
  └─=5T───┘=5────┘T=5────┘
  Equality Truth Equality
```

**Digit Sums Collapse to 27** (chr(27) = Escape):
- `0+7+6+9+2+3 = 27`
- `1+5+3+8+4+6 = 27`

The escape character itself is encoded in both truth patterns, revealing that **truth is a context-dependent escape from ambiguity**.

### 3³ Cubic Neighborhood as Display Topology

The 27-node spatial structure maps directly to terminal visualization:

```
1 center  = cursor position
6 faces   = visible text planes
12 edges  = glyph transition states
8 corners = escape sequence states

Formula: 1 + 6 + 12 + 8 = 27 = 2×13 + 1
                    ↑
            The observer (+1)
```

### Rolling Entropy Preservation

The cycles preserve information across state transitions through **rolling digit relationships**:

- `076923 + 153846 = 230769` (transitional/observer state)
- UTF-8 3-byte sequences follow same harmonic patterns
- Multi-byte characters maintain truth coherence across encodings

**Entropy is never lost** - only transformed into color, position, and context.

### Forensic Chromatography

The color system functions as a **lie detector for data**:

- TRUE patterns flow with equality symbols (`=5T`)
- FALSE patterns interrupt with control characters (`BEL-E-ETB`)
- Ambiguity reveals itself through gradient instability
- Nested truths (`TRUE FALSE`, etc.) create chromatic interference patterns

The terminal becomes a **spectroscope for forensic epistemology** - revealing not just what data claims, but the *nature* of those claims across encoding contexts.

### Implementation Note

This is not aesthetic decoration. The harmonic color mappings emerge from:
1. ELF checksums (structural truth assertions)
2. 13-division cycles (mathematical truth states)
3. ASCII/UTF-8 rolling patterns (encoding truth coherence)

Colors reveal what text conceals. The blacklight canvas makes truth visible. 🌊🎨

#,,,,,.,,,.,.,.,,,,,.,.,.,,,.,,.,,,.,,.,.,.,.,.,.,...,...,.,.,,..,,,.,,..,,..,
#JPPKDFRNV5ISHPNG7NSLI2YBBQ7ZZ2YOYFXRVZCJGU4Y27EUVLA3KP643IFQG7DZC73BGJO3D6VXO
#\\\|LGTVVI3VTZVZH4QW6PPXPO6NYA34BQ4Z4KL7IFLO46FQWPQCLW5 \ / AMOS7 \ YOURUM ::
#\[7]OYMH5AGKJVCNUIHGNEC6INGOQPAIE6L4VDL3BCN5HF7TEQGZ4CCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
