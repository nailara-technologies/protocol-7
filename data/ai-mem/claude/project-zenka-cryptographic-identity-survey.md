---
name: project-zenka-cryptographic-identity-survey
description: "ground-truth inventory of P7's crypto/identity infrastructure (keys zenka, crypt.C25519.*, TOFU, discover/nodes/external) before designing zenka-as-first-class-identity + capability delegation"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3c264315-73af-4677-a8b4-23ce085cb5a8
---

**2026-07-17, research-only, no design/code yet.** Two Explore-agent survey
passes, commissioned to answer: what already exists before designing zenki
as first-class cryptographic identities with delegable, attenuable
authority (raised right after the [[topic-write-access-security-infrastructure]]
discussion — this is that project's foundational research).

## bottom-line finding (the one fact that reframes everything)

**Every layer of trust in this codebase collapses to one per-USER C25519
base key (`<user>.base`).** Session keys, TOFU pinning, key-signs-key
web-of-trust, and `discover`'s signed multicast packets are all rooted in
the same identity. There is no per-zenka cryptographic identity anywhere
today — `crypt.C25519.generate_session_keypair` names its output
`session:<zenka-name>`, but the *signing authority* behind it is still
the user's base key; the zenka name is cosmetic labeling only. Making
zenki first-class identities is not extending something half-built — the
concept doesn't exist yet, though adjacent infrastructure would support
it well.

## pass 1 — keys zenka, crypt.C25519.*, TOFU, session keys

- **`keys` zenka**: console-only (confirmed: `keys.init_code` deletes
  `<buffer.zenka.log_cmd>` for itself, no network-handler modules in its
  whitelist). Pure UI over `crypt.C25519.*` — generates nothing itself.
  Storage: `~/.n/user-keys/<name>.{secret,private,public}`, base32,
  `U:`/`.:` prefix (unencrypted/Twofish-encrypted). Commands:
  `keys.console.{list,create,remove,rename,sign-key,...}`.
- **Doc correction**: CLAUDE.md says user keys live in `modules/USR.
  [username].*` — verified these are actually a baked-in **public**
  keyring (each file `return`s one public key string), not where
  private material lives. Real private/secret keys are under
  `~/.n/user-keys/`, not in the source tree.
- **`crypt.C25519.*`** has a full key-signs-key web-of-trust primitive
  (`sign_keys`/`verify_key_signature`/`create_signature_request`) — one
  identity vouches for another's pubkey. **Confirmed via direct grep**:
  no capability/delegation/attenuation concept exists anywhere in the
  codebase — all "delegation" hits are AI task-routing
  (`context.delegate.*`), all "capability" hits are protocol/session
  negotiation (compression, encoding), not cryptographic authority.
- **TOFU has two implementations with a live naming inconsistency**:
  `crypt.C25519.store_remote_key`/`get_remote_key` write/read
  `remote.<host>_<port>.public`, but the display code
  (`keys.console.list`, `keys.list_remote_keys`) scans for
  `remote-host.<host>_<port>.public` — different prefix. No writer of
  the `remote-host.*` pattern was found in `modules/`. **Resolve this
  before building anything on "the" TOFU filename convention** — unclear
  which is current vs. legacy, or if a third code path produces the
  observed `remote-host.local_42.public` files.
- **The more interesting TOFU path**: `plugin.auth.auth-keypair.
  validate-incoming-tofu` pins an *incoming client's* pubkey and gates
  it behind an explicit admin-created authorization symlink
  (`~/.n/remote-keys/authorized/<zenka>/<user>.public`) — structurally
  "pin identity, then explicitly grant trust," much closer to what a
  zenka-identity system needs than host-key TOFU. Currently keyed by
  **username**, not zenka — the `zenka_name` param only selects which
  `authorized/<zenka>/` directory to check, not the identity itself.
- Two separate **non-asymmetric** session-auth paths also exist
  (`base.auth.set_zenka_key`/`set_v7_key`): shared-secret bearer tokens,
  BLAKE2b-384-hashed, gated by an `auth.setup.usr.<zenka> = :zenka:`
  config tag. Distinct from the C25519 identity chain entirely.

## pass 2 — discover / nodes / external pipeline

- **`discover`**: real Ed25519 signing (`crypt.C25519.sign_data` /
  `Crypt::Ed25519::verify`) of multicast presence packets (UDP
  239.13.5.42:47) — but signed with `discover.crypt.key_user =
  <system.amos-zenka-user>`, the same per-user base key as everything
  else. BMW hash (`base.chk-sum.bmw.L13-str`) used only for replay
  protection/indexing, never as the authenticity mechanism itself.
  Packet = header (type+hostkey) + optional cross-signature lines +
  indented `HOST[name]{...}` payload + optional `p7ref` (orbital overlay
  ref) + timestamp + Ed25519 signature over all of it.
- **`nodes`**: pure aggregator, zero crypto of its own — consumes
  pkeys `discover` already verified. TOFU pin/auth *data fields*
  (`pinning_status`/`auth_status`, init `'unpinned'`/`'pending'`) exist
  on `$data{'nodes'}{'remote-nodes'}` entries, but **no command
  transitions them** — scaffolded, not finished (`[LLL]`-tagged
  stub nearby). `nodes.cmd.add-tronk` (manual admin peer-add) accepts
  an operator-supplied pubkey with **zero cryptographic verification**
  — format-only checks.
- **`external`**: connection-management glue over `nodes`/`discover`'s
  orbital overlay cache — no new identity/capability concept. Its
  "transport registry"/"protocol bridge registry" are empty scaffolding
  for an unpopulated plugin system. Infers "encrypted" by substring-
  matching a reply string, never verifies encryption itself. Second-hand
  "grid sync" peers (learned from a peer's peer) get a **literal null
  placeholder pubkey** (`"\x00" x 32`) — tracked but unauthenticated by
  construction.
- No single shared "peer identity" struct — `discover`/`nodes`/
  `external` each keep their own copy of the same
  `{hostname, ip_addr, hwaddr, pkey}` tuple, stitched together via
  cross-zenka command calls, not shared by reference.

## synthesis / how to apply

This confirms rather than changes the design direction: the missing
piece is (1) a zenka's own distinct keypair, certified via the
*existing* key-signs-key link to its owning user's master key (reuse
`sign_keys` as-is), and (2) a new scoped, attenuable authority token
built on the *existing* `sign_data`/`verify_sign` primitives — no new
crypto primitives needed, just new structure on top of what's there.
The `discover`/`nodes` pin-then-authorize *shape* (status fields +
admin-symlink gate) is a familiar, already-used pattern in this
codebase for exactly this kind of trust bootstrap — reusing its shape
for zenka identity would feel native, not foreign, even though the
actual state-machine wiring for it doesn't exist yet in `nodes`.

Before designing further: resolve the `remote.*` vs `remote-host.*`
TOFU naming inconsistency (pass 1) — don't build a new convention on
top of an already-ambiguous one.

[[topic-write-access-security-infrastructure]]
[[topic-ncode-safe-refactor-workflow]]

#,,,.,.,.,.,,,,,.,,..,,,.,,.,,...,...,..,,..,,..,,...,...,...,,..,,,.,,,,,...,
#2JEFOMO3KTTWI5IQDPNVCURI7COUFSYOWAO2FGHEQDJPQNPLM7SLLBZIZLXJD2IPIWKAGSN4X4UQW
#\\\|D6PLQZXWCGWANXUKAS2XHRZMRBN5THQIJHGEW5X5SJKTZRFCSNV \ / AMOS7 \ YOURUM ::
#\[7]RCHFH5RNZVBAOQCSENL6YOPVZKFEPKJUW4TGN6QQM4RYF4JI3QCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
