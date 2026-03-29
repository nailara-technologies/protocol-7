---
name: namespace-tree-intelligence
description: Architectural vision — the deduplicated namespace tree IS the intelligence layer, unifying code/data/state/history/planning with branch summarization and universal access
type: project
---

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

## Why This Matters

The tree unifies the currently separate concepts:
- Code organization (modules/) → tree branch
- Runtime state (%data) → tree branch
- Inference cache (observations/) → tree branch
- Task history (results/) → tree branch
- Planning (context-templates) → tree branch

One namespace, one summarization engine, one access protocol.

#,,.,,.,,,,..,,,.,.,,,.,.,,.,,.,.,,.,,,..,.,.,..,,...,...,...,...,,..,.,.,.,.,
#3ZKX6S3MIHMG36X2CN3UW5EXVNFS7HZNZYJK7VXV7EN5IKVYS6FSJQBSDPGEFQOO5DXGZ3HI3XMFK
#\\\|HGJOLT4IFSJHS3QKHG36PQSLLVZI2SUQJL4YEVSVDHK2POQTELH \ / AMOS7 \ YOURUM ::
#\[7]DIBLFXOMVGPWMTOG2XABLL5TE6MB7EVZI4M4USHSUOG6ISNJZWCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
