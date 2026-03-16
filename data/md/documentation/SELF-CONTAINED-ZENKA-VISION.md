# Self-Contained Zenka Vision

## Overview

A zenka should be fully self-contained: able to boot from a single file, transfer its
state to another node, reconstitute itself there, and continue operating — without
requiring shared disk, a common repo checkout, or a running v7 manager.

This document captures the architectural features planned in the March 2026 session
that make this possible.

---

## 1. `__DATA__` Content Registry (inline module packing)

`bin/Protocol-7` already has a `__DATA__` block with named sections. The planned
extension turns it into a first-class content registry.

### Section format

```
.:[ section-name ]:.
.:[ chksum=LQKM3XP size=4192 compression=xz+b32 ]:.
<base32-encoded xz-compressed payload>
```

### Discriminator rules (what a section represents)

| Name pattern | Interpretation |
|---|---|
| no `/` | `%code` subroutine (module source) |
| relative path | repo file (served via `file.*` abstraction) |
| leading `/` with further `/` | absolute export path on target system |

### Tooling

- **Dep-graph** (`data/md/documentation/module-dependency-graph.*`) selects the
  transitive closure of modules for a given zenka profile
- A packing tool reads that closure, compresses each module with xz+base32, and
  writes it into the `__DATA__` block
- Result: `bin/Protocol-7` can boot a named zenka with zero external dependencies

### Status

- `__DATA__` block exists; `-use-http-src` flag already implemented (lines 597,
  1162, 1396-1416 of `bin/Protocol-7`) for fetching from plain HTTP source
- Dep-graph functional
- **Pending**: packing tool + `file.*` registry lookup (see §3)

---

## 2. `file.*` Abstraction Layer (transparent source routing)

The `file.*` namespace becomes a unified interface. Callers do not know or care
where content lives.

### Lookup priority (proposed)

1. `__DATA__` registry (inline, always available)
2. In-memory zenka store (`$data{'file.cache'}{$path}`)
3. Local disk (current behaviour)
4. Network fetch (peer zenki, httpsd) — with AMOS7 checksum verification

### Key property

Same call signature regardless of source:

```perl
my $content = <[file.slurp]>->($path);
```

The implementation routes transparently. A zenka booted from `__DATA__` never
calls `open()` for its own modules.

### Status

- Disk path working
- `-use-http-src` covers HTTP fetch (plain, needs upgrade to httpsd/peer)
- **Pending**: `__DATA__` lookup step; in-memory cache step; AMOS7 verification
  on network-fetched content

---

## 3. Network Fetch Upgrade (`-use-http-src` → authenticated peers)

Current `-use-http-src` fetches from a plain HTTP URL. Planned upgrade:

- Target: httpsd (existing HTTPS zenka with full cert chain) or a peer zenka
  serving via the P7 protocol
- Each fetched module verified via AMOS7 checksum before loading
- Fetch result cached in in-memory store (§2 step 2) so subsequent calls hit cache

---

## 4. Zenka Serialization (`devmod.cmd.dump`)

A dump command that produces a reproducible, transferable representation of a
zenka's current state.

### Format for `%data` values

| Value type | Serialized as |
|---|---|
| Scalar (short) | base32-encoded string |
| Scalar (long, xz saves) | `XZ:` prefix + xz+base32 |
| Arrayref / Hashref | YAML structure, values recursively encoded |
| Coderef | P7REF: `CREF:CHKSUM7:ADDR_B32` (see §5) |
| Filehandle | redirect-capable via protocol command (see §6) |

### Compression threshold

xz compression applied when compressed size < raw size (savings threshold).
Otherwise base32-only. The dump itself notes which encoding was used per value,
so the receiver can decode without guessing.

### Status

- `devmod.cmd.dump` exists as an embryo
- **Pending**: encoding logic, YAML serializer for nested structures, coderef
  P7REF emission, receiver-side reconstitution

---

## 5. Coderef Transfer via P7REFs

Coderefs cannot be serialized across process boundaries. The solution: emit a
P7REF that identifies the module by content checksum. The receiver resolves it
locally.

### Transfer format

```
CREF:LQKM3XP:4XYZAB
```

- `CREF` — type discriminator
- `LQKM3XP` — AMOS7 checksum of the module source
- `4XYZAB` — B32-encoded address hint (optional, for fast lookup)

### Resolution on receiver

1. Look up checksum in loaded `%code` entries
2. If found and checksum matches → wire local coderef
3. If not found → fetch module source (via `file.*` abstraction, §2)
4. If checksum mismatch → reject with error; log at level 0

### Security

Foreign code (checksum not in local `%code`) requires the 4-crossing consent
protocol before it may be loaded and wired. This applies even if the module is
available via network fetch.

---

## 6. STDIO as Pure Data Transport

The v7 stdout SHM log (already implemented, `/var/run/SHM/.v7/STDOUT`) decouples
zenka log output from STDIO. This frees STDIO as a clean data channel.

### Planned commands

- `redirect.stdio` — detach STDIO from terminal/log, hand it to a named handler
- Re-attach via Unix domain socket once SSH bootstrap completes
- Log output migrates to SHM; STDIO carries only structured protocol frames

### Why this matters for roaming zenki (§7)

SSH gives a STDIO pipe between nodes. If STDIO is a clean data channel, a zenka
can tunnel its full P7 protocol through it — no separate TCP connection needed
for the initial bootstrap.

---

## 7. Roaming Zenki

A zenka that can detach from its current node, traverse to a remote node via an
SSH/STDIO pipe, operate there, and return.

### Lifecycle

1. Zenka requests detach from v7 (`v7.roam.request`)
2. v7 grants, pauses heartbeat, preserves slot
3. Zenka serializes state via `devmod.cmd.dump` (§4)
4. Dump transmitted over SSH STDIO pipe to remote node
5. Remote node reconstitutes zenka from dump (coderefs resolved via P7REFs)
6. Zenka operates on remote node; findings accumulated
7. Zenka serializes updated state, returns via SSH STDIO pipe
8. Home node reconstitutes, re-attaches to v7
9. **4-crossing consent protocol** applied to all findings before integration

### 4-crossing consent (brief)

Before any data collected on a remote node influences the home node's state,
four independent verification crossings must pass. Prevents a compromised remote
from injecting malicious state. Full protocol in
`data/md/documentation/harmonic-transit-vision-architecture.md`.

### Status

- SSH pipe concept identified; STDIO decoupling (§6) is prerequisite
- v7 slot-preservation not yet designed
- **Pending**: all of the above

---

## 8. Empty Zenka Spawning (lightweight bootstrap)

A remote node that doesn't have a running Protocol-7 instance can receive a zenka
by spawning a minimal empty instance:

```bash
perl bin/Protocol-7 --empty-shell | ssh remote 'perl - --reconstitute'
```

Or the packing tool produces a self-contained Perl one-liner that carries the
`__DATA__` registry and reconstitution logic inline.

The empty instance:
- Loads only `base.*` bootstrap modules
- Accepts a serialized dump over STDIN
- Reconstitutes `%data` and `%code` from the dump
- Connects back to home node via Unix socket or TCP

### Status

- Conceptual; depends on §4 (serialization) and §6 (STDIO transport)

---

## 9. Dependency Graph → Packing Tool Pipeline

### Current state

- `data/md/documentation/module-dependency-graph.dot` / `.asc` — dep-graph exists
- Dep-graph is functional (used by other tooling)

### Planned pipeline

```
zenka profile
    → dep-graph traversal (transitive closure of modules)
    → packing tool (compress each module, write __DATA__ sections)
    → signed bin/Protocol-7 variant
    → deployable single-file zenka
```

The packing tool also embeds:
- `configuration/zenki/<name>/start` inline
- Any data files the zenka needs at boot (yaml configs, certs)
- Version metadata and AMOS7 checksums for the whole bundle

---

## Implementation Order (proposed)

| Step | Feature | Depends on |
|---|---|---|
| 1 | `devmod.cmd.dump` encoding (scalar/struct) | nothing |
| 2 | `file.*` `__DATA__` lookup step | nothing |
| 3 | Coderef P7REF emission + resolution | dump encoding |
| 4 | STDIO redirect commands | SHM log (done ✅) |
| 5 | Packing tool | dep-graph (done ✅) |
| 6 | Network fetch upgrade (httpsd/peer) | file.* abstraction |
| 7 | Roaming zenka lifecycle (v7 slot preserve) | STDIO transport, dump |
| 8 | 4-crossing consent integration | roaming lifecycle |
| 9 | Empty zenka bootstrap | all of the above |

---

---

## 10. External Source Adapter Plugins

The `file.*` abstraction layer (§2) is the natural integration point for adapters
that fetch content from external systems — GitHub releases, HuggingFace model repos,
PyPI, or arbitrary HTTP mirrors.

### Adapter interface

Each adapter is a module in the `file.fetch.*` namespace:

```
file.fetch.github        — GitHub releases API, tag-pinned downloads
file.fetch.huggingface   — HuggingFace Hub, model/dataset files
file.fetch.http          — generic HTTP/HTTPS with mirror fallback list
```

Adapters are called by the `file.*` abstraction when a path cannot be resolved
from `__DATA__`, in-memory cache, or disk. The adapter returns the content (or
writes to disk) and hands back to the normal cache path.

### Cryptographic security for known versions

For any external resource where the canonical checksum is known in advance, the
adapter verifies before accepting:

| Checksum type | Use case |
|---|---|
| BMW (AMOS7 BMW-256) | P7-native; primary authority for all blessed versions |
| AMOS7 (7-char) | compact identity token; collision-free via template system |
| SHA-256 | initial cross-check against upstream publisher manifests only |
| SHA-1 | legacy only — `download_impressive.pl` reference impl, not used in new adapters |

BMW is the authoritative checksum for all P7-blessed external resources — recorded
once on first acceptance and stored in the version registry. SHA-256 may be used
as a one-time cross-reference against upstream publisher manifests (HuggingFace
model cards, GitHub release notes) but is not stored or re-checked after the BMW
is recorded. New adapters do not use SHA at all once BMW is available.

### Version registry entry (proposed format)

```yaml
package: impressive
adapter: http
version: 0.11.1
urls:
  - http://sourceforge.net/projects/impressive/files/Impressive/0.11.1/Impressive-0.11.1.tar.gz/download
  - http://mirror.nailara.net/impressive/Impressive-0.11.1.tar.gz
checksums:
  archive:
    size: 195743
    sha1: 0f47caec3abd0398814550cabfb78ecca8b5eb85   # legacy ref only
    bmw: <recorded on first blessed install>
  extracted:
    path: Impressive-0.11.1/impressive.py
    size: 244877
    sha1: b35f9bdc5c702cb8865bfc618fc0fd497566af88   # legacy ref only
    bmw: <recorded on first blessed install>
signed_by: <AMOS7 footer on this file>
```

The registry file itself is signed by the P7 signing system — so the entire chain
from "known good version" declaration to download verification is covered by the
same integrity infrastructure as source modules.

### Existing reference implementation

`bin/install-scripts/download_impressive.pl` — written ~a decade ago for automated
kiosk appliance setup. Already implements the core pattern:
- version-pinned download
- size check before SHA1 verify (fast pre-filter)
- SHA1 verify on archive AND on extracted file (two-layer)
- multiple fallback mirrors
- clean rollback on any failure (unlink archive, unlink partial extract, rmdir)
- idempotent: exits clean if already installed and checksum matches

The adapter plugin generalizes this pattern:
- registry-driven (no hardcoded versions)
- BMW as primary checksum (SHA as secondary)
- result goes into `file.*` in-memory cache (no re-download on repeated access)
- failure modes surfaced via P7 protocol reply rather than `die`

### Security model

- **Known version, recorded BMW**: full trust — download, verify BMW, cache, serve
- **Known version, no BMW yet**: download, verify SHA-256 against upstream manifest,
  record BMW on first acceptance (pending user confirmation or 4-crossing consent
  if the resource will be executed as code)
- **Unknown version**: fetch only with explicit request; prompt for consent before
  recording checksum; never auto-execute
- **Mismatch**: hard reject, log at level 0, never cache, never serve

---

## Related Documents

- `data/md/documentation/harmonic-transit-vision-architecture.md` — CCW matrix,
  4-crossing consent, DTM 6×7×13 topology
- `data/md/documentation/deferred-compilation-design.md` — deferred stub mechanism
- `data/md/documentation/module-dependency-graph.asc` — current dep-graph
- `data/yaml/coding-tasks/modules-subdir-pm-extraction.yaml` — .pm cleanup

#,,..,.,.,,.,,,,.,.,,,,..,,..,.,,,,,.,.,.,,.,,..,,...,...,...,,,,,.,,,,..,..,,
#QUPPQUS6VBRNGKDYWI3HXUFRKSWAWHJHQV3S4MO74SDV57VFJWHOF4XYIBRGZXWXCD7HCAXZ2ZNIK
#\\\|O5IITRIYVOUTY2VULSRP656JOMNVKDXEX6YMGSE34MNSF3AKWVL \ / AMOS7 \ YOURUM ::
#\[7]KUQY7TDFX4CX3EHKWBSO3O32BIPW3OKPBGOKV7TY2QT45OD5IEAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
