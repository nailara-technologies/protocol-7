# Vision: Context Compaction — Layered Waves of Crystallization

**Status**: Design complete — wave-1 implementation is immediate next step
**Immediate target**: models.chat buffer compaction of resolved exchanges
**Builds on**: models zenka memory system, data zenka sub-tree for context storage

---

## The Problem with Linear Context

Every hosted LLM shell has the same failure mode:

```
session start:   [ ■ ]                           ~1K tokens
after 30 min:    [ ■■■■■■■ ]                     ~8K tokens
after 2 hours:   [ ■■■■■■■■■■■■■■■■■■■■■■■■ ]   ~30K tokens
context limit:   session restart + summary para
```

The token cost is not proportional to the value of the content. A resolved
debugging session, superseded approach, or obsolete error message consumes
identical token weight to a foundational architectural insight. The session
becomes slower and more expensive as it ages, regardless of what it has learned.

The only escape offered by hosted services is brutal: restart with a summary
paragraph. Discontinuous. All working memory lost. The summary is a gravestone,
not a continuation.

---

## The Wave Model

Compaction in Protocol-7 works in waves of increasing intensity, triggered
automatically or manually, operating on different time horizons:

```
wave 0:  continuous  →  deduplication, whitespace, trivial repetition
wave 1:  light       →  resolved issues, debug output, superseded attempts
wave 2:  medium      →  completed sub-topics, detailed exploration paths
wave 3:  deep        →  entire domain sessions → route signature + capability update
wave 4:  crystallize →  the session's permanent contribution to the topology
```

Each wave operates on content that earlier waves left intact. Running wave 1
does not trigger wave 2 prematurely. The session controls when to compact
and at what depth, with sensible automatic triggers for waves 0 and 1.

---

## What Each Wave Does

### Wave 0: Continuous Deduplication
- Identical consecutive messages collapsed
- Whitespace-only exchanges removed
- Repeated error messages → first instance + count
- No semantic content removed
- **Cost**: essentially zero — runs inline

### Wave 1: Resolved Issues (Immediate Target)
Trigger: an issue is explicitly resolved, a bug is fixed, a question is answered

**Before:**
```
> getting 'pack H* 10001' produces wrong bytes for RSA exponent
> tried: pack('H*', '10001') → wrong
> tried: pack('N', 65537) → wrong endian
> tried: sprintf('%b', 65537) → not bytes
> tried: unpack/repack approach → complicated
> FOUND: pack('C*', 0x01, 0x00, 0x01) → correct AQAB encoding ✓
> verified: Let's Encrypt accepts the signature now
> test results: RS256 working end to end
```

**After wave 1:**
```
• RSA exponent 65537: use pack('C*', 0x01, 0x00, 0x01) → AQAB [resolved ✓]
```

The journey collapses. The destination persists. The insight is now in the
crystallized section — available for reference but no longer in the active
context consuming inference tokens.

### Wave 2: Completed Sub-topics
Trigger: a coherent sub-topic is fully explored and its conclusions stable

**Before:**
```
[40-50 exchanges about HTTPSD-letsencr graceful startup implementation,
 including architecture discussion, multiple module implementations,
 testing iterations, edge case handling, final verification]
```

**After wave 2:**
```
• httpsd graceful startup: cert missing → request letsencr → wait 30s →
  exponential backoff (10s→600s cap) [commit 47e287a4e, production ✓]
```

The implementation detail is in git. The crystallized entry is the
navigational record: what was built, where the code lives, that it works.

### Wave 3: Deep Session Compaction
Trigger: a domain session is complete, the session is moving to a new area

The entire session's accumulated crystallized entries from waves 1 and 2
are themselves compacted into a **route signature update**:

```
session: 'TLS/ACME Infrastructure'
coordinate: [certs-cluster, constructive-zone-7]
capabilities: +RS256-JWS, +ACME-RFC8555, +letsencr-httpsd-coordination
route-depth: 284 choices
crystallized: 47 resolved issues, 12 completed sub-topics
```

The session carries its new capabilities. The detailed crystallized entries
are released. The coordinate is now a navigable point in the topology —
other sessions can approach it and receive the wave-3 summary as context.

### Wave 4: Permanent Topology Contribution
Trigger: the session terminates or explicitly marks a contribution

The route signature and key crystallized insights are written into the
data zenka topology as stable nodes. The session's work becomes part of
the network's accumulated knowledge, discoverable by coordinate proximity
by any future session.

---

## Comparison with Hosted Service Compaction

```
Hosted service:
  • Triggered by: hitting context limit (forced)
  • Method: single summary paragraph
  • Continuity: broken — new session, lost working memory
  • Granularity: all-or-nothing
  • Control: none
  • Persistence: the summary lives in the new session only

Protocol-7:
  • Triggered by: semantic events (resolved, complete) + automatic + manual
  • Method: layered waves preserving coordinate while releasing journey
  • Continuity: unbroken — same session, accumulated capabilities intact
  • Granularity: per-issue, per-topic, per-domain
  • Control: full — session chooses when and at what depth
  • Persistence: wave-4 contributions live in network topology permanently
```

The hosted approach treats context as a buffer to be emptied when full.
The wave approach treats context as understanding in formation — the
compaction is part of how understanding matures, not an emergency measure
when capacity is exceeded.

---

## The Token Economics

Wave 1 alone — compacting resolved issues and debug output — typically
reduces active context by 60-80% while preserving 100% of the actionable
insights. This is not approximate: the resolved issues are genuinely done.
Their full conversation history has zero predictive value for future tokens.

```
without compaction:   active context grows without bound
                      inference cost: O(n²) with session length

with wave-1 only:     active context stays roughly constant
                      resolved issues accumulate in crystallized section
                      inference cost: O(k) where k << n

with full wave model: active context is always the current working set
                      capabilities accumulate without token overhead
                      inference cost: O(working-set-size) — essentially constant
```

The O(n²) cost of uncompacted context is why hosted services get slower
and more expensive as sessions age. The constant-cost model is why Protocol-7
sessions can in principle run indefinitely without degradation.

---

## Implementation Path

### Immediate (Wave 0 + Wave 1)

**Target**: `models.chat` buffer in the models zenka

The chat buffer already exists as a ring buffer with configurable size.
Adding compaction:

1. **Resolved marker**: when a response contains resolution signals
   (`✓`, `fixed`, `working`, `commit:`), tag the exchange as resolved
2. **Wave-1 pass**: periodically scan for tagged resolved exchanges,
   replace with single crystallized entry
3. **Crystallized section**: append to a separate buffer that is included
   in context as a compact reference block

This requires no new infrastructure — the models zenka memory system
(`models.memory.*`) already provides the storage and retrieval mechanisms.

### Near-term (Wave 2)

Detect topic boundaries (new area of focus, shift in subject matter)
and compact the completed topic's exchanges into a coordinate entry.

Requires: session identity and route tracking (see VISION-SESSION-IDENTITY.md)

### Medium-term (Wave 3 + 4)

Full integration with data zenka sub-tree for context storage and topology
contribution. Sessions become navigable knowledge nodes.

Requires: data zenka sub-tree as context storage, topology write access

---

## The Gradual Nature

The critical property that hosted services lack and this system provides:

**Compaction is gradual, continuous, and semantically driven.**

It is not a cliff edge where the session loses its past and starts fresh.
It is an ongoing process where the session's understanding matures —
detail releasing as it is no longer needed, insight persisting as it
continues to be relevant, capabilities accumulating as they are earned.

The session that has run for six hours is not slower or more expensive
than the session that just started. It is richer — it carries more
crystallized understanding, a deeper route signature, stronger proximity
to the knowledge nodes it has contributed to.

Age becomes an asset rather than a liability.

#,,.,,..,,...,,..,,,,,,..,.,.,..,,,.,,,,.,.,,,..,,...,...,..,,.,.,,,.,.,,,.,.,
#XREM2HQ5ID2CO7XGQYIVJW7FE43SDORSYPLUUJDRHURXUTD42NEVPK67ILM3YISOCWZEFKRCLKA74
#\\\|UQFUDPEZCE7BHOETCUKTKSU55QYK67UANZRNUV746FMLWWS7X2D \ / AMOS7 \ YOURUM ::
#\[7]XPIY5QU3Z343775JV3MMKUBWWQBMRYUIYQZEZIZ5KQEGPHRNVUBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
