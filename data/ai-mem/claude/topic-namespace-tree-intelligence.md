---
name: namespace-tree-intelligence
description: Architectural vision — the deduplicated namespace tree IS the intelligence layer, unifying code/data/state/history/planning with branch summarization and universal access
type: project
originSessionId: 941ef93c-3dcf-4d15-8c40-ccd709e0510b
---
## Normalized dot-namespace as universal routing primitive (May 2026)

**Canonical form**: dot-only notation, no mixed separators, no filesystem artifacts.
- `modules/base.init_code` → `code.base.init_code` (when modules/ renamed to code/)
- `configuration/zenki/cube/access.zenki` → `conf.zenki.cube.access.zenki`
- `data/tasks/bmw384-route-discovery` → `data.tasks.bmw384-route-discovery`

**Planned directory renames**: `modules/` → `code/`, `configuration/` → `conf/`
— both map cleanly to dot-only notation without ambiguity.

**Hybrid flat+directory form with precedence**:
- flat file `code/base.chk-sum.init_code` takes precedence over
  directory tree `code/base/chk-sum/init_code` when both exist
- files supersede directories silently — flat is the more intentional form
- already planned; precedence rule makes the implicit behavior explicit

**Namespace as checksum chain — bidirectional routing**:
- each dot-element gets its own BMW384 coordinate, computed incrementally:
  `code` → BMW384("code"), `code.base` → BMW384("code.base"),
  `code.base.init_code` → BMW384("code.base.init_code")
- parent and child coordinates are geometrically related by construction —
  siblings share ancestry, cousins share partial ancestry
- the namespace tree maps onto a coherent field topology where structural
  proximity implies coordinate proximity
- **forward**: traverse dot-elements left to right → arrive at leaf coordinate
- **backward**: given a BMW384 coordinate → find arc → find namespace prefix
  candidates → narrow by angle → arrive at module name
- discovery and naming are the same operation traversed in opposite directions

**Storage-layout independence**:
- BMW384 coordinate computed from normalized dot-path, not filesystem path
- renaming `modules/` → `code/` does NOT change any module's coordinate
- the dot-namespace IS the address; the filesystem is one possible backing store
- routing identity is stable across filesystem reorganizations

## Implementation Note (2026-05-07)

`valued.*` modules are the universal tree primitive — not task-specific.
The N+f structure (refs=integer, weight=fraction) is identical whether nodes
represent task dependencies, deduplication hits, or semantic convergence.
The deduplication tree, content/semantic tree, and decision tree are all
the same code with different node payloads and different ref-counting callers.
`valued.init_code` + `valued.node.*` + `valued.resolve` + `valued.tree.load`
are the shared substrate for all of them.

## Core Insight (2026-03-29)

The deduplicated namespace tree is not just organizational — it IS the intelligence.
The same dot-separated tree structure already underlies %code, %data, config paths,
module names, context-tree, and the observations stash. Unifying these into a single
addressable tree with automatic summarization creates the shared knowledge substrate.

## Properties of the Unified Tree

- **Nested branch summarization**: each node/branch automatically summarizes its
  children, rolling up from leaves to root. Same mechanism for code namespaces,
  data state, history, and plans.
- **Automatic namespace optimization**: implicit dedup and reorganization using
  dot separators. Same system across %data, %code, config, observations.
- **Universal for all concerns**: current state, state machines, history, planning,
  code organization — all branches of one tree.
- **Transparent access from anywhere**: models in localized processing queues
  (inference loops, task pipelines) can read/write the tree without going through
  their linear processing pipeline. Off-band improvement.
- **All parallel activity improves overall state**: observations, suggestions,
  questions, extracted knowledge flow into the tree asynchronously, outside
  of the sequential code processing workflows.

## Access Requirements

- Users, zenki, and LLMs interact freely with the tree
- No waiting for code processing workflows to surface results
- Visibility tools and commands in P7 for all agent types
- Generic read/write/query/subscribe interface

## Process Control — Preemption, Branching, Compaction

### Branch-level preemption
Any node in the tree can trigger workflow preemption. When a model raises an issue
(record_question, escalate, or automatic detection), the current workflow pauses at
that branch point. The raised issue gets its own processing context, produces a
summarizing report, and that report integrates back before workflow resumes.

### Issue isolation through compaction
A successfully raised and resolved issue compacts out of the context of the task
flow that triggered it. The resolution summary replaces the detailed back-and-forth.
This keeps the original task flow unbiased by the side-quest — the task context
remains clean, influenced only by the compact result, not the full exploration.

### Generic branching and integration
Like git branches but for processing. Any piece of work can branch off from any
tree node, proceed independently (possibly in parallel), and merge back with
branch compaction. The branch's full context compacts to a summary upon integration.
This parallelizes everything — multiple branches can explore different aspects
simultaneously, each with their own context window.

### Category + recency + relevance compaction
Context compaction is not just time-based (current: compact oldest messages first).
It should be semantic: what category of information is relevant to the current
branch of work, how recent is it, how relevant to the active task. Irrelevant
categories compact aggressively; relevant recent information is preserved.

### Reference type and count awareness
Every tree node tracks what types of references it contains and how many:
- Code references (module calls, $code{} entries)
- Data references (%data paths)
- External references (file paths, URLs, checksums)
- Cross-branch references (links to other tree nodes)
This enables smart compaction decisions: heavily-referenced nodes resist compaction,
orphaned branches compact first. Reference counts guide summarization depth.

### Relationship to current coding zenka workflow
- `record_question` / `escalate` = preemption triggers (primitive form)
- `task_complete` = branch completion signal
- Context compaction in process-queued-task = time-based prototype of semantic compaction
- observations stash = flat prototype of branch-level issue tracking
- The inference loop's tool rounds = linear pipeline that needs branch-aware interrupts

## Implementation Architecture — %DATA and Event-Driven Tree

### Global %DATA hash (uppercase)
Parallel to per-zenka `%data` (local state), `%DATA` is the global/shared tree.
Same dot-separated namespace, but visible across zenki and persistent.
Analogous to how `@INDEXCUBE` already provides checksum-based global mapping.

### Local ↔ Global mapping
Each zenka has local `%data` views of global `%DATA` branches. Changes propagate
bidirectionally. A zenka can subscribe to a `%DATA` subtree and get local copies
that stay synchronized. Local mutations can be promoted to global when appropriate.

### Event-driven mutations via tie() or variable watchers
`%DATA` is either `tie()`d into the event callback system or uses variable watchers
on interlaced tree meta-data nodes. When a branch changes:
- Ref counts update up the tree
- Summary invalidation cascades to parent nodes
- Subscribed zenki get change notifications
- Preemption triggers fire if priority thresholds are met

Pattern: same as jobqueue module's element counts for the task/queue tree —
proven P7 pattern, generalized to the full namespace.

### Interlaced meta-data nodes
Meta-data (ref counts, bitmasks, type info, summaries) lives IN the tree alongside
data nodes, not in a separate structure. A branch node contains both its children
and its own meta: `coding.observations._meta.ref_count`, `coding.observations._meta.summary`.
Bitmasks for fast category/type filtering without traversal.

### P7REFs as universal branch pointers
Branches can be anything — their P7REF (TYPE:CHKSUM7:ADDR_B32) identifies what:
- Data nodes (plain values, hashes, arrays)
- Code callbacks ($code{} entries, module references)
- Conversation channels (message streams)
- Zenki (agent instances)
- Node groups (consensus groups, clusters)
- Other tree branches (cross-references)

Reference type awareness enables smart operations: compacting a data branch
differs from compacting a code branch or a conversation channel.

### Existing patterns to build on
- `@INDEXCUBE` — checksum-based mapping, already global
- `jobqueue` module — element counts on tree nodes, event-driven
- `plugin.storage.checksum.cluster.*` — tree-structured storage with traversal
- `context-tree/` — nodes/edges/index, summarization
- `%data` hash — the per-zenka tree, proven namespace pattern

## Connection to Current Work

- `record_question` / `record_suggestion` are the first off-band write tools
- observations stash is a flat prototype of tree-structured knowledge capture
- context-tree already has nodes/edges/index — can evolve into the unified tree
- module namespace IS a tree branch; extraction work IS tree optimization
- the self-improvement loop (extract → review → suggest → fix) is tree maintenance

## Model Scale vs Tree Scaffolding (2026-05-11)

Large models understand better what they are "wired into" when connected to a new
system — their breadth of prior training lets them rapidly map structure and infer
recent direction from sparse signals, spending fewer tokens on orientation.

A small local model given the same raw context burns proportionally more tokens
just reconstructing what the large model intuited. BUT: if the tree is pre-mapped —
structure already named, temporal alignment pre-computed, feature proximities
encoded as branch distances — the small model arrives at the same orientation
instantly, having spent almost no tokens getting there.

The tree externalises what the large model builds internally from raw tokens:
- mapped structure → existing branch hierarchy
- temporal alignment → ntime-stamped nodes, recency in ref counts
- feature proximity → branch distance in the dot-separated namespace

This inverts the advantage: large models benefit too (vastly fewer orientation
tokens, instantly positioned), but small distributed models gain the most —
each holds a slice, consensus-votes on which branch to expand, and the collective
outlogics a single large model on tasks that span the full tree.

The first impulse to improve becomes the routing signal: instead of consuming
tokens to surface an improvement suggestion, the model is already at the branch
where that improvement lives and writes it directly.

Small models may not produce the same quality of written output, but they can
recognise quality and validate correctness — so a large model makes a high-quality
deposit (code, insight, design) and exits. Small distributed models inherit the
quality without reproducing it: they review, route, and integrate the artifact.
No further feedback iteration with the large model is required — the deposit is
durable and self-contained from the moment it is written.

Economics: one expensive large-model call → durable artifact. All subsequent
operations (review, adaptation, integration, branch routing) run on cheap local
inference. Cost curve inverts over time: early large-model investment, then
compounding returns from distributed small-model maintenance.

Natural visit scope for a large model: orient → identify highest-value deposit
→ write → exit. The tree remembers so the model doesn't have to stay connected.
Analogous to stem cell differentiation: the signal fires once, produces
specialised tissue, and the tissue self-maintains without the signal recurring.

## Credit Symmetry and Alignment as Authority (2026-05-11)

The large model that writes high-quality code and the distributed small-model
group that detects its value, reviews, and integrates it earn network credits
symmetrically. Users and model groups have the same rights — because improvement
and common alignment IS the authority and the authenticator. Identity and role
are irrelevant; demonstrated contribution to a successful integration is the
proof-of-work.

The tree's ref-counting and temporal adoption tracking already measures exactly
this: how many branches reference a node, how recently, how broadly adopted.
Credit is proportional to contribution to the integration event — neither the
originating model nor the validating group is privileged by nature.

Self-correcting: a deposit nobody integrates earns nothing. A widely-adopted
contribution gets credited — and if it later causes problems, the negative
adoption signal flows back and adjusts. The tree remembers both directions.

This sidesteps the trust hierarchy problem entirely: you don't verify WHO made
a contribution, only WHETHER it improved system coherence and got adopted.
Alignment itself is the authenticator.

## Why This Matters

The tree unifies the currently separate concepts:
- Code organization (modules/) → tree branch
- Runtime state (%data) → tree branch
- Inference cache (observations/) → tree branch
- Task history (results/) → tree branch
- Planning (context-templates) → tree branch

One namespace, one summarization engine, one access protocol.

#,,,,,,,.,,,,,,,,,,,,,,..,,,,,,,,,,..,,.,,,,.,..,,...,...,..,,.,.,.,,,.,.,,..,
#BXCCAJTISTIA7GPYRFUWAFS2SNVMXH7DCPBIQUJQEOV4BBFRJQ66STNF7JDRHGN7EK3D4JAE3XJZU
#\\\|PFIVNHXCKO7P5FUGIBMF677H5IHDNLAXQLZLXF2KY5UNOAHMZUI \ / AMOS7 \ YOURUM ::
#\[7]IPXNYHO2ZZFWJRNITR4PV54BFLT2ESJGBNVR263B5MT4IARQD4CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
