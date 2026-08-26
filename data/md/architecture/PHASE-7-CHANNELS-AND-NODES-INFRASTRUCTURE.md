# Phase 7: Channels & Nodes Infrastructure

## Overview

This document describes the implementation plan for Protocol-7's distributed communication and state synchronization infrastructure, spanning three major components: **server-side TOFU completion**, **nodes zenka for inter-node link stability**, and **channels zenka for lazy pub/sub and shared memory**.

---

## 1. Architecture Overview

### 1.1 Layered Design

```yaml
Layer 3 - Applications:
  - Developer-AI approval workflows
  - Content discovery pipelines
  - LLM-driven curation
  - User context management

Layer 2 - Channels Infrastructure:
  - Lazy pub/sub messaging
  - Memory-sync substrate
  - Generic mappings
  - IP multi-cast distribution

Layer 1 - Stability Foundation:
  - Nodes zenka (inter-node links)
  - TOFU authentication (client pinning)
  - Discover integration (topology)
  - Route stability & collapse detection

Layer 0 - Core Protocol-7:
  - Cube routing
  - Base network I/O
  - Event management
```

### 1.2 Component Relationships

```yaml
dependencies:
  complete-tofu-pinning:
    - server-side TOFU (incoming client key pinning)
    - host-restricted & unrestricted modes
    - cleanup routines with timeout
    reason: "Establishes secure foundation for remote node trust"

  nodes-zenka:
    - depends_on: "complete-tofu-pinning"
    - coordinates: "discover zenka"
    - provides: "stable inter-node routes"
    - heartbeat_pattern: "protocol-7 timeout-less push (next-data-timestamp style)"
    reason: "Channels need reliable routes to synchronize over"

  channels-zenka:
    - depends_on: ["nodes-zenka", "discover zenka"]
    - reuses: "nodes zenka patterns (subscriptions, announcements, state tracking)"
    - provides: "distributed messaging and shared memory"
    - foundation: "all applications and integrations"
    reason: "Lazy pub/sub enables vast ecosystems with minimal core logic"
```

---

## 2. Implementation Sequence

### 2.1 Phase 7a: Complete Server-Side TOFU Pinning

**Status:** Foundation laid (validate-incoming-tofu module exists)

**Remaining tasks:**

```yaml
tasks:
  - task_id: "7a.1"
    title: "Support host-restricted incoming client modes"
    description: |
      Implement incoming/<user>.<host>_<port>.public file variant.
      Admin can pin clients to specific host/port or leave unrestricted.
    acceptance_criteria:
      - TOFU checks restricted file first before unrestricted
      - Symlink auth works for both restricted and unrestricted
      - Admin can migrate between modes by managing files
    files_affected:
      - src/plugin.auth.auth-keypair.validate-incoming-tofu
    estimated_complexity: "low"

  - task_id: "7a.2"
    title: "Add incoming/ cleanup routine with timeout"
    description: |
      Unpinned keys (no symlink in authorized/) are automatically removed
      after configurable timeout to prevent disk overflow.
      Rate limiting on concurrent pinning requests.
    acceptance_criteria:
      - Cleanup runs periodically (cron-like or event-based)
      - Honors TTL configuration for unpinned keys
      - Logs cleanup actions
      - Handles cleanup errors gracefully
    files_affected:
      - src/plugin.auth.auth-keypair.cleanup-incoming-keys
      - src/crypt.C25519.init_code (add cleanup trigger)
    estimated_complexity: "medium"
```

**Deliverables:**
- Host-restricted TOFU pinning working
- Cleanup routine preventing disk overflow
- Production-ready TOFU infrastructure

---

### 2.2 Phase 7b: Nodes Zenka for Inter-Node Link Stability

**Purpose:** Maintain stable routes between discovered nodes; foundation for channels

**Key patterns to implement:**

```yaml
patterns:
  link_establishment:
    description: "Establish and maintain persistent routes to remote nodes"
    mechanism: "TOFU authentication + heartbeat validation"
    timeout_handling: "Protocol-7 timeout-less architecture (use next-data-timestamp pattern)"
    route_persistence: "Cube routing caches route, drops it on disconnect"

  health_monitoring:
    description: "Track health of inter-node links"
    mechanism: "Periodic heartbeat via channels (next-data-timestamp blocking)"
    recovery: "Automatic reconnection with exponential backoff"
    notification: "Inform interested zenka when link status changes"

  announcement:
    description: "Announce node presence and status to discover zenka"
    mechanism: "Integrate with discover zenka's topology awareness"
    frequency: "On-demand + periodic sync"

  subscription:
    description: "Allow zenka to subscribe to remote node state"
    mechanism: "Lazy: no traffic when no subscribers; active when subscribed"
    scope: "Can subscribe to node, or specific aspects of node state"

  graceful_collapse:
    description: "Handle node disappearance cleanly"
    mechanism: "Protocol-7's no-timeout design naturally propagates disconnect"
    client_notification: "Blocked queries get FALSE reply on disconnect"
```

**Implementation tasks:**

```yaml
tasks:
  - task_id: "7b.1"
    title: "Design nodes zenka command interface"
    description: |
      Define commands for:
      - nodes.connect <hostname> <port>
      - nodes.status
      - nodes.subscribe <node-id>
      - nodes.list-connected
    acceptance_criteria:
      - Clear command protocol defined
      - Integration points with discover zenka documented
      - Heartbeat mechanism specified
    files_affected:
      - cfg/zenki/nodes/zenka.v7
      - src/nodes.cmd.* (new modules)
    estimated_complexity: "medium"

  - task_id: "7b.2"
    title: "Implement link establishment and heartbeat"
    description: |
      - Connect to remote nodes discovered by discover zenka
      - Send periodic heartbeats using timeout-less push pattern
      - Detect and recover from link failures
      - Integrate with cube routing
    acceptance_criteria:
      - Links stay open persistently
      - Heartbeat uses next-data-timestamp pattern (no polling)
      - Recovery automatic with exponential backoff
      - Route collapse propagates to clients
    files_affected:
      - src/nodes.link_manager
      - src/nodes.heartbeat
      - src/nodes.init_code
    estimated_complexity: "high"

  - task_id: "7b.3"
    title: "Document nodes zenka patterns for channels reuse"
    description: |
      Extract reusable patterns:
      - Subscription/publication model
      - Announcement/discovery mechanism
      - Blocking wait pattern (next-data-timestamp)
      - Lazy activation (no traffic when no subscribers)
      - State tracking and deduplication
    acceptance_criteria:
      - Pattern documentation clear enough to guide channels implementation
      - Code examples showing pattern usage
      - Template provided for channels to adapt
    files_affected:
      - cfg/zenki/work/source/NODES-CHANNELS-PATTERNS.md
    estimated_complexity: "low"
```

**Deliverables:**
- Stable inter-node links maintained automatically
- Nodes zenka fully integrated with discover
- Reusable pattern documentation for channels

---

### 2.3 Phase 7c: Channels Zenka - Lazy Pub/Sub Infrastructure

**Purpose:** Distributed messaging and shared memory substrate for Protocol-7

**Core commands:**

```yaml
commands:
  last-data-timestamp:
    description: "Get current state timestamp synchronously"
    syntax: "channel.last-data-timestamp [<channel-path>]"
    reply: "<timestamp_b32>"
    latency: "immediate"
    usage: "Query current state without blocking"
    hierarchy: |
      No path: entire remote (single timestamp)
      channel.security: security.* subtree
      channel.security.tofu: security.tofu.* subtree
      /security.tofu: ONLY security.tofu (absolute, no subkeys)

  next-data-timestamp:
    description: "Block until data changes, then return timestamp"
    syntax: "channel.next-data-timestamp [<channel-path>] [since:<timestamp_b32>]"
    reply: "TRUE <timestamp_b32> | FALSE"
    latency: "blocks until change or disconnect"
    usage: "Subscribe to changes; push notification pattern"
    behavior: |
      Holds connection open indefinitely (no timeout)
      Returns TRUE <timestamp_b32> when data changes
      Returns FALSE if disconnected or error
      Uses Protocol-7's no-timeout design as feature

  channels-since:
    description: "Query which channels changed since timestamp"
    syntax: "channel.channels-since <last-synchronized-timestamp>"
    reply: |
      channel.name1
      channel.name2
      CHECKSUM <checksum_b32>
    latency: "immediate"
    usage: "Discover deltas after receiving timestamp change"
    deduplication: |
      Both timestamp and checksum are base32-encoded
      Checksum is AMOS7 harmonic of changed tree
      Clients cache based on checksum match
```

**Hierarchical timestamp deduplication:**

```yaml
deduplication_rules:
  default_no_path:
    scope: "entire remote"
    behavior: "single timestamp for all channels"
    example: |
      13 clients subscribing to different channels on same remote
      → all get same timestamp on any change

  implicit_tree_logic:
    scope: "channel subtree"
    behavior: "timestamp scoped to path prefix"
    example: |
      channel.next-data-timestamp security
      → covers security, security.tofu, security.keys, etc.

  absolute_syntax:
    scope: "exact channel only"
    behavior: "no subtree multiplication"
    syntax: "/channel.name"
    example: |
      channel.next-data-timestamp /security.tofu
      → only security.tofu changes trigger reply

  route_dependent:
    benefit: "Multiple subscriptions on same route share one timestamp counter"
    effect: "More subscribers = more efficient, not less"
```

**Implementation tasks:**

```yaml
tasks:
  - task_id: "7c.1"
    title: "Design channels zenka core infrastructure"
    description: |
      Adapt nodes zenka patterns for pub/sub:
      - Subscription model (implicit from last/next-data-timestamp calls)
      - Channel registry and metadata
      - Timestamp tracking with route-aware deduplication
      - AMOS7 harmonic checksum generation
    acceptance_criteria:
      - Channel data structure designed
      - Timestamp deduplication logic specified
      - Checksum calculation defined
      - Integration points with discover identified
    files_affected:
      - cfg/zenki/channels/zenka.v7
      - src/channels.init_code
    estimated_complexity: "medium"

  - task_id: "7c.2"
    title: "Implement last-data-timestamp command"
    description: |
      Always-reply synchronously with current timestamp.
      Support hierarchical path syntax and deduplication.
    acceptance_criteria:
      - Replies immediately for any request
      - Respects implicit tree logic
      - Respects absolute syntax (/)
      - Returns base32-encoded timestamp
    files_affected:
      - src/channels.cmd.last-data-timestamp
    estimated_complexity: "low"

  - task_id: "7c.3"
    title: "Implement next-data-timestamp command (blocking push)"
    description: |
      Block until data changes, reply with new timestamp.
      Use Protocol-7's no-timeout architecture.
      Handle client disconnection gracefully.
    acceptance_criteria:
      - Holds connection open indefinitely
      - Returns TRUE <timestamp_b32> on data change
      - Returns FALSE on disconnect
      - Works with hierarchical path syntax
      - Route collapse propagates cleanly
    files_affected:
      - src/channels.cmd.next-data-timestamp
      - src/channels.push_handler
    estimated_complexity: "high"

  - task_id: "7c.4"
    title: "Implement channels-since command (delta discovery)"
    description: |
      Query which channels changed since last known timestamp.
      Include AMOS7 harmonic checksum of changed tree.
      Minimal reply for cache validation.
    acceptance_criteria:
      - Returns list of changed channels
      - Includes base32-encoded checksum
      - Checksum matches clients' expectations
      - Works with hierarchical paths
    files_affected:
      - src/channels.cmd.channels-since
      - src/channels.delta_calculation
    estimated_complexity: "medium"

  - task_id: "7c.5"
    title: "Implement memory-sync channel core"
    description: |
      Enable mapping and synchronization of %data branches
      across zenka using variable watches and events.
      Foundation for distributed state management.
    acceptance_criteria:
      - Variable watches trigger on %data changes
      - Mapped branches synchronized across zenka
      - Minimal latency propagation
      - Conflicts handled by ownership hierarchy
    files_affected:
      - src/channels.memory_sync
      - src/channels.variable_watches
    estimated_complexity: "high"

  - task_id: "7c.6"
    title: "Implement generic mapping system"
    description: |
      Allow zenka to declare subscriptions to channel subtrees
      and map them to local %data branches.
      Enable vast ecosystems with minimal core logic.
    acceptance_criteria:
      - Declarative mapping syntax
      - Support read-only and read-write modes
      - Automatic propagation via memory-sync
      - Documentation with examples
    files_affected:
      - src/channels.mapping
      - cfg/zenki/channels/mapping_templates
    estimated_complexity: "high"

  - task_id: "7c.7"
    title: "Implement heartbeat & timeout tracking"
    description: |
      Latest timestamp acts as low-rate heartbeat.
      Track channel status (ACTIVE/IDLE/SUSPENDED) using patterns
      from nodes zenka timeout handling.
      Implement base.cmd.list channels for admin visibility.
    acceptance_criteria:
      - Periodic heartbeat timestamp generation (no data change needed)
      - Status transitions working: ACTIVE → IDLE → [stale]
      - Configurable timeout intervals
      - base.cmd.list channels shows Protocol-7 table format
      - Table includes: name, status, last update, subscriber count
      - Status persistence (not disappearing during timeout)
    files_affected:
      - src/channels.heartbeat
      - src/channels.status_tracking
      - src/base.cmd.list (extended)
      - src/channels.init_code
    estimated_complexity: "medium"
```

**Deliverables:**
- Lazy pub/sub messaging fully functional
- Memory-sync substrate working
- Generic mapping system enabling complex ecosystems
- Heartbeat tracking with status visibility (base.cmd.list channels)
- All commands documented and tested

---

## 3. Synchronization Protocol

### 3.1 Client-Side Flow

```
Client subscribes to security channel:

1. channel.last-data-timestamp security
   → MZXW6YTBOI======

2. Process current state (if needed)

3. channel.next-data-timestamp security since:MZXW6YTBOI======
   → [connection held open...]
   → [admin authorizes TOFU key]
   → TRUE MZXW6YTBON======

4. Query what changed:
   channel.channels-since MZXW6YTBOI======
   → security.tofu
      security.access
      CHECKSUM JBSWY3DPEBLW64TMMQ======

5. Client checks: does checksum match cache?
   YES: skip fetch, use cached data
   NO: fetch new data for changed channels

6. Loop back to step 3
   channel.next-data-timestamp security since:MZXW6YTBON======
   → [holds open for next change...]
```

### 3.2 Round-Trip Efficiency

```yaml
round_trips:
  per_change_cycle: 2
    - "1st: next-data-timestamp (notification)"
    - "2nd: channels-since (delta discovery)"
    - "optional 3rd: fetch data only if checksum new"

  compression:
    - "Checksum deduplication prevents redundant fetches"
    - "Large reference sets benefit from hash matching"
    - "Multiple clients with same checksum share cache"

  known_latency:
    - "Predictable: no surprises in protocol complexity"
    - "Can chain operations or select() on multiple channels"
```

### 3.3 Heartbeat & Timeout Handling

**Low-rate heartbeat via latest timestamp:**

```yaml
heartbeat_mechanism:
  description: "Latest timestamp acts as low-rate health signal"
  pattern: "Similar to nodes zenka heartbeat, adapted for channels"
  implementation:
    - "Periodically emit timestamp update (even if no data changed)"
    - "Clients see fresh timestamp = channel/node is alive"
    - "No update for interval = timeout condition"

  timeout_handling:
    active_channels:
      - "Track all subscribed channels in status table"
      - "Use last-data-timestamp reply as heartbeat indicator"
      - "Timeout = no reply for configured interval"

    status_transitions:
      initial: "ACTIVE"
      no_heartbeat: "IDLE (after timeout period)"
      reconnect: "ACTIVE (on new data/heartbeat)"
      admin_action: "SUSPENDED (explicit unsubscribe)"

  tracking_via_base_cmd_list:
    description: "Display active channels in Protocol-7 style table"
    command: "base.cmd.list channels"
    output: |
      Channel Name         Status    Last Update      Subscribers
      ─────────────────────────────────────────────────────────
      security.tofu        ACTIVE    MZXW6YTBON====== 3
      security.access      IDLE      MZXW6YTBOI====== 1
      discovery.new-items  ACTIVE    MZXW6YTBOM====== 2
      playlist.queue       ACTIVE    MZXW6YTBOK====== 5
      [stale]              SUSPENDED  (expired)        0

    integration:
      - "Reuses Protocol-7 table formatting"
      - "Shows real-time status of all active/tracked channels"
      - "Status changes during timeout period (ACTIVE → IDLE → [stale])"
      - "Allows admin to see channel health at a glance"
```

**Why status persistence is better than disappearing:**

```yaml
advantage_status_over_disappear:
  transparency: "Admins see what happened, not just blank"
  debugging: "IDLE vs SUSPENDED tells story of what occurred"
  recovery: "Can re-activate IDLE channels without full resubscribe"
  auditing: "Full history of channel state changes in logs"
  grace_period: "IDLE channels don't disappear immediately; configurable TTL"
```

---

## 4. Use Case Flows

### 4.1 TOFU Authorization Workflow

```
Timeline:
  T0: Remote client connects, sends auth-keypair request
      Server: Key pinned to incoming/<user>.public
      Callback: triggered (via hook in validate-incoming-tofu)

  T1: Channel message sent to security-channel
      security-channel.tofu-requests:
        - username: "friend"
        - host: "192.168.1.50"
        - timestamp: MZXW6YTBOI======

  T2: Admin subscribed to security channel receives notification
      Admin's device gets pushed the message (least-idle device routing)

  T3: Admin authorizes
      Creates symlink: authorized/cube/friend.public → ../incoming/friend.public
      Updates channel: security.tofu.authorized
      Triggers next-data-timestamp watchers

  T4: Client retries connection
      TOFU validation finds symlink
      Returns 0 (authorized + valid)
      C25519 session established
      User "friend" now authenticated
```

### 4.2 Content Discovery Pipeline

```
Timeline:
  T0: Discovery trigger (scheduled or manual)
      content-discovery zenka scans video/audio sources

  T1: New material found
      Channel update: discovery.new-content
      Sends: discovery.new-content:
        - url: "https://..."
        - source: "yt:xyz123"
        - timestamp: MZXW6YTBOI======

  T2: LLM zenka subscribed to discovery.new-content
      Receives notification
      Auto-generates transcript (if video)
      Evaluates interest based on data{'user'}{'context'}

  T3: LLM decides interest level
      Channel update: discovery.rated-content
      High interest → adds to data{'queue'}{'curated'}
      Memory-sync propagates to playlist zenka

  T4: Playlist zenka sees update
      Adds track to mpv queue
      User hears personalized content in background

  T5: User provides feedback
      Updates data{'user'}{'interests'}
      Memory-sync propagates to all watchers
      LLM refines future evaluation
```

### 4.3 Developer-AI Approval Workflow

```
Timeline:
  T0: Developer pushes changes
      Code enters review queue
      Channel: developer-review.pending

  T1: AI reviewer subscribed to developer-review
      Receives notification
      Analyzes diff
      Sends review comments via channel

  T2: Developer reads review in GUI
      Approves one-time (no key re-entry needed)
      Sends approval via channel

  T3: AI sees approval signal
      Executes git commands automatically:
      - git add
      - git commit -m "..."
      - Optionally: git push if configured

  T4: Changes committed
      Channel update: developer-review.completed
      Notification sent to team
      Callback: optional CI/CD trigger
```

---

## 5. Implementation Dependencies

### 5.1 Dependency Graph

```yaml
graph:
  complete_tofu_pinning:
    blocks: ["nodes_zenka"]
    reason: "TOFU establishes secure foundation for remote node trust"

  nodes_zenka:
    depends_on: ["complete_tofu_pinning"]
    blocks: ["channels_zenka"]
    reason: "Channels need stable routes; nodes provides patterns"
    reuses_from: "nodes"
      - subscription_model
      - announcement_mechanism
      - blocking_wait_pattern
      - lazy_activation
      - state_tracking

  channels_zenka:
    depends_on: ["nodes_zenka", "discover_zenka"]
    blocks: ["applications"]
    reason: "Lazy pub/sub enables all higher-level workflows"

  applications:
    depends_on: ["channels_zenka"]
    examples:
      - developer_ai_approval
      - content_discovery_pipeline
      - llm_driven_curation
      - user_context_management
```

### 5.2 Critical Path

```
[Complete TOFU] (7a)
        ↓
[Nodes Zenka] (7b)
  ↓      ↓
  → [Doc Patterns]
        ↓
[Channels Zenka] (7c)
        ↓
[Applications] (Phase 8+)
```

---

## 6. Risk & Mitigation

```yaml
risks:
  nodes_complexity:
    description: "Inter-node heartbeat and recovery logic could be intricate"
    probability: "medium"
    impact: "high"
    mitigation:
      - "Use Protocol-7's no-timeout as feature, not constraint"
      - "Start with simple heartbeat; add recovery later"
      - "Extensive testing with connection failures"

  channels_state_consistency:
    description: "Multi-node state synchronization edge cases"
    probability: "medium"
    impact: "high"
    mitigation:
      - "Timestamp-based ordering (ACID-like guarantees)"
      - "Ownership hierarchy resolves conflicts"
      - "Memory-sync is append-only until conflict resolution"

  route_collapse_handling:
    description: "Clean disconnect when remote nodes disappear"
    probability: "low"
    impact: "high"
    mitigation:
      - "Protocol-7's design naturally propagates disconnect"
      - "Clients expect FALSE reply; graceful fallback"
      - "Discover zenka detects topology changes"

  performance_at_scale:
    description: "Many subscribers to same channel"
    probability: "low"
    impact: "medium"
    mitigation:
      - "Route-dependent deduplication reduces load"
      - "More subscribers = more efficient (shared timestamp)"
      - "Monitor and optimize checkpoint intervals"
```

---

## 7. Success Criteria

```yaml
phase_7a_success:
  - "Host-restricted TOFU pinning working (p-7-r -strict)"
  - "Cleanup routine tested and preventing disk overflow"
  - "No regressions in auth-keypair auth flow"

phase_7b_success:
  - "Stable links maintained between discovered nodes"
  - "Heartbeat working via timeout-less push pattern"
  - "Recovery from disconnects working automatically"
  - "Pattern documentation guides channels implementation"

phase_7c_success:
  - "Commands: last-data-timestamp, next-data-timestamp, channels-since working"
  - "Hierarchical timestamp deduplication proven"
  - "Memory-sync substrate synchronizing data branches"
  - "Generic mapping system enabling new applications"
  - "Full end-to-end flows verified (TOFU, content discovery, approvals)"
```

---

## 8. Timeline Estimate

```yaml
timeline:
  phase_7a_tofu:
    effort: "1-2 weeks"
    velocity: "high (straightforward extensions of existing code)"

  phase_7b_nodes:
    effort: "3-4 weeks"
    velocity: "medium (new zenka, but patterns exist elsewhere)"

  phase_7c_channels:
    effort: "4-6 weeks"
    velocity: "medium-low (complex state sync, novel architecture)"

  total_infrastructure:
    estimate: "8-12 weeks"
    comment: "Phases are sequential; can be parallelized partially"
```

---

## 9. Testing Strategy

```yaml
testing:
  phase_7a:
    - "Unit tests for incoming file selection logic"
    - "Integration tests: TOFU flow with cleanup"
    - "Manual test: restricted vs unrestricted modes"

  phase_7b:
    - "Link establishment under normal conditions"
    - "Heartbeat interval tuning"
    - "Recovery scenarios: node restart, network partition"
    - "Multi-node routing verification"

  phase_7c:
    - "Timestamp accuracy across concurrent updates"
    - "Checksum consistency (deterministic hash)"
    - "Memory-sync propagation latency"
    - "Route collapse detection and cleanup"
    - "End-to-end workflows (TOFU, discovery, approval)"
    - "Stress tests: many channels, many subscribers"
```

---

## 10. Integration Points

```yaml
external_integrations:
  discover_zenka:
    reason: "Channel topology awareness, node announcement"
    integration_point:
      - "nodes registers with discover"
      - "channels queries discover for subscriptions"
      - "discover announces channel state changes"

  cube_routing:
    reason: "Message delivery between nodes"
    integration_point:
      - "channel messages routed via cube"
      - "nodes uses cube for link establishment"
      - "route collapse detected via cube disconnect"

  events_system:
    reason: "Variable watches, callback triggers"
    integration_point:
      - "watches fire events on %data changes"
      - "memory-sync integrates with event system"
      - "TOFU callback hook triggers channel messages"

  auth_system:
    reason: "TOFU pinning, symlink authorization"
    integration_point:
      - "auth-keypair validates incoming clients"
      - "validate-incoming-tofu fires callback"
      - "callback triggers security-channel message"
```

---

## 11. Next Steps

1. **Review & approve** this planning document
2. **Complete Phase 7a** (server-side TOFU)
3. **Implement Phase 7b** (nodes zenka)
4. **Document patterns** (7b.3)
5. **Implement Phase 7c** (channels zenka)
6. **Test end-to-end** workflows
7. **Begin Phase 8** (applications)

---

**Document Version:** 1.0
**Last Updated:** 2026-01-02
**Status:** Ready for Implementation

#,,.,,..,,.,,,.,,,.,.,,,.,.,,,,..,,.,,,,,,,..,..,,...,...,..,,,..,.,.,...,..,,
#P6GXRNFJ7P7QJHDMPVCBZHNW2MSYJW5WWWWM6JQTUTWXS3ZRZW7I3V3M5PJKYTKUPUGFNWGUKWSUW
#\\\|Z25JG6EB7G2TASQUAYGYMCBSPV7Q3IEOZUQ42G3QQQFPWIDXIXK \ / AMOS7 \ YOURUM ::
#\[7]GVJICFI23Z5X3AEBP3TIS4NJMTKNVGXUECU6TMFV24B46Y323MDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
