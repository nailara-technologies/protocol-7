---
name: project-cross-host-trust-bootstrap-gap
description: "confirmed via full-text read of 10 existing design docs: no doc solves a zenka reaching another zenka's host with no shared protocol-7 cube; jobsite/httpd jobs-sync chosen as the pilot to build it"
metadata: 
  node_type: memory
  type: project
  originSessionId: 5d437747-f04b-4b79-bedc-b5ebe9e545a1
  modified: 2026-07-18T14:46:00.645Z
---

**2026-07-18.** Follow-on to [[project-zenka-cryptographic-identity-survey]]
(2026-07-17, which established there's no per-zenka C25519 identity yet,
only per-user). This entry adds: (a) a cred-mesh capability survey, (b) a
full read of every existing design doc mentioning C25519/identity/trust,
(c) the concrete decision to use jobs-sync as the pilot.

## trigger

httpd auth was recently enabled on POST /jobs-sync (commit 9d6486427
loaded plugin.web.auth so the gate actually works instead of crashing).
jobsite's sync client sends no auth header at all → every sync now 401s.
The naive fix (mint jobsite a `plugin.web.auth` session token via cube
route-send) was caught before implementation: **jobsite and httpd/web are
only guaranteed to share a cube on today's single-host setup** — the
user's stated reason `/jobs-sync` is HTTP instead of a native zenka route
in the first place is to support jobsite running on a separate host with
no p7 link back. A fix that only works same-cube would need redoing.

## cred-mesh, surveyed fresh

`cred-mesh` (cfg/zenki/cred-mesh/, modules/cred-mesh.*) is a
**local secret storage/rotation broker**, not an identity or trust
mechanism: `register` declares a slot's metadata (owner, type, rotation),
`resolve` decrypts and formats the stored secret for use
(`{inject_header=>{Authorization=>...}}` etc). Encryption is envelope
C25519 ECDH via a detached `key_holder` child process, purely for local
at-rest protection — unrelated to TOFU/peer-auth C25519 usage elsewhere.
Cross-zenka only via intra-cube `protocol-7.route-send` to an owning
zenka; **no cross-host concept at all**. jobsite/weather already have
`cred-mesh.register`/`.resolve` access grants in
`cfg/zenki/cube/access.zenki` but **zero real call sites** —
scaffolding provisioned ahead of use.

## confirmed: the gap is real, not something earlier research missed

Read in full: `data/md/coding-tasks/zenka-key-identity-infrastructure.md`,
`data/md/design/KEY-TREE-AUTHORITY-FIELD.md`,
`data/md/design/PRIVACY-PRESERVING-IDENTITY-CREDENTIALS.md`,
`data/md/design/RING-ROUTING-PROTOCOL.md`,
`data/md/design/SIGNED-COMMAND-INTERFACE.md`,
`data/tasks/web-sessions-distributed.md`, `data/tasks/keyring-phase1.md`,
`data/tasks/needs-testing/credentials-zenka.md`,
`data/tasks/completed/credential-fabric.md` (an audit doc, not a shipped
feature, despite the "completed" directory),
`data/yaml/reasoning-templates/key-tree-authority-field.yaml`.

**None solves cross-host-with-no-shared-cube.** Every mechanism assumes
either a shared cube/session substrate (key-tree authority, ring routing,
key-as-directory routing, cred-mesh, credentials-zenka's cube-injected
`source_zenka`) or a pre-shared admin-installed secret
(`web-sessions-distributed.md`'s `/etc/protocol-7/web/session.key`,
explicitly "deployed via admin, not synced" — sidesteps the bootstrap
problem rather than solving it). Nameserv-based discovery across
disconnected cubes isn't addressed by any of the ten docs.

**Most reusable building block found: `SIGNED-COMMAND-INTERFACE.md`.**
Concrete generate-on-first-use + TOFU pin + explicit signed-rotation
ceremony (signature footer = BMW384 hash + C25519 sig + key fingerprint +
ntime + nonce, `security.tofu.*` config keys, `data/keys/tofu/` storage,
`p7c base.cmd.rotate-key`) — closest existing shape to what jobs-sync
needs, but scoped to P7's internal command dispatch, not HTTP. Second
most relevant: `PRIVACY-PRESERVING-IDENTITY-CREDENTIALS.md`'s "drone
visiting a foreign P7 node" section — right problem framing, but
describes credential *format*, not the handshake/discovery transport.

**Known unresolved naming collision** (flagged by doc #9 itself):
`credentials.*` (credentials-zenka, needs-testing) vs `cred-mesh.*`
(renamed to avoid the collision) — not yet reconciled codebase-wide.
Don't add a third parallel credential namespace without checking this.

**New fact vs. the 2026-07-17 survey**: that survey said "no writer of
the `remote-host.*` pattern was found in `modules/`" for TOFU-pinned
files. The user's own `v7.keys list` output today shows real
`remote-host.local_42.public` / `remote-host.localhost_42.public` /
`remote-host.127.0.0.1_42.public` files under the `taeki` user, and a
`global-root` + `protocol-7.base` key pair under a locked-down
(`no-r.perms`) system `protocol-7` user — global-root is the intended
common trust anchor these chain toward. The `remote-host.*` writer likely
exists outside `modules/` (console/keys-zenka path?) or was written
manually — **unresolved, worth a targeted grep before relying on either
naming convention**.

## decision: jobs-sync as pilot

User's framing: jobs-sync is the ideal non-critical pilot — local setup
still exists today (auth can be disabled again anytime, zero risk), and
a real remote-server setup already exists to test the actual
split-location case once a mechanism is built. Once proven here, the
same mechanism generalizes to other applications needing the same
"closed trust loop from the start" (proxy/transport's outbound creds,
discover's host validation, nameserv zero-conf bootstrap all touch the
same gap).

**Layered decomposition agreed with user** (small generic components,
each individually complete, rather than one jobs-sync-specific fix):
1. **Identity** — normalize per-zenka/per-host key ownership & chaining
   (grouping/nesting not yet decided) on top of existing
   `crypt.C25519` key-signs-key primitive.
2. **Handshake/trust establishment, transport-agnostic** — generalize
   TOFU (today only over `p-7-r` sessions) + chain-signature
   verification (today only in `discover`'s multicast path) so the same
   decision logic runs over HTTP too.
3. **Credential storage/use downstream of a handshake** — cred-mesh,
   largely as-is; jobsite/weather's already-provisioned access grants
   are waiting for exactly this.
4. **Discovery/bootstrap** — nameserv TXT/SRV (real, working today for
   generic zones) extended to publish zenka endpoint+pubkey; explicitly
   later-phase, not a blocker for 1-3.

**Update 2026-07-18 (same session)**: `auth.required` removed from the
`/jobs-sync` route again (`cfg/zenki/httpd/routes`) — sync
works, zero risk since jobsite is local-only today. Open questions and
the full "already exists" map captured in
`data/md/design/ZENKA-IDENTITY-AND-TRUST-TOPOLOGY.md` (umbrella doc,
not a spec — components to be derived from it one at a time).

**Correction (twice-refined)**: `nodes.cmd.update-protocol-elf` (a
content-derived protocol-version checksum) IS a logical root the user
intended to raise here — but a **practical/topological** one, not an
**authority/trust** one. A network can carry one global name while
diverging protocol versions running inside it already fragment it into
logical islands/sub-identities, even where seamlessly bridged. Don't
conflate this axis with the authority-root questions (who is trusted)
— it's "which protocol dialect this zone speaks," a separate axis
entirely. The settled plan for the bridging itself is **protocol
translation plugins**, providing back-/forward-compatibility at the
boundaries of real protocol changes (renamed commands, changed
parameter APIs) — the checksum is a candidate value such a plugin
boundary might key off, not a proposal in itself. **User confirmed
"topological root" as the precise term for this axis (2026-07-18) — use
it consistently rather than re-deriving other phrasing later.**

**Status as of 2026-07-18: design conversation only, no code written.**
User's explicit reason to slow down: avoid "poking in the dark," avoid
committing to a first-idea architecture that only serves jobs-sync and
needs a later rewrite once other use cases (proxy/transport creds,
discover, nameserv zero-conf) show up. See
[[feedback-small-generic-components-before-wiring]] for the general
working-style takeaway.

[[project-zenka-cryptographic-identity-survey]]
[[topic-write-access-security-infrastructure]]

#,,.,,.,,,..,,,,.,.,.,,,,,..,,.,.,,.,,...,.,,,..,,...,...,..,,.,,,...,,,.,.,,,
#FMTGEAPQ7QPZJ2XINFMZL2NUXXH4U2PDYLNN5N2GQNM72Z7SL3EPZEYEJDZV2DC3K2567Q2HMUSOA
#\\\|MYHZ4MF54726YBQ3GDZCHY6Z3REHOHEJOGYWV36U2TSB3ZO6OGN \ / AMOS7 \ YOURUM ::
#\[7]HSDVHAKK2NQKVUN5E7DOFN336JVRYZCRXNXLVCJOIPTIXZYXQWBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
