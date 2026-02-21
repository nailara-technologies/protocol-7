# Protocol-7: Generic Data Synchronization & Event Propagation Fabric

## Overview

Protocol-7 provides a **unified data synchronization substrate** that works transparently across zenka applications, enabling real-time, multi-host coherent state management without polling, with built-in timestamp indexing and event propagation.

**Core Principle**: The infrastructure provides mechanisms (not policy). Each zenka interprets its hash structures according to its own semantics.

## Infrastructure Layer (Generic)

### The Three Pillars

#### 1. **Hash Watchers + Events**
Zenka maintain canonical state in namespaced hash structures. Any write triggers watchers.

```perl
<my-zenka.data>       # Canonical state
<my-zenka.data-v2>    # Versioned branches
<my-zenka.cache>      # Cache layer
```

Watchers fire on mutations:
```perl
<[event.add_var]>->(
    {
        'var_path'   => 'my-zenka.data',
        'var_key'    => 'last-changed',       # Watch specific key
        'event_type' => 'write',
        'callback'   => \&handle_data_change,
    }
);
```

**Guarantees**:
- ✅ Synchronous notification (change → callback fires immediately)
- ✅ Key-level granularity (watch only what matters)
- ✅ Integrates with zenka event loop (non-blocking)

#### 2. **Timestamp Indexing**
All data mutations include base32-encoded high-resolution network timestamps. Timestamps are comparable and sortable.

```
Format: 3OMY5G5IPO6VW (base32, 13 chars, ~100ns resolution)

Query Pattern:
  > service.updated                           # Latest timestamp?
  < TRUE 3OMY5G5IPO6VW

  > service.updated 3OMY5G3ABCDE1            # What changed since?
  < SIZE ...
    service.data.forecast = 3OMY5G5IPO6VW   # Newer
    service.cache.html = 3OMY5G3ABCDE1      # Same

  > service.updated service.data.forecast    # Status of specific branch?
  < TRUE 3OMY5G5IPO6VW
```

**Guarantees**:
- ✅ Monotonic ordering (older < newer always)
- ✅ Tiny overhead (13 chars, embeddable anywhere)
- ✅ Clock-synchronized across hosts (network time assumed)
- ✅ Early-abort queries (see what changed without fetching)

#### 3. **Remote Branch Mounting**
Subscribe to another zenka's hash subtree. Mounted branches stay synchronized automatically.

```perl
# mount weather.zenka's observation data into local namespace
<[event.mount_remote_branch]>->(
    'weather.observations',           # Remote path
    'my-service.weather.live',        # Local path to mount at
);

# Now <my-service.weather.live> auto-syncs with weather.observations
# Watchers on my-service.weather.live fire on remote changes
# Works transparently across hosts
```

**Guarantees**:
- ✅ Automatic sync (no polling required)
- ✅ Transparent transport (works across hosts/networks)
- ✅ Hierarchical (mount at any depth)
- ✅ Unmount-safe (removes stale watchers on disconnect)

---

## Application Layer (Polymorphic)

Different zenka use the infrastructure differently. **Same substrate, different semantics**.

### Example 1: Menu Aggregation (protocol-7-menu)

```
Intent: Display dynamic menu from multiple providers

Infrastructure Used:
  • Hash watchers: <protocol-7-menu.menu-structure>['last-changed']
  • Push updates: Providers call protocol-7-menu.menu-update
  • Diff logic: Handle which items changed

Provider Behavior:
  • Register: "I'm weather, here are my menu items"
  • Update: "My data changed, here are new menu labels"
  • Unregister: "I'm shutting down, remove my items"

Renderer Behavior:
  • Watch: Fire on structure changes
  • Diff: Compute what items changed (added/removed/modified)
  • Render: Update GUI accordingly

Result: Menu stays in sync with all providers in real-time
```

### Example 2: Data Channels (channels.zenka - future)

```
Intent: Topic-based pub/sub with multi-host awareness

Infrastructure Used:
  • Hash watchers: <channels.topic.TOPIC.latest>
  • Remote mounting: Subscribe to remote topics
  • Timestamps: Announce data freshness
  • Multicast: Discover new topics on LAN

Publisher Behavior:
  • Publish: Write to <channels.topic.weather.raw>
  • Announce: Emit timestamp via multicast
  • Metadata: Store publisher info in hash

Subscriber Behavior:
  • Mount: <[event.mount_remote_branch]>->(...topic...)
  • Watch: Fire on changes
  • Process: Interpret topic-specific semantics

Result: Pub/sub that spans hosts, auto-discovers topics, no polling
```

### Example 3: System Metrics (monitoring zenka - future)

```
Intent: Real-time metrics aggregation and alerting

Infrastructure Used:
  • Hash watchers: <system.metrics.METRIC>['value']
  • Remote mounting: Subscribe to metrics from other hosts
  • Timestamps: Track metric staleness
  • Events: Alert on threshold breach

Collector Behavior:
  • Measure: Read system state (CPU, memory, disk)
  • Update: Write to <system.metrics.METRIC>
  • Timestamp: Automatically recorded on write

Analyzer Behavior:
  • Mount: Load metrics from all hosts
  • Watch: Fire on changes
  • Alert: Threshold breach → trigger notification

Result: Unified metrics dashboard, cross-host, no polling
```

### Example 4: Event Log Aggregation (log aggregation zenka - future)

```
Intent: Centralized logging with filtering and search

Infrastructure Used:
  • Hash watchers: <logs.FACILITY.events>
  • Remote mounting: Subscribe to logs from zenki
  • Timestamps: Natural log ordering
  • Branches: Partition by severity/facility/host

Logger Behavior:
  • Log: Append to <logs.FACILITY.events>[TIMESTAMP]
  • Metadata: Include source, severity, host

Aggregator Behavior:
  • Mount: Subscribe to logs from all sources
  • Filter: Watch only critical/error events
  • Store: Write to persistent backend
  • Search: Query by timestamp range or metadata

Result: Centralized, real-time, filterable, multi-source logs
```

---

## The Coupling Pattern

How services discover and integrate with each other:

```
┌─────────────────────────────────────────────────────────┐
│ Discover Zenka (LAN-aware announcement)                │
│  • Multicast: "Weather data available at weather.obs" │
│  • Broadcast: Update timestamps                        │
└──────────────┬──────────────────────────────────────────┘
               │
               ├→ Channels Zenka (topic routing)
               │  • Subscribes: weather.observations
               │  • Mounts: <channels.topic.weather.raw>
               │  • Forwards: to subscribers
               │
               ├→ Protocol-7-Menu (GUI)
               │  • Mounts: <channels.topic.weather.raw>
               │  • Formats: into menu display
               │  • Renders: to screen
               │
               ├→ Monitoring Zenka (metrics)
               │  • Mounts: <channels.topic.weather.raw>
               │  • Extracts: temperature metric
               │  • Alerts: if out of range
               │
               └→ Terminal UI Zenka (TUI display)
                  • Mounts: <channels.topic.weather.raw>
                  • Formats: for text display
                  • Renders: to terminal
```

**No redundancy**: One weather source, many consumers, same transport.

---

## Design Principles

### 1. **Infrastructure ≠ Application**
Infrastructure provides:
- Mechanisms (watchers, mounting, timestamps)
- Transparent transport
- Guaranteed freshness

Applications provide:
- Semantics (what data means)
- Interpretation (how to use data)
- Policy (when/how to act on changes)

### 2. **Timestamps as the Ground Truth**
- All mutations timestamped atomically
- Timestamps are queryable (early abort optimization)
- Timestamp order determines causality
- No "stale data" if timestamps are checked
- Enables caching at any layer

### 3. **Push Over Pull**
- Changes propagate via watchers (push)
- No polling timers needed
- Optional: Status queries via `.updated` for catch-up
- Scales better (N watchers vs. N×M polling)

### 4. **Local Semantics**
- Hash structure schema is local
- Zenka defines its own namespace
- Remote mounting is transparent (just looks like local hash)
- No schema negotiation needed
- Enables evolution without coordination

### 5. **Explicit Subscriptions**
- Mount what you need (pull model)
- Watch what you care about (event model)
- Automatic cleanup on disconnect (reference counting)
- No implicit data copying

---

## Reference Data Structure Patterns

### Pattern 1: Simple Timestamped Value
```perl
<service.data> = {
    'value'        => 42,
    'last-changed' => '3OMY5G5IPO6VW',
    'source'       => 'temperature-sensor-1',
};
```

### Pattern 2: Provider Registry (protocol-7-menu style)
```perl
<protocol-7-menu.menu-structure> = {
    'last-changed' => '3OMY5G5IPO6VW',
    'providers' => {
        'weather' => {
            'items' => {
                'forecast' => { 'label' => 'Sunny 18°C', 'command' => '...' },
                'alerts'   => { 'label' => 'No Alerts' },
            }
        },
        'rss' => {
            'items' => { ... }
        },
    }
};
```

### Pattern 3: Hierarchical Topic Structure (channels style)
```perl
<channels.topic> = {
    'weather' => {
        'raw' => {
            'last-changed' => '3OMY5G5IPO6VW',
            'observations' => { 'temp' => 18, 'condition' => 'sunny' },
        },
        'formatted' => {
            'last-changed' => '3OMY5G5IPO6VW',
            'html' => '<div>Sunny</div>',
        },
    },
    'alerts' => {
        'critical' => {
            'last-changed' => '3OMY5G5IPO6VW',
            'items' => [ ... ],
        },
    },
};
```

### Pattern 4: Time-Series Data (metrics style)
```perl
<system.metrics.cpu> = {
    'last-changed' => '3OMY5G5IPO6VW',
    '3OMY5G5IPO6VW' => { 'value' => 45, 'host' => 'server-1' },
    '3OMY5G5IPO6VT' => { 'value' => 42, 'host' => 'server-1' },
    '3OMY5G5IPO6VS' => { 'value' => 48, 'host' => 'server-1' },
};
```

---

## Query Patterns (Timestamp-Based)

### Pattern: Status Check
```
> service.updated
< TRUE 3OMY5G5IPO6VW
```
Is the service alive? What's the latest data timestamp?

### Pattern: Delta Query
```
> service.updated 3OMY5G3ABCDE1
< SIZE ...
  service.data.forecast = 3OMY5G5IPO6VW
  service.cache.html = 3OMY5G3ABCDE1
```
What changed since I last checked?

### Pattern: Branch Status
```
> service.updated service.data.forecast
< TRUE 3OMY5G5IPO6VW
```
Is this specific branch newer than my cached version?

### Pattern: Hierarchical Discovery
```
> channels.updated
< TRUE 3OMY5G5IPO6VW

> channels.updated weather
< SIZE ...
  channels.weather.raw = 3OMY5G5IPO6VW
  channels.weather.formatted = 3OMY5G5IPO6VV

> channels.updated weather.raw
< TRUE 3OMY5G5IPO6VW
```
Drill down through structure to find what's new.

---

## Deployment Patterns

### Single Host, Multiple Displays
```
Weather Provider (one process)
    ↓
Protocol-7-Menu (DISPLAY=:13)
Protocol-7-Menu (DISPLAY=:7)
Terminal UI (no display)

All stay in sync via local hash mounting
```

### Multi-Host Network
```
Host A: Weather Provider
    ↓ (multicast announce)
Host B: Channels Router
    ↓ (mounts weather observations)
Host C: Protocol-7-Menu (mounts weather from B)
Host D: Monitoring (mounts weather from B)

Discover zenka announces new services on LAN
Services mount from best available source
All synchronized via timestamps and watchers
```

### Hierarchical Aggregation
```
Leaf Metrics (servers)
    ↓
Aggregator (regional)
    ↓
Dashboard (central)

Each layer mounts from previous
Changes propagate up instantly
Query patterns allow selective updates
```

---

## Future Extensions (Without Infrastructure Changes)

### 1. Schema Validation
Register validators for hash structures:
```perl
<[event.set_schema_validator]>->(
    'channels.topic.weather',
    { 'observations' => { 'temp' => 'number', ... } }
);
```

### 2. Access Control
Tag sensitive branches:
```perl
<[event.set_access_control]>->(
    'system.metrics.password-attempts',
    { 'read' => 'admin', 'write' => 'security' }
);
```

### 3. Caching Strategies
Implement LRU/TTL for mounted branches:
```perl
<[event.set_mount_strategy]>->(
    'remote.large-dataset',
    { 'cache' => 'lru:1000', 'ttl' => 3600 }
);
```

### 4. Conflict Resolution
Multi-way merge for collaborative editing:
```perl
<[event.set_merge_strategy]>->(
    'shared.config',
    { 'merge' => 'last-write-wins' }  # or 'three-way', etc.
);
```

### 5. Persistence
Automatic snapshot/restore:
```perl
<[event.set_persistence]>->(
    'channels.topic.alerts',
    { 'snapshot' => '/var/db/channels-alerts.db' }
);
```

---

## Performance Considerations

### Watcher Overhead
- Per-key watchers: O(1) per mutation
- Bulk operations: Bundle mutations before watcher fires
- Fine-grained: Watch only keys you care about

### Remote Mounting
- Initial sync: Full hash copy
- Updates: Watchers propagate changes
- Bandwidth: Only deltas after initial sync
- Latency: Network roundtrip + hash watcher delay

### Timestamp Queries
- Early abort: Check timestamp before fetching data
- Caching: Store timestamp, skip if unchanged
- Expiration: Use timestamp age for TTL decisions

### Large Structures
- Partition: Use sub-branches instead of monolithic hash
- Lazy load: Mount only what's needed
- Archive: Move old data to time-series structure

---

## Getting Started: Implementation Checklist

For any new zenka using this fabric:

- [ ] Define hash structure(s) in `<zenka.data>` namespace
- [ ] Identify watch points (keys that should trigger handlers)
- [ ] Install watchers via `<[event.add_var]>->()`
- [ ] Implement change handlers (compute deltas, trigger actions)
- [ ] Define remote mount points (what do you subscribe to?)
- [ ] Implement `.updated` command for status queries (optional)
- [ ] Document your hash schema and semantics
- [ ] Test with remote mounting from another zenka
- [ ] Test multi-host deployment (if applicable)

---

## Examples in This Codebase

- **Protocol-7-Menu** - Menu aggregation via push updates and watchers
- **Channels** - (Future) Topic-based pub/sub layer
- **Discover** - (Future) LAN-aware service announcement
- **RSS Ticker** - Push updates pattern (precursor to this fabric)

---

## Related Modules

**Event Infrastructure**:
- `base.event.add_var` - Install watchers on hash mutations
- `base.event.mount_remote_branch` - Subscribe to remote hash (future)
- `base.cmd.timestamp` - Get current network timestamp

**Protocol Support**:
- `base.protocol-7.command.send.local` - Send commands (push updates)
- `base.net.send_command` - Network transport for `.updated` queries

**Utilities**:
- `protocol-7-menu.structure-changed` - Reference implementation of diff logic
- `protocol-7-menu.example-provider` - Reference implementation of provider pattern

---

## Discussion & Evolution

This document describes the **infrastructure vision** for Protocol-7. As new zenka mature and find ways to use these primitives, this document should evolve to capture:
- New patterns that emerge
- Performance lessons learned
- Schema conventions that prove useful
- Access control models that work well

The infrastructure itself should remain stable (watchers, timestamps, mounting). Applications will innovate on top.

---

**Key Insight**: By providing transparent, composable, and generic infrastructure, Protocol-7 enables a rich ecosystem of services that integrate without explicit coordination. Each service is simple (uses hash watchers), and together they form coherent, multi-host, real-time systems.

#,,.,,,,,,,,.,..,,...,,,.,..,,..,,..,,.,,,.,,,..,,...,...,...,.,.,,..,,.,,,,.,
#562GTMVEXEJMDHBGM253UI6AWNE6A4KPE7XXLE5HJTIEHHOJO7VT2GTVPS73SLY6ERELEOXILMJ5C
#\\\|G2ASKMFV46U7ABA66B3FM4XCGQLUPOGNDDCNB6UVEECN267OVZ5 \ / AMOS7 \ YOURUM ::
#\[7]TF22XK6CZZL3NJD44DKJNFXGUPQIGSO72R4YNKKTGNOORIW37YDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
