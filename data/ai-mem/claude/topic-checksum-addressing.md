---
name: checksum-based universal addressing
description: AMOS checksums as universal routing primitive — models, tasks, deps, groups all addressed by CHKSUM7; everything is a group of size 1 by default
type: project
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

## Expectability principle

Reliable base layer built on awareness of what all common functionality shares.
When every layer uses the same addressing and routing primitives, each new
capability inherits the reliability of the base — no need to re-prove routing
for each use case. Complexity investment is front-loaded but repaid through
minimization and reuse at every subsequent scale.

#,,.,,,.,,..,,,..,,,.,,.,,,..,,..,..,,,..,.,.,..,,...,...,.,,,,..,...,,.,,,..,
#E7F7NGO34QP53YVH6FCEWFORSD2K4BOSVEOS3SBCAKQW3KKPL6Z56CSG7BZRVSHNAHVW3DHPDJDPC
#\\\|YWUKBY3AWNMUTQ2TCKMPD5URV4XYQVQK5TF5WLZHB4SAY3BDYJ7 \ / AMOS7 \ YOURUM ::
#\[7]3I7I3DMIT3ZN6KCEZUXTYC7MZWUF63EUQ66A7T6332KO6DRD2MBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
