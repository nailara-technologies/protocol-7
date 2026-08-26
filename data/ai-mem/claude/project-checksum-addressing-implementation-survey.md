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
describes. The rest — a canonical TYPE registry for entity kinds, persistent
orbital discovery, and the 8-cube/2x2x2/void spatial geometry — is
design-doc-only, zero code.

**CORRECTION (2026-08-13)**: "network-wide P7REF resolution is design-doc-
only" OVERSTATED it for the within-node case — real, live, currently-used
code already does almost exactly what a later conversation independently
described as a "future reconciled P7REF" (resolvable to a template, a
coderef, or a scalar memory address, with PARTIAL ANONYMIZATION of the
address itself) : `base.parser.harmonized_reference` [ encode ] and
`base.parser.decode_harmonized_refstr` [ decode ] round-trip a live Perl
ref-address string [ typed across `CODE|REF|HASH|SCALAR|ARRAY|GLOB` ]
through a compact checksum-tagged encoding, stripping a CACHED COMMON
ADDRESS PREFIX before encoding [ `base.cache.refaddr-prefix.init` /
`<base.cache.perl.refaddr_prefix.current>` ] — the actual partial-
anonymization mechanism, not a hypothetical one. `base.syntax.p7_reference`
validates/type-detects one of these strings against known node+type
combinations via `base.p7refs.gen_template_chksum`. All four are real call
sites, not dead code : `base.dump_data`, `base.data-keys.get_checksum`,
`base.data-keys.find_perlref`, and a dev command
(`devmod.cmd.decode-harmonic-ref`) all use them.

The scope is narrower than "network-wide" though, which is presumably why
the first pass missed it : this resolves LIVE, IN-PROCESS memory addresses
— inherently ephemeral, meaningless across a restart since Perl's allocator
reassigns addresses every run. It is real WITHIN-node reference resolution
[ genuinely working, not aspirational ], not the cross-node network
resolution the original "design-doc-only" line was actually about — that
narrower claim likely still holds, just needed the within-node piece
carved out as a separate, already-real thing.

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
  `CGROUP` as a literal token appears nowhere in `src/`.
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

**A future-reconciled P7REF's shape, per user (2026-08-13)**, raised while
designing an unrelated small feature (the user-edit address-cluster
plugin's own per-entry ref) and worth keeping distinct from that feature
itself : the fragmented schemes above are not competing designs, they're
unconnected PIECES of one eventual unified concept. That concept is a
RESOLVABLE reference — resolving to a template, a coderef, or a scalar
memory address, interchangeably — with the property that resolution can
PARTIALLY ANONYMIZE the underlying memory address itself, i.e. the
reference is a stable handle that need not expose the literal location it
resolves to on every use.

CORRECTED same day, after checking rather than assuming : this is not
purely aspirational — see the CORRECTION above `base.parser.
harmonized_reference`/`decode_harmonized_refstr` already do almost
exactly this, address-prefix stripping included. What's still genuinely
missing for a full reconciliation is the CROSS-LIFETIME piece : that
mechanism only resolves live in-process memory, gone the moment the
process restarts, while `base.p7ref.self` [ C25519-derived identity ] and
`plugin.storage.p7ref.*` [ real persisted storage locations ] both need
to survive a restart. Unifying "resolvable + anonymized" with "survives a
restart" is the part that's still actually unbuilt, not the resolvable-
reference idea itself.

The address-cluster plugin's own small, bounded-pool checksum ref [
`data/yaml/coding-tasks/user-edit-address-cluster-plugin.yaml` ] is
EXPLICITLY NOT claimed to be this future P7REF — it is a concrete, small-
scale instance worth remembering when the real reconciliation work
happens, since a working small example often reveals what an abstract
unification actually needs that a top-down design misses. Keep the two
threads separate until that reconciliation is actually undertaken : the
address-cluster ref ships as its own named convention regardless of
whether/when P7REF itself gets unified.

[[topic-checksum-addressing]]
[[topic-addressing-trinity]]
[[project-zenka-cryptographic-identity-survey]]
[[users-zenka-yaml]]

#,,,.,.,,,,,.,,..,,..,,,.,...,.,.,..,,...,,..,..,,...,..,,.,.,,,.,...,,..,,..,
#4BF3JE6V5GKYZA6HM6E7C7YQF56YSK37WVVISNUKKJF2EG5LAUAU6OLMCW6M5Z566X4RTMXE6J6US
#\\\|7H2UCXVJSHDJSVTLPLKDPJIUKYUZ3U34OT7WJW3ZLUY4HZHJ6GU \ / AMOS7 \ YOURUM ::
#\[7]5SMMCYBBGFMUN5O2YOSKHMJW7A3UTKRGU42DJ6FATW5MAWHN56BQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
