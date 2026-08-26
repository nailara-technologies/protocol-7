# DNS Rhizome - Implementation Roadmap

## Vision

Protocol-7 as a self-healing, cryptographically-secured, DNS-routed compute mesh.
DNS serves as the rhizomatic backbone - an underground root network connecting
nodes horizontally without central hierarchy.

## Architecture Components

### 1. Node Discovery Layer
**Status**: 🟡 Partially Implemented

| Component | Status | Task File | Notes |
|-----------|--------|-----------|-------|
| DNS TXT records | 🟡 Planned | [Write task: dns.txt.publish] | Node metadata publishing |
| DNS SRV records | 🟡 Planned | [Write task: dns.srv.publish] | Service endpoint routing |
| DNSSEC validation | 🟡 Planned | [Write task: dns.dnssec.validate] | Cryptographic proof |
| Multicast fallback | 🟢 Working | discover.zenka | Local LAN discovery |
| TOFU key pinning | 🟢 Working | plugin.auth.auth-keypair | Trust on first use |

**Reference**: [DNS_RHIZOME.md](DNS_RHIZOME.md) - Full specification

---

### 2. Cubic Space Topology
**Status**: 🔴 Not Implemented

| Component | Status | Task File | Notes |
|-----------|--------|-----------|-------|
| SHA256→coordinates | 🔴 Planned | [Write task: cubic.position.calc] | Node positioning |
| Distance metrics | 🔴 Planned | [Write task: cubic.neighbor.find] | Find nearby nodes |
| 3D visualization | 🔴 Planned | [Write task: cubic.visual.render] | Topology mapping |
| Ring formation | 🔴 Planned | [Write task: cubic.ring.form] | 5-of-7 groups |

**Purpose**: Geographic-agnostic routing based on hash-space proximity

---

### 3. Consensus Layer (5-of-7)
**Status**: 🔴 Not Implemented

| Component | Status | Task File | Notes |
|-----------|--------|-----------|-------|
| Ring node selection | 🔴 Planned | [Write task: consensus.ring.select] | Choose validators |
| Byzantine agreement | 🔴 Planned | [Write task: consensus.byzantine] | Fault tolerance |
| Result aggregation | 🔴 Planned | [Write task: consensus.vote.tally] | Count validations |
| Attack detection | 🔴 Planned | [Write task: consensus.attack.detect] | Identify bad actors |

**Purpose**: Survive 2 node failures, detect split-brain attacks

---

### 4. Dynamic Routing
**Status**: 🔴 Not Implemented

| Component | Status | Task File | Notes |
|-----------|--------|-----------|-------|
| Load reporting | 🔴 Planned | [Write task: route.load.report] | CPU/RAM/BW metrics |
| Cost-aware routing | 🔴 Planned | [Write task: route.cost.optimize] | €/task minimization |
| Latency optimization | 🔴 Planned | [Write task: route.latency.minimize] | Geo-distribution |
| Failover logic | 🔴 Planned | [Write task: route.failover.handle] | Automatic retry |
| Task delegation | 🟢 Working | coding.task.dequeue | Basic task routing |

**Purpose**: Route tasks to optimal nodes in real-time

---

### 5. Key Delegation Infrastructure
**Status**: 🟡 Partially Implemented

| Component | Status | Task File | Notes |
|-----------|--------|-----------|-------|
| Master key registration | 🟢 Working | discover.register-master-key | Ed25519 root key |
| Delegated key generation | 🟡 Planned | [Write task: key.delegate.generate] | Session keys |
| Key propagation | 🟢 Working | discover.process_incoming_packet | Broadcast via mcast |
| TOFU validation | 🟢 Working | auth-keypair.validate-incoming-tofu | Trust verification |
| Parent blessing | 🔴 Planned | [Write task: key.parent.bless] | Approve child keys |
| Key revocation | 🔴 Planned | [Write task: key.revoke.handle] | Remove compromised |

---

### 6. DNS Integration
**Status**: 🟡 Partially Implemented

| Component | Status | Task File | Notes |
|-----------|--------|-----------|-------|
| DNS client (lookup) | 🟢 Working | dns.zenka | Query DNS records |
| DNS server (publish) | 🔴 Planned | [Write task: dns.server.publish] | Write records |
| Zone file management | 🔴 Planned | [Write task: dns.zone.manage] | BIND integration |
| Dynamic updates | 🔴 Planned | [Write task: dns.dynamic.update] | Real-time TTL |
| DNSSEC signing | 🔴 Planned | [Write task: dns.dnssec.sign] | Record signatures |

---

### 7. Task Distribution Mesh
**Status**: 🟡 Partially Implemented

| Component | Status | Task File | Notes |
|-----------|--------|-----------|-------|
| Failed task queue | 🟢 Working | coding.task.fail/resurrect/bury | Retry failed tasks |
| Note system | 🟢 Working | note.* | Cross-task knowledge |
| Loop detection | 🟢 Working | coding.tool.detect_loop | Prevent stuck tasks |
| Remote execution | 🔴 Planned | [Write task: mesh.remote.execute] | Run on other nodes |
| Result aggregation | 🔴 Planned | [Write task: mesh.result.merge] | Combine outputs |
| WoL integration | 🟡 Working | nodes.list (hwaddr cached) | Wake sleeping hosts |

---

## Implementation Phases

### Phase 1: Foundation (Current)
- ✅ DNS zenka (local lookups)
- ✅ Discover zenka (multicast)
- ✅ Nodes zenka (TOFU)
- ✅ Failed task queue
- ✅ Note system
- ✅ Loop detection

### Phase 2: DNS Publishing
- 🟡 TXT/SRV record generation
- 🟡 Zone file integration
- 🟡 Dynamic updates
- 🟡 DNSSEC signing

### Phase 3: Topology
- 🔴 Cubic space positioning
- 🔴 Neighbor discovery
- 🔴 Ring formation
- 🔴 5-of-7 consensus

### Phase 4: Optimization
- 🔴 Load-aware routing
- 🔴 Cost optimization
- 🔴 Automatic failover
- 🔴 Task migration

---

## Task File Template

For components marked [Write task: xxx], create:

```markdown
# Task: <component-name>

## Objective
Brief description of what this component does.

## Requirements
- Requirement 1
- Requirement 2

## Interface
```perl
# Example API
my $result = <[component.name]>->($args);
```

## Dependencies
- Module A
- Module B

## Status
- [ ] Design drafted
- [ ] Implementation
- [ ] Tests
- [ ] Documentation

## References
- Link to DNS_RHIZOME.md section
- Related task files
```

---

## Current Priorities

1. **DNS Publishing** - Enable nodes to announce themselves
2. **Cubic Positioning** - Hash-based topology
3. **Remote Execution** - Actually distribute tasks
4. **5-of-7 Consensus** - Byzantine fault tolerance

---

*Last updated*: 2026-04-01
*Next review*: When hosted nodes are configured

#,,..,,..,.,,,.,,,.,.,...,.,.,..,,.,.,...,...,.,.,...,...,..,,,.,,,,.,,,,,,,,,
#4JPBGLPC4T24AL2DTOA4AQKO7AHH2SEOLILTLOVQKPULPX3UC3PFLH4VNQOGFIC6P52YPEUVQSWK2
#\\\|5X4GNMW7WLDHXBRWRE2SRSJFBRMRNP3L47SJ4DIYVOAUKOLVKBA \ / AMOS7 \ YOURUM ::
#\[7]IFYG7UNMP6Y6Q6SQ3H3XGQRXG7IBJSEFUKMUISPRHPOWSJE456BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
