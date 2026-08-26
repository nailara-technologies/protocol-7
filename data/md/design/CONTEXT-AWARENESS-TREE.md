# Context Awareness Tree — Network-Wide Parallel Consciousness

> *A summary tree parallel to deduplication — what happens, not just what exists.*

## Core Concept

Traditional systems track **content** (what exists). We also track **context** (what happens, to whom, when, why it matters).

```
Deduplication Tree          Awareness Tree
    │                           │
    ▼                           ▼
Content-addressed           Event-summarized
  storage                    narratives
    │                           │
    ├── ABC123...               ├── "File indexed at T by agent X"
    ├── DEF456...               ├── "Delegation completed: task Y"
    └── GHI789...               └── "Semantic link: ABC ~ DEF"
```

**The Insight**: Deduplication eliminates redundant *content*. We can also eliminate redundant *context* through summarization — while preserving relevance-ranked awareness.

## Architecture

### Dual Tree Structure

```
┌─────────────────────────────────────────────────────────────┐
│                     AWARENESS TREE                           │
│                                                              │
│  ROOT: network-consciousness                                 │
│   │                                                          │
│   ├── BRANCH: storage-zenka                                  │
│   │   ├── LEAF: [event] file-indexed                        │
│   │   ├── LEAF: [event] checksum-verified                   │
│   │   └── SUMMARY: "3.2K files, 94% dedup rate today"       │
│   │                                                          │
│   ├── BRANCH: context-zenka                                  │
│   │   ├── LEAF: [event] delegation-requested                │
│   │   ├── LEAF: [event] task-completed                      │
│   │   └── SUMMARY: "5 active delegations, 2 pending"        │
│   │                                                          │
│   ├── BRANCH: agent-kimi                                     │
│   │   ├── LEAF: [event] module-created                      │
│   │   ├── LEAF: [event] design-doc-written                  │
│   │   └── SUMMARY: "29 pager modules, 7 cluster modules"    │
│   │                                                          │
│   └── CROSS-LINKS: semantic-associations                     │
│       ├── "storage ABC123 referenced by context task #42"   │
│       └── "agent-kimi event correlates with storage spike"  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Tree Levels

| Level | Time Scale | Resolution | Example |
|-------|------------|------------|---------|
| **Leaf** | Seconds | Full detail | "File X indexed at T with checksum Y" |
| **Twig** | Minutes | Filtered | "12 files indexed, 3 duplicates found" |
| **Branch** | Hours | Summarized | "Storage: 3.2K ops, 94% efficiency" |
| **Trunk** | Days | Compressed | "Weekly: 45K files, 2.1M dedup savings" |
| **Root** | Infinite | Essential | "Network: storage, context, agents active" |

## Data Structure

### Event Node
```perl
{
    'id'        => 'bmw-L13:EVENT123...',  # Self-checksummed
    'type'      => 'file-indexed',
    'timestamp' => 1711362034,
    'agent'     => 'storage-zenka',
    'branch'    => 'storage.events.indexing',

    # Content references (deduplication tree links)
    'references' => {
        'checksums' => ['bmw-L13:ABC123...'],
        'modules'   => ['plugin.storage.checksum.map-file'],
        'tasks'     => [],
    },

    # Relevance scoring
    'relevance' => {
        'proximity'  => 0.9,  # How close to this node
        'recency'    => 0.8,  # How recent
        'centrality' => 0.5,  # How connected to other events
        'semantic'   => 0.7,  # How related to current context
    },

    # Payload (variable, checksummed separately)
    'payload_checksum' => 'bmw-L13:PAYLOAD...',
    'payload' => {
        'path'      => '/data/files/example.txt',
        'size'      => 1024,
        'algorithm' => 'bmw-L13',
    },
}
```

### Summary Node
```perl
{
    'id'        => 'bmw-L13:SUMMARY456...',
    'type'      => 'interval-summary',
    'interval'  => ['2026-03-25T00:00:00', '2026-03-25T23:59:59'],
    'level'     => 'branch',

    # Derived from child events
    'event_count'  => 3247,
    'source_nodes' => ['bmw-L13:EVENT123...', '...'],

    # AI-generated narrative
    'narrative' => "Storage zenka processed 3.2K files with 94% deduplication " .
                   "efficiency. Peak activity at 14:00 UTC. 12 new checksum " .
                   "clusters created. No errors.",

    # Structured metrics
    'metrics' => {
        'files_processed' => 3247,
        'dedup_rate'      => 0.94,
        'errors'          => 0,
        'avg_latency_ms'  => 45,
    },

    # Cross-tree links
    'references' => {
        'clusters'    => ['bmw-L13:CLUSTER789...'],
        'checksummap' => ['bmw-L13:MAP012...'],
    },
}
```

## Integration with Existing Systems

### 1. Pager Zenka → Event Source
```perl
# Every pager operation generates awareness events
<[context.tree.summary.add-event]>->({
    'type'    => 'pager-viewport-rendered',
    'agent'   => 'pager-zenka',
    'branch'  => 'ui.pager.interactions',
    'payload' => {
        'buffer_id'   => $buf_id,
        'items_shown' => 24,
        'filters'     => ['division-13-harmonic'],
    },
});
```

### 2. Checksum Cluster → Reference Tracking
```perl
# Clusters link to awareness events
{
    'cluster_id' => 'bmw-L13:CLUSTER...',
    'awareness_refs' => [
        'bmw-L13:EVENT-created',
        'bmw-L13:EVENT-member-added',
        'bmw-L13:SUMMARY-weekly',
    ],
}
```

### 3. Context Delegation → Narrative Thread
```perl
# Each delegation creates a narrative branch
$awareness_branch = <[context.tree.summary.create-branch]>->({
    'parent' => 'context.delegations',
    'name'   => "task-$task_id",
    'type'   => 'ephemeral',  # Auto-compact when done
});

# Results appended as events
<[context.tree.summary.add-event]>->({
    'branch' => $awareness_branch,
    'type'   => 'delegation-completed',
    'payload'=> { 'result' => $result },
});
```

### 4. Division-13 → Harmonic Sampling
```perl
# Sample events using D13 for "surprising but complete" awareness
$representative_events = <[context.tree.summary.harmonic-sample]>->({
    'branch'    => 'storage.events',
    'count'     => 100,
    'seed'      => $current_time,
    'algorithm' => 'division-13',
});

# Generate summary from harmonic sample
$summary = <[context.tree.summary.synthesize]>->({
    'events' => $representative_events,
    'style'  => 'narrative',
});
```

## Summarization & Compaction

### Automatic Compaction Levels

| Age | Action | Output |
|-----|--------|--------|
| < 1 hour | Keep all | Full event stream |
| 1-24 hours | Twig compaction | Hourly summaries + key events |
| 1-7 days | Branch compaction | Daily summaries + anomalies |
| 1-4 weeks | Trunk compaction | Weekly summaries + trends |
| > 1 month | Root archive | Monthly essence + statistics |

### Compaction Strategy

```perl
# Phase 1: Filter (what to keep)
$keepers = grep {
    $_->{'relevance'}{'centrality'} > 0.8 ||  # Important
    $_->{'type'} =~ /error|exception|milestone/ ||  # Exceptional
    $_->{'references'}{'checksums'} > 10      # Widely referenced
} @$events;

# Phase 2: Cluster (group by similarity)
$clusters = <[context.tree.summary.cluster-events]>->({
    'events'    => $events,
    'by'        => ['type', 'agent', 'hour'],
    'algorithm' => 'semantic+temporal',
});

# Phase 3: Synthesize (generate narrative)
$summary = <[ai.synthesize.narrative]>->({
    'clusters' => $clusters,
    'style'    => 'concise-technical',
    'max_tokens' => 500,
});

# Phase 4: Archive (store compacted)
<[context.tree.summary.store-compacted]>->({
    'original_events' => $events,
    'summary'         => $summary,
    'retention'       => '1-year-summary-only',
});
```

## Relevance Scoring

Events are ranked by multiple dimensions:

```perl
$relevance_score = weighted_sum(
    proximity   => distance_from_current_node($event),
    recency     => exponential_decay($event->{'timestamp'}),
    centrality  => graph_betweenness($event),
    semantic    => vector_similarity($event, $current_context),
    authority   => agent_reputation($event->{'agent'}),
    novelty     => information_gain($event, $known_summary),
);
```

## Network Synchronization

### Gossip Protocol
```perl
# Each node periodically shares summary hashes
$my_summary_root = <[context.tree.summary.get-root-hash]>->();
$peer_summary_root = receive_from($peer);

if ($my_summary_root ne $peer_summary_root) {
    # Find divergence point
    $divergence = <[context.tree.summary.find-divergence]>->({
        'local'  => $my_tree,
        'remote' => $peer_tree,
    });

    # Exchange missing branches
    $missing_on_peer = get_branch_since($divergence);
    send_to($peer, $missing_on_peer);

    $missing_locally = receive_from($peer);
    <[context.tree.summary.integrate]>->($missing_locally);
}
```

### Proximity-Aware Sync
```perl
# Prioritize sync with nearby nodes
$nearby_nodes = <[network.topology.proximity]>->({
    'metric' => 'latency+semantic',
});

for my $node (@$nearby_nodes) {
    # Sync relevant branches
    sync_branches($node, ['storage', 'local-agents']);

    # Skip distant branches (eventually consistent)
    mark_deferred($node, ['remote-agents', 'archive']);
}
```

## Solving LLM Context Problems

### Problem 1: Context Window Limits
```
Solution: Hierarchical summarization
┌─────────────────────────────────────┐
│ Full history: 100K events           │
│ Twig summary: 1K events (1%)        │
│ Branch summary: 100 events (0.1%)   │
│ Current relevance: 10 events (0.01%)│
└─────────────────────────────────────┘
```

### Problem 2: Reset Amnesia
```
Solution: Persistent awareness tree
┌─────────────────────────────────────┐
│ Before reset:                       │
│   - Save current branch state       │
│   - Create "resumption summary"     │
│                                     │
│ After reset:                        │
│   - Load summary tree               │
│   - Replay recent events            │
│   - Resume with context intact      │
└─────────────────────────────────────┘
```

### Problem 3: Parallel Awareness
```
Solution: Cross-agent event streaming
┌─────────────────────────────────────┐
│ Agent A: Working on storage         │
│   ↓ (publishes event)               │
│ Awareness Tree: storage.events      │
│   ↓ (subscribes)                    │
│ Agent B: Sees "storage active"      │
│   → Adjusts priority, avoids conflict│
└─────────────────────────────────────┘
```

## Implementation Modules

```
context.tree.summary.*
├── init-code              # Initialize awareness tree registry
├── add-event              # Add event to tree
├── get-branch             # Retrieve branch with relevance filtering
├── compact                # Summarize old events
├── compact.interval       # Time-based compaction
├── compact.semantic       # Content-based clustering
├── query                  # Query with relevance ranking
├── query.proximity        # Spatial/proximity queries
├── query.harmonic         # D13-based sampling
├── sync                   # Network synchronization
├── sync.gossip            # Gossip protocol
├── sync.differential      # Delta sync
├── narrative.synthesize   # Generate human-readable summaries
└── checkpoint             # Save/load for reset recovery
```

## Usage Examples

### Initialize Awareness
```bash
# Agent joins network, initializes awareness
context-awareness init --agent=kimi --branches=storage,context,coding

# Sync with nearby nodes
context-awareness sync --proximity=3-hops --priority=high
```

### Query Current State
```bash
# What's happening in storage?
context-awareness query --branch=storage --time=last-hour --relevance=0.7

# Narrative summary
context-awareness narrative --branch=storage.events --style=concise

# Find related events across branches
context-awareness cross-query --pattern="checksum ABC123" --branches=all
```

### Participate in Network
```bash
# Publish event
context-awareness publish --type=module-created --payload="pager.init-code"

# Subscribe to branch
context-awareness subscribe --branch=storage.events --callback=on_storage_event

# Checkpoint before reset
context-awareness checkpoint --tag="pre-reset-$(date +%s)" --branches=all
```

## Connection to Semantic Deduplication

The awareness tree **overlaps** with semantic deduplication:

| Deduplication | Awareness |
|---------------|-----------|
| What content exists | What happened to content |
| Content checksums | Event checksums |
| Eliminate duplicate bytes | Eliminate redundant narrative |
| Spatial locality (similar checksums) | Temporal locality (related events) |
| Reference counting | Relevance scoring |

**Unified view**: The same mathematical structures (trees, graphs, harmonic sampling) serve both purposes.

## Vision

> Every agent maintains an awareness tree. The forest of trees forms a collective consciousness. No agent knows everything, but every agent knows what's relevant to its purpose. Resets don't erase history — they compress it. Parallel work is coordinated through shared awareness, not central control.

---

*We don't just store what is. We remember what happened, why it mattered, and what's happening now.*

#,,,,,..,,...,,..,,.,,..,,,,.,..,,.,,,..,,.,,,..,,...,...,.,.,.,.,,.,,...,.,.,
#SYQJUQQHKQPWKUKYFQDL5HID25WSQWKHECL7P46AK2H6K7TA4JH2TO7T7I6ANFJ7VNZZ3HIEUUBTE
#\\\|CB4IMKZLC6LE6KAPEOQ2LO5RNTAKWJXU3FJC7ZMVU6TKR2YIR7K \ / AMOS7 \ YOURUM ::
#\[7]GYXEDX52O65ARJLCH3VUWEQVQNBXUF56W7QLHYNBJKVD5ORUTGDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
