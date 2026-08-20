# zenka identity and trust topology — umbrella / open questions

## origin

surfaced 2026-07-18 while fixing a 401 on jobsite's `/jobs-sync` push
(httpd recently started enforcing `plugin.web.auth` on that route —
see commit `9d6486427`). the obvious fix — mint jobsite a session token
via cube route-send — was caught before implementation: jobsite and
httpd/web are only guaranteed to share a cube on today's single-host
setup, and the whole reason `/jobs-sync` is http instead of a native
zenka route is to support jobsite running on a separate host with no p7
link back. a same-cube-only fix would need redoing later.

**`auth.required` on `/jobs-sync` is disabled again for now**
(`cfg/zenki/httpd/routes`) — this is safe, jobsite currently
only runs local, and there's a real second host available to test the
actual split-location case once a mechanism exists.

this document is not a spec. it's a place to keep the open questions
and the map of what already exists, so small components can be derived
from it one at a time, each referenced back in as they land, until
there's enough to build the jobs-sync key exchange from and integrate.
see [[feedback-small-generic-components-before-wiring]] (ai memory) for
why this is deliberately not being solved in one pass.

---

## what already exists (grounded, re-verified 2026-07-18)

### cryptographic primitives
- `crypt.C25519.*` — real Ed25519 sign/verify, plus a genuine
  key-signs-key web-of-trust primitive (`sign_keys` /
  `verify_key_signature` / `create_signature_request`).
- `keys` zenka (console-only) — already supports **virtual / seed-phrase
  keys** (`create-stub-key`, `gen-file-seed-key`, `gen-pwd-keyfile`,
  `get-sp-pub-key`): a key that's rederived from a passphrase on load
  rather than decrypted from an at-rest file. no new mechanism needed
  for "user key controlled by a passphrase, never on disk" — it's an
  existing loading mode.
- storage today, per `v7.keys list`: per-Unix-user keys
  (`~/.n/user-keys/<user>.*`) plus a `global-root` + `protocol-7.base`
  pair under a locked-down system `protocol-7` user (`no-r.perms`) —
  the de-facto common trust anchor. no per-zenka identity concept
  exists yet (confirmed by exhaustive grep, see
  `project-zenka-cryptographic-identity-survey.md`, ai memory).
- `plugin.auth.auth-keypair.*` — working TOFU pinning, but scoped to
  `p-7-r` protocol-7-link sessions, keyed by username not zenka, gated
  behind a manual admin symlink into `authorized/<zenka>/`.
- `discover` — verifies multicast presence packets carry a signature
  from an already-known/trusted key (chain verification), all rooted
  in the same per-user base key.
- **known inconsistency, unresolved**: TOFU pin filenames
  (`remote.<host>_<port>.public` written by `crypt.C25519.store_remote_key`
  vs `remote-host.<host>_<port>.public` used by `keys.console.list`) —
  confirmed real files exist under the `remote-host.*` name on disk
  (`v7.keys list` output, 2026-07-18) so a writer for that pattern
  exists somewhere, just not found in `modules/` yet. resolve before
  building on either convention.

### namespace / derivation models
- `data/md/design/KEY-TREE-AUTHORITY-FIELD.md` — dotted module namespace
  as an HKDF-style C25519 derivation tree (`derive(parent,label)`).
  design proposal, not implemented. intra-system authority only, no
  host/network boundary concept.
- `data/md/design/CHECKSUM-PARENTING-NAMESPACE-TREES.md` — auto-parenting
  algebra: `C0 = chksum(C1:name)`, gives whole-tree collision protection
  without storing explicit parent/child edges. a candidate primitive for
  however grouping/nesting ends up represented.
- `data/md/design/CODE-NAMESPACE-AND-SIGNING-INFRASTRUCTURE.md` — three-
  category dot-notation namespace (code/config/data) with a signing
  pipeline as a policy-enforcement gate; described as extending working
  infrastructure, not a blank slate. directly relevant to "source code
  version is its own root, code signed" (see open question below) —
  needs a read-through against that framing specifically, not yet done.

### session / DAG models
- `data/md/design/BRANCH-OPEN-CAPACITY-SESSION-DAG.md` — branch =
  region of free continuation capacity; open/closed/field states;
  large (678 lines), not yet read against the "everything may be a
  session, some eternal until a parent reference clears" framing raised
  in this doc — likely load-bearing, needs a dedicated pass.
- `data/md/design/SESSION-DESIGN-TREE-OVERVIEW.md` — dispatch/parent doc
  for an earlier design-doc batch; a map of docs, not itself a mechanism.

### credential storage
- `cred-mesh` — local secret storage/rotation broker (register declares
  a slot, resolve decrypts+formats for use). no cross-host concept.
  jobsite/weather already have `cred-mesh.register`/`.resolve` access
  grants with zero real call sites — scaffolding ahead of use.
- **naming collision, unresolved**: `credentials.*` (needs-testing
  credentials zenka, cube-local OAuth-like broker) vs `cred-mesh.*`
  (renamed specifically to avoid colliding with it, per
  `data/tasks/completed/credential-fabric.md`). don't add a third
  parallel credential namespace without reconciling this first.

### http-facing sessions
- `plugin.web.auth.*` — working session-cookie/bearer-token mechanism
  for httpd, 24h TTL, never auto-extended on activity. this is what
  gated `/jobs-sync` and is now disabled for that route again.
- `data/tasks/web-sessions-distributed.md` — the one doc that touches
  http-facing cross-node sessions, but sidesteps the bootstrap problem
  with a pre-shared admin-installed secret file
  (`/etc/protocol-7/web/session.key`, "deployed via admin, not synced")
  — same shim shape as what was almost implemented here today, just
  written down earlier instead of coded.
- `data/md/design/SIGNED-COMMAND-INTERFACE.md` — most reusable shape
  found so far: generate-on-first-use identity + TOFU pin + an explicit
  **signed rotation ceremony** (old key signs the handoff to the new
  key). scoped to p7's internal command dispatch, not http — the
  rotation-ceremony piece specifically hasn't been discussed elsewhere
  in this thread yet and deserves attention.

### protocol version as a practical (not authority) logical root
- `nodes.cmd.update-protocol-elf` (`modules/nodes.cmd.update-protocol-elf`)
  computes a content-derived checksum (`chk-sum.elf.get-true` over a
  defined set of protocol-relevant source paths from
  `protocol.protocol-7.protocol-version-path-set-up`), written as
  `PROTOCOL-7-VERSION[...]` — a functional fingerprint of the protocol
  code itself, distinct from the human-facing release version (a new
  release doesn't necessarily change it; a local modification does).
- **this is a topological root, not a trust/authority one**: a network
  with one global name still fragments into logical islands/
  sub-identities wherever protocol versions diverge internally, even
  when seamlessly bridged. the settled plan for that bridging is
  **protocol translation plugins**, providing back-/forward-
  compatibility at the boundaries of actual protocol changes (renamed
  commands, changed parameter apis for widely-used functions) — the
  checksum is a candidate value such a plugin boundary might key off,
  not a proposal in itself. distinct axis from the authority-root
  questions (1, 3, 5) above: don't conflate "who is trusted" with
  "which protocol dialect this zone actually speaks."

### discovery
- `nameserv` — real, working authoritative DNS server, including
  genuine TXT/SRV serving for `_protocol7._tcp.*` queries
  (`nameserv.handler.p7ref_lookup`). the specific "publish a zenka's
  http endpoint + pubkey for cross-network discovery" behavior
  (`data/yaml/coding-tasks/nameserv-zenka.yaml`) is a design doc, not
  built. zero-conf bootstrap candidate, explicitly later-phase.

---

## open questions

each of these is a place a small, independently-complete component
could be derived from — not all need answering before any one of them
gets built.

1. **network identity vs. user identity.** two co-existing perspectives,
   deliberately not reduced to one: (a) single root, user is a member
   with ability to modify its own position/group memberships; (b) every
   key is its own root, roots project onto a shared field of agreed
   overlap — that overlap *is* the network's active interaction zone.
   both hold. the structurally interesting part is the overlap/horizon
   between zones, not either model alone.

   note — a practical (not authority) logical root sits alongside this:
   a network can carry one global name while running diverging protocol
   versions internally; those versions already make it fragment into
   logical islands/sub-identities, even where protocol translation
   plugins bridge them seamlessly (see the protocol-version-compatibility
   note below). not a trust/authority boundary — a topological one. one
   global name can still be logically plural underneath.

2. **is everything a session?** including a network identity itself —
   a session or tree/group of sessions, some open-ended/eternal until a
   parent reference is cleared. what clears a parent reference, and
   what happens when it does (gc vs. left dangling) — not yet decided,
   possibly policy-dependent rather than a hard rule. check against
   `BRANCH-OPEN-CAPACITY-SESSION-DAG.md` before inventing a new session
   model.

3. **free/parallel grouping vs. the namespace-derivation tree.** these
   are two different relations that coexist: a key derived under
   `jobsite.sync.*` can still be granted membership in a group with no
   relation to its derivation lineage. free, nested, non-exclusive
   grouping is called out as *the* structural component that lets later
   complexity emerge non-linearly — don't collapse it into the
   derivation tree for convenience.

4. **capability model.** declared registry (namespace-pattern → allowed
   operations, checked at delegation time) vs. emergent from possession
   (holding a validly delegated/grouped key under a namespace prefix
   *is* the capability, nothing separate to keep in sync). undecided;
   may also turn out to be another "both, perspective-dependent" case
   like (1).

5. **delegation mechanism.** confirmed nowhere in the codebase today
   (exhaustive grep, `project-zenka-cryptographic-identity-survey.md`).
   candidate: reuse `crypt.C25519.sign_keys` as-is for the
   derivation/vouching edge, plus a new scoped/attenuable authority
   token for delegation proper — per that survey's synthesis, no new
   crypto primitive needed, just new structure on existing
   `sign_data`/`verify_sign`.

6. **transport-agnostic handshake.** `SIGNED-COMMAND-INTERFACE.md`'s
   pin + signed-rotation-ceremony shape is the closest existing TOFU
   mechanism to what jobs-sync needs, but it's scoped to p7's internal
   command dispatch. generalizing it to run the same decision logic
   over bare http (not just `p-7-r`) is a candidate component on its
   own, independent of the identity-root questions above.

7. **discovery/bootstrap.** nameserv TXT/SRV extended to publish a
   zenka's endpoint + pubkey, so a remote zenka can find and
   provisionally validate a peer without a hardcoded config entry.
   later-phase; not a blocker for 1–6.

8. **naming collisions to resolve before building anything new**:
   `credentials.*` vs `cred-mesh.*` (flagged by cred-mesh's own design
   doc, unresolved), `remote.*` vs `remote-host.*` TOFU pin filenames
   (flagged above, unresolved).

---

## candidate small components (not started, order not fixed)

these are the shapes that fell out of decomposing the practical
jobs-sync problem — kept as candidates pending the open questions
above, not commitments:

- **identity** — normalize per-zenka/per-host key ownership & chaining
  on top of existing `crypt.C25519` key-signs-key, informed by
  questions 1, 3, 5. **spun off 2026-07-30**: see
  `ZENKA-IDENTITY-COMPONENT.md` — identity and signature-tree treated as
  one component (identity IS the edge set), built entirely on existing
  primitives (`sign_keys`, `create_signature_request`,
  `store_remote_key`, the `SIGNED-COMMAND-INTERFACE.md` rotation
  ceremony), no new crypto. narrows questions 1/3/5 for this component's
  scope without closing them generally; four remaining decisions
  (key-naming/storage location, succession-edge marking, group-key
  custody, lineage-vs-membership in-band distinguishability) left there
  for a human call.
- **handshake/trust establishment, transport-agnostic** — generalize
  TOFU + chain-signature verification to run over http, informed by
  questions 6, 8.
- **credential storage/use downstream of a handshake** — cred-mesh,
  largely as-is; jobsite/weather's access grants are already waiting
  for this. informed by question 8.
- **discovery/bootstrap** — nameserv TXT/SRV extension. informed by
  question 7. explicitly later-phase.

## how to use this document

when an open question above gets enough of an answer to act on, spin
off a focused design or task doc for just that piece, link it back into
the relevant question and/or the "already exists" section, and narrow
the question here rather than closing this document. once enough
components exist to actually build the jobs-sync key exchange, derive
it from them, integrate, and re-enable `auth.required` on `/jobs-sync`
against the new mechanism — then update this doc's status below.

## status

**2026-07-18**: open questions stage, no components started. jobs-sync
auth disabled, sync works. next action not yet chosen.

**2026-07-30**: first candidate component spun off — see `identity` above
and `ZENKA-IDENTITY-COMPONENT.md`. also resolved in passing: the
`remote-host.*` TOFU-pin-filename mystery (question 8) is confirmed to
have no missing writer — those files were manually created test
artifacts, not evidence of an unlocated writer function; see the new
doc's "naming collisions" section. `credentials.*` vs `cred-mesh.*`
remains unresolved. remaining candidates (handshake, credential storage,
discovery) not started.

## related

- `data/ai-mem/claude/project-cross-host-trust-bootstrap-gap.md` (ai
  memory) — the research pass this document was assembled from.
- `data/ai-mem/claude/topic-multidimensional-identity-session-topology.md`
  (ai memory) — the vision synthesis behind open questions 1–4.
- `data/ai-mem/claude/project-zenka-cryptographic-identity-survey.md`
  (ai memory) — ground-truth crypto/identity inventory this builds on.

#,,,,,,,.,..,,.,.,,,,,,,.,...,.,,,,,.,,,.,.,,,..,,...,...,...,,,.,,,.,,,,,...,
#R47JQQIS36SEWDAOKC5BOIU2QVGPPCKL27IGSC5JF7OCLK65QIMW5NL5RAFELNWTWFE6LKFECT72S
#\\\|YEJXY4MNCCGOKRTYDHCQEXHK5T3VDP4YWDJYN7VVMGKU5SV6SLI \ / AMOS7 \ YOURUM ::
#\[7]Q4WQTNDIDJSPRMXKPFEL7LX5ZPUN6U3JEZCKAAAALNB6LQ6AKKBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
