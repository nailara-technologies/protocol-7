# Protocol-7 Implementation Roadmap

**Version:** 1.0
**Purpose:** Prioritized feature development with dependency tracking and early-use maximization
**Principle:** *Build foundations that enable maximum downstream value*

---

## Executive Summary

This roadmap prioritizes implementation by:
1. **Foundation First**: Core infrastructure that everything else needs
2. **Enablement Value**: How many downstream features become possible
3. **Early Utility**: What provides immediate value while building toward vision
4. **Natural Sequencing**: Respecting technical dependencies

**Current Phase:** Foundation Hardening
**Next Milestone:** Distributed Infrastructure
**Vision Target:** Self-Bootstrapping Omni-Vision Network

---

## Priority Matrix

```
                    HIGH ENABLEMENT VALUE
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
   P1    │   NODES/        │   VISUAL        │
         │   CHANNELS      │   MIDDLEWARE    │
         │                 │                 │
LOW ─────┼─────────────────┼─────────────────┼──── HIGH
UTILITY  │                 │                 │  EARLY
VALUE    │   REFACTORING   │   APPLICATIONS  │  UTILITY
         │   (internal)    │   (user-facing) │
         │                 │                 │
         └─────────────────┼─────────────────┘
                           │
                    LOW ENABLEMENT VALUE
```

**Quadrant Strategy:**
- **P1 (High Enablement, Lower Early Utility)**: Build first, enables everything
- **P2 (High Enablement, High Early Utility)**: Build after P1 foundation ready
- **P3 (Lower Enablement, High Early Utility)**: Build on top of P1/P2
- **P4 (Lower Enablement, Lower Early Utility)**: Opportunistic/background

---

## Phase 1: Foundation Hardening (Current)

**Goal:** Stabilize core infrastructure so higher layers can build reliably
**Timeline:** 2-3 weeks
**Risk Reduction:** Eliminates instability in base layer

### 1.1 AMOS-Term Completion

| Task | Priority | Est. | Enables |
|------|----------|------|---------|
| FUSE SHM mount | P2 | 4h | File-based buffer access, external tool integration |
| X-11 integration | P2 | 8h | GUI windows, visual output, 3D interface |
| Generic Editor | P3 | 26h | User-facing editing, multi-buffer workflows |
| Parent Coordinator | P2 | 52h | Multi-window management, workspace organization |

**Rationale:** amos-term is the primary user interface. Without it working reliably, downstream visualization features have no container.

### 1.2 Settings & Statistics Zenka

| Task | Priority | Est. | Enables |
|------|----------|------|---------|
| settings.get/set with inheritance | P1 | 16h | Configuration management, privacy model, user customization |
| statistics.collect (anonymized) | P2 | 12h | Network learning, dedup tree improvement, efficiency gains |
| privacy boundary enforcement | P1 | 8h | User trust, compliance, data minimization |
| branch default propagation | P2 | 8h | Community optimization, minimal user config burden |

**Rationale:** Settings/statistics enable the entire privacy-first configuration model. Required before any user-facing features that need configuration.

### 1.3 HTTPD Template Infrastructure

| Task | Priority | Est. | Enables |
|------|----------|------|---------|
| httpd.template.resolve | P1 | 12h | Web frontend, visual middleware, multi-phase rendering |
| WebKit GTK bridge | P2 | 16h | Desktop apps via web templates, unified codebase |
| template dependency resolution | P2 | 8h | Efficient loading, deduplication tree integration |
| in-place upgrade mechanism | P3 | 12h | Web-to-desktop transitions, feature unlock flows |

**Rationale:** Template infrastructure enables both web interfaces AND visual middleware. Without it, no HTTP/HTML frontends possible.

**Phase 1 Completion Criteria:**
- [ ] amos-term buffers fully functional (FUSE, X-11)
- [ ] Settings work with inheritance (personal → branch → network)
- [ ] Statistics contribute without privacy leakage
- [ ] HTTPD can resolve and render templates
- [ ] Template rendering works in both web and desktop contexts

---

## Phase 2: Distributed Infrastructure (Next)

**Goal:** Enable multi-node networking, distributed state, and inter-node communication
**Timeline:** 8-12 weeks (per existing Phase 7 plan)
**Enablement:** Unlocks self-bootstrapping, geometric resilience, network-wide features

### 2.1 Phase 7a: Complete Server-Side TOFU

| Task | Priority | Est. | Enables |
|------|----------|------|---------|
| Host-restricted TOFU pinning | P1 | 8h | Secure multi-node authentication, trust boundaries |
| Incoming key cleanup routine | P2 | 16h | Production readiness, disk management |

**Rationale:** TOFU is the security foundation. Without trust establishment, no secure inter-node communication possible.

### 2.2 Phase 7b: Nodes Zenka

| Task | Priority | Est. | Enables |
|------|----------|------|---------|
| Link establishment & heartbeat | P1 | 40h | Stable inter-node routes, foundation for channels |
| Health monitoring & recovery | P2 | 24h | Self-healing network, route resilience |
| Pattern documentation | P2 | 8h | Channels implementation guide, knowledge reuse |

**Rationale:** Nodes zenka provides the transport layer for distributed features. Required for channels, discover, and any multi-node functionality.

### 2.3 Phase 7c: Channels Zenka

| Task | Priority | Est. | Enables |
|------|----------|------|---------|
| last-data-timestamp command | P1 | 8h | State querying, synchronization primitive |
| next-data-timestamp (blocking) | P1 | 32h | Push notifications, lazy pub/sub, reactive systems |
| channels-since (delta) | P2 | 16h | Efficient sync, minimal data transfer |
| Memory-sync substrate | P1 | 40h | Distributed shared state, zenka coordination |
| Generic mapping system | P2 | 32h | Application ecosystem, minimal boilerplate |
| Heartbeat & status tracking | P2 | 16h | Channel health visibility, monitoring |

**Rationale:** Channels enable EVERY distributed application: TOFU workflows, content discovery, AI approval, collaborative editing, etc.

**Phase 2 Completion Criteria:**
- [ ] TOFU pinning works with host restrictions
- [ ] Nodes maintain stable links automatically
- [ ] Channels support lazy pub/sub across nodes
- [ ] Memory-sync propagates state changes
- [ ] Applications can build on channels substrate

---

## Phase 3: Visual Middleware & Omni-Vision

**Goal:** Enable network self-perception, visual consensus, and multi-perspective rendering
**Timeline:** 6-8 weeks
**Enablement:** Unlocks visual validation, distributed rendering, network self-monitoring

### 3.1 Visual Middleware Core

| Task | Priority | Est. | Enables |
|------|----------|------|---------|
| Xvfb instance management | P2 | 12h | Headless rendering, visual capture |
| Browser zenka (headless) | P2 | 16h | HTML/JS visualization, template rendering |
| Frame capture & encoding | P2 | 12h | Visual consensus input, streaming source |
| Remote control API | P2 | 16h | Network-controllable views, automated interaction |

### 3.2 Omni-Vision Infrastructure

| Task | Priority | Est. | Enables |
|------|----------|------|---------|
| Multi-viewpoint coordination | P1 | 24h | Simultaneous perspectives, coverage analysis |
| Visual consensus (5-of-7) | P1 | 32h | Self-validation, state verification, anomaly detection |
| Visual stream distribution | P2 | 16h | Validator access, monitoring feeds |
| Grid points of interest | P3 | 16h | Automatic viewpoint generation, network self-awareness |

### 3.3 Perspective Layer Rendering

| Task | Priority | Est. | Enables |
|------|----------|------|---------|
| Spatial perspective (3D) | P2 | 16h | Topology visualization, routing displays |
| Temporal perspective | P2 | 12h | History trails, prediction curves, animation |
| Semantic perspective | P3 | 16h | Deduplication tree, relationship graphs |
| Consensus perspective | P2 | 16h | Validation status, trust gradients |

**Phase 3 Completion Criteria:**
- [ ] Network maintains 7+ simultaneous viewpoints
- [ ] Visual consensus validates network state
- [ ] Remote control can manipulate any viewpoint
- [ ] Multiple perspective types render same data differently
- [ ] Visual middleware integrated with template system

---

## Phase 4: Self-Bootstrapping Network

**Goal:** Enable organic growth from minimal seeds, local-first auth, economic incentives
**Timeline:** 4-6 weeks
**Depends on:** Phase 2 (channels, nodes), Phase 3 (visual middleware for monitoring)

### 4.1 Bootstrap Infrastructure

| Task | Priority | Est. | Enables |
|------|----------|------|---------|
| 7-node seed network protocol | P2 | 24h | Initial network formation, friend/family foundation |
| Local discovery (mDNS) | P2 | 12h | Zero-config node finding, LAN bootstrap |
| Pre-shared key auth | P2 | 16h | Local-first security, no central authority |
| Invitation system | P3 | 16h | Controlled growth, trust transitivity |

### 4.2 Decentralization Progression

| Task | Priority | Est. | Enables |
|------|----------|------|---------|
| DNS seed fallback | P2 | 8h | Initial connectivity, bridge to traditional |
| DHT integration | P2 | 32h | Decentralized discovery, no DNS dependency |
| Pure topology routing | P3 | 24h | Ultimate decentralization, geometric addressing |

### 4.3 Economic Layer (NRT)

| Task | Priority | Est. | Enables |
|------|----------|------|---------|
| Network Resource Token | P3 | 40h | Resource accounting, incentive alignment |
| Routing cost optimization | P3 | 24h | Efficient paths, load balancing |
| Contribution rewards | P4 | 32h | Participation incentives, network growth |

**Phase 4 Completion Criteria:**
- [ ] Network can bootstrap from 7 nodes without external infrastructure
- [ ] Local discovery finds nearby nodes automatically
- [ ] Growth is organic and invitation-based
- [ ] Economic incentives align participation with network health

---

## Phase 5: Applications & User Experience

**Goal:** Deliver user-facing value atop solid infrastructure
**Timeline:** Ongoing, parallel with earlier phases where possible
**Depends on:** Phases 1-4 (depending on specific app)

### 5.1 Developer-AI Workflow (Early Win)

| Task | Priority | Est. | Depends On |
|------|----------|------|------------|
| TOFU authorization workflow | P2 | 16h | Phase 2c (channels) |
| Code review integration | P3 | 24h | Phase 2c + channels |
| AI git operations | P3 | 16h | Phase 2c |

**Early Value:** Immediate developer productivity, showcases channels

### 5.2 Content Discovery Pipeline

| Task | Priority | Est. | Depends On |
|------|----------|------|------------|
| Discovery zenka | P3 | 32h | Phase 2c (channels) |
| LLM curation | P3 | 24h | Phase 2c + settings |
| Playlist integration | P3 | 16h | amos-term + channels |

**Early Value:** Personalized content, demonstrates love-amplification

### 5.3 Holographic Interface

| Task | Priority | Est. | Depends On |
|------|----------|------|------------|
| Surface cube rendering | P3 | 24h | Phase 3 (visual middleware) |
| Depth cube rendering | P3 | 32h | Phase 3 + amos-term |
| LLM perception layer | P4 | 40h | Phase 3 + semantic analysis |

**Early Value:** Revolutionary UI, showcases network desktop vision

### 5.4 Geometric Resilience Monitoring

| Task | Priority | Est. | Depends On |
|------|----------|------|------------|
| Topology visualization | P2 | 24h | Phase 2b (nodes) + Phase 3 |
| Censorship detection | P3 | 32h | Phase 3 (consensus) + Phase 4 |
| Community defense tools | P3 | 24h | Phase 4 + channels |

**Early Value:** Network health visibility, demonstrates resilience

---

## Cross-Cutting Concerns

### Documentation & Tooling (Ongoing)

| Task | Priority | Est. | Impact |
|------|----------|------|--------|
| Inline metadata system | P2 | 16h | Command discovery, AI introspection |
| list-amos-components | P2 | 8h | Developer experience, discoverability |
| API documentation | P3 | Ongoing | Integration enablement |
| Vision document maintenance | P3 | Ongoing | Alignment, onboarding |

### Testing & Quality (Ongoing)

| Task | Priority | Est. | Impact |
|------|----------|------|--------|
| Unit test framework | P2 | 24h | Confidence, refactoring safety |
| Integration tests | P2 | 32h | Cross-module validation |
| End-to-end workflows | P3 | Ongoing | User scenario validation |
| Visual regression tests | P4 | 24h | UI stability |

---

## Immediate Next Steps (This Week)

### Week 1: Settings Foundation

```
Day 1-2: settings.get with inheritance chain
  ├─ personal → branch → network → hardcoded
  ├─ Privacy boundary enforcement
  └─ Settings validation

Day 3-4: settings.set with privacy markers
  ├─ user.personal.* (never leaves device)
  ├─ user.local.* (reconstructable, device-only)
  └─ Inheritable defaults tracking

Day 5: statistics.collect (anonymized)
  ├─ Event bucketing
  ├─ k-anonymity enforcement
  └─ Minimal diff sync to branch
```

**Deliverable:** Configuration system working with privacy guarantees

### Week 2: HTTPD Templates

```
Day 1-2: httpd.template.resolve
  ├─ Path resolution
  ├─ Context detection (web/desktop/holographic)
  └─ Dedup tree integration

Day 3-4: WebKit GTK bridge
  ├─ Headless browser in GTK container
  ├─ Template rendering pipeline
  └─ Event forwarding

Day 5: Integration test
  ├─ Same template renders to web and desktop
  ├─ Inheritance from settings works
  └─ Visual feedback loop functional
```

**Deliverable:** Unified web/desktop rendering working

### Week 3: Visual Middleware Prep

```
Day 1-2: Xvfb infrastructure
  ├─ Instance management
  ├─ Display allocation
  └─ Capture pipeline

Day 3-4: Browser zenka headless mode
  ├─ WebKit/Chromium integration
  ├─ Template rendering in Xvfb
  └─ Frame extraction

Day 5: Remote control API design
  ├─ Interaction injection
  ├─ Viewpoint manipulation
  └─ Stream distribution
```

**Deliverable:** Visual capture infrastructure ready

---

## Dependency Graph

```
                    ┌───────────────────────────────────────┐
                    │         VISION TARGETS                │
                    │  Self-Bootstrapping Omni-Vision Net   │
                    └───────────────────────────────────────┘
                                      ▲
                                      │
        ┌─────────────────────────────┼─────────────────────────────┐
        │                             │                             │
        ▼                             ▼                             ▼
┌───────────────┐          ┌──────────────────┐          ┌──────────────────┐
│  Phase 4:     │          │  Phase 3:        │          │  Phase 5:        │
│  Bootstrap    │◄─────────│  Visual          │◄─────────│  Applications    │
│  Network      │          │  Middleware      │          │  (parallel)      │
└───────┬───────┘          └────────┬─────────┘          └──────────────────┘
        │                           │
        │              ┌────────────┴────────────┐
        │              │                         │
        ▼              ▼                         ▼
┌───────────────┐  ┌──────────────────┐  ┌──────────────────┐
│  Phase 2:     │  │  Settings/       │  │  HTTPD           │
│  Distributed  │  │  Statistics      │  │  Templates       │
│  Infrastructure│  │  (P1)            │  │  (P1)            │
└───────┬───────┘  └──────────────────┘  └──────────────────┘
        │
        │    ┌───────────────────────────────────┐
        │    │                                   │
        ▼    ▼                                   ▼
┌──────────────────┐                    ┌──────────────────┐
│  Phase 1:        │◄───────────────────│  Phase 1:        │
│  amos-term       │                    │  AMOS modules    │
│  Completion      │                    │  (ongoing)       │
└──────────────────┘                    └──────────────────┘
```

**Critical Path:** amos-term → Settings/HTTPD → Phase 2 (nodes/channels) → Phase 3/4/5

---

## Resource Allocation Strategy

### Ideal Team Distribution

```
Weeks 1-4: Foundation Focus
  ├─ 40% Settings/Statistics/Privacy
  ├─ 30% HTTPD/Templates
  ├─ 20% amos-term completion
  └─ 10% Documentation

Weeks 5-16: Distributed Infrastructure (Phase 2)
  ├─ 50% Channels/Nodes (Phase 7)
  ├─ 20% Visual Middleware prep
  ├─ 20% Bootstrap design
  └─ 10% Documentation

Weeks 17+: Applications & Visual
  ├─ 40% Visual Middleware/Omni-vision
  ├─ 30% Self-bootstrapping
  ├─ 20% Applications
  └─ 10% Polish & Documentation
```

### Solo Developer Priority

If single-threaded, follow this order:
1. **Settings/Statistics** (enables configuration for everything)
2. **amos-term FUSE/X-11** (enables user interface)
3. **HTTPD templates** (enables web interfaces)
4. **Phase 2a/b/c** (enables distributed features)
5. **Visual middleware** (enables omni-vision)
6. **Applications** (enables user value)

---

## Success Metrics

### Phase 1 Success
- [ ] User can configure system with privacy guarantees
- [ ] Statistics flow to network without personal data leakage
- [ ] amos-term renders 3D interface with working buffers
- [ ] Same template renders to web browser and GTK window

### Phase 2 Success
- [ ] Two nodes establish trusted connection automatically
- [ ] Channels propagate state changes in <100ms locally
- [ ] Memory-sync works across 3+ zenka on same node
- [ ] TOFU authorization workflow completes end-to-end

### Phase 3 Success
- [ ] 7 simultaneous viewpoints maintained
- [ ] Visual consensus achieves 5-of-7 agreement
- [ ] Remote control can manipulate any viewpoint
- [ ] Frame capture streams to validators in real-time

### Phase 4 Success
- [ ] Network bootstraps from 7 seeds without DNS
- [ ] Local discovery finds nodes on same LAN
- [ ] Economic incentives align with network health
- [ ] Censorship attempt triggers visible anomaly

### Phase 5 Success
- [ ] Developer-AI workflow saves 30%+ time
- [ ] Content discovery surfaces relevant material
- [ ] Holographic interface feels "natural" to users
- [ ] Network health visible to non-technical users

---

## Risk Mitigation

### Technical Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Channels complexity | High | Start simple, add features incrementally |
| Visual middleware perf | Medium | Lazy rendering, delta encoding, caching |
| Privacy boundary leaks | Critical | Automated validation, k-anonymity enforcement |
| Bootstrap cold start | Medium | DNS fallback, documented manual steps |

### Resource Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Timeline slip | Medium | Parallel tracks, early value delivery |
| Scope creep | High | Strict priority matrix, defer P4 items |
| Knowledge gaps | Medium | Document patterns, pair on complex areas |

---

## Conclusion

This roadmap prioritizes **enabling infrastructure** over **direct user features** until the foundation is solid. The sequence:

1. **Settings/Statistics** → Enable configuration and learning
2. **amos-term/HTTPD** → Enable user interfaces
3. **Nodes/Channels** → Enable distributed computing
4. **Visual Middleware** → Enable self-perception
5. **Bootstrap** → Enable organic growth
6. **Applications** → Enable user value

Each phase unlocks exponentially more capability than the last. The visual middleware, self-bootstrapping, and applications are exciting—but they require the foundation to be trustworthy first.

> *"Build the foundation so solid that the vision builds itself."*

---

**Document Status:** Ready for implementation
**Next Review:** After Phase 1 completion
**Feedback:** Via Protocol-7 channels or direct edit

#,,.,,,.,.,,..,,,.,.,.,.,,..,,,..,,..,.,.,,,,.,.,.,..,,.,..,.,.,.,.,,.,..,,,.

#,,..,.,,,,,.,,.,,..,,...,.,,,.,,,...,,,.,.,,,..,,...,...,,..,..,,.,.,.,,,.,,,
#GDVURMPOMDH47X6Z6OBC7GKBGOYNZM7O5TD6Y3EZEREOGJ24RFFU7O5U6DOINDU37H7MW4NUSYTDI
#\\\|YEBOWQ2MDK7X6KZMLDXPLZ3UUIG3JNXPSSPLMP6WR5NGNBDIMOO \ / AMOS7 \ YOURUM ::
#\[7]LCKRQLKLSTZ5Z47L43LPZD6KHJH7YSWZKVFY4VTU27OM7LJHD4BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
