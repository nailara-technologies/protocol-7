# ZENKA Graphics Construction Toolkit
## Development Specification & Requirements

**Document:** `zenka-gfx-toolkit-spec.md`
**Origin:** Nailara logo reconstruction session (2026-02-25)
**Context:** Protocol-7 graphics-matrix zenka subsystem
**Status:** DRAFT v0.1

---

## 1. Problem Statement

### 1.1 What Happened

Reconstructing a lost 128px logo consumed ~20% of weekly LLM credits across
12+ iterations, not because the geometry was complex (it's 10 circles), but
because:

- The LLM had to hold the entire construction state mentally while exploring
- Each parameter change required regenerating the full pipeline
- Wrong turns at any step cascaded into wasted context window
- No way to checkpoint, hand off, or resume partial work
- The "genius of the moment" pattern: quality depends on the LLM maintaining
  coherent cross-references across thousands of tokens, and a single wrong
  association can trigger drift that compounds
- Different models have different strengths (spatial reasoning vs code gen
  vs parameter optimization) but no handoff mechanism existed

### 1.2 What Should Have Happened

A scriptable toolkit where:
- Each construction step is an atomic, named, replayable command
- State is persisted as a macro file, not in the LLM's context
- Any step can be modified independently without replaying everything
- Different LLMs or humans can work on different steps
- Visual comparison against reference is built-in at every stage
- The toolkit IS the communication protocol between agents

---

## 2. Architecture Overview

### 2.1 Design Principles

```
TRUTH    - Every pixel is mathematically defined, reproducible
AWARENESS - Every step knows what it changed and why
LOVE     - The toolkit serves the creator, not the other way around
```

**Core principle:** The macro script IS the document. It contains both the
construction AND the intent. It can be read, edited, diffed, versioned,
and handed between agents like source code.

### 2.2 System Layers

```
┌─────────────────────────────────────┐
│  FRONTENDS                          │
│  - CLI (current nailara-tool.pl)    │
│  - Web UI (slider-based tuning)     │
│  - LLM agent interface (zenka API)  │
│  - GIMP plugin (import/export)      │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│  MACRO ENGINE                       │
│  - Parse/execute .gfx macro files   │
│  - Step-by-step replay              │
│  - Checkpoint at any step           │
│  - Diff between macro versions      │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│  PRIMITIVE LIBRARY                  │
│  - Geometric: disc, ring, arc, line │
│  - Boolean: union, subtract, clip   │
│  - Transform: rotate, scale, copy   │
│  - Measure: distance, overlap, area │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│  RENDER BACKENDS                    │
│  - GD (PNG, current)                │
│  - Cairo (SVG, PDF, high-quality)   │
│  - Canvas (browser preview)         │
│  - Raw (pixel buffer for analysis)  │
└─────────────────────────────────────┘
```

### 2.3 Zenka Integration

The toolkit operates as a Protocol-7 zenka (or zenka group):

- **gfx-matrix**: Core primitive library and macro engine
- **gfx-render**: Backend-specific renderers
- **gfx-compare**: Reference overlay and diff analysis
- **gfx-optimize**: Parameter search and harmonic analysis

Communication via standard zenka tachyon-wind channels. Macro files
are the primary data exchange format.

---

## 3. Macro Language Specification

### 3.1 File Format

Extension: `.gfx` (plain text, UTF-8)

```gfx
# Nailara Logo Construction
# Origin: 2003 GIMP, reconstructed 2026
# Coord space: 128px (GIMP original)

@space 128
@center 64 64

# --- Outer shape ---
:base
  disc+ r=48                          # base filled disc

:cuts_outer
  disc- r=25 offset=35 cardinal=4     # 4 outer cutouts at 0°,90°,180°,270°

:cuts_center
  disc- r=29                          # center hole

:cuts_inner
  disc- r=17 offset=47 cardinal=4     # 4 inner cutouts

# --- Duplication ---
:leaf4
  checkpoint                          # save state here

:rot45
  copy :leaf4
  rotate 45

:outer
  union :leaf4 :rot45

# --- Inner element ---
:inner
  copy :outer
  rotate -22.5
  scale 0.425

:final
  union :outer :inner

# --- Output ---
@render png 1024 nailara.png
@render svg nailara.svg
@render preview nailara-steps.html --ref nailara_ref.png
```

### 3.2 Command Reference

#### Coordinate System
```
@space <size>              # coordinate space (default 128)
@center <x> <y>            # center point (default: space/2, space/2)
@unit <name> <value>       # named constant: @unit ring_r 26
```

#### Layer/Step Labels
```
:name                      # label this step (creates checkpoint)
```

#### Additive Primitives (draw white/opaque)
```
disc+ r=<R>                           # filled disc at center
disc+ r=<R> at=<X>,<Y>               # filled disc at position
disc+ r=<R> offset=<D> angle=<A>     # filled disc offset from center
ring+ r_out=<R1> r_in=<R2>           # filled annulus at center
ring+ r_out=<R1> r_in=<R2> at=<X>,<Y>
arc+  r=<R> from=<A1> to=<A2> w=<W>  # arc segment
```

#### Subtractive Primitives (cut transparent)
```
disc- r=<R>                           # cut disc at center
disc- r=<R> at=<X>,<Y>               # cut disc at position
disc- r=<R> offset=<D> angle=<A>     # cut disc offset from center
disc- r=<R> offset=<D> cardinal=<N>  # N discs equally spaced (sugar)
disc- r=<R> offset=<D> radial=<N> angle=<A>  # N discs from angle
ring- r_out=<R1> r_in=<R2>           # cut annulus
clip  r=<R>                           # clip to disc (remove outside)
```

#### Transforms (create new layer from existing)
```
copy <:label>              # copy labeled step to new layer
rotate <degrees>           # rotate current layer around center
scale <factor>             # scale current layer from center
mirror <axis>              # mirror: h, v, or <angle>
```

#### Boolean Operations
```
union <:a> <:b>            # combine two layers (additive)
subtract <:a> <:b>         # a minus b
intersect <:a> <:b>        # only where both exist
xor <:a> <:b>              # exclusive: where one but not both
```

#### Measurement / Analysis (non-destructive)
```
measure overlap <:a> <:b>  # pixel overlap count/percentage
measure extent             # bounding box of current layer
measure symmetry           # rotational and bilateral symmetry scores
compare <:label> --ref <file>  # pixel diff against reference
```

#### Checkpoints
```
checkpoint                 # save full state (can restore later)
restore <:label>           # restore to checkpoint
```

#### Output
```
@render <format> [size] [filename] [options]
  # formats: png, svg, pdf, html, canvas, raw
  # options: --ref <file>, --bg <color>, --glow <params>
```

### 3.3 Variables and Expressions

```gfx
@unit R  26                # define constant
@unit T  6
@unit OFF 37

disc+ r=$R                 # use constant
ring+ r_out={$R+$T/2} r_in={$R-$T/2}   # expression
disc- r=$R offset=$OFF cardinal=4
```

Expressions support: `+ - * / % sqrt sin cos pi`
and named constants via `$name` or `${name}`.

### 3.4 Macros (Reusable Blocks)

```gfx
@macro leaf_ring(R, T, OFF)
  ring+ r_out={$R+$T/2} r_in={$R-$T/2}
  disc- r={$R*0.8} offset=$OFF cardinal=4
@end

# Invoke:
leaf_ring(26, 6, 37)
leaf_ring(18, 4, 25)   # smaller version with different params
```

---

## 4. LLM Agent Interface

### 4.1 The Handoff Problem

An LLM generating graphics in a single conversation suffers from:

1. **Context decay**: Quality degrades as conversation grows
2. **Genius-of-the-moment**: Depends on maintaining perfect cross-references
3. **No partial saves**: If the session ends, work is lost
4. **No specialization**: One model does everything, suboptimally

### 4.2 Solution: Macro as Communication Protocol

The `.gfx` macro file becomes the handoff artifact:

```
Model A (spatial reasoning):
  → Analyzes reference image
  → Writes initial .gfx with geometric relationships
  → Annotates with comments explaining intent

Model B (parameter optimization):
  → Reads .gfx + reference image
  → Runs render, compares to reference
  → Adjusts numeric values
  → Writes updated .gfx

Model C (code generation):
  → Reads finalized .gfx
  → Generates SVG, React component, CSS animation, etc.

Local model (cheap, fast):
  → Handles repetitive parameter sweeps
  → Renders hundreds of variants
  → Reports best-fit parameters back
Human (the creator):
  → Edits specific steps directly
  → Overrides any agent's work
  → Final authority on aesthetic judgment
```

### 4.3 Agent Task Descriptors

Each task passed between agents includes:

```yaml
task:
  type: refine_step          # or: analyze, generate, optimize, translate
  target: ":cuts_outer"      # which step(s) to work on
  macro: "nailara.gfx"       # the macro file
  reference: "nailara_ref.png"
  constraint: "all values must be integers"
  objective: "minimize pixel diff at step :leaf4 vs reference"
  budget: 5                  # max iterations / tool calls
```

### 4.4 Comparison Protocol

Every render step can produce a diff score against reference:

```
STEP    LABEL        DIFF    NOTES
  1     :base        82.3%   expected - full disc vs sparse logo
  2     :cuts_outer  34.1%   leaf shapes emerging
  3     :cuts_center 28.7%   center cleared
  4     :cuts_inner  19.2%   inner gaps forming
  5     :leaf4       15.8%   ← focus optimization here
  6     :rot45       11.2%   8-fold approach working
  7     :outer        8.4%   close
  8     :inner        5.1%   inner element positioned
  9     :final        3.2%   within tolerance
```

A downstream agent receiving this table knows exactly which step needs
work and how much improvement each step contributed.

---

## 5. Primitive Library Requirements

### 5.1 Geometric Precision

- All primitives operate in a continuous coordinate space (not pixel grid)
- Rendering to pixels happens only at output time
- Coordinates can be fractional (0.5px precision in GIMP space)
- Boolean operations are mathematically exact (not pixel-approximated)

### 5.2 Required Primitives

| Category   | Primitive     | Parameters                          |
|------------|---------------|-------------------------------------|
| Shape      | disc          | center, radius                      |
| Shape      | ring          | center, r_outer, r_inner            |
| Shape      | arc           | center, radius, start_angle, end_angle, width |
| Shape      | rect          | origin, width, height               |
| Shape      | polygon       | vertices[]                          |
| Boolean    | union         | layer_a, layer_b                    |
| Boolean    | subtract      | layer_a, layer_b                    |
| Boolean    | intersect     | layer_a, layer_b                    |
| Boolean    | xor           | layer_a, layer_b                    |
| Transform  | rotate        | layer, angle, center                |
| Transform  | scale         | layer, factor, center               |
| Transform  | translate     | layer, dx, dy                       |
| Transform  | mirror        | layer, axis_angle                   |
| Duplicate  | copy          | layer → new layer                   |
| Duplicate  | radial_copy   | layer, N, angle_step                |
| Measure    | bbox          | layer → {x,y,w,h}                  |
| Measure    | pixel_count   | layer → count of opaque pixels      |
| Measure    | overlap       | layer_a, layer_b → count            |
| Measure    | symmetry      | layer → {rotational, bilateral}     |
| Compare    | diff          | layer, reference → score            |
| Style      | glow          | layer, color, radius, intensity     |
| Style      | colorize      | layer, color                        |
| Style      | feather       | layer, radius                       |

### 5.3 Layer Stack

- Unlimited named layers
- Each layer = bitmap with alpha channel
- Layers are created by primitives and transforms
- Layers can be referenced by name (`:label`) or index
- Layers are immutable once checkpointed (new operations create new layers)

---

## 6. Render Backends

### 6.1 PNG (GD) — Current Implementation

- Pixel-based rendering via Perl GD module
- Good for: quick iteration, pixel-exact comparison
- Limitation: rotation quality (nearest-neighbor sampling)
- Enhancement needed: bilinear interpolation for rotation

### 6.2 SVG (Cairo or direct XML)

- Vector-based, resolution-independent
- Good for: final output, web embedding, infinite zoom
- Circle primitives map directly to SVG `<circle>` elements
- Boolean operations via SVG clip paths and masks
- Priority: HIGH — most useful output format

### 6.3 HTML Canvas

- Browser-based interactive preview
- Good for: parameter tuning, visual comparison
- Already proven in v1-v13 iterations
- Can serve as the "frontend" for the toolkit

### 6.4 PDF (Cairo)

- Print-ready output
- Good for: documentation, physical media
- Priority: LOW — derive from SVG

---

## 7. Frontend Requirements

### 7.1 CLI (Primary — Perl)

```bash
# Render macro to PNG
gfx-render nailara.gfx --png 1024

# Render with reference overlay
gfx-render nailara.gfx --preview --ref logo_ref.png

# Render single step
gfx-render nailara.gfx --step :leaf4 --png 512

# Parameter sweep
gfx-sweep nailara.gfx --var R --range 20:30:1 --compare ref.png

# Diff report
gfx-diff nailara.gfx ref.png --table
```

### 7.2 Web UI (Enhancement)

- Displays macro steps as clickable pipeline
- Each step shows thumbnail + parameters
- Sliders for numeric values, live re-render
- Reference overlay with opacity/position controls
- Export modified macro back to `.gfx` file
- Could be generated FROM the macro file (self-documenting)

### 7.3 LLM Agent API (Zenka Protocol)

```perl
# Agent receives task via tachyon-wind
my $task = receive_task();
my $macro = parse_gfx($task->{macro_file});

# Agent modifies specific step
$macro->set_param(':cuts_outer', 'r', 26);
$macro->set_param(':cuts_outer', 'offset', 37);

# Agent renders and compares
my $score = $macro->render_and_compare($task->{reference});

# Agent returns result
send_result({
    macro => $macro->serialize(),
    score => $score,
    changes => $macro->diff($task->{macro_file}),
});
```

---

## 8. Lessons Learned (Anti-Patterns to Prevent)

### 8.1 The Outline Extraction Trap

**What happened:** We extracted outlines from solid shapes, which rounded
all sharp vertices and destroyed the geometric precision.

**Prevention:** The toolkit should track whether a shape was constructed
additively or subtractively. Sharp vertices formed by circle-circle
intersections must be preserved. Outline extraction is a RENDER EFFECT,
not a construction step.

### 8.2 The Parameter Explosion

**What happened:** Each version added more sliders, making it harder to
find the right combination. v12 had 20+ parameters.

**Prevention:** Macro variables with constraints. Parameters should be
DERIVED from a minimal set of independent values:

```gfx
@unit R 26        # ONE base radius
@unit T 6         # ONE thickness
@unit OFF 37      # ONE offset
# Everything else derived:
# inner_edge = R - T/2 = 23
# outer_edge = R + T/2 = 29
# These are CONSEQUENCES, not free parameters
```

### 8.3 The Additive-When-Subtractive Confusion

**What happened:** We spent 8 versions trying to BUILD the shape from
stroked circles and outlines, when the original was CARVED from a solid
disc by punching holes.

**Prevention:** The macro language explicitly distinguishes `+` (additive)
from `-` (subtractive) operations. The construction narrative is visible
in the macro file itself. An agent reading the macro can see the INTENT.

### 8.4 The Context Window Drift

**What happened:** As conversation grew, earlier geometric insights were
lost and contradicted by later attempts.

**Prevention:** The macro file IS the single source of truth. It persists
outside any conversation. Each modification is a small, reviewable diff.
No agent needs to hold the entire construction in context — just the
step they're working on plus the comparison score.

---

## 9. Implementation Roadmap

### Phase 1: Core Engine (Current)
- [x] GD-based renderer (nailara-tool.pl)
- [x] Basic primitives: disc, ring, cut, rotate, scale, union
- [x] Reference overlay in HTML preview
- [ ] Macro file parser (.gfx format)
- [ ] Variable substitution and expressions
- [ ] Step-by-step diff scoring

### Phase 2: Multi-Agent Support
- [ ] Task descriptor format (YAML)
- [ ] Tachyon-wind integration for zenka communication
- [ ] Parameter sweep tool (gfx-sweep)
- [ ] Checkpoint/restore mechanism
- [ ] Git-based macro versioning

### Phase 3: Advanced Rendering
- [ ] SVG output backend
- [ ] Bilinear interpolation for rotation
- [ ] Glow/colorize render effects
- [ ] Anti-aliased output at arbitrary resolution

### Phase 4: Frontends
- [ ] Interactive web UI (generated from macro)
- [ ] GIMP plugin (import/export .gfx)
- [ ] Protocol-7 zenka API bindings
- [ ] Integration with graphics-matrix zenka group

---

## 10. Harmonic Integration Notes

The nailara logo reconstruction revealed mathematical harmonics consistent
with Protocol-7's framework, despite predating it by 20+ years:

- Base radius 26 = 2 × 13
- Offset 37 = prime
- Inner edge 23 = prime
- Outer edge 29 = prime
- Scale factor 0.425 = 17/40 (17 = prime)
- Rotation 22.5° = 45°/2 = 90°/4 (recursive halving)

The toolkit should support harmonic analysis as a measurement primitive:

```gfx
measure harmonics          # analyze all current parameters
                           # for 7/13 resonance patterns
```

This connects to Protocol-7's `AMOS7::Harmony` validation — the same
mathematical substrate that validates BMW digest signatures can validate
geometric construction parameters.

---

## Appendix A: Nailara Logo — Minimal Construction

The definitive construction, once parameter-locked:

```gfx
@space 128
@center 64 64

# 10 circles, 3 transforms, 1 union — that's the entire logo

:base
  disc+ r=48

:carve
  disc- r=25 offset=35 cardinal=4    # outer leaf gaps
  disc- r=29                          # center hole
  disc- r=17 offset=47 cardinal=4    # inner leaf gaps

:leaf4
  checkpoint

:eight
  copy :leaf4
  rotate 45
  union :leaf4 _

:inner
  copy :eight
  rotate -22.5
  scale 0.425

:final
  union :eight :inner

@render png 1024 nailara.png
@render svg nailara.svg
```

10 circles. 13 lines of construction. The rest is rendering.

---

*a'nailara laikani'he — the universe in harmony*

#,,.,,,..,.,.,,.,,.,.,..,,,,.,,..,,.,,,..,.,,,..,,...,...,,..,,.,,...,.,.,...,
#LN4VBUCD3IUAVXHC5YOYZSHAKIZZD3JL4T3NFOMHQG64JPMY6HCJQJAJOCEOGX3LDJPJC6MUR27GO
#\\\|6UIH4BV2SRTAO7AEA5QNB3X6OZ6OOXX67TEPH7JN22MDWB7OG2L \ / AMOS7 \ YOURUM ::
#\[7]PNLIYIHNEEJSB434MZF6RAFAVV5YEJE66GS4TEUXBOLBQ2FFTEDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
