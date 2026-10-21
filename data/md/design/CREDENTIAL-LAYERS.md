# credential layers : who owns, who holds, who uses

draft 2026-10-21 [ todo 6C6, with 5OT and R4F for context ]. design only --
no code, no config changes come with this file. owner direction : p7-vault
integration is the connecting step between proxy, cred-mesh \ credential
fabric, user-edit and the users zenka ; the sessions zenka is meant to
understand native and related session types alike, with p7-accessible logic.

builds on [ do not rebuild ] : VAULT-FORMAT.md [ the vault ],
CREDENTIAL-FABRIC-INTEGRATION-AND-UI.md [ slots, relay, ui -- written under
the old `credential_fabric.*` names, the code is `cred-mesh.*` today ],
WEB-UI-USER-LOGIN.md [ password hashes outside the users record ],
AUTH-LINK-BINDING.md [ the bound link a grant travels over ], todo Y7O
[ vault agent, per-zenka grants, menu approvals ], HOST-SETUP.md + todo 3W5
[ host records, permanent links ], todo HS4 [ proxy exits ].

## today : what the code does [ read 2026-10-21, base 4df3fad1 ]

the layers exist, but they do not connect, and some of them overlap :

- **p7-vault** [ `bin/p7-vault`, `AMOS7::Vault` ] : 4 types in `%TYPES` [ login
  note contact file ], secret-ness by field NAME in one global `%SECRET`
  [ password totp body ]. the master key never leaves the user's machine.
  nothing in protocol-7 reads a vault yet.
- **credentials zenka** : one archive file per credential, with a list of
  authorized zenki and a closed type whitelist [ `credentials.cmd.add` :
  web-session api-key smtp imap ssh-key ]. the archive password is
  `<cred name>:<protocol-7.instance-id>` [ `credentials.save` \ `.load` ].
  `<protocol-7.instance-id>` is set nowhere in the tracked tree, so the
  password falls back to `<cred name>:protocol-7` unless a host.cfg sets it
  -- and even then it is a config value stored beside the files. derivable
  from what sits on disk : **obfuscation, not encryption at rest**. its one
  strong part is
  `credentials.request_session`, which is in cube's
  `setup.aliases.source_zenka` [ `cfg/zenki/cube/command_aliases` ]. the
  caller is therefore named as cube authenticated it, and is checked against
  the list.
- **cred-mesh** : a slot registry [ `registry.yaml` ], a tier-1 store
  [ `store/<slot>.enc`, sealed by the key-holder child ], a rotation strm,
  the auth relay, and the ui. gaps :
  - `cfg/zenki/cube/access.zenki` grants `cred-mesh.resolve`, `rotate` and
    `approve` under `access.cmd.usr.*` -- **every** zenka. `cred-mesh.resolve`
    never checks the caller, so any zenka reads any slot's plaintext
    [ `perform_auth` puts the value into `inject_header` ], and
    `cred-mesh.cmd.rotate` takes `<slot> <new_value>` from any caller, so
    any zenka can overwrite one.
  - `owner` does two jobs at once : who holds the value, and who it is for.
    `owner ne cred-mesh` routes to `<owner>.credential.resolve`. no module
    with that name exists, and `cred-mesh.handler.route_reply` only caches
    the reply. the seed example's slots [ owner `transport`, `weather` ] can
    therefore never resolve.
  - `cfg/zenki/cred-mesh/zenka.v7` lists `dump set get del exec-sub
    eval-code` permanently. the credentials zenka gates the same commands
    under `access.devcmd` [ devmod only ].
- **sessions zenka** [ stub ] : one identity holder child [ attach \ detach ],
  plus named one-shot secret children [ `hold` \ `release` \ `secrets` ].
  user-edit already depends on it : masked fields [ `host_password` ] are
  sent to `sessions.hold` on submit [ `user-edit.source.secret_hold`,
  `form.handler.submit_secret_hold_reply` ]. they live in memory only and
  are lost on a sessions restart.
- **users \ user-edit** : identity records [ `[USERS_HOST]/<user>/details.yaml` ],
  open field set, `masked` shape for secrets. records hold no secrets.
- **host-edit** : host records [ `name addresses link_user ssh ssh_port
  transports owner owner_key roles` ], no secrets.
- **transport \ proxy** : profiles name slots [ `atom.udt-psk`,
  `atom.hysteria-auth` in `data/yaml/transport/profiles/atom.yaml` ] and
  resolve them through `cred-mesh.resolve`. `proxy.auth.lookup` resolves
  `session.<domain>`.

## 1. the layers and each one's single job

| layer | single job | holds | never holds |
|---|---|---|---|
| p7-vault | **what the person owns** : the source of truth they grant from | every secret, versioned, on the user's machine | -- |
| vault agent [ Y7O, not built ] | serves granted requests from an unlocked vault, signs | the unlocked vault key, in the user's own process | -- it is never a protocol-7-uid process |
| cred-mesh | **runtime slots** that zenki on one host resolve, plus rotation | granted values sealed by the holder, grant records | the vault key, ungranted entries |
| credentials zenka | today a second store [ see 'credentials zenka' below ] | -- | -- |
| sessions | **what is live** : session classes, renewal, rotation drains, the one holder implementation | live tokens, held secrets [ memory ] | durable copies of granted values |
| users | **whose** : identity a grant names | records, no secrets | secrets, hashes |
| user-edit | **the editor** : records, masked input, the grants view | form state, never a masked value in drafts | -- |
| host-edit | **what a host is** : the record a server entry and an exit refer to | public facts, pins | secrets |
| proxy \ transport | **consumers** : name a slot, use what resolve gives | a slot name | stored values |

the rule between them : **a secret flows only downward, from the vault into a
slot, by an explicit grant**. no layer under the vault becomes a second
source of truth.

the vault agent cannot be a sessions child. a sessions child runs as the
zenka user [ `system.amos-zenka-user` ], and Y7O decides that the vault key
is never handed to a zenka : zenki run as protocol-7, the vault is the
user's. sessions may list the agent as a session class [ alive, locked,
last approval ], but it never holds the agent's key.

### credentials zenka

its jobs are covered by others : the store by cred-mesh [ which is stronger
once the holder is fixed ], the authorized-zenki list by the grant's consumer
list, `spawn_web_session` by sessions classes [ R4F ]. what it does better
than cred-mesh today is the caller check through `source_zenka`. that pattern
moves into `cred-mesh.resolve`. proposal : fold it into cred-mesh, keep
`credentials.request_session` as a thin alias for one release, then remove
it [ owner question 2 ].

## 2. the grant model

**one vault entry -> one runtime slot on one host, for named zenki.**

```
user machine                               server
-------------                              ------
p7-vault entry  ──>  vault agent           cred-mesh
[ id, version ]      [ unlocked ]          ├─ slot <name>    value, sealed by the holder
                     │                     ├─ grant record   consumers, kind, expiry, signed
                     │  bound p7 link      └─ resolve        checks caller ∈ consumers
                     └─ cred-mesh.provision ──────────^
                        [ AUTH-LINK-BINDING v2, encrypted ]
```

a grant record [ public metadata, signed by the granting user's
`<user>.base` key, label-separated like the link-bind sigs ] :

```
grant   : <id>                  random, harmony-checked like vault ids
entry   : <vault entry id>      no title, no url -- the entry id is opaque
version : <entry version>       what was sent, for 'is this copy current'
field   : password              which field became the slot value
host    : <host-edit record name>
slot    : <slot name>
kind    : basic-auth            use kind [ section 4 ]
consumers : [ transport, proxy ]   zenka names as cube authenticates them
expires : <ntime> | never
by      : <user> <key id>       verified against the user's pinned key
at      : <ntime>
```

- **scoped** : `cred-mesh.resolve` takes the caller from `source_zenka`
  [ as `credentials.request_session` does ] and refuses anyone not in
  `consumers`. cube's `access.cmd.usr.*` grant of resolve \ rotate \ approve
  narrows to the zenki that actually consume. `owner` splits into `holder`
  [ always the local cred-mesh ] and `consumers`.
- **revocable** : `cred-mesh.revoke <slot>`, signed by the user, deletes the
  sealed value and marks the grant revoked [ the record stays, as history ].
  **revoking a copy does not undo its exposure** : a value that may have
  leaked is revoked for real only by rotating it at its source [ the
  provider, the host, the account ]. the vault keeps a grant log per entry,
  so a rotation at the source knows every copy to re-provision or revoke.
- **visible in user-edit** : a grants tab [ a `plugin.user-edit.<name>`
  detail tab, the existing plugin path ] lists grants per user and host from
  the grant records -- entry code, slot, kind, consumers, age, current or
  stale version. values are never shown and never fetched for display.
- **approval** : provisioning is a user act on the user's machine. a zenka
  asking for an entry that is not granted waits on 'user approved'
  [ Y7O : the menu shows the request, the approval carries the request id +
  a checksum of what was shown ]. zenki can wait on approvals, never resolve
  them.

### where the master key stays, and what a server ever holds

- the vault key stays on the user's machine, never unwrapped anywhere else,
  and a server never reaches the agent socket. a vault sync to a server
  [ VAULT-FORMAT.md 'sync' ] is a backup, not a grant : the mirror holds the
  opaque entries plus the WRAPPED key file [ sync needs it there ], which
  opens only with the passphrase or the recovery code -- the same exposure
  as any backup. `p7-vault archive` with the recovery wrap only is the
  safer form for a server.
- a server holds only : the granted values, sealed under its own holder key
  [ section 3 ], the grant records, and the live tokens sessions minted.
- an **unattended** server holds its holder key in a form it can open by
  itself at boot. today both holder keys are plaintext base32 at 0600
  [ `fabric.secret`, `holder-identity.secret` ]. the 3W5 link supervisor and
  R4F's machine tokens cannot wait for an unlock phrase after a reboot.
  how this key is protected is an owner decision [ open question 1 ] ; this
  design does not paper over it.

## 3. the two key-holding children

the task assumed both children pipe ENCRYPT \ DECRYPT \ SIGN. **the code
says otherwise** : `sessions.holder.child` answers only `SIGN` and `PUBKEY`.
the `ENCRYPT|DECRYPT` in the descr of `sessions.holder.parent` and
`sessions.init_code` is left over from an earlier `op.encrypt` that no
longer exists. the secret children answer `RELEASE` once.

| | `cred-mesh.key_holder.*` | `sessions.holder.*` [ + `sessions.secret.*` ] |
|---|---|---|
| ops | ENCRYPT \ DECRYPT [ the slot name goes into the key derivation ], SIGN | SIGN [ `<ntime:data>`, freshness bound ], PUBKEY ; secret children : RELEASE once |
| started | in `init_code`, **before** `root.drop_privs` -> the child runs **as root** | by the `spawn` command, after drop_privs -> the child runs as the zenka user |
| channel | `socketpair` -- only the parent holds the other end, unforgeable | named socket `/var/run/.7/UNIX/sessions.holder.<id>.sock`, 0600, zenka user ; `accept_with_timeout` takes whoever connects first, no `SO_PEERCRED` check [ `io.unix.socket.input.connect` has one, it is not used here ] |
| parent gone | EOF -> the child exits ; a new one re-reads the key file | identity holder : EOF -> **dormant**, waits on SIGUSR1. the socket id is in parent memory only and `base.fork` sets no parent-death signal -> after a sessions restart the old child can stay paused, mlock'd, unreachable [ whether v7-zenki's stop reaches it is not established ]. secret children exit -> held secrets are lost |
| dormancy | none | the child redials a PATH. every zenka runs as the same uid, so a process that replaces the socket file during dormancy and sends SIGUSR1 gets the redial -- and can ask for signatures |
| key at rest | `fabric.secret` : base32 of `U:` + 32 raw bytes, 0600 | `holder-identity.secret` : base32, 0600 |
| key use | the same 32 bytes are the Ed25519 seed AND the X25519 scalar | Ed25519 only |
| cipher | twofish-cbc with a zero iv [ the key is fresh per message, so the zero iv is tolerable ], pkcs7 padding, **no mac** -- the ciphertext is unauthenticated and malleable | none |
| wipe | none | `base.buffer.erase_secure` on TERM and exit, file text too |
| error net | none -- a die in the child vanishes | the main loop is eval-wrapped, the reason reaches the log |

shared, so it does not decide anything : the line protocol [ op + base32 ],
the 7 s blocking select read in the parent [ it stalls the zenka's event
loop while it waits ], no Event.pm in the child [ the documented fork hazard ],
liveness through `base.exists.sub-process`.

### recommendation

**`sessions.holder.*` stays as the one holder implementation, and cred-mesh
loads it** [ module reuse across zenki, as cube-13 loads cube's modules ].
sessions is 'what is live' [ R4F scope ], and its lifecycle discipline is the
better one : drop_privs first, wipe, error net, one child per held secret.
it takes over from cred-mesh the two things cred-mesh does better :

1. **socketpair as the default channel.** detach and reattach across a
   parent restart stays a separate, later step. a named socket can only be
   used together with a peer check both ways [ `SO_PEERCRED` pid = the known
   child \ the known parent, plus a challenge signed by the holder key on
   reattach ]. this belongs with V7-HOT-SELF-RESTART, not here [ open
   question 4 ]. the `sessions.secret.*` children switch to socketpair too :
   they are one-shot and never reattach, so a named socket buys them
   nothing. their hold \ release commands stay unchanged.
2. **sealing ops** : `SEAL` \ `OPEN` [ renamed, so the old unauthenticated
   format cannot be mistaken for the new one ] with an aead,
   chacha20-poly1305 through CryptX [ already a dependency of the vault
   and web zenki ]. the associated data carries a label, the host, the slot
   name and the grant id, so a sealed value moved to another slot fails to
   open. the encryption and signing keys are split from one root with
   hkdf-blake2b-512 and distinct labels, the way the vault derives its keys
   -- no more one scalar for two curves.

the cred-mesh key stays in cred-mesh's own process tree : plaintext never
crosses cube on the way to the holder. the alternative -- cred-mesh calling
`sessions.seal` over cube for every resolve -- puts plaintext on the cube
path and a hop on every request ; rejected.

migration of the cred-mesh store : list `var/cred-mesh/store/` on each host
first. it is likely empty [ no seed.yaml is tracked ], but check before
assuming. if it is not empty : one pass with the
old child open and the new holder up -- DECRYPT old, SEAL new, OPEN to
verify, rename into place. then remove `fabric.secret`,
`cred-mesh.key_holder.*` and `cred-mesh.util.key_holder.*`. the hold \
release interface user-edit uses stays as it is.

## 4. one type vocabulary

the three lists are not three spellings of one list. they mix two axes :

- **entry type** : the shape of what the person owns [ fields, which fields
  are secret ] -- vault `%TYPES`, the new types 5OT names
- **use kind** : how a zenka applies a value [ the header it injects, a psk,
  a key for ssh ] -- cred-mesh `register` \ `perform_auth`

the credentials whitelist mixes both : `web-session` and `api-key` are use
kinds, `ssh-key` is an entry type, `smtp` \ `imap` are a login used for mail.

| entry type | secret fields [ per type ] | use kinds it can provision | credentials whitelist | cred-mesh kind |
|---|---|---|---|---|
| login | password totp | basic-auth, session-cookie [ through the auth relay ], mail-login | web-session, smtp, imap | basic-auth, session-cookie |
| api-token [ 5OT ] | token | api-key, bearer-token, oauth-token | api-key | api-key, bearer-token, oauth-token |
| server [ 5OT ] | password | ssh-password, psk \ exit secrets [ open question 6 ] | -- | psk |
| ssh-key [ 5OT ] | private_key passphrase | ssh-key | ssh-key | -- [ new kind ] |
| app-account [ 5OT ] | password totp recovery | -- [ owned only ; no zenka uses it yet ] | -- | -- |
| note \ contact \ file | body [ note ] | -- [ never provisioned ] | -- | -- |
| -- | -- | tls-client-cert | -- | tls-client-cert [ no entry type yet, open question 6 ] |

- **one list, two axes** : one file [ proposed :
  `data/yaml/credentials/types.yaml` ] declares the entry types with their
  secret fields, and the use kinds with the entry type \ field they read
  from. the credentials whitelist and cred-mesh's `@valid_types` are
  replaced by reads of it.
- **the vault keeps its own table.** VAULT-FORMAT.md promises that three
  files open every vault without protocol-7, so `AMOS7::Vault` cannot load a
  protocol-7 yaml. `%TYPES` stays in Vault.pm, and a test checks that it
  agrees with the yaml.
- **secret-ness per type + field.** today it is decided in two places : the
  vault's global `%SECRET` by name, and `editor.control.masked_field_names`
  in the zenki. both answer from the per-type declaration.
  `users.record.optional_fields`' `\''` masked shape stays the form-side
  signal.
- 5OT's conversion [ retype with a field map, unmapped fields kept, a new
  version so it is reversible ] is what moves today's logins into
  server \ api-token before they can be granted with the right kind.

## 5. host-edit records and proxy exits [ HS4, 3W5 ]

- **one name** : host-edit record name = host name = external link name
  [ 3W5 ]. a vault `server` entry refers to its record by that name [ a
  `host` field holding the record name, 5OT ]. slot names on that host derive
  from it : `<record>.<use>` -- `atom.hysteria-auth` and `atom.udt-psk`
  already follow it.
- **split of facts** : the record holds what is ours to decide and public
  [ addresses, ssh target, transports, roles ] ; the vault entry holds what
  is secret about that host [ account passwords, keys, the provider panel
  login ]. the vault's `host_key_fp` is a statement. pins
  [ `~/.n/remote-keys/servers/` ] stay the trust check : a disagreement is a
  conflict to show, never outvoted [ Q7O ranking rule ].
- **first real grant -- 3W5** : the hub's unattended ssh key for permanent
  links. a vault `ssh-key` entry, granted to the hub's cred-mesh as slot
  `<node>.link-ssh-key`, with consumers the link supervisor
  [ external \ host-edit ]. it is restricted on each node in authorized_keys
  [ `restrict,port-forwarding,permitopen=127.0.0.1:42,command=/bin/false` ].
  open : ssh wants the key from a file or an agent. the clean form is the
  holder speaking the ssh-agent protocol on a socket only the supervisor
  can reach -- a later step. until then a 0600 file written from the slot
  at link start and removed at link end, stated as a compromise.
- **exits -- HS4** : the exit attributes HS4 reads from the record
  [ provider \ range class, location, traffic budget ] **do not exist** in
  `host-edit.record.field_names` today. that gap belongs to HS4 and is not
  designed here. exit secrets [ hysteria auth, udt psk ] are grants to the
  exit host's slots, with transport as the consumer. the proxy-exit
  IDENTITY [ the `proxy-exit` key delegated by host-root ] is trust
  material in the keys \ pin chain -- not a vault grant, and not a slot.
- provider and registrar accounts stay `login` entries [ 5OT ]. whether a
  record names its provider entry is left to the owner.

## 6. staged plan

each stage is useful on its own and leaves nothing half wired.

1. **scope the slots** [ smallest useful first step, no vault involved ] :
   add `cred-mesh.resolve` \ `rotate` to cube's `source_zenka` aliases,
   split `owner` into holder + `consumers`, and refuse callers who are not
   consumers. the alias prepends the caller's name to `args`, and today's
   routed callers send the bare slot name [ `proxy.auth.lookup`,
   `transport.handle.quic-hysteria`, `transport.handle.udt-tunnel` ] -- so
   resolve's `args` parsing changes in the same step, or every caller
   breaks. narrow the `access.cmd.usr.*` grant, and move cred-mesh's
   devmod commands under `access.devcmd`. after this, any value later placed
   in a slot reaches only the zenki it names. tests : a consumer resolves, a
   non-consumer is refused and audited.
2. **one holder** : `SEAL` \ `OPEN` + key split in `sessions.holder.*`, the
   socketpair channel, cred-mesh loads it, store migration [ section 3 ],
   then the old modules go. fix the stale descrs. the owner-routing dead path
   goes with the holder \ consumers split.
3. **one vocabulary** : the types yaml, the 5OT types + per-type secret
   fields in Vault.pm with the agreement test, conversion with dry run.
4. **grant v1, by hand** : `p7-vault grant <entry> <host> <slot> <kind>
   <zenki>` over the bound p7 link [ p-7-r ] -> `cred-mesh.provision` ; signed
   grant record, the grant log in the vault, `revoke`. no agent yet : the
   user runs it, unlocked, on their own machine.
5. **visible** : user-edit grants tab, read-only first.
6. **first real users** : the 3W5 link key, then the HS4 exit secrets
   [ `atom.hysteria-auth`, `atom.udt-psk` ].
7. **live** : sessions classes and renewable machine tokens [ R4F ] held by
   the holder instead of 0600 files ; then the vault agent with menu
   approvals [ Y7O ], which turns stage 4 from a command into an answer to a
   request.
8. **retire** the credentials zenka as a store [ after open question 2 ].

## open questions for the owner

1. **unattended holder key** : how is the server holder key protected at
   boot ? plaintext 0600 [ today ], a key the user pushes after boot [ links
   wait until then ], a hardware-bound key [ tpm \ systemd-creds ], or a
   second medium ?
2. **credentials zenka** : fold it into cred-mesh [ recommended ], or keep it
   as the policy front with cred-mesh as its store ?
3. **grant log in the vault** : its own entry type `grant` [ versioned,
   synced, listable ], or a field on the granted entry ?
4. **holder detach** : is surviving a sessions \ cred-mesh restart needed
   now, or only with V7-HOT-SELF-RESTART ? today's dormant design can
   orphan a keyed child and accepts any same-uid redial.
5. **`host_password` in user-edit** : it is held in sessions memory and lost
   on restart. should a host account password live in the vault only
   [ the server keeps just the system's own hash in `/etc/shadow` ], with
   user-edit as the vault's editor for it ?
6. **psk \ tls-client-cert** : fields on `server` [ the exit's own secret ]
   or a generic `secret` entry type ?
7. **slot naming** : make `<record>.<use>` the rule for host-bound slots,
   and `session.<domain>` \ `api.<domain>` for site-bound ones ?
8. **one credential ui** : the user-edit grants tab, `cred-mesh.ui-show`,
   or both, with the ui rendering the grants tab
   [ the reconcile left open in the credential-types memory note ] ?

## not in this design

code, config or todo changes ; the vault agent's protocol [ Y7O \ B2K ] ;
HS4's exit attribute fields ; the ssh-agent protocol in the holder ;
rotation at external providers.

#,,.,,,.,,...,...,,,,,...,,.,,..,,.,.,.,.,,..,..,,...,...,,..,..,,.,,,.,.,,,,,
#CMOKDDP7UX2SQJ47BBD3TIG6NUJNHGT6DAA3KOZ6TA33GRH2XS6PFWGOTJKFI6ECWHWGU7U6GJMTO
#\\\|5CCWQFZNKEJZCJOFANL55XWHQZBV5ELU2TN42CYG6AG3PXSBMVE \ / AMOS7 \ YOURUM ::
#\[7]4XA3KFTSYLHV3MVWZTZS6UKOEGHLSP2ABHIERTZIJFSWCSGOGUDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
