---
name: topic-observer-centric-space
description: "observer-centric reference space — client always 0, signed address -n/2..0..+n/2, reference-count gravity, buffer swapping navigation, EM field transport model"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4b3850d2-8acb-4166-bbdf-ddf52d8182ba
---

design doc: `data/md/design/OBSERVER-CENTRIC-REFERENCE-SPACE.md`
related: [[topic-routing-crystal]], [[topic-reference-bubble]], [[topic-checksum-tree-wire]]

## core model

client IS 0 — not "at 0". grid recenters around it via buffer swapping.
navigation = position reassignment, not movement.

address space: -n/2 ... -2 -1 [0] +1 +2 ... +n/2
- position = reference count rank on each axis independently
- highest reference count → ±1 (closest to observer)
- new arrivals start at ±n/2 (boundary), fall inward as used
- n auto-expands outward; collapses when outer positions empty
- no coordinator: position IS reference count rank

## buffer swapping

client accesses node at +3 → node at +3 and node at 0 swap buffers →
relevant thing is now at 0. O(1) access to most relevant (already at 0).
accessing something = increasing its reference count = moving it toward 0.

## EM field analogy

reference count distribution = the field.
inner nodes (close to 0) = strong coupling, fast routing.
outer layers = carry actual traffic (like EM boundary).
center (observer) = source; doesn't carry traffic; IS routing.

## deduplication = convergence toward center

identical content from N sources collapses to one position.
position = total reference count across all sources.
deduplicated node is MORE central than any individual source.
dedup IS gravitational pull toward observer.

## routing without tables

address magnitude = hop count to observer.
route from +7 to 0: follow gradient -1 per hop. no table.
node-to-node: inward (01) to LCA, outward (10) to target.
LCA = local minimum of address magnitude on path = the 11 pivot.

## the darksun = observer at 0

position 27 = 3³ = the fixed center. 076923×n: all digit sums = 27.
8×(4×4×4-1)=504, void at 27 = the cube shells outward = iris rings.
corpus orbits darksun; darksun fixed by division by 13, not by corpus.
see VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md + IMPLOSION-CROSS-CORRELATION.md

## view specification

```yaml
view:
  observer: { z, y, x }          # darksun position (default 0,0,0)
  focus:
    position: { z, y, x }        # where observer looks
    normal: { z, y, x }          # away from observer = outward
                                  # toward observer = inward (backward lens)
  focus_secondary:
    position: { z, y, x }        # second vertex — binocular / dual view
    normal: { z, y, x }          # can point toward viewer = simultaneous
                                  # inner + outer perspective
  focal_length: 13               # zoom; 13 = natural harmonic
```

observer: IS the 0 point (darksun). space recenters around it.
focal_length = 0/'omni' → omnidirectional: all 8 cube faces in grid view simultaneously.
focal_length = 13 → natural harmonic default.
focal_length → ∞ → orthographic (parallel projection).
focus.normal toward observer = inward view: outer field watching darksun.
drone: mobile remote vertex deployed into reference space, looking back toward
  mothership (normal toward observer), relays acquired remote perspective back.
combined: observer at f=omni (all local faces) + drone at f=N (precise remote view).
observer at 0 = pivot all views originate from and return to, not a single viewpoint.

## temporal bandwidth (same mechanism as spatial)

clock period = 13 slots (natural harmonic, generator 076923 closes through 13).
face slot count in sequence = bandwidth = reference count rank.
sequence IS the allocation protocol — no negotiation needed.
receiver reads density to know bandwidth; no separate signalling.
spatial: reference count → distance from darksun (position).
temporal: reference count → slots per clock cycle (bandwidth).
same gravity, two domains, one mechanism.
checksum tree: multiple same-face-ID leaves per cycle = leaf count = bandwidth.
the allocation IS the attention — bandwidth follows reference counts with zero overhead.

## connections to existing systems

- `branch.group.propagate` — propagates interest count = drives position reassignment
- `branch.route.cache` — inner-ring nodes in the reference space
- routing crystal harmonic memory = this reference distribution in spatial form
- reference bubble follows reference gradient toward center
- hyperspace topology closed observer loop = observer always origin of own coordinates

#,,.,,...,.,,,...,..,,,..,...,,,.,.,,,...,.,.,..,,...,...,..,,.,,,,,.,,..,.,.,
#5FY4YQFJ7W4QH3ZPNVVR5OWXYBVDJZ4SN7YOGIHPPOKBVVYM4M3I432KFWJP52YVOPWSNWJRTDHW4
#\\\|YSFPWGI7HW3W6YNAPYSGTWMLERCEIIZUVNY5E5AJ56GMD22FHX5 \ / AMOS7 \ YOURUM ::
#\[7]Z65O4YOIZUYG5WJK5ZSGXAQUL5MB6M4PWMJDOX2XX6V4LWFKAMDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
