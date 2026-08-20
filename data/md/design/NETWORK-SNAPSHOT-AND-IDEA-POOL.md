# NETWORK-SNAPSHOT-AND-IDEA-POOL — always-current contextual awareness

## status

design — extracted from duck.ai design conversation 2026-07-29
(INCOMING/duck.ai_2026-07-29_01-27-33.txt, prompts 65–66).

builds on the IMPLEMENTED memory tree (src/memory.*, 52 modules —
note: MEMORY-TREE-SYSTEM.md's "nothing built yet" header is stale) and
context.tree.summary.checkpoint. what is new here: the always-current
network-structure snapshot, drift-resilient resume, and the idea pool.
memory.tree.checkpoint / memory.tree.diff from the original namespace
plan are still unimplemented and belong to this line.

## the problem

agents (and their models) operate with partial, stale context:

- a client disconnecting mid-inference loses live network state
- embeddings are point-in-time; topology drifts after training
- models don't know what is IMMEDIATELY available to contact — the
  idea pool is limited to whatever happens to be in context
- recent chat histories, code momentum, and module hotspots are not
  systematically loadable

the cost is not just scan/lookup time — it is a smaller idea pool.

## the snapshot

a layered, loadable snapshot of always-current context:

```
data/snapshots/<label>.json     (atomic write: .tmp + rename)

components:
  network-topology    orbital ring state: live zenki, roles, cubic
                      addresses, connections, bandwidth/overflow state
  embedding-cache     which models are loaded, when, query stats,
                      last-N queries (for warm reload)
  chat-histories      recent conversations; full if < ~50KB,
                      decision/output summary otherwise
  code-momentum       last ~50 commits, per-module activity counts,
                      hotspot modules (what is moving right now)
  dedup-tree          content-address index state (sha256 → path)
```

tolerance is the design goal: if an agent disconnects mid-inference, or
the snapshot was taken before the last embedding retrain, the drift is
small and the resume friction minimal. snapshots are close-enough
anchors, not perfect state.

## resume semantics

- reconcile snapshot topology against LIVE zenki: still-online agents
  adopt the snapshot's allocation/connection state; missing agents are
  logged, never block
- embedding models reload from disk; recent queries pre-warm the cache
- chat histories restore (full or summary form)
- code-momentum informs context prioritization: recently-changed
  modules rank higher in semantic loads

## the idea pool

a generated view over the same state: "what can I reach right now?"

```
agents_available      live zenki, role, current task, response time
knowledge_domains     loaded embedding domains, cache warmth, latency
code_hotspots         modules with recent commit momentum
recent_conversations  context-rich histories that fit in context
suggestion_graph      cross-domain links: analyzing X → consider
                      plugins/CWEs/techniques/src related to X
```

surfaced INTO model context at task start (compact rendering), the idea
pool increases the solution space by reminding the model what exists —
the same function the memory tree's focus vector serves for content,
applied to capability.

## relationship to existing systems

| existing | this design adds |
|---|---|
| memory tree (content-addressed, scored) | network/topology dimension; snapshot + resume |
| context.tree.summary.checkpoint | live-agent state, embeddings cache, momentum |
| dep-graph semantic embeddings (task) | code-momentum as retrain weighting signal |
| FASTTEXT-LOG-AWARENESS (design) | the snapshot as the loadable unit of log awareness |

## implementation direction

- new module family: context.snapshot.{capture,restore,reconcile} and
  context.ideapool.{generate,render}
- snapshot cadence: on-demand + nightly (piggyback the 04:07 slot era)
- dedup across snapshots via the existing content-address machinery —
  unchanged components are shared, snapshot chains stay small
- perl reference sketches exist in the conversation transcript
  (prompts 65–66, ContextualMemoryTree + idea pool) — adapt, don't
  transcribe

## open questions

- snapshot size budget vs restore latency (what deserves inclusion)
- how the suggestion_graph is built: static cross-references vs
  embedding-driven linking (probably the latter, once the security
  domains exist)
- whether snapshots become git-committed artifacts or runtime state

#,,..,,,.,,,.,,..,.,,,..,,,,.,..,,.,,,.,,,,,,,..,,...,...,...,,,,,..,,.,,,,,,,
#5FLJXR3TA3GFI3BILZ3YISGGTEGZCQAP57GNQAOFXI2BPURIPXREUIX2T52LHK6UMEHAUEM5AKZB6
#\\\|U52WTQDOK3G6FTQR6AUKQTXX43IHBGD4Q5VO5DPM3BP5VVUUQC5 \ / AMOS7 \ YOURUM ::
#\[7]BC6B6XX2ZQM7YUAMZL3SIEUBM6LVHXGF5LE5OQP6JTL7XAUWHGDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
