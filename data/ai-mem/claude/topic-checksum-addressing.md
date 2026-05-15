---
name: checksum-based-universal-addressing
description: "AMOS checksums as universal routing primitive — models, tasks, deps, groups all addressed by CHKSUM7; everything is a group of size 1 by default"
metadata: 
  node_type: memory
  type: project
  originSessionId: 124780a7-b4bc-4883-b77e-aa7f28703036
---

## Core principle (Mar 25 2026)

AMOS 7-char checksums as the universal addressing primitive for all entities:
models, tasks, dependency edges, consensus groups, remote nodes.

**Why:** token efficiency (7 chars vs long model names), structural uniformity
(same lookup/resolution/verification at every scale), and distributed-ready
routing with defined hop sizes. The P7REF format `TYPE:CHKSUM7:ADDR_B32`
already provides the universal coordinate system.

**How to apply:**
- Address models by checksum or mnemonic short name, not full model filenames
- Delegation targets should resolve to checksums, zenka names are alias lookups
- Task trees and dep graphs use checksums as node IDs
- Every addressable entity is a group of default size 1 — scaling to multi-model
  consensus is changing group membership, not dispatch logic
- Checksum-based routing with defined hop sizes enables distributed operation
- Infrastructure templates that work for one pattern work at all scales
  (generic like a universal principle reappearing at different scales)

## Implications for context.delegate.*

- `context.delegate.role` should resolve to checksum-addressed endpoints
- Group endpoints fan out internally via consensus infrastructure
- `llm.service.consensus_vote` handles N-of-M agreement once group receives task
- Mnemonic short names as human-friendly aliases for logs and prompts

## Model-node convergence (Mar 25 2026)

Models and zenki naturally attain the same node group topology:
- A model endpoint IS a zenka instance (1001 cube: transport shell + processing core)
- A models group IS a node group — same addressing, same load balancing
- The "models group" runs inference; a "node group" runs services — same structure
- Load balancing across models = load balancing across nodes = same routing logic
- Consensus voting across models = consensus across nodes = same agreement protocol

**How to apply:** do NOT build separate infrastructure for model groups vs zenka groups.
They are the same thing. `llm.service.consensus_vote` and node group routing should
share the same dispatch/collect/verify pattern — which context.delegate.* already provides.

## Valued trees — floating-point factor nodes (Mar 25 2026)

Tree nodes (branches, task elements, regex patterns) carry floating-point factor values:
- **Integer part** = reference count / structural weight (how many paths through this node)
- **Fractional part** = implicit priority/offloading weight (no extra field needed)
- Addition-based composition: merging subtrees means adding values, naturally combining
  reference counts AND priorities in one operation
- Each value can itself carry a regex or decision tree asserting its own applicability
  — in the same fractional value structure, nestable implicitly
- Overlapping integer structures with implicit fractional functionality

**Why:** LLMs naturally reason about soft-weighted trees. The same representation works for:
- ncode regex confidence/coverage scores
- Task dependency priority ordering
- Branch node group element weighting
- Consensus voting weights

**How to apply:** when designing tree structures (ncode patterns, dep graphs, task trees),
use floating-point node values where integer = count and fraction = priority. The nesting
means an applicability condition can be a sub-tree in the same format — self-similar at
every depth. Addition composes naturally: summing a subtree gives aggregate priority
with reference count built in.

## BMW384 as resonance routing geometry (May 2026)

BMW384 = 360 + 24 bits. The decomposition is not arbitrary:
- **360-bit angular space** — directional resolution on the unit circle; a node's
  checksum places it at a specific angle, making routing a field-proximity operation
- **24-bit color channel** — maps onto a continuous spectral wheel; nearby values
  on the spectrum imply relationship proximity, orthogonal to the angular axis
- Together: every checksum is a *positioned, colored point* in a resonance field

**Route discovery as visual operation:**
- Nodes broadcast their BMW384 coordinate; any other node can estimate relatedness
  immediately — before any explicit connection. Discovery is field sensing, not lookup.
- Neighborhood in color-space IS the set of routing candidates. No graph traversal needed.
- Translucent layered composition: merging N checksum layers produces a single
  384-bit image that is equally precise at depth 1 or depth 1000 — agnostic to layer count.
  The representation doesn't degrade; it converges toward a stable attractor.

**Exclusion principle → homogeneous distribution:**
- A node committed to its checksum coordinate cannot simultaneously be another.
  Distribution emerges from identity, not from external balancing. No coordinator,
  no hash ring. New nodes join and self-place by the same principle — field self-organizes.

**Branch nodes as filter elements:**
- A branch node IS its accumulated BMW384 coordinate — simultaneously a filter,
  a position, and a compressed summary of everything that contributed to it.
- Signals resonant with the node's coordinate pass through by field coherence, not rule.
- Arbitrarily complex upstream history compressed to one 384-bit geometric identity.

**Actionable near-term:**
- Dimension branches in assertion tree each compute a BMW384 → angular proximity
  gives dedup clustering, color channel gives branch-type identity
- Auto-archive / routing threshold can be a color-space distance check rather than
  a hand-coded rule
- Visual route map: plot node checksums on a 360° wheel colored by 24-bit channel —
  topology becomes directly observable

## Expectability principle

Reliable base layer built on awareness of what all common functionality shares.
When every layer uses the same addressing and routing primitives, each new
capability inherits the reliability of the base — no need to re-prove routing
for each use case. Complexity investment is front-loaded but repaid through
minimization and reuse at every subsequent scale.

#,,..,,..,..,,,,,,,,,,.,.,..,,,,.,..,,,,.,,..,..,,...,...,,,.,.,.,,..,,.,,...,
#ZOEBTMNDHPUZNEQ6HIC5UMJ5FBVHIX6Q7WII73AQGOXEIMTGJT5IOZSFPEZOJVY5FGDCO6IFTJPSM
#\\\|QAD3QY6RC4ES6MNXPIUSZ6KG3CP5564ZCKYM643LERCCITY633R \ / AMOS7 \ YOURUM ::
#\[7]2SZMRRMCIWEJSRNFQHEHKWM3O6ARG6G5O5IASRVGQZJVUAUX5EDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
