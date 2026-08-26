# network build system

## vision

the protocol-7 network becomes its own build system. artifacts flow as data,
toolchains are capabilities routed on demand, and no destination node needs a
local build environment. supply chain integrity is enforced by consensus and
LLM audit before any build is permitted.

---

## layer 1 : build.zenka [ entry point ]

the introduction feature — wraps what is currently done by hand:

- **source registry** : git URLs, local paths, branches/tags to build from
- **recipe registry** : build scripts already exist as templates (e.g.
  `bin/build-scripts/llama-cpp/build-llama-server-cuda-flashattn.sh`); the
  zenka treats these as first-class named recipes
- **docker backend** : runs builds in isolated containers; extracts artifacts
  to the right destination; updates symlinks
- **post-build cleanup** : prunes docker build cache, removes superseded
  binaries, reports artifact hashes
- **own-fork awareness** : for forks (e.g. openbox, ik_llama.cpp), tracks
  which patches are applied, detects when upstream moves past a patch
  (clean-apply vs conflict), flags when a rebuild is needed after a
  dependency update

immediate value: reproducible builds, no manual cache cleanup, patch drift
detection — all before the network distribution layer exists.

---

## layer 2 : build graph

once multiple recipes exist, dependency ordering becomes relevant:

- openbox depends on libobrender which depends on pango/cairo/etc.
- the zenka knows the build order, rebuilds the chain when a base lib updates
- dry-run mode: run the install script in a minimal container first as a
  sanity check before touching the live system

the build graph is the foundation for the distribution layer — you cannot
route a build job to a remote node without knowing what that node needs to
have available first.

---

## layer 3 : network build distribution

the network routes build jobs to nodes with the required toolchain capability:

- a destination node requests an artifact (e.g. `llama-server-cuda-fa`)
- the network finds a capable build node (has docker, cuda toolkit, etc.)
- the build runs remotely; the artifact flows back as signed data
- the destination node writes files — no local toolchain required

local systems stay minimal. the WSL2 node does not need docker, cmake, or
gcc installed — those are capabilities somewhere on the network. the DKMS /
sqv / keyring class of problems disappears entirely at this layer.

---

## layer 4 : 5/7 consensus verification

independent build nodes produce the same artifact and compare hashes:

- **quorum threshold** : 5 of 7 nodes must produce matching artifact hashes
- **compromised node detection** : a node producing a different hash is
  immediately visible as the odd one out — no silent corruption
- **non-owned build zenki** : build contributions from network nodes outside
  direct control are safe; the consensus result is the trust, not any
  individual node's reputation
- **supply chain hardness** : injecting a backdoor requires corrupting enough
  nodes to reach quorum simultaneously — structurally infeasible

the AMOS7 checksum chain attaches full provenance to each artifact: source
commit, toolchain version, build flags, node IDs that participated in quorum.
everything is verifiable after the fact on any node independently.

---

## layer 5 : supply chain intake pipeline

new upstream versions enter the network through a staged gate:

```
upstream version arrives
  → LLM audit zenka : diff review
      - what changed functionally
      - new outbound connections to unexpected hosts
      - rewritten functions with suspicious patterns (timing side-channels etc.)
      - new binary blobs or unexpected encoded data
      - build system changes that could inject at compile time
  → static analysis pass
  → if passes : build job opens to consensus network
  → 5/7 quorum build
  → artifact enters network cache with full provenance chain
```

failed audits do not just block — they become corpus entries:
- what version, what diff, what was flagged, what was decided
- the audit zenka calibrates over time to the project's actual risk tolerance
  rather than generic rules
- the corpus is itself a training signal for future audits of the same
  dependency

audit results carry a checksum and enter the network like any other data:
permanent record, forensics and compliance as a structural side effect.

---

## layer 6 : end state

- **minimal local OS** : no full dev environment required anywhere
- **ondemand toolchain** : capability routing replaces local installation
- **no package manager ceremony** : the WSL2/DKMS/sqv class of problems
  simply does not exist — the network handles it above the OS layer
- **own servers or network nodes** : build capacity scales naturally; a new
  node with a toolchain joins the network and immediately becomes available
  as a build target
- **living dependency cache** : the network tracks and caches its own OS and
  dependency sources; importing a new version is a workflow, not a manual
  operation

---

## implementation path

each layer adds immediate value independently:

| layer | entry point | immediate value |
|-------|-------------|-----------------|
| 1 | build.zenka + docker backend | reproducible builds, patch drift detection |
| 2 | build graph | dependency ordering, safe chain rebuilds |
| 3 | network distribution | toolchain-free destination nodes |
| 4 | consensus verification | supply chain integrity, compromised node detection |
| 5 | LLM audit intake | upstream diff review, calibrating audit corpus |
| 6 | full network OS cache | minimal local systems, ondemand capability |

the large dependency chain that previously blocked this is getting short —
LLM zenki are live, the job pipeline works, consensus voting exists in
`llm.service.consensus_vote`. layer 1 is buildable now.

#,,.,,,,.,.,,,,,.,.,.,..,,.,.,,,.,,,,,,..,.,.,..,,...,...,,.,,.,,,..,,,,,,.,,,
#M5JRU3E3U7LTF4ANWKN2RTQAF63OLMQRGCCZZH5IPVBJ64RUHRPWCUBCD2INHWYXO33V6LDSYOFX4
#\\\|7QVXBWFN7GPRJ4JQ4ZHI47SXPLFIEZO2OXROCMIQCJVRTCZNNQZ \ / AMOS7 \ YOURUM ::
#\[7]UOTWXUWPWHEMM4XWGCEHZ3WBFQJEQCCAVBUMZ5O23HCFOHIGBCAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
