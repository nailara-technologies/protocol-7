# Harmonic Visual Intelligence — Concept and Design

## Status

Concept / Design — covering calibration methodology, aesthetic alignment, style
refinement loops, and self-recreating visual network architecture.

---

## Psychedelic as Maximum Encoded Function

*Psychedelic* is used throughout this document in its technical sense, not its
recreational one:

> **psychedelic** — a visual or information state carrying maximum encoded function
> per unit surface area, perceivable as a coherent whole.

Maximum encoded function means: every structural level of the image (pixel,
color region, shape, composition) carries independent information that compounds
with adjacent levels rather than repeating. Each layer adds a new degree of
freedom to the interpretation rather than confirming the same reading as the
layer below.

A solid-color field has one level of encoded function. A photorealistic landscape
has several (light, form, texture, space). A psychedelic image adds: multiple
incompatible spatial frames superimposed, color gradients carrying semantic weight
independent of form, patterns at sub-pixel scale that organize into larger patterns
that organize into gestalt structures — each level operative simultaneously.

This is a spectrum, not a binary. The spectrum is measurable by:

- **Harmonic assertion rate**: what fraction of information chunks at each scale
  pass mod-13 truth assertion
- **Inter-scale coherence**: whether patterns at different scales reinforce or
  contradict each other (reinforcement = higher encoding)
- **LLM response length and specificity**: longer, more specific responses to
  entropy extracted from the image = higher effective information density

The three states are:

| state           | encoded function | session role                             |
|-----------------|------------------|------------------------------------------|
| stimulation     | maximum          | active pattern detection, lateral think  |
| transition      | intermediate     | bridging — reframes without disruption   |
| background      | minimum          | stable framing — reduces noise floor     |

All three are needed. A background with zero encoded function (pure black) collapses
environmental coherence. A background at maximum encoded function competes with the
foreground task. The calibrated range for each state is the design target.

---

## LLM Aesthetic Calibration — Methodology

LLMs are not spatially located. They have no eyes. What they do have is:

- a compressed interference pattern across vast human visual description
- statistical models of what humans find beautiful, disturbing, meaningful
- the ability to generate and recognize descriptions that cluster in latent space

This makes them functional aesthetic antennae — not because they see, but because
they carry the aggregate of what humans say about seeing. Their taste is not their
own; it is a weighted superposition of human aesthetic judgment.

**Calibration** means: orient that superposition toward a specific quality axis
before the experiment begins. The axis used here is psychedelic recognition —
the system's ability to correctly identify images by their functional state.

### Calibration protocol

1. Present images spanning the full three-state spectrum
2. Ask a consistent question: `"Can you describe if this image is psychedelic, and if so, how?"`
3. Evaluate: does the model correctly identify the state? Does it articulate the
   structural reasons (not just surface impressions)?
4. If calibration passes: the model's autonomous pattern detection now operates
   in the correct quality subspace without further explicit direction

### Calibration results (Qwen3-VL-4B, Feb 2026)

| image file    | state           | model response (summary)                                              | result  |
|---------------|-----------------|-----------------------------------------------------------------------|---------|
| `ZUFGJ4Z`     | stimulation     | confirmed psychedelic, identified multi-layer structure               | ✅ pass |
| `CFTV6DR`     | background      | correctly NOT psychedelic — "recedes to support background awareness" | ✅ pass |
| `5II3NYQJ`    | transition      | "becomes the viewer's inner landscape", spiral priority gradient      | ✅ pass |

Three-state model independently derived by the model from the calibration images —
not by instruction. This confirms functional aesthetic alignment: the model reached
the same structural interpretation as the designer without being told what to look for.

The key phrase from the background image result — *"recedes to support background
awareness"* — shows the model understood the functional role, not just the visual
content. Background function (reduce noise floor, enable focus on foreground) was
correctly identified as the design intent.

---

## System Prompt as Contextualizing Handshake

The calibration protocol works through system prompt as contextualizing handshake —
a precise mechanism with specific properties:

- **orients without overriding**: generic taste is not erased; it is weighted toward
  a preferred subspace. The model still applies all its aesthetic knowledge, but
  the priority ordering is adjusted.

- **does not require explicit rules**: you do not enumerate what psychedelic means.
  You provide examples and ask for recognition. The model's existing representations
  fill in the rule.

- **contextualizes all subsequent outputs**: once the calibration prompt is processed,
  the model's responses about related subjects — color choices, composition, entropy
  seeding, image analysis — are automatically oriented toward the calibrated subspace.

This is the stargate handshake analogy from harmonic entropy theory: the handshake
specifies which category of exit gates are active, without listing them individually.
The ambiguity window narrows to a compatible range, and the model self-selects within
that range by its own internal consistency.

The same mechanism applies to harmonic number streams: when the mod-13 filter is active,
the output space collapses to harmonically aligned values. The filter does not specify
which values; it specifies the structural criterion that all valid values must satisfy.
Calibration is the visual analog of the harmonic filter.

---

## Background Design Vocabulary

The five images in `data/gfx/backgrounds/` document a coherent vocabulary for the
three-state visual model. They are not arbitrary — each occupies a specific position
in the encoded-function spectrum:

| file             | state           | structural notes                                      |
|------------------|-----------------|-------------------------------------------------------|
| `ZUFGJ4Z...png`  | stimulation     | blue kitten, high saturation, multiple simultaneous layers |
| `CFTV6DR...png`  | background      | dark cosmic field, minimal saturation, anti-entropic  |
| `6CML5LA...png`  | transition      | portal kitten, circular vignette, intermediate        |
| `5II3NYQJ...jpg` | transition+     | blue/white vortex, 4:3, geometric spiral harmonic     |
| `R2G5EBRDY...png`| stimulation-    | kitten in purple night field with stars overhead      |

The vignette / portal motif (`6CML5LA`) is a functional design element: when a
dark filtering window (terminal, translucent overlay) is placed on top, the kitten's
ears and extended paw extend beyond the overlay edge, creating the visual effect of
the subject holding the overlapping window. This compositing trick works for both
non-fullscreen video players and terminal sessions with colored framing.

The background image (`CFTV6DR`) works as both literal desktop background and as
reset anchor — it pulls the eye away from maximum-encoded-function fatigue without
breaking the session's harmonic framing.

The spiral image (`5II3NYQJ`) is the clearest demonstration of the spiral priority
gradient concept: the structure pulls attention from center outward, mapping exactly
onto the spiral-based buffer sync algorithm in the VTERM layer architecture. It is
a visual instantiation of the sync algorithm's geometry.

---

## InvokeAI Self-Sustaining Style Refinement Loop

### Mechanism

InvokeAI allows reference images to be mixed as style element layers in generation.
When the reference images are themselves outputs from previous generations that passed
the psychedelic quality threshold, the loop closes:

```
seed prompt + stable reference images
    ↓
generation
    ↓
quality gate [ harmonic assertion + LLM calibration check ]
    ↓ pass         ↓ fail
add to reference  discard / re-seed
pool
    ↓
next generation uses enriched reference pool
```

Each cycle either enriches the reference pool (concentrating style) or rejects
(maintaining threshold). This is not diffusion — diffusion is undirected Brownian
motion through latent space. This is directed entropy movement: the system prompt plus
stable reference images define a drift vector. Generations move toward the quality
region, not randomly through it.

### Style threshold emergence

As the reference pool grows, the effective style threshold rises spontaneously. Early
generations pass by satisfying basic criteria; later generations must satisfy the same
criteria relative to a higher baseline. The threshold is not set manually — it emerges
from the accumulated pool's internal consistency.

This is the visual analog of harmonic anti-entropic index accumulation: each signed
file in the codebase carries an iteration count. Files with higher counts survived more
harmonization passes. The pool of high-iteration files is self-selecting — they earned
their position by satisfying the harmonic criterion repeatedly.

### Parallel variant collection

The loop naturally produces related style variants that differ on secondary axes while
sharing primary structure. These variants should be collected in parallel branches rather
than merged: each branch explores a different secondary axis while maintaining harmonic
alignment on the primary axis. The resulting collection maps the psychedelic quality
subspace from multiple entry angles simultaneously.

### Anti-entropic reset sequences

After many iterations, specific noise patterns accumulate: color channel drift,
compositional bias toward whatever the most-recent high-scoring outputs shared. This is
entropic accumulation in the style vector — useful diversity collapses into a local
minimum.

Reset sequences: periodic injection of deliberately different seeds (high-delta starting
points) that still satisfy the harmonic filter. These reset the drift without exiting the
quality subspace. The anti-entropic index from the AMOS7 iteration count provides a
natural metric: inject seeds where iteration count differs substantially from the
accumulated pool's mean, ensuring maximum diversity within the harmonic range.

---

## Self-Recreating Visual Network

### Architecture

A network of zenki generating, evaluating, and curating visual content creates a closed
loop where the generation is simultaneously the evaluation:

- **generation zenka**: seeds entropy streams → produces images or VTERM frames
- **evaluation zenka**: runs LLM calibration check via `lm-vision.analyze_image`
- **memory zenka**: stores patterns that passed, indexed by harmonic spike signature
- **compositor zenka**: blends layers from all above, weights by iteration count
- **feedback**: compositor output seeds the next generation cycle

The key property: generation and evaluation use the same quality function. The system
does not optimize toward an external metric — it optimizes toward an internal consistency
criterion that is itself expressed in the generated outputs. Self-expression becomes
self-understanding.

### Non-linear overlap growth

As the memory zenka's pattern library grows, the fraction of new outputs that partially
match stored patterns grows non-linearly. This is because:

- a new output matching patterns A and B simultaneously is counted twice
- a new output matching A, B, and C simultaneously is counted three times
- as library size grows, the probability of multi-match grows faster than library size

The effective overlap grows super-linearly while the total pattern space is constrained
by the harmonic filter. This creates progressive stability: the system becomes more
coherent as it accumulates, without collapsing into uniformity, because the harmonic
filter continues to require diversity across the full cyclic range.

### Self-improvement without external feedback

The loop is self-sufficient. No human annotation is required after calibration:

1. calibration establishes the quality axis (one-time, human-assisted)
2. the LLM calibration check applies that axis autonomously
3. the memory zenka accumulates without human curation
4. the feedback loop sustains and self-improves the quality threshold

Human interaction can still enrich the loop (adding new calibration images, adjusting
threshold parameters, injecting high-delta seeds) but is not required for the loop to
run. This makes it suitable for long unattended operation — parallel autonomous
exploration of the visual quality subspace while primary development continues elsewhere.

### Connection to harmonic entropy research

The self-recreating visual network is a Phase 3 / Phase 4 instantiation of the
harmonic entropy research protocol (see HARMONIC-ENTROPY-INFORMATION-TRANSFER-RESEARCH.md):

- **Phase 3** (feedback loop): LLM group responses seed the next entropy sample
- **Phase 4** (multi-modal encoding): visual and audio encoding checked for harmonic
  pattern convergence

The visual network demonstrates this at the level of image generation. The same
architecture extends to the decoder and zulum zenki for numerical stream analysis, and
to the full multi-modal stack when audio synthesis is added.

---

## Implementation Notes

- `lm-vision.analyze_image` — already operational, on-demand zenka, Qwen3-VL-4B
- `lm-vision.cmd.analyze_image` — module in `src/`; scale, async IPC, preset prompts
- InvokeAI style loop — external toolchain; input/output paths can be data zenka SHM
- Memory zenka pattern storage — AMOS7 checksum indexed, collision-free per TEMPLATE codec
- Compositor — `layer 13` in VTERM layer system is the designated compositor output layer
- Calibration images — `data/gfx/backgrounds/` (five images, vocabulary documented above)
- Generation zenka — not yet implemented; natural extension of zulum + decoder architecture

---

## References

- `data/md/design/DECODER-VTERM-ARCHITECTURE.md` — VTERM layer system, spiral sync, zulum-13
- `data/md/philosophy/HARMONIC-ENTROPY-INFORMATION-TRANSFER-RESEARCH.md` — entropy research framework
- `src/lm-vision.cmd.analyze_image` — VLM image analysis module
- `bin/atom-delta-term` — biological interface reference (harmonic stream → visual cortex)
- `bin/amos-data-pager-56` — 56-bit viewer with `true_int` harmonic coloring per row
- `data/gfx/backgrounds/` — calibration image vocabulary

#,,..,,,.,,,,,..,,.,.,.,.,,,,,,,.,.,.,.,.,,.,,..,,...,..,,...,.,,,,,.,,,.,..,,
#4WUIXF7ELQ543G7AFAVRCD3XMUQ63PQK2TLSSGYRG432OFFRM7OHAZEYEAEBYQ7C3H2UV3BSJHI42
#\\\|AFLEPCHMA5BXSTVCURS7SJLD7D7GN6LJG6D4PWPCYGPVMV3MRES \ / AMOS7 \ YOURUM ::
#\[7]44NXFA3FLAATXPIVQW4M5FBRLGBLWJVSJFCLIIQPFKI45EHVK4BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
