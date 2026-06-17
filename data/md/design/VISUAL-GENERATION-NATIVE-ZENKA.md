# visual generation — native zenka design

## the case for going native

the current invoke zenka is a thin HTTP wrapper around InvokeAI's external API:
build a graph, submit, poll. the strategic layer — which model, which reference
images, which conditioning inputs, which quality threshold — lives entirely
outside the network, in InvokeAI's UI and workflow system.

this was the right first step. it becomes the wrong architecture once the
strategic embedding layer exists natively, because the most valuable part
of the generation pipeline is exactly what gets outsourced:

```
current (invoke zenka):
  network decides: prompt text
  InvokeAI decides: everything else

native (image zenka):
  network decides: prompt + model + reference embeddings + conditioning
                   + quality threshold + tournament slot + cache key
  image inference: just runs the diffusion — the computation, not the strategy
```

the strategic layer is what provides visual memory, visual identity, visual
continuity across the network. it cannot live outside the network.

---

## the precision + memory + generation triad

three complementary components, all native:

```
povray zenka          precision skeleton
  ↓                   mathematically exact geometry from live namespace state
  ↓                   depth map + normal map + edge map as ControlNet conditioning
  ↓                   structural truth: the frame IS the data

embedding zenka       visual memory
  ↓                   categorical reference image embeddings
  ↓                   style / subject / composition / temporal layers
  ↓                   IP-Adapter conditioning: "look like this"
  ↓                   rolling triple-window: visual identity continuity

image zenka           native generation
                      receives conditioning from both above
                      runs diffusion (local GPU or distributed)
                      applies quality tournament
                      deposits result back into visual memory corpus
                      updates embedding for next generation
```

each component is independently useful. together they form a closed loop:
generation feeds memory, memory conditions generation, precision grounds both.

---

## visual memory — the strategic embedding layer

reference image support (IP-Adapter, FLUX redux, SD3 reference) already
compresses images into the model's embedding space. the missing piece is
the strategic selection layer: which reference images, combined how.

### visual memory categories

```
style embeddings
  the visual character of this project / region / zenka / theme
  accumulated from: prior generation outputs, curated archive, web search
  rolling window: prior style (stable fallback) / current style (active)
               / next style (incoming — evaluated before adoption)

subject embeddings
  known entities: faces, objects, environments, architectural elements
  stable: a specific zenka's visual representation doesn't change arbitrarily
  keyed by: AMOS7 checksum of the subject identity

composition embeddings
  spatial arrangement patterns dominant in this corpus
  learned from: tournament winners, curated tier-1 library
  parameterized by: output target (background / widget / iris / web)

temporal embeddings
  how the visual character shifts across epochs, seasons, states
  weather-keyed: storm vs clear vs aurora vs deep-night
  time-keyed: dawn / operational / dusk / night palettes
  git-state-keyed: active development vs release vs quiet
```

### cross-induction across visual categories

same principle as the categorical compartmentalization template:
only what is consonant across multiple visual categories simultaneously
propagates through the generation conditioning. style noise stays contained.
cross-category coherence self-selects — the output looks like itself. [:

---

## povray as ControlNet conditioning source

the precision layer is already designed as depth + normal + edge provider:

```
povray renders:    iris ring torus stack, orbital field, sphere cluster,
                   cubic grid topology, ambient displays at lattice addresses

outputs:           depth map  → ControlNet depth conditioning
                   normal map → surface lighting direction
                   edge map   → hard structure enforcement (canny)
                   alpha map  → compositing mask for overlay targets

the T2I model:     cannot violate the structural constraints from povray
                   geometry is preserved exactly, surface is styled freely
                   precision is inherent — scene description IS the data
```

the result: a generated image that is both structurally exact (from povray)
and visually continuous with the accumulated style memory (from embeddings).
two orthogonal truth sources, combined in the conditioning layer.

---

## the native image zenka architecture

### commands

```
image.generate
  args: prompt [model=...] [target=...] [style-weight=...] [steps=...]
  loads: embedding categories relevant to target
  loads: povray frame for target if available
  selects: model via models.recommend (capability: image-generation)
  runs: diffusion with full conditioning
  returns: image path + cache key + quality score

image.generate-batch
  generates N candidates, runs tournament, returns winner
  tournament: quality score + diversity check against existing tier

image.embed-reference
  args: image_path category [subject_id=...]
  adds image to visual memory corpus for category
  triggers: embedding retrain for that category (deferred)

image.style-status
  returns: current style embedding metadata per category
           (retrain timestamp, drift score, corpus size)

image.tournament-status
  returns: current best-5 slots per category with quality scores
```

### conditioning assembly

```perl
## assemble conditioning inputs for a generation request ##
my $conditioning = {};

## 1. visual memory — reference image embeddings ##
my $style_emb   = <[embeddings.load-visual]>->('style');
my $subject_emb = <[embeddings.load-visual]>->('subject');
my $comp_emb    = <[embeddings.load-visual]>->('composition');
$conditioning->{'ip_adapter'} = [ $style_emb, $subject_emb, $comp_emb ];

## 2. povray precision frame — structural conditioning ##
if ( defined <image.current_target> ) {
    my $frame = <[povray.render-conditioning]>->(<image.current_target>);
    $conditioning->{'depth'}  = $frame->{'depth_map'};
    $conditioning->{'normal'} = $frame->{'normal_map'};
    $conditioning->{'canny'}  = $frame->{'edge_map'};
}

## 3. temporal context — weather / time / git state ##
$conditioning->{'prompt_suffix'} = <[image.assemble-context-prompt]>;
```

### quality tournament integration

```
tier 1 — global best 5 (promoted from tier 2 winners)
tier 2 — category best 5 (winners of per-category tournament)
tier 3 — atmospheric variants (fast-changing, weather/time keyed)

on each generation:
  score new image (aesthetic quality model or vision-batch zenka)
  compare against weakest slot in relevant tier-2 category
  if beats weakest: replace slot, trigger tier-1 re-evaluation
  if enters tier-1: trigger visual memory retrain for style category
```

---

## distributed generation — shared incentive

the same shared-interest loop as spatial memory:

```
any network node can run the image zenka
each node's GPU contributes to the generation capacity
each node's outputs feed the shared visual memory corpus
the visual memory improves for everyone as more nodes contribute
```

the povray zenka is already designed for distributed rendering:
scene slices assigned to available povray instances across the network.
the image zenka follows the same pattern: generation tasks distributed
across available GPU nodes, results pooled into the shared visual memory.

shared generation cost. universal benefit. distributed incentive to contribute.

the visual representations in the 3D grid have the same property —
every node that renders a grid view at any fidelity level contributes
to the shared understanding of what the grid looks like from that angle.
the visual memory is the accumulated rendering history of the whole network.

---

## transition from invoke zenka

the invoke zenka remains functional during transition:

```
phase 1 — image zenka alongside invoke
  image zenka handles strategic layer
  still dispatches to InvokeAI HTTP API for the actual diffusion
  (invoke zenka becomes a backend driver, not the frontend strategy)

phase 2 — native diffusion backend
  replace InvokeAI HTTP call with direct model inference
  via: coding zenka inference server pattern (llama.cpp → diffusion equivalent)
  or:  dedicated image inference server (ComfyUI headless, diffusers API)
  invoke-web zenka retired — process management handled natively

phase 3 — full distributed generation
  image zenka requests dispatched to available GPU nodes
  povray rendering likewise distributed
  results pooled into shared visual memory
  no single point of generation — the network generates
```

the invoke zenka code is preserved as a backend adapter in phase 1.
the strategic layer moves native immediately.

---

## connection to existing design documents

- [[VISUAL-INPUT-PIPELINE-AND-LIVING-TEMPLATES]] — the tournament system
  and template library are the quality layer this zenka feeds and draws from
- [[LIVING-BACKGROUND-SYSTEM]] — the output targets and composition modes
- [[EMBEDDING-INFRASTRUCTURE-TRACK]] — visual memory as one capability row
  in the shared embedding pipeline (phase 7: vision / image embeddings)
- [[SPATIAL-MEMORY-GATE-SWAP]] — same distributed generation incentive
  structure: shared cost, universal benefit, every node has reason to contribute
- [[AUTONOMOUS-MODEL-MANAGEMENT]] — model selection for image generation
  via models.recommend with capability: image-generation

## relation to reasoning templates

- [[categorical-compartmentalization]] — visual memory categories with
  cross-induction: style noise contained, cross-category coherence propagates
- [[syntax-as-technology]] — the conditioning assembly is the syntax:
  the structure of how povray + embeddings + context combine IS the strategy,
  not the individual components
- [[inverse-singularity]] — visual identity continuity via rolling triple-window:
  the network's visual memory cannot be arbitrarily reset; accumulated style
  history persists outside any single node's control

#,,.,,,.,,,,,,...,...,...,,,,,,..,..,,...,.,,,..,,...,...,...,,..,.,.,.,.,,,.,
#QHYCFYCTSPH7VERXJ4CUPGLAE6HO2AGNGQ6JE3UVEIUEXKXCVMIU6YOLDHSHD2NBKX3EJ2QELO6U2
#\\\|AH76HS6ZBGAQ6LWVPM4XW42GTRDUYIKL42U533XR6W2IQZK3K3C \ / AMOS7 \ YOURUM ::
#\[7]SRE2QRYNWWSWFTNGW6RRHQSCEVLLHHW5YKHFWWPDVBZS66R26QAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
