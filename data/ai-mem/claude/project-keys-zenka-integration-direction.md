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

#,,..,,,,,.,.,.,,,,..,,..,...,,,,,,,.,..,,,,.,..,,...,..,,,.,,.,.,,..,..,,,.,,
#YCKLNKKRGLXLGOUYUKGE6GHLSYC2KB4CYLOVNG5C4ERWCE7DIAQPABBVL2QFTQSIDITNTD3GLNUOS
#\\\|AIVYJXXAVSZXCIHFIG7KTLJ7KRY5MY7IJETRASI2VTN2T47PQG6 \ / AMOS7 \ YOURUM ::
#\[7]FYIBA4CPP5272WRHHLFTYBQIRRLMTAWLOEVES4GAR7VC7GUFDWCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
