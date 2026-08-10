---
name: checksum-addressing-implementation-survey
description: "ground-truth survey (2026-08-10) of how much of the checksum-addressing/P7REF vision is real code vs design-only, commissioned before designing users-zenka identity"
metadata:
  type: project
---

**2026-08-10, Explore-agent survey, commissioned before deciding users-zenka's
(5PN) key-authority model** — should it build on crypt.C25519 or on the
checksum-addressing vision ([[topic-checksum-addressing]],
[[topic-addressing-trinity]])? Answer below.

## bottom line

Roughly a third of the checksum-addressing vision is real: AMOS/BMW checksum
generation, a working (but **triple-fragmented**) P7REF string format, a
genuinely geometric BMW384 coordinate/routing engine, and at least two real
call sites combining name+checksum+timestamp as the "addressing trinity"
describes. The rest — a canonical TYPE registry for entity kinds,
network-wide P7REF resolution, persistent orbital discovery, and the
8-cube/2x2x2/void spatial geometry — is design-doc-only, zero code.

**Practical takeaway for any new addressable entity (users zenka included):**
build identity on `crypt.C25519` as root of trust; treat P7REF as a
derived/display layer on top, the way `base.p7ref.self` already does. Do NOT
wait for or invent a canonical TYPE registry — none exists, every existing
caller invents its own type vocabulary inline, so registering a new TYPE
(e.g. `USER`) is unconstrained but also gets no cross-checking for free.

## per-topic findings

- **P7REF format**: THREE incompatible schemes coexist, not one —
  `base.p7refs.gen_template_chksum` (Perl-ref-address encoding, unrelated to
  entity identity), `base.p7ref.self` (`TYPE:CHKSUM7:ADDR_B32`, TYPE ∈ ZENKA/
  CUBE/V7/CODE/MODEL/VISION/LOG/HTTPD, ADDR_B32 derived from the zenka's
  **C25519 pubkey** — this is the identity-relevant one, already wired into
  `base.init_code`'s `@INDEXCUBE[0]`), and `plugin.storage.p7ref.*` (a
  separate `p7://type:address@authority` URI scheme for storage resources).
  A new design saying "use P7REF" must say which.
- **AMOS/BMW/ELF/JHA checksums**: real, mature, used for actual addressing
  (not just file-integrity) at `index.cmd.write`,
  `plugin.storage.checksum.cluster.lookup`, `route.bmw384.index.register`.
- **BMW384 as routing geometry**: real — `AMOS7::CHKSUM::BMW384.pm` extracts
  a genuine 24-bit color + 360-bit angle from the digest, and
  `route.bmw384.route.*` does real Hamming-distance-threshold routing
  decisions, no graph traversal. BUT scoped entirely to **local code-module
  coordinates** for a CLI find-route command and HTTP visualization
  endpoints (`httpd.route.handler.iris-route*`) — no wire/network dispatch
  found anywhere in `route.bmw384.*`. Not yet a network routing mechanism.
- **base32 ntime + trinity shape**: real (`base.ntime.*`), and genuinely
  combined with checksum+name twice (`index.cmd.write`,
  `base.indexcube.push/pop`, the latter AMOS-signed over
  `p7ref:timestamp:depth`) — but the real field shape is
  `p7ref/timestamp/depth/signature`, not the memory's literal
  `name/checksum/timestamp/latest/current`.
- **discover.orbital.***: confirms
  [[project-zenka-cryptographic-identity-survey]]'s finding — memory-only,
  no persistence, keyed by BMW L13 of pubkey, but DOES push live to STRM
  listeners. **Correction**: `orbital.build_summary` / `cmd.orbital-sync`
  live under `graphics-matrix.*`, NOT `discover.*` — a different subsystem
  (GUI/grid visualization), not distributed discovery. Also:
  `nameserv.handler.p7ref_lookup` is a misleadingly-named plain DNS TXT/SRV
  shim, not P7REF checksum resolution — don't be fooled by the name.
- **TYPE registry**: does not exist. Every caller (`base.p7ref.self`,
  `space.register.node`, `plugin.storage.p7ref.*`,
  `base.p7refs.gen_template_chksum`) has its own disjoint type vocabulary.
  `CGROUP` as a literal token appears nowhere in `modules/`.
- **Cubic/8-cube/void geometry**: 100% design-doc
  (`VISUAL-ELEMENT-DEDUP-HOLOGRAPHIC-CORE.md`, `GRID-HARDNODE-CURSOR-MODEL.md`,
  `ROUTING-CRYSTAL-HARMONIC-INFERENCE.md`, etc.) — zero runtime code.
  `index.cube.*` (P7IC mmap format) and `base.indexcube.*` (a linear signed
  call-stack) are false-friend names, unrelated to 3D spatial geometry.

## how to apply

When designing users-zenka (5PN) or any future first-class-addressable
entity: root identity in crypt.C25519, derive a P7REF via `base.p7ref.self`'s
shape (not the other two) if a display/log-friendly short address is wanted,
and don't block on or design against the checksum-addressing vision's
unimplemented pieces (TYPE registry, network P7REF resolution, BMW384 as
cross-node routing, cubic geometry) — they're real future direction but zero
current infrastructure to integrate with.

[[topic-checksum-addressing]]
[[topic-addressing-trinity]]
[[project-zenka-cryptographic-identity-survey]]
[[users-zenka-yaml]]

#,,.,,..,,..,,,.,,..,,.,,,..,,.,,,,..,,,.,,..,..,,...,.,.,,,.,..,,.,.,,,.,...,
#YPRUZVDUJBDCD7MMPNH3J5LVB2ESD5XJQV7ZH3CUGFMXEOKBKIBZFASCMWJZLH35POJDLLUF6MV3Q
#\\\|MHUCJESSDEUKGOVWWR4O5G5GMYGSQU7ZEL6HCKXU6HKC3TAFEQM \ / AMOS7 \ YOURUM ::
#\[7]I5AD446S5M4BQIQ7HSF2NVAI7AA6B45D7PWSQHQXHRMU2PNR5IAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
