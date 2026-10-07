# trust chain step 2 : scoped certification, owner root [ draft ]

draft 2026-10-07. builds on `HOST-ROOT-DELEGATION.md` [ step 1, live since
2026-10-07 : host-root -> cube S, clients pin the host-root fingerprint ]
and the vision in `data/ai-mem/claude/vision-2026-10-05-generic-trust-chain.md`.
DESIGN ONLY -- open decisions are marked **[ decide ]**, each with a
proposal.

## what step 1 left open

- every host is its own island : a client pins ONE fingerprint per
  `<host>_<port>`, a second host means a second TOFU pin
- host-root certifies exactly one key [ cube's S, scope '' ] ; other keys
  a host owns [ zenka keys, users' `<user>.base` ] are trusted by TOFU
  [ cube's `incoming/` pins ] or not at all
- the old cross-signing path [ `keys.console.sign-key`, `.ks \ .sk \ .rq`
  files ] signs a bare public key : no name, no expiry, no domain
  separation -- the last user of the pre-statement format

## shape

```
owner root  [ offline, one per owner ]
   |  scope '<host>.*'            -- one statement per host
host-root   [ per host, v7-zenki, root-held ]
   |  scope ''                    -- leaf : certifies nothing
service key [ cube S, a zenka key, a user key ]
```

- the SAME statement format as step 1 [ `p7 delegation v1`, no v2 ] :
  the `scope` field already exists and is the only thing that changes
  meaning
- a verifier may anchor at ANY level : pinning the owner fingerprint
  covers every host the owner certified ; pinning a host-root
  fingerprint keeps working exactly as today [ step 1 pins stay valid ]
- the presenter sends its whole chain [ leaf first ] -- verified
  locally, no lookups, no extra round trip

## scope grammar

`scope` = what the SUBJECT may certify, as a name pattern :

- `''` : nothing [ a leaf ]
- `<name>` : exactly that name
- `<prefix>.*` : any name ending in `.<something>` below `<prefix>`,
  any depth [ `atom.*` covers `atom.cube`, `atom.zenka.httpd` ]
- `*` : anything [ only an anchor's implicit scope, never issued ]

a statement is valid under its issuer when its `name` matches the
issuer's scope AND its own `scope` is within the issuer's scope [ no
widening : `atom.*` may hand out `atom.zenka.*`, never `beta.*` ].
one pattern per statement ; charset as the name rule plus a final `*`.

**[ decided : one ]** a list of patterns per statement [ `atom.*,shared.cube` ]
vs exactly one. proposal : one -- a host needing two scopes gets two
statements, the verifier stays a single string comparison per hop.

## the owner root

where its secret lives is NOT fixed by the design [ decided : keep it
flexible ]. the owner root is an ordinary C25519 key the keys zenka
already knows how to hold, in any of its existing forms :

- passphrase-derived, never stored [ `gen_keys` from `AMOS7::13::key_32`
  ; only the public half on disk ] -- re-derived for each signature
- encrypted at rest [ the `.:` encrypted-key format, password prompt ]
- seed phrase [ the `:seed-phrase` virtual key ]
- root-held [ `user-keys/root/`, like host-root ]
- plain [ `U:` ] -- allowed, discouraged, `list` marks it

the certify command only names the key and lets `crypt.C25519.
load_keypair` do what it already does for that form [ prompt, decrypt,
derive ] ; the secret is wiped after the signature. anything more
specific [ an air-gapped host, a hardware token, a split secret ] is a
WRAPPER around the command, never a restriction inside it.

`p7-keys certify-host <owner key> <host> <host-root fingerprint | pub>`
[ run wherever the owner key is ; the host-root pub comes from the
host's `.dlg` or out of band, the fingerprint must match ].

- the existing floor applies unchanged : the password prompt requires
  13 chars [ `$AMOS7::TERM::pwd_min_len` ], seed data likewise
  [ `AMOS7::13`, `$min_seed_data_len` ] -- every passphrase \ seed key
  form already goes through it, nothing new is added
- above that floor, a weak passphrase-derived owner root is a weak root :
  the command WARNS for passphrase-derived and plain owner keys, it
  NEVER refuses
  [ decided : a tool users cannot use the way they need gets
  circumvented or not adopted -- warn, explain, let them choose ].

owner statement lifetime : 365 days [ re-signed by hand ] ; host-root's
own statements stay 30 days.

## where the host-root's owner statement lives

`user-keys/root/host-root.owner.dlg` is NOT readable by cube. the chain
the server presents must be readable by the presenting process ->
proposal : `user-keys/host-root.dlg` [ public artefact beside the
service `.dlg` files, written by the certify command or copied in by
hand ]. v7-zenki appends it when it issues a service `.dlg` : the
service `.dlg` file then holds the CHAIN, one wire per line, leaf first.

## what host-root certifies [ step 2 scope ]

**[ decided ]** which service keys get statements, in order :
1. cube S [ as now ]
2. zenka keys that authenticate to OTHER hosts [ external links, the
   remote-fetch client ] -- replaces their TOFU pins on the far side
3. users' `<user>.base` keys -- a user's key certified by their host
   lets a remote cube accept `<user>@<host>` without a separate
   `incoming/` pin
names : `<host>.cube`, `<host>.zenka.<zenka>`, `<host>.user.<user>`.

## verifier changes [ `trust.verify` ]

already a chain walker [ step 1 builds it generic ]. changes :
- scope check per hop [ grammar above, no widening ]
- anchors may be any number of fingerprints [ owner + host pins mixed ]
- leaf scope stays '' for every key that authenticates a link
- chain length limit : 4 [ owner -> host -> service is 2 hops ;
  room for node groups later ]

## wire

- select reply 4th field : a chain instead of one statement. proposal :
  statements joined with `.` inside the b32 field [ `.` is not in the
  b32 alphabet ], leaf first. the 2048-char limit holds : one statement
  is ~285 chars, a 3-link chain ~860.
- discover HOST packets carry the same chain in the `dlg:` line.
- clients that only know step 1 refuse a 2-link chain [ no compatibility,
  as decided for step 1 -- every client is ours ].

## pins

- `~/.n/remote-keys/servers/<host>_<port>.public` keeps the host-root
  fingerprint ; NEW `~/.n/remote-keys/owners/<name>.public` holds owner
  fingerprints. a chain is accepted when ANY of its issuers matches a
  pin for that host OR an owner pin.
- **[ decided : no host pin ]** first contact with an owner-certified host whose owner
  is pinned : no host pin written [ the owner pin covers it ]. proposal :
  yes, write nothing -- fewer pins, rotation of host-root then needs no
  client action at all.

## sign-key migration

`keys.console.sign-key <signer> <subject>` becomes : issue a statement
[ `p7 delegation v1`, name + scope + 30 days ] with the signer's key,
written to `<subject>.dlg`. `.ks \ .sk \ .rq` writing is removed ;
`remove-signature` removes `.dlg` files ; `keys.console.list` shows
`[ certified by <issuer fp> until <date> ]`. no existing `.ks` files on
the hosts checked so far -> no data migration.

## revocation

still none beyond expiry [ step 1 : 30 days ]. an owner-signed
revocation list is a later step ; short host statements keep the window
bounded. **[ decided : yes ]** whether step 2 needs an emergency path [ e.g.
`p7-keys distrust <fingerprint>` writing a local deny file every
verifier checks ]. proposal : yes, local only, cheap.

## not in this step

- node groups, rings, re-keying [ vision steps 3-4 ]
- permission by verified name [ `access.*` keyed by `<host>.user.<u>` ]
  -- the verified name is returned ; wiring access to it is its own step
- the sourcecode key \ public-network context

## build order [ proposal ]

1. scope grammar + `trust.verify` changes + test vectors [ Perl + C ]
2. chain in the `.dlg` file, select reply, discover line [ server ]
3. owner root : certify-host command, owner pins [ client ]
4. sign-key migration
5. zenka \ user key certification [ needs 1-3 ]

## decisions [ user, 2026-10-07 ]

1. the shape, scope grammar, wire, pins, build order : as proposed
   [ one scope pattern per statement, no widening ; chain in the 4th
   select field and the `dlg:` line ; owner pins under
   `~/.n/remote-keys/owners/`, no host pin when the owner is pinned ]
2. the owner root's secret : FLEXIBLE -- any key form the keys zenka
   supports ; special set-ups are wrappers, never restrictions
3. certification order : cube S, zenka keys used across hosts, users'
   `.base` keys
4. emergency local distrust [ `p7-keys distrust <fingerprint>` ] : yes
5. passphrase-derived \ plain owner keys : the existing 13-char prompt
   minimum stays ; beyond it a WARNING only, never a refusal [ refusing
   gets circumvented or blocks adoption ]

#,,.,,,,,,..,,..,,,..,,..,...,...,...,...,,..,..,,...,...,.,.,,..,..,,.,.,,.,,
#APX7ZPMET6CWCA4IURQSBVZRQ7U6BKAC3V4BUU4PYQOZOIMDL7VXZ56CFUU6W4DRNGWWSMGD25Y3Y
#\\\|KJJFFCROVAHPRJ3GCQTZBJYLML74YN6XO6FG4Q26OKV45ABVS2Y \ / AMOS7 \ YOURUM ::
#\[7]7UZ5HLE4JOYDWCUETRQFF5ZYVN446GHETISNUJAW5WFF5NEZJUCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
