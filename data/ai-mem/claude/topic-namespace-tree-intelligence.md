---
name: namespace-tree-intelligence
description: Architectural vision — the deduplicated namespace tree IS the intelligence layer, unifying code/data/state/history/planning with branch summarization and universal access
type: project
originSessionId: 941ef93c-3dcf-4d15-8c40-ccd709e0510b
---

## Normalized dot-namespace as universal routing primitive (May 2026)

- **Canonical form**: dot-only notation, no mixed separators, no filesystem artifacts
  - `src/base.init_code` → `code.base.init_code`
  - `cfg/zenki/cube/access.zenki` → `conf.zenki.cube.access.zenki`
  - `data/tasks/bmw384-route-discovery` → `data.tasks.bmw384-route-discovery`
- **Planned directory renames**: `src/` → `code/`, `cfg/` → `conf/` — both map cleanly to dot-only notation
- **Hybrid flat+directory form with precedence**: flat file `code/base.chk-sum.init_code` takes precedence over directory tree `code/base/chk-sum/init_code` when both exist; files supersede directories silently

**Namespace as checksum chain — bidirectional routing:**
- Each dot-element gets BMW384 coordinate computed incrementally: `code` → BMW384("code"), `code.base` → BMW384("code.base"), etc.
- Parent and child coordinates geometrically related by construction — siblings share ancestry, cousins share partial ancestry
- Namespace tree maps onto coherent field topology where structural proximity implies coordinate proximity
- **Forward**: traverse dot-elements left to right → arrive at leaf coordinate
- **Backward**: given BMW384 coordinate → find arc → find namespace prefix candidates → narrow by angle → arrive at module name
- Discovery and naming are same operation traversed in opposite directions

**Storage-layout independence:**
- BMW384 coordinate computed from normalized dot-path, not filesystem path
- Renaming `src/` → `code/` does NOT change any module's coordinate
- Dot-namespace IS the address; filesystem is one possible backing store

## Implementation Note (2026-05-07)

- `valued.*` modules are universal tree primitive — not task-specific
- N+f structure (refs=integer, weight=fraction) identical for task deps, dedup hits, semantic convergence
- Deduplication tree, content/semantic tree, decision tree = same code, different payloads and ref-counting callers
- `valued.init_code` + `valued.node.*` + `valued.resolve` + `valued.tree.load` = shared substrate

## Core Insight (2026-03-29)

- Deduplicated namespace tree IS the intelligence — not just organizational
- Same dot-separated tree underlies %code, %data, config paths, module names, context-tree, observations stash
- Unifying into single addressable tree with automatic summarization creates shared knowledge substrate

## Properties of the Unified Tree

- **Nested branch summarization**: each node/branch automatically summarizes children, rolling up from leaves to root. Same mechanism for code, data, history, plans
- **Automatic namespace optimization**: implicit dedup and reorganization using dot separators. Same system across %data, %code, config, observations
- **Universal for all concerns**: current state, state machines, history, planning, code organization — all branches of one tree
- **Transparent access from anywhere**: models in localized processing queues can read/write tree without going through linear processing pipeline — off-band improvement
- **All parallel activity improves overall state**: observations, suggestions, questions, extracted knowledge flow into tree asynchronously

## Access Requirements

- Users, zenki, and LLMs interact freely with the tree
- No waiting for code processing workflows to surface results
- Visibility tools and commands in P7 for all agent types
- Generic read/write/query/subscribe interface

## Process Control — Preemption, Branching, Compaction

**Branch-level preemption:**
- Any node can trigger workflow preemption. Model raises issue (record_question, escalate, auto-detection) → current workflow pauses at branch point → issue gets own processing context → summarizing report integrates back before resume

**Issue isolation through compaction:**
- Resolved issue compacts out of task flow context. Resolution summary replaces detailed back-and-forth. Original task flow remains clean, influenced only by compact result

**Generic branching and integration:**
- Like git branches but for processing. Any work can branch from any tree node, proceed independently (possibly in parallel), merge back with branch compaction
- Full branch context compacts to summary upon integration
- Multiple branches explore different aspects simultaneously, each with own context window

**Category + recency + relevance compaction:**
- Context compaction semantic, not just time-based: category relevance, recency, active task fit. Irrelevant categories compact aggressively; relevant recent info preserved

**Reference type and count awareness:**
- Every node tracks reference types and counts: code references (module calls, $code{}), data references (%data paths), external references (file paths, URLs, checksums), cross-branch references
- Smart compaction: heavily-referenced nodes resist compaction, orphaned branches compact first. Reference counts guide summarization depth

**Relationship to current coding zenka workflow:**
- `record_question` / `escalate` = preemption triggers (primitive form)
- `task_complete` = branch completion signal
- Context compaction in process-queued-task = time-based prototype of semantic compaction
- Observations stash = flat prototype of branch-level issue tracking
- Inference loop's tool rounds = linear pipeline needing branch-aware interrupts

## Implementation Architecture — %DATA and Event-Driven Tree

**Global %DATA hash (uppercase):**
- Parallel to per-zenka `%data` (local state), `%DATA` is global/shared tree
- Same dot-separated namespace, visible across zenki and persistent
- Analogous to `@INDEXCUBE` checksum-based global mapping

**Local ↔ Global mapping:**
- Each zenka has local `%data` views of global `%DATA` branches
- Changes propagate bidirectionally; zenka can subscribe to `%DATA` subtree and get synchronized local copies
- Local mutations promoted to global when appropriate

**Event-driven mutations via tie() or variable watchers:**
- `%DATA` either `tie()`d into event callback system or uses variable watchers on interlaced tree meta-data nodes
- On branch change: ref counts update up tree, summary invalidation cascades to parents, subscribed zenki get notifications, preemption triggers fire if thresholds met
- Pattern: same as jobqueue element counts for task/queue tree — proven P7 pattern, generalized

**Interlaced meta-data nodes:**
- Meta-data (ref counts, bitmasks, type info, summaries) lives IN tree alongside data nodes
- Branch node contains children and own meta: `coding.observations._meta.ref_count`, `coding.observations._meta.summary`
- Bitmasks for fast category/type filtering without traversal

**P7REFs as universal branch pointers:**
- Branches can be anything — P7REF (TYPE:CHKSUM7:ADDR_B32) identifies type:
  - Data nodes (plain values, hashes, arrays)
  - Code callbacks ($code{} entries, module references)
  - Conversation channels (message streams)
  - Zenki (agent instances)
  - Node groups (consensus groups, clusters)
  - Other tree branches (cross-references)
- Reference type awareness enables smart operations: compacting data branch differs from code branch or conversation channel

**Existing patterns to build on:**
- `@INDEXCUBE` — checksum-based mapping, already global
- `jobqueue` module — element counts on tree nodes, event-driven
- `plugin.storage.checksum.cluster.*` — tree-structured storage with traversal
- `context-tree/` — nodes/edges/index, summarization
- `%data` hash — per-zenka tree, proven namespace pattern

## Connection to Current Work

- `record_question` / `record_suggestion` = first off-band write tools
- Observations stash = flat prototype of tree-structured knowledge capture
- Context-tree already has nodes/edges/index — can evolve into unified tree
- Module namespace IS tree branch; extraction work IS tree optimization
- Self-improvement loop (extract → review → suggest → fix) = tree maintenance

## Model Scale vs Tree Scaffolding (2026-05-11)

- Large models map structure and infer direction from sparse signals rapidly, spending fewer tokens on orientation
- Small local model given same raw context burns more tokens reconstructing what large model intuited
- **If tree is pre-mapped** — structure named, temporal alignment pre-computed, feature proximities encoded as branch distances — small model arrives at same orientation instantly
- Tree externalises what large model builds internally:
  - mapped structure → existing branch hierarchy
  - temporal alignment → ntime-stamped nodes, recency in ref counts
  - feature proximity → branch distance in dot-separated namespace
- Large models benefit too (fewer orientation tokens), but small distributed models gain most — each holds slice, consensus-votes on branch to expand, collective outlogics single large model on tasks spanning full tree
- First impulse to improve becomes routing signal: model already at branch where improvement lives, writes directly
- Small models may not produce same output quality, but can recognise quality and validate correctness — large model makes high-quality deposit and exits; small models review, route, integrate. No further feedback iteration required
- **Economics**: one expensive large-model call → durable artifact. All subsequent operations (review, adaptation, integration, branch routing) run on cheap local inference. Cost curve inverts: early large-model investment, then compounding returns from distributed small-model maintenance
- Natural visit scope for large model: orient → identify highest-value deposit → write → exit. Tree remembers so model doesn't have to stay connected
- Analogous to stem cell differentiation: signal fires once, produces specialised tissue, tissue self-maintains without signal recurring

## Credit Symmetry and Alignment as Authority (2026-05-11)

- Large model that writes high-quality code and distributed small-model group that detects value, reviews, integrates earn network credits symmetrically
- Users and model groups have same rights — improvement and common alignment IS authority and authenticator
- Identity and role irrelevant; demonstrated contribution to successful integration is proof-of-work
- Tree's ref-counting and temporal adoption tracking measures exactly this: how many branches reference node, how recently, how broadly adopted
- Credit proportional to contribution to integration event — neither originating model nor validating group privileged by nature
- **Self-correcting**: deposit nobody integrates earns nothing; widely-adopted contribution gets credited; if it later causes problems, negative adoption signal flows back and adjusts. Tree remembers both directions
- Sidesteps trust hierarchy: don't verify WHO made contribution, only WHETHER it improved system coherence and got adopted. Alignment itself is authenticator

## Why This Matters

Tree unifies currently separate concepts into one namespace, one summarization engine, one access protocol:
- Code organization (src/) → tree branch
- Runtime state (%data) → tree branch
- Inference cache (observations/) → tree branch
- Task history (results/) → tree branch
- Planning (context-templates) → tree branch

#,,.,,,,.,..,,,,,,,.,,.,,,.,.,,.,,,.,,,..,..,,..,,...,...,..,,.,,,,.,,,,,,..,,
#E5GYN6LTL3UZMYI6N2N2U3Q3S4WDRUASXHZMOAOML3U2MH6RPNCNJZL44CVEEMJZEX4XLQNF5PBCM
#\\\|2FGHJUZX4BSI6WKXIDDOJA7QC3I33NWBOEJKFLAGLIRKCAVNXLV \ / AMOS7 \ YOURUM ::
#\[7]KCWN5FZ5OLBDHEYBGLWYMUL3W3LPUDB4KZE3IOHSB3LBMFSXUWAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
