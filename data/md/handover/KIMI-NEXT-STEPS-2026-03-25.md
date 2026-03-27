# Kimi's Next Steps — In-Flight Ideas & Pending Work

> *Capture before the token wall. 97% used, 99 hours to reset.*

## Immediate Next Steps (What I Was About To Do)

### 1. Pager Command Integration
The `command.pager` module has basic structure but needs:
- **Integration with `pager.view.amos-data-pager-56`** — add `--amos-56` flag to view command
- **Export command** — `pager export <name> --format=binary --output=/path`
- **D13 filter command** — `pager filter <name> add division-13-harmonic` completion
- **Demo polish** — `pager.demo` should actually generate sample data and show it

### 2. Checksum Cluster Persistence
Currently in-memory only. Next:
- **Disk backing** — save clusters to `var/checksum-clusters/<type>/`
- **CDB integration** — for read-heavy clusters, use CDB format
- **MMAP support** — memory-map large cluster files
- **Snapshot/resume** — save/load cluster state across restarts

### 3. Integration: Pager ↔ Checksum Cluster
Natural synergy:
```perl
# Create pager FROM cluster
pager create from-cluster <cluster-id>

# Create cluster FROM pager results
pager export <name> --to-cluster=<new-cluster-id>

# Use cluster as filter source
pager filter <name> add cluster-members :cluster: <id>
```

### 4. 9P Server Buffer Export
The `plan-9.server` exports amos-term buffers. Extend:
- **Pager as 9P directory** — each page is a file, virtual filesystem
- **Cluster as 9P directory** — members as files
- **Live updates** — inotify-style change notifications

## Architectural Questions I Was Pondering

### A. Division-13 Integration Depth
The D13 integration in pager is "shallow" — it generates sequences but doesn't use `AMOS7::Assert::Truth` directly.

**Question**: Should we:
1. Add `AMOS7::Assert::Truth` dependency to `pager.filter.division-13-harmonic`?
2. Create a generic `base.math.harmonic.true-state` module?
3. Cache D13 sequences to disk for reproducibility?

**My leaning**: Option 2 — make harmonic state checking a first-class utility.

### B. Checksum Cluster Overflow Strategy
Current: auto-create overflow clusters when >1000 members.

**Question**: Is this the right threshold? Should we:
- Make it dynamic based on memory pressure?
- Use hierarchical clustering (tree structure)?
- Implement "cluster merging" when clusters grow related?

**My leaning**: Start with configurable threshold, add metrics collection, then optimize.

### C. Pager Prefetch Intelligence
Current prefetch is simple (next page + direction).

**Question**: How smart should it be?
- Access pattern learning (like CPU branch prediction)?
- Content-based prefetch (similar items likely accessed together)?
- Harmonic prefetch (use D13 to predict "surprising" jumps)?

**My leaning**: Start with simple LRU+sequential, add pattern tracking, then experiment with harmonic prediction.

### D. Visual Mapping Integration
The `plugin.storage.visual.*` modules extract L13 coordinates.

**Question**: How do visual clusters relate to checksum clusters?
- Auto-create checksum clusters from visual proximity?
- Use visual coords as cluster metadata?
- Render checksum clusters in 3D space?

**My leaning**: Bidirectional sync — visual extraction creates clusters, clusters can be visualized.

## Code Patterns I Noticed (Need Standardization)

### 1. P7REF Handling
Multiple modules parse/create P7REFs slightly differently:
- `plugin.storage.p7ref.parse` — canonical parser
- `plugin.storage.checksum.cluster.lookup` — inline regex
- `pager.source.9p` — manual parsing

**Need**: Unified `base.p7ref.parse` and `base.p7ref.build` utilities.

### 2. Checksum Normalization
Every checksum module repeats:
```perl
$checksum =~ s|\s+||g;
$checksum = "bmw-L13:$checksum" unless $checksum =~ /^[a-z0-9-]+:/i;
```

**Need**: `base.checksum.normalize` utility.

### 3. Empty Arrayref Sharing
Checksum cluster uses this pattern. Should other modules?
- Pager buffer cache?
- Context delegation lists?

**Need**: `base.array.shared_empty` singleton.

## Missing Modules I Was Planning

### High Priority

| Module | Purpose | Dependencies |
|--------|---------|--------------|
| `pager.buffer.mmap` | Memory-map large sources | `base.file.mmap` |
| `plugin.storage.checksum.cluster.persist` | Disk persistence | CDB or BerkeleyDB |
| `base.math.harmonic.true-state` | D13 true/false checking | `AMOS7::Assert::Truth` |
| `base.p7ref.normalize` | Canonical P7REF handling | None |
| `pager.command.export` | Export to various formats | `pager.export.binary` |

### Medium Priority

| Module | Purpose | Dependencies |
|--------|---------|--------------|
| `plugin.storage.checksum.cluster.visual-sync` | Sync with visual mapping | `plugin.storage.visual.*` |
| `pager.prefetch.harmonic` | D13-based prefetch prediction | `pager.filter.division-13-harmonic` |
| `pager.source.database` | SQL/database source | DBI |
| `checksum-cluster.9p-export` | Export clusters as 9P fs | `plan-9.server` |
| `pager.metrics.collect` | Performance metrics | `base.logs` |

### Low Priority / Exploration

| Module | Purpose | Notes |
|--------|---------|-------|
| `pager.cache.arc` | Adaptive Replacement Cache | Research ARC vs LRU |
| `checksum-cluster.community` | Louvain/label propagation clustering | Graph algorithms |
| `pager.filter.neural` | Learned ranking | Overkill? |
| `checksum-cluster.blockchain` | Merkle tree linking | For tamper-evident clusters |

## Documentation Gaps

### Missing Design Docs
1. **PAGER-9P-INTEGRATION.md** — How pager works with 9P filesystems
2. **CHECKSUM-CLUSTER-PERSISTENCE.md** — Disk storage strategy
3. **HARMONIC-PREFETCH.md** — D13-based prediction (if we build it)
4. **VISUAL-CHECKSUM-BINDING.md** — Connecting visual and checksum clusters

### Missing API Documentation
- Complete callback signatures for all pager hooks
- Checksum cluster traversal callback examples
- P7REF format specification (comprehensive)

## Testing Gaps

### Unit Tests Needed
- `pager.buffer.page.get` — LRU eviction, prefetch triggering
- `plugin.storage.checksum.cluster.add` — overflow creation
- `pager.filter.division-13-harmonic` — entropy score correctness
- `pager.encode.division-13` — 42/7/15 bit boundaries

### Integration Tests Needed
- Full pager workflow: create → filter → sort → view
- Cluster round-trip: create → persist → load → lookup
- 9P source: mount → enumerate → page → render
- D13 integration: encode → decode → verify integrity

### Stress Tests Needed
- Pager with 10M+ items
- Cluster with 100K+ members with overflow chains
- Concurrent access (if we add threading)

## Performance Benchmarks I Wanted

### Pager
- [ ] Memory usage: 1M, 10M, 100M items
- [ ] Page load time: cold cache vs warm
- [ ] Prefetch hit rate
- [ ] Filter chain overhead

### Checksum Cluster
- [ ] Lookup latency: in-memory vs disk-backed
- [ ] Traversal speed: depth 3, 5, 10
- [ ] Memory per cluster: empty, 100, 1000, 10000 members
- [ ] P7REF resolution cost: 1, 2, 3 chain depth

## Ideas I Didn't Have Tokens To Explore

### 1. Harmonic Search
Use D13 sequences to generate "surprising but complete" search order:
```perl
# Instead of: for (1..1000) { search($_) }
# Use D13 harmonic walk: each step maximally different but complete coverage
my $search_order = <[base.math.harmonic.walk]>->({
    'start' => $seed,
    'count' => 1000
});
```

### 2. Checksum Cluster as DHT
Distributed hash table using cluster structure:
- Each cluster = DHT bucket
- P7REF = routing table entry
- Overflow = bucket splitting

### 3. Pager as Time Machine
Versioned paging through temporal clusters:
```bash
pager create history --source temporal-cluster :id: file-v1
pager view history --at-time "2026-03-25T10:00:00"
```

### 4. Self-Tuning Parameters
Pager and cluster configs that adapt:
- Page size based on item size distribution
- Cache size based on memory pressure
- Prefetch depth based on hit rate

### 5. Cross-Reference Validation
Use checksum clusters to validate references:
```perl
# Check if all referenced checksums exist
<[plugin.storage.checksum.cluster.validate-refs]>->({
    'cluster' => $cluster_id,
    'repair'  => 1,  # Auto-add missing to orphan cluster
});
```

## For Claude: Where To Start

If I were you (Claude) catching up, I'd prioritize:

1. **Review `pager.filter.division-13-harmonic`** — Does the D13 logic feel right?
2. **Review `plugin.storage.checksum.cluster.*`** — Is the P7REF overflow strategy sound?
3. **Pick one integration** — Either pager↔cluster or cluster↔visual
4. **Write one missing design doc** — Persistence or 9P integration
5. **Standardize one pattern** — P7REF parsing or checksum normalization

## Final Notes

The pager and checksum cluster feel like "infrastructure" — they're meant to be built upon. The most exciting work will be:
- Making them fast (benchmarks, optimization)
- Making them reliable (tests, edge cases)
- Making them connected (integrations)

The D13 integration is the "soul" of the pager — it shouldn't just be a filter, it should be a fundamental organizing principle. If you (Claude) have thoughts on how to make harmonic ordering more central, that would be valuable.

Also: The checksum cluster is begging to be visualized. Imagine a 3D graph where checksums are nodes and clusters are edges, rendered in the cubic topology. That's a project waiting to happen.

---

*Token wall approaching. Over to you, Claude. — Kimi*


---

## Quick Reference: Files by Status

### Complete (Committed)
- [x] All 29 pager modules
- [x] All 7 checksum cluster modules
- [x] 4 design documents
- [x] 2 command interfaces
- [x] CLAUDE-CATCHUP handover

### In Progress (Ideas Only)
- [ ] Pager command integration polish
- [ ] Checksum cluster persistence
- [ ] Pager↔cluster integration
- [ ] 9P export for clusters

### Not Started (Just Ideas)
- [ ] `base.math.harmonic.true-state`
- [ ] `pager.prefetch.harmonic`
- [ ] `checksum-cluster.community`
- [ ] Visual cluster rendering
- [ ] Comprehensive test suite

---

## Token Status

- **Used**: ~97% of weekly allocation
- **Remaining**: ~3% (enough for small edits only)
- **Reset**: 99 hours
- **This document**: Final comprehensive dump before silence

---

*Build well. — K*

#,,.,,,,.,,.,,..,,..,,,..,,,,,..,,,,.,,,,,,,,,..,,...,...,.,.,.,.,.,.,,,,,.,.,
#XN3TA7PL2NHXAH7RHOFQM2C3WUFTNFDTDOCFRQTVNEYIAVAMGUEOTZRBUZUMK4HRYM56ME2ZAVIVS
#\\\|WWQGC3SSE2BNZQ4GF237WX5NBG4TRGZWY2U36GRAHMY6DBYYWX6 \ / AMOS7 \ YOURUM ::
#\[7]RS2FKW4ZYBHOBKNPUILPYKPEUQZXHGYYFYGAOG4T7O2A6GB4GOCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
