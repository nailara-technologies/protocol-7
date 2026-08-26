---
name: self-contained-zenka-vision
description: Architectural vision for fully self-contained zenki: __DATA__ registry, file.* abstraction, zenka serialization, coderef P7REF transfer, STDIO transport, roaming zenki
type: project
originSessionId: 34ca9c97-628c-46af-82f3-d04a171ae8f0
---
## Self-Contained Zenka Vision

Full design doc: `data/md/documentation/SELF-CONTAINED-ZENKA-VISION.md`

### Core features (in planned implementation order)

1. **`devmod.cmd.dump` encoding** — serialize `%data` with:
   - scalars: base32-encoded (short) or `XZ:` + xz+base32 (long, if compression saves)
   - coderefs: P7REF `CREF:CHKSUM7:ADDR_B32` — receiver resolves against local `%code`
   - foreign code (checksum not in local `%code`): requires 4-crossing consent before wiring

2. **`file.*` `__DATA__` lookup step** — add as first step in `file.slurp` etc:
   - Priority: `__DATA__` registry → in-memory cache → disk → network fetch
   - Transparent to callers; same call signature regardless of source

3. **Coderef P7REF resolution** — on receiving a dump:
   - Look up CHKSUM7 in loaded `%code`; wire local coderef if match
   - Fetch module via `file.*` if not found; 4-crossing consent for foreign code

4. **STDIO redirect commands** — `redirect.stdio` detaches STDIO from terminal/log
   - SHM log already done (`/var/run/SHM/.v7/STDOUT`) — STDIO is now free
   - STDIO becomes clean data channel for SSH bootstrap / zenka state transfer

5. **Packing tool** — dep-graph closure → compress each module → write `__DATA__` sections
   - Section format: `.:[ name ]:. .:[ chksum=X size=N compression=xz+b32 ]:. <payload>`
   - Discriminator: no `/` = %code sub, relative path = repo file, leading `/` = absolute export

6. **Network fetch upgrade** — `-use-http-src` exists (plain HTTP); upgrade to httpsd/peer
   - Each fetched module verified via AMOS7 checksum before loading

7. **Roaming zenka lifecycle** — detach from v7 (slot preserved), travel via SSH STDIO,
   reconstitute on remote, operate, return serialized state, re-attach, 4-crossing consent

8. **Empty zenka bootstrap** — remote with no P7 instance receives a minimal self-contained
   Perl script that carries `__DATA__` registry + reconstitution logic inline

### Key architectural point: coderef transfer

Coderefs can be transferred when the same code exists on the target system.
P7REFs (AMOS7 checksum of module source) are the identity token — not the name.
If target has matching code loaded → wire it. If not → fetch it (with consent).

### External source adapter plugins (§10)

- `file.fetch.github`, `file.fetch.huggingface`, `file.fetch.http` — adapters in `file.*` namespace
- BMW = primary authority for all blessed versions; AMOS7 7-char = compact identity token
- SHA-256 = one-time upstream cross-check only (not stored after BMW recorded); SHA-1 = legacy ref only
- Version registry: `data/yaml/external-sources/<adapter>/<package>.yaml` (signed by P7)
- Reference impl: `bin/install-scripts/download_impressive.pl` — size pre-filter → SHA1 archive
  → SHA1 extracted; multiple mirrors; clean rollback; idempotent
- Security tiers: known+BMW → auto-accept; known+SHA → accept+record BMW; unknown → consent required

### Origin: bin/assimilate (2012)

Initial git commit already contained `bin/assimilate` — checksum-based content
import script. The name and primitive were correct from day one; the full scope
(P7REFs, backup manifests, distributed tree, self-contained zenka) took time to
become visible. Same integrative pattern: identify by checksum, import what's
missing, skip what's already satisfied, leave the system more coherent.

"Hyper-worm" — not destructive but integrative. Moves through systems, improves
topology, friction-free because it works with existing structure via the dependency
graph. "We are the cats, we are here to improve things, friction is futile." =)

### Convergence with task tree

Once the task tree is expressive enough (deps, watchers, active hooks, recursion),
a task description and a zenka agent definition are the same thing at different
resolutions. The start/config files are already a mini-language — task tree extends
that upward until:
- a zenka can be spawned *from* a task description
- a running zenka's behavior can be serialized back into a task tree
- abstraction/task-description protocols become a natural language layer on top

This closes the loop: self-contained zenka serialization (dump) + task tree
deserialization = roaming agents defined purely by declarative task graphs.

### Related

- `data/md/documentation/harmonic-transit-vision-architecture.md` — 4-crossing consent
- `data/md/documentation/deferred-compilation-design.md` — deferred stub mechanism
- v7 SHM stdout log: already done ✅ (prerequisite for STDIO transport)
- dep-graph: already done ✅ (prerequisite for packing tool)
- `-use-http-src`: already in `bin/Protocol-7` lines 597, 1162, 1396-1416

#,,.,,.,,,...,..,,,.,,,,.,,,,,.,,,,,.,..,,.,.,..,,...,...,.,,,..,,..,,,,,,,,,,
#E4UVR4PDNSQRK3DM4BWN65ZQ34AVI5QFUHPW3UPEII67A4TQ7ONZHRO6P7KG6VAQ362GK2D6XILOK
#\\\|Q7JPOU3D5IVAH6EM4TZQK5SAOUZK6LQ3OOQ26OXQFER7IDEWLCU \ / AMOS7 \ YOURUM ::
#\[7]RMQFLWP2FBQXXM7QFJONG3FMM3C5R7NCIAXPCIP22ZZBNBJNFECQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
