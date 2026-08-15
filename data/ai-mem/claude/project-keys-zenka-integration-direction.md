---
name: project-keys-zenka-integration-direction
description: "2026-08-12 user direction: integrate keys zenka functionality alongside the users/user-edit and credentials work -- keys already holds the TOFU host-key pins the users remote/ work depends on, and already carries a credential command (github-pat), so identity/secret material now spans four namespaces needing explicit reconciliation"
metadata:
  type: project
---

**Per user, 2026-08-12**, alongside
[[project-credential-types-into-user-edit]]: integration of `keys` zenka
functionality is a third direction for the user-edit/users work.

## what `keys` actually holds — four distinct key shapes

From live `v7.keys list`, the checksum prefix encodes the shape:

| shape | example | marker |
|---|---|---|
| normal keypair | `taeki.base` | `<:ZITAETA:YKO7BCA:>` + private/secret/public |
| virtual / seed-phrase | `ncode-sign-key` | `<:virtual::CWPEXYA:>` |
| encrypted at rest | `proto-7.sourcecode` | `<::[enc-key]::MI4B6FA:>` |
| TOFU host key | `remote-host.127.0.0.1_4242.public` | single checksum, public only |

28 console commands (create, enc-key/dec-key, sign-key, split-keypair,
duplicate, rename, remove-signature, keys-backup-archive,
decrypt-archive, encoding-upgrade, gen-pwd-keyfile, get-sp-pub-key,
github-pat ..). It is a mature surface, not a stub.

`keys` is a **standalone console zenka** — no network modules at all.
It is the exact shape `user-edit` was originally cloned from, which is
also why user-edit shipped with no connectivity until `43d22a1f8` (see
[[topic-user-edit-console-zenka-status]]).

## two concrete connections, both verified

**1. The TOFU host-key pins live here.** `crypt.C25519.init_code`
classifies key files with

```perl
qw| tofu_hostkey | => qr|^(remote-host\.[0-9a-z\.\-_]+)\.public$|
```

and `keys.console.list` renders exactly those as `[hostkey]` entries.
These are the same pins the `users` remote-fetch/auth-keypair work
depends on (commit `e4185e78b`, where TOFU pin-key stability was one of
the 8 bugs found — see
[[bug-auth-keypair-client-composition-gotchas]]). So peer-host identity
for `users.remote-get` is ALREADY persisted, in the user's C25519 key
dir, surfaced through `keys` — not a gap to fill. Naming convention is
`remote-host.<host>_<port>.public`.

**2. `keys` already carries a credential command.** `github-pat
<repository>` configures a GitHub Personal Access Token — a
credential, living in `keys`, not in `credentials`. Direct overlap with
[[project-credential-types-into-user-edit]].

## the actual architectural question

Identity and secret material now spans **four** namespaces:

- `keys` — C25519 keypairs, seed-phrase/virtual keys, TOFU host pins,
  key archives, and (already) at least one credential type
- `credentials` — typed credential entries, encrypted archive at rest,
  per-credential authorized-zenki lists
- `cred-mesh` — slots, rotation, key_holder parent/child, encrypt/decrypt
- `users` — per-user canonical records, `remote/` peer discovery, and a
  stated key-authority role ("when a zenka needs to contact a user or
  another zenki, it asks the users zenka to acquire/resolve the correct
  key")

`users-zenka.yaml` already claims key authority, and `user-edit` already
loads `crypt.C25519` under the resolved LOCAL key model. So the boundary
is not "does users touch keys" — it already does — but **which zenka
owns each kind of secret, and which are merely front-ended by others**.

**How to apply:** do NOT start moving key material between these. The
sequencing that makes sense is to let `user-edit` become the shared
front-end first (it already talks to `users` and already loads
`crypt.C25519`), and only then decide ownership per material type. The
strongest early candidates for reconciliation, because they are already
duplicated rather than merely adjacent:

- `github-pat` (credential in `keys`) vs. `credentials`' type whitelist
- TOFU host pins (in `keys`) vs. `users`' `remote/{incoming,outgoing}`
  peer records and `discover.orbital.known` — three places describing
  peers, previously flagged as an open item in
  [[project-users-zenka-unblocks-cross-host-testing]]
- `keys` being standalone/no-network vs. `users` needing key resolution
  over the network for routing

Also unexamined: `cred-mesh.cmd.ui-show` is an existing credential UI
with live nshell integration — settle whether user-edit's form subsumes
it before building a parallel one.

**Idea, per user 2026-08-14 (not yet designed further)**: move TOFU host
pins (`remote-host.<host>_<port>.public`) out of the regular `keys`
directory entirely, into a parallel directory of their own — surfaced
while scoping the `user_keys` field (see
[[topic-user-edit-console-zenka-status]]), which deliberately excludes
hostkey entries from its "your keys" list because they already read as a
different category of thing than a named keypair, not just a filtering
convenience. Would also bear on the "three places describing peers"
question above (`keys`' hostkey pins vs. `users`' `remote/` vs.
`discover.orbital.known`) if it goes anywhere.

**How much freedom exists to redesign this — stated directly by the user,
2026-08-14, after the `user_keys`/`identity_key` work surfaced how little
of the key system is actually load-bearing (see
[[bug-crypt-c25519-key-vars-base-identity-hijack]]'s "identity key is a
NEW concept" section for the concrete evidence)**: key names are loose,
free-form conventions (`base`, `global-root` are just strings someone
picked, not semantics the system enforces), and almost nothing depends on
the current structure holding still. Per user: "we can freely change a
lot without breaking anything. the only load bearing thing currently is
the availability of the sourcecode signature key... which i can
recreate." Framing, also stated directly: this looseness isn't neglect,
it "was all waiting for the current moment... when other parts of the
system demand the emergence of a clean yet flexible structure" — i.e. the
key/identity system was deliberately left unformalized until real,
concrete demand (from `users`/`user-edit`/`credentials` work) would shape
what it actually needs to be, rather than guessing ahead of that demand.
**How to apply**: a future redesign of `key_vars`/`base_key_name`/naming
conventions doesn't need to preserve today's incidental shape (e.g.
`<user>.base` as THE default) for backward-compatibility reasons — very
little actually depends on it. The one real constraint is the
`proto-7.sourcecode` signing key's *availability* for the pre-commit
signature-check flow, and even that is recreatable, not irreplaceable.

**Target shape, per user, same conversation**: "clean signature trees."
Realization driving it: signatures can exist MANY in parallel for one
key, so there is no need to "attach" them to the key itself the way
`keys.console.list`'s current `key_signed_by` mechanism does (scans for
signature files pattern-matched by name INSIDE the same key's own
directory — genuinely attached, one key's dir holding its own signature
files). Per user, likely shape instead: **a separate file type whose job
is specifically to define key SIGNATURE RELATIONSHIPS** — decoupled from
the keys/directories themselves, so many parallel signatures over one key
(or a chain of them) are just more entries in that structure, not more
files crowded into a key's own directory.

Directly overlaps prior art already flagged as the reference to read
first before designing this from scratch: `data/md/design/
PRIVACY-PRESERVING-IDENTITY-CREDENTIALS.md` (see
[[topic-key-recovery-flexible-recreatability]]'s own account) already
specifies close to this shape — `parent_key` SIGNS each `child_key`'s
public component as a cert-chain authorization (not derivation from a
shared seed), and credentials are content-addressed by `BMW384(credential)`
with an explicit `next: BMW384(new)` pointer for auditable upgrades (mode
A) vs. a historyless clean replacement (mode B). Both are already
"signature/authorization relationships recorded separately from the key
material itself" — check whether that doc's existing design already
answers "what does the relationship file type look like" before
inventing a new one.

**General policy, per user, same conversation: prefer an unencrypted key
over no key at all.** Rationale stated directly: an unencrypted key still
attaches its entropy to SOME physical security (filesystem/OS access
control, even without a passphrase layer) — strictly better than nothing
— and can already be used for TOFU pinning from first boot, so the system
should not block on ideal security before establishing initial trust.
Matches an existing, already-buildable capability rather than a new one:
`keys.console.gen-file-seed-key`'s `-U` flag already skips at-rest
encryption on request (see [[topic-key-recovery-flexible-recreatability]]),
and `crypt.C25519.autocreate-user-key`'s default autocreate path already
produces a plain key today — this policy makes that existing default
behavior an explicit, intentional principle for the clean redesign,
rather than an unstated default.

**But, for important cases — user keys on an interactive system
specifically** — per user: give an easy key-upgrade path (unencrypted →
passphrase-protected) that is IMMEDIATELY SYNCHRONIZED once taken, not a
manual multi-step re-issue. Likely UI surface for that upgrade prompt:
`user-edit`'s `masked` field type (see
[[project-credential-types-into-user-edit]]), already built for
event-loop-safe secret entry, though an event-loop-safe prompt for
entering a secret INSIDE an already-running form is still flagged
unbuilt there — the same gap would need closing for this upgrade flow
too.

**Overall stance, stated directly**: "it will prefer better security, but
use any it can already get" — progressive enhancement, not
all-or-nothing: never block functionality waiting for the ideal case,
always make the upgrade path easy once better security becomes available
or needed.

#,,..,,,,,.,.,,,.,.,,,..,,,.,,.,,,.,.,..,,,..,..,,...,..,,.,.,...,.,.,...,,.,,
#CUHIJGI7LWGZ5VM5HUQ557CGBCVFOWFXVJND6R5FP6KJ6U5SMGS6GZBGMOB3JQRBBZNYE6TILKEMS
#\\\|NU2FF3XVHIMKTTE5456CSZLDL6R4UKH2FSKGSU3QQL7QUL4WJTV \ / AMOS7 \ YOURUM ::
#\[7]TZ5KW5GUVC2ZBRYFUO4A2WETOGVTGSRJI3MNK5OHMEIB2YYLUMBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
