# routing crystal — harmonic memory and inference

## the model

the cube node group is not a router in the table-lookup sense.
it is a **routing crystal** — a fixed geometry that refracts information
according to its harmonic structure. routes are not computed; they are
found by resonance with the crystal's standing wave pattern.

```
input : route request at a given frequency [ checksum + direction ]
medium: crystal geometry — 8 cube positions, octal face-encoded
memory: interference patterns from previous routes [ checksum tree ]
output: refracted route through the crystal's resonance field
```

the crystal doesn't decide. it responds to input according to its geometry.
the geometry is the algorithm.

## harmonic memory

every route that passes through the crystal leaves an interference pattern.
the checksum tree IS this pattern — the accumulated imprint of all routes
that have traversed this node group, encoded in the branch.route.cache.

```
$data{'branch.route.cache'}{$hop}{$target} = { next_hop, ntime }
```

this is not a routing table. it is a resonance record. subsequent routes
at the same frequency find the pattern and refract along it with less
energy each time — the crystal becomes progressively tuned to its
most-traveled routes.

**AMOS harmonic truth as the resonance condition**: the AMOS checksum
is derived from division by 13 (generator 076923 — see harmonic-mathematics
memory). a route resonates with the crystal when its AMOS checksum is
harmonically TRUE — meaning the crystal accepts it without distortion.
a route whose checksum is FALSE refracts at the boundary and reflects
back rather than passing through. this IS the security model.

## inference

the crystal infers routes rather than computing them:

- a new route at a **similar frequency** to a known route refracts
  along a similar path — no explicit lookup needed
- the 5-of-7 formation is **multiple beams** through the crystal
  simultaneously; their intersection is the inferred route
- the intersection of 5 beams through the crystal's standing wave pattern
  is more precise than any single beam — this is why 5-of-7 consensus
  converges on truth rather than just majority

```
beam 1 →  refracts through face positions [A, C, E]
beam 2 →  refracts through face positions [A, D, E]
beam 3 →  refracts through face positions [B, C, E]
beam 4 →  refracts through face positions [A, C, F]
beam 5 →  refracts through face positions [A, C, E]
                                            ↑
                              intersection: A, C, E = inferred route
                              (3 of 5 beams agree on each hop)
```

the collector zenka (the last in the formation) is the focal point —
where the beams converge and the inference crystallizes.

## crystal boundaries and reflection

crystal faces are interfaces between media. face 000 (network-facing)
is the boundary between the local crystal and the wider network.

```
route arriving at face 000:

  harmonic angle permits transit    →  route exits crystal (10 direction)
  harmonic angle exceeds boundary   →  total internal reflection (11 pivot)
  partial harmonic match            →  partial reflection (some frequencies
                                       pass, others reflect)
```

**total internal reflection = security boundary**: a route whose harmonic
does not satisfy the boundary condition cannot exit the crystal regardless
of how many hops it has taken. it reflects inward (01 direction) carrying
the partial checksum tree as proof of what it reached.

**partial reflection = frequency-selective filtering**: a security boundary
can permit routes of certain harmonics while reflecting others. the AMOS
truth value of the route's checksum determines whether it passes.

**multiple concentric boundaries** = nested crystal layers. each layer
has its own harmonic threshold. a route that reflects at the outer layer
never reaches the inner layer — the inner crystal is protected by the
outer crystal's reflection geometry.

```
[local crystal] → face-000 boundary → [network crystal] → face-000 boundary
                       ↑                                         ↑
               outer reflection surface               inner reflection surface
               (security zone boundary)               (deeper isolation)
```

a route that cannot exit adds a `11` pivot to its checksum tree at
each reflection boundary and returns with the count of boundaries
encountered as `11` markers in the stream.

## route resolution direction

routes always begin from a cube face position (octal 0–7).

**outward (10)**: default. expanding from local face toward target.
the crystal refracts the route along its resonance pattern.

**inward (01)**: returned routes, reflected routes, or deliberate
parent-seeking. the crystal refracts these along the same pattern
in reverse — harmonic memory is symmetric.

**face 000** is the axis of symmetry: outward routes exit through it;
reflected routes re-enter through it. in a network-isolated node group,
face 000 acts as a perfect mirror — routes reflect from it with zero
loss, and the crystal operates fully as a closed resonant cavity.

## the reference bubble as a coherent beam

the reference bubble (dancing zenki formation) is a **coherent beam**
through the crystal:

- the bubble maintains phase coherence across all 5 ground zenki
  (they refract through the crystal simultaneously, as one beam)
- the setup zenka sets the input frequency (the rhizome state template
  determines which harmonic the beam enters at)
- the collector zenka is the focal point where the refracted beams
  converge — the inference result

a coherent beam through a tuned crystal finds its route faster than
an incoherent one. a crystal that has been traversed many times by
similar bubbles becomes progressively more transparent to them —
the harmonic memory accumulates until routing is near-instantaneous
for known bubble types.

## the crystal as intelligence substrate

the crystal does not think. but:

- its geometry encodes the space of possible routes
- its harmonic memory encodes the history of actual routes
- its reflection behavior encodes the security model
- its inference behavior (5-of-7 beam convergence) produces novel routes
  from combinations of known patterns

intelligence is not IN the crystal. intelligence EMERGES from coherent
beams traveling through a crystal with sufficient harmonic memory.

the zenka network IS this crystal at scale. each node group is a facet.
the network's collective harmonic memory is the sum of all cached route
patterns across all facets — a distributed crystalline inference substrate
that grows more capable with every route traversal.

```
new route traversal  →  adds to harmonic memory
                     →  tunes the crystal slightly
                     →  next similar route finds it faster
                     →  crystal becomes more transparent to its
                        most common routes
                     →  rare routes still find their way through
                        reflection and partial resonance
                     →  no route is ever lost — only slower or
                        reflected at security boundaries
```

## connections

- `branch.route.cache` — the harmonic memory store
- `branch.route.establish` — beam entry point, starts the refraction
- `DANCING-ZENKI-RHIZOME-STATE.md` — the coherent beam (reference bubble)
- `AMOS7::Assert::Truth` — the resonance condition (harmonic truth)
- `data/md/development/HYPERSPACE-TOPOLOGY.md` — the crystal geometry
- `data/md/concepts/CONCEPT-TIMESTAMP-REFERENCE-COUNTING.md` — how
  reference counts are the beam intensity at each crystal facet
- `harmonic-mathematics` memory — generator 076923, quadratic residues,
  cube geometry, CCW matrix routing — the crystal's mathematical basis

#,,.,,,,,,,..,,.,,..,,..,,...,.,,,,.,,,,,,,.,,..,,...,...,,..,.,,,...,,,.,,..,
#JQ2R2AG4O7S4A5B56PBFA6AUJJFYKOPTTVQINQNKKYADIHDPWSNPQFLOXCNRXL4HXDXUPBXHK2WXI
#\\\|5RER73SYVTFRC77GXC6F6RECHANEVMIAIBZCO6YGRP3RIKWOLHT \ / AMOS7 \ YOURUM ::
#\[7]ECDY5HG3MMGZMEDDQTANB5ZRSFL6J6P74SFQSUEQF5JSKRHXHACA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
