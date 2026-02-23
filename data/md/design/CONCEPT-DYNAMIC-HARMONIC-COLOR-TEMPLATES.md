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

- `modules/keys.console.list` - current regex-based implementation (fragile)
- `data/lib-path/pm/AMOS7.pm` - `%C` color definitions (foundation)
- `configuration/zenki/cube/pm-dep/AMOS7__Assert__Truth` - ELF truth assertions

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
