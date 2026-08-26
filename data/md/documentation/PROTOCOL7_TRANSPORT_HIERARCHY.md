# Protocol-7 Transport & Feature Hierarchy

## Design Philosophy

Protocol-7 operates as an **intelligent overlay mesh** that gracefully
coexists with existing infrastructure. Features are organized in **preference
stacks** where P7-native implementations are preferred, but fallbacks are
automatically selected when unavailable.

---

## Transport Layer Stack

### L1: Preferred Native Transport
```
┌─────────────────────────────────────────┐
│  UDT/P7 Native                          │
│  ├─ Message-oriented (P7 packet model)  │
│  ├─ High BDP optimization               │
│  ├─ Congestion fairness                 │
│  └─ NAT traversal (UDP hole punching)   │
├─────────────────────────────────────────┤
│  Alternative: TCP/P7 with custom framing│
│  [when UDT unavailable]                 │
└─────────────────────────────────────────┘
```
**Reference**: [UDT Implementation](bin/dev/script-scratchpad/udt_test_*.pl)

---

### L2: Bridge/Fallback Transport
```
┌─────────────────────────────────────────┐
│  TCP/TLS Bridge                         │
│  ├─ Legacy compatibility                │
│  ├─ Firewall-friendly (port 443)        │
│  ├─ Standard TLS encryption             │
│  └─ Slower but universally available    │
├─────────────────────────────────────────┤
│  Alternative: WebSocket bridge          │
│  [when direct TCP blocked]              │
└─────────────────────────────────────────┘
```
**Module**: `external` zenka (planned)

---

### L3: Discovery Bootstrap
```
┌─────────────────────────────────────────┐
│  Multicast (LAN)                        │
│  ├─ Zero-configuration                  │
│  ├─ Fast local discovery                │
│  └─ No infrastructure required          │
├─────────────────────────────────────────┤
│  Alternative: DNS TXT/SRV (WAN)         │
│  [when multicast not available]         │
├─────────────────────────────────────────┤
│  Alternative: Static seed nodes         │
│  [bootstrap from config]                │
└─────────────────────────────────────────┘
```
**Modules**: `discover` (multicast), `dns` (DNS), `nodes` (static)

---

## Discovery Layer Stack

### L1: Preferred Native Discovery
```
┌─────────────────────────────────────────┐
│  Multicast Announce                     │
│  ├─ Real-time presence                  │
│  ├─ No central registry                 │
│  └─ Instant peer detection              │
└─────────────────────────────────────────┘
```
**Module**: `discover` zenka ✅ Working

---

### L2: Scalable WAN Discovery
```
┌─────────────────────────────────────────┐
│  DNS TXT/SRV Records                    │
│  ├─ Globally distributed                │
│  ├─ DNSSEC-signed                       │
│  ├─ Cached and TTL-controlled           │
│  └─ Universal resolver support          │
├─────────────────────────────────────────┤
│  Alternative: DHT (Kademlia)            │
│  [when DNS unavailable]                 │
├─────────────────────────────────────────┤
│  Alternative: Central registry (last)   │
│  [bootstrap fallback only]              │
└─────────────────────────────────────────┘
```
**Reference**: [DNS_RHIZOME_ROADMAP.md](DNS_RHIZOME_ROADMAP.md)

---

## Trust Layer Stack

### L1: Strong Identity
```
┌─────────────────────────────────────────┐
│  Ed25519 Key Delegation                 │
│  ├─ Hierarchical trust chain            │
│  ├─ Parent-blessed children             │
│  ├─ Revocation capability               │
│  └─ Global key visibility               │
└─────────────────────────────────────────┘
```
**Modules**: `discover` (broadcast), `auth-keypair` (validation) ✅ Working

---

### L2: Bootstrap Trust
```
┌─────────────────────────────────────────┐
│  TOFU (Trust On First Use)              │
│  ├─ Automatic pin on first contact      │
│  ├─ Mismatch detection (MITM warning)   │
│  ├─ Expiration cleanup                  │
│  └─ Human override possible             │
├─────────────────────────────────────────┤
│  Alternative: Pre-shared keys           │
│  [air-gapped initial setup]             │
├─────────────────────────────────────────┤
│  Alternative: Certificate authorities   │
│  [enterprise integration]               │
└─────────────────────────────────────────┘
```
**Module**: `auth-keypair` zenka ✅ Working

---

## Routing Layer Stack

### L1: Optimal Path Selection
```
┌─────────────────────────────────────────┐
│  Cubic Space Topology                   │
│  ├─ Hash-based positioning (x,y,z)      │
│  ├─ Geometric neighbor discovery        │
│  ├─ Distance metrics in 3D space        │
│  └─ Geographic-agnostic routing         │
└─────────────────────────────────────────┘
```
**Reference**: [DNS_RHIZOME.md](DNS_RHIZOME.md) 🔴 Planned

---

### L2: Traditional Routing
```
┌─────────────────────────────────────────┐
│  Latency-based selection                │
│  [when cubic unavailable]               │
├─────────────────────────────────────────┤
│  Geographic proximity                   │
│  [when latency unknown]                 │
├─────────────────────────────────────────┤
│  Random/round-robin                     │
│  [last resort]                          │
└─────────────────────────────────────────┘
```
**Status**: Fallback modes

---

## Consensus Layer Stack

### L1: Byzantine Fault Tolerance
```
┌─────────────────────────────────────────┐
│  5-of-7 Ring Consensus                  │
│  ├─ Survives 2 node failures            │
│  ├─ Detects split-brain attacks         │
│  ├─ Cryptographic verification          │
│  └─ Automatic disagreement detection    │
└─────────────────────────────────────────┘
```
**Reference**: [DNS_RHIZOME.md](DNS_RHIZOME.md) 🔴 Planned

---

### L2: Simpler Agreement
```
┌─────────────────────────────────────────┐
│  Simple majority voting                 │
│  [when 5-of-7 unavailable]              │
├─────────────────────────────────────────┤
│  Trusted coordinator                    │
│  [single point of failure]              │
├─────────────────────────────────────────┤
│  No consensus (blind trust)             │
│  [testing only]                         │
└─────────────────────────────────────────┘
```
**Status**: Fallback modes

---

## Task Execution Layer Stack

### L1: Resilient Execution
```
┌─────────────────────────────────────────┐
│  Failed Task Queue                      │
│  ├─ Automatic retry with backoff        │
│  ├─ Cross-node resurrection             │
│  ├─ Bury permanently (failed-stopped)   │
│  └─ Note persistence across failures    │
├─────────────────────────────────────────┤
│  Loop Detection                         │
│  ├─ Weighted pattern analysis           │
│  ├─ Model self-assessment               │
│  ├─ 777 round limit                     │
│  └─ Escalation warnings                 │
├─────────────────────────────────────────┤
│  Note System                            │
│  ├─ Cross-task knowledge                │
│  ├─ L1/L2/L3 summarization              │
│  └─ Categorization & search             │
└─────────────────────────────────────────┘
```
**Modules**: `coding.task.*`, `note.*` ✅ Working

---

### L2: Basic Execution
```
┌─────────────────────────────────────────┐
│  Simple job queue                       │
│  [no retry, fire-and-forget]            │
├─────────────────────────────────────────┤
│  Local-only execution                   │
│  [no distribution]                      │
└─────────────────────────────────────────┘
```
**Status**: Fallback modes

---

## Dependency Graph

```
                    ┌─────────────┐
                    │   Task      │
                    │  Execution  │
                    └──────┬──────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
           ▼               ▼               ▼
    ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
    │   Routing   │ │ Consensus   │ │   Trust     │
    │   (Cubic)   │ │   (5-of-7)  │ │  (TOFU+     │
    │             │ │             │ │ Delegation) │
    └──────┬──────┘ └──────┬──────┘ └──────┬──────┘
           │               │               │
           └───────────────┼───────────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │  Discovery  │
                    │ (Multicast  │
                    │   + DNS)    │
                    └──────┬──────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
           ▼               ▼               ▼
    ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
    │    UDT      │ │    TCP      │ │   Bridge    │
    │   Native    │ │    /TLS     │ │  (External) │
    └─────────────┘ └─────────────┘ └─────────────┘
```

---

## Status Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Working/Implemented |
| 🟡 | Partially Implemented |
| 🔴 | Planned/Not Started |
| ⬜ | Alternative/Fallback |

---

## Decision Records

### Why UDT over TCP for native transport?
- **High BDP**: Saturates long-haul links better than TCP
- **Fairness**: Doesn't starve TCP traffic
- **Messages**: Fits P7's packet model vs TCP streams
- **NAT**: UDP hole punching works better than TCP

### Why DNS + Multicast for discovery?
- **Multicast**: Zero-config for LAN
- **DNS**: Ubiquitous for WAN
- **Redundancy**: Two independent paths
- **Caching**: DNS TTL for efficiency

### Why 5-of-7 consensus?
- **Byzantine**: Survives 2 malicious/failed nodes
- **Practical**: Small ring size (7 nodes)
- **Efficient**: Only 3+ agreement needed
- **Secure**: Cryptographic verification

---

## References

| Document | Purpose |
|----------|---------|
| [DNS_RHIZOME.md](DNS_RHIZOME.md) | Full DNS rhizome specification |
| [DNS_RHIZOME_ROADMAP.md](DNS_RHIZOME_ROADMAP.md) | Implementation tracking |
| [Protocol-7 README](../../README.md) | Project overview |

---

*Last updated*: 2026-04-01
*Status*: Living document - evolves with implementation

#,,.,,.,.,..,,..,,,..,,,.,.,,,,.,,.,,,,,.,,.,,.,.,...,...,...,,,,,,..,...,,,,,
#A3TVGJUNQBJZQ6QHKL4YOC7JNKPLRDBVOAV4WVE5PRX27QJUGM7LEXFDB5WP3QPTB6QAGNL4XCUIY
#\\\|5VQOIYBOVPMMLD4EQK4UHS7EFEC7OHS2QMPMQBSUVVC32UCR4HK \ / AMOS7 \ YOURUM ::
#\[7]DXQRHQN4D4W25SYCVCO34EITLUE3SZUQ5CZ3SRDRUGPGDLHY6EAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
