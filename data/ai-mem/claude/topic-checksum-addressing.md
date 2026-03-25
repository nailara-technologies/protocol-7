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

## Expectability principle

Reliable base layer built on awareness of what all common functionality shares.
When every layer uses the same addressing and routing primitives, each new
capability inherits the reliability of the base — no need to re-prove routing
for each use case. Complexity investment is front-loaded but repaid through
minimization and reuse at every subsequent scale.

#,,,.,,..,.,,,,..,,,.,,,,,,,,,,.,,,..,..,,,.,,..,,...,...,...,,.,,,..,,,,,...,
#C4TMCSI3R2BMB6PJWOS63AV2GTMCP2PLYIIRRY67GURK2RBWYGAMKTRWWBXNB26EGB7HM6P7RQPSC
#\\\|SBGGDN6UYZZBWVNJBNQ5YQZXEXW3UHCXHGS3S6XRHWCXBKQNAEY \ / AMOS7 \ YOURUM ::
#\[7]R6JY2HYKCKWLBJBNIJ5B4NFNYALJNYQPMILSOO65MWDVHLZJFQDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
