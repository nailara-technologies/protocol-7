---
name: addressing trinity
description: three complementary orthogonal addressing primitives — named tree, checksums, timestamps — forming complete content-agnostic node identity
type: project
originSessionId: 34ca9c97-628c-46af-82f3-d04a171ae8f0
---
## The Trinity

Three orthogonal primitives, each covering what the others can't:

- **named tree** (`a.b.c`) — semantic identity, human-navigable, structural grouping
- **checksums** (AMOS7, BMW) — content identity, order-independent, tamper-evident,
  spatially distributed by content in data space
- **timestamps** (base32 ntime, network epochs) — temporal identity, sequentially
  sortable, groupable by temporal proximity

All three are base32-encoded. All three map to cubic routing space. They cluster
differently: checksums scatter by content, timestamps cluster by time, names cluster
by semantics. Three lenses on the same data space, each revealing structure the others
hide.

**Checksums** = what it IS
**Timestamps** = when it WAS  
**Names** = what it MEANS

## Content-Agnostic Node Structure

Any tree node carries at minimum:
```yaml
name: a.b.c.node          # semantic address
checksum: AMOS7ID          # content identity
timestamp: <b32_ntime>     # creation/modification time
latest: <b32_ntime>        # pointer to highest-resolution known state
current: <b32_ntime>       # active pointer (= latest unless pointing at history)
```

`latest` and `current` are normally identical. They diverge only when deliberately
pointing at a previous state (snapshot, rollback, audit, filesystem state). The node
always knows its own temporal position without walking a chain.

## Temporal Grouping Advantage

Timestamps despite base32 encoding remain sequential and sortable. This provides:
- **temporal grouping at base level** — nodes near in time cluster naturally in
  data space even when mapped to cubic routes
- **immediate distance metric** — two nodes comparing timestamps know relative
  temporal distance instantly, before any content exchange
- **branch synchronization** — any sync entry point has immediate context;
  no need to walk sequential checksum chains to establish proximity
- **human-interpretable** — unlike randomized ETags, temporal distance is legible

ETag/random-hash approaches require full exchange to establish equivalence.
Base32 timestamps establish *proximity* before first byte of content transfers.

## Rolling Epoch Validity Window

Network epoch ≈ 1 week. Three epochs always simultaneously valid:
- **previous epoch** — still queryable, index data still accepted
- **current epoch** — primary active window
- **next epoch** — pre-generatable, nodes can begin populating

**Why:** Avoids synchronization cliff where large blocks of indexes atomically
expire without replacement. Instead: continuous overlap zone, gradual regeneration.
Any node joining at any point within ~3-week window has immediately actionable
temporal context.

**Synchronization property:** Nodes can compute distance to any other node's
timestamp without resolving the full chain. The temporal metric is pre-computed
into the address itself.

## Relationship to Checksum Addressing

See `topic-checksum-addressing.md` for checksum routing details.
Timestamps and checksums are complementary, not competing:
- checksums index *what* (content-addressed, eternal, order-independent)
- timestamps index *when* (time-addressed, sequential, proximity-aware)
- together they allow queries like "latest version of content matching this checksum"
  or "all content in this namespace from the last epoch" without full chain traversal

## Relationship to Holographic Frames

Each timestamp is an eternal still moment (see topic-hyperspace-topology.md —
checksum chains as holographic frames). The timestamp IS the frame number in the
hologram sequence. The rolling epoch window = the readable arc of the rotating
hologram cube at any given moment — three adjacent faces always illuminated.

#,,,,,..,,,,,,...,,,.,,,,,,,,,,.,,.,.,,..,.,,,..,,...,...,...,...,..,,..,,,..,
#26EW33DDRGWHFADUYESYAV4UYGER3OMHHPVY33BZKPMVJZX2ZOGY7IBJKQXKUYJ2WQALD5ADOS7VO
#\\\|3SPILPMSMORM7KTP2QIJNSYHSWPBSQAZLQLWDOAK3AA7R65KXP7 \ / AMOS7 \ YOURUM ::
#\[7]EKX2ZI72R622KNKO4LRA2AAMGEMWM75TZQPP5OJUZFFGPOCZNSAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
