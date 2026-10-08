# trust chain step 2 : scoped certification, owner root [ draft ]

draft 2026-10-07. builds on `HOST-ROOT-DELEGATION.md` [ step 1, live since
2026-10-07 : host-root -> cube S, clients pin the host-root key id ]
and the vision in `data/ai-mem/claude/vision-2026-10-05-generic-trust-chain.md`.
DESIGN ONLY -- open decisions are marked **[ decide ]**, each with a
proposal.

## what step 1 left open

- every host is its own island : a client pins ONE key id per
  `<host>_<port>`, a second host means a second TOFU pin
- host-root certifies exactly one key [ cube's S, scope '' ] ; other keys
  a host owns [ zenka keys, users' `<user>.base` ] are trusted by TOFU
  [ cube's `incoming/` pins ] or not at all
- the old cross-signing path [ `keys.console.sign-key`, `.ks \ .sk \ .rq`
  files ] signs a bare public key : no name, no expiry, no domain
  separation -- the last user of the pre-statement format

## terms [ 2026-10-08 ]

- **key id** : `trust.key_id` = b32 of bmw384 over the raw public key [ 77
  chars ]. what pins, anchors, distrust entries and owner pins hold ; ONE
  fixed-size identity for any key type [ post-quantum public keys are KB,
  they cannot be pinned directly ]. compare the FULL key id when it
  matters [ `p7c host-root-id` ].
- **label** : the first 7 chars of a key id, shown by `p7-keys list` to
  RECOGNISE a pin -- never a verification [ 35 bits ].
- not a 'fingerprint' : a 384 bit hash of a 256 bit key is longer than
  the key ; 'fingerprint' stays the short AMOS key checksums of `keys
  list` [ `<:..:..:>` ].

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
- a verifier may anchor at ANY level : pinning the owner key id
  covers every host the owner certified ; pinning a host-root
  key id keeps working exactly as today [ step 1 pins stay valid ]
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
issuer's scope AND its own `scope` is STRICTLY narrower than the
issuer's scope, or `''` [ authority only flows downward and never
copies itself : `atom.*` may hand out `atom.zenka.*` or `atom.cube`,
never `atom.*` again, never `beta.*` ; under an exact `<name>` scope only
`''` ]. a scope `*` is never issued [ only an anchor's implicit scope ].
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

`p7-keys certify-host <owner key> <host> <host-root key id | pub>`
[ run wherever the owner key is ; the host-root pub comes from the
host's `.dlg` or out of band, the key id must match ].

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
- anchors may be any number of key ids [ owner + host pins mixed ]
- leaf scope stays '' for every key that authenticates a link
- chain length limit : 4 [ owner -> host -> service is 2 hops ;
  room for node groups later ]

## wire

- select reply 4th field : a chain instead of one statement. proposal :
  statements joined with `.` inside the b32 field [ `.` is not in the
  b32 alphabet ], leaf first. the 2048-char limit holds : one statement
  is ~285 chars, a 3-link chain ~860.
- discover HOST packets carry the same chain in the `dlg:` line.
- the server verifies the LEAF under its own issuer first [ as in step 1
  ; failing : refused ] ; the chain above it is sent only while the whole
  chain verifies, else the leaf goes alone [ one level 0 line per change ]
  -- an owner statement expiring between two daily `delegation.issue`
  runs must not refuse every select. one parser for the field and the
  file : `trust.chain` [ twin : the helper's `chain_split` ] -- the only
  place the leaf-first \ anchor-most-first order flips.
- clients that only know step 1 refuse a 2-link chain [ no compatibility,
  as decided for step 1 -- every client is ours ].

## pins

- `~/.n/remote-keys/servers/<host>_<port>.public` keeps the host-root
  key id ; NEW `~/.n/remote-keys/owners/<name>.public` holds owner
  key ids. a chain is accepted when ANY of its issuers matches a
  pin for that host OR an owner pin.
- **[ REVISED 2026-10-07 : name-bound host pin ]** the earlier 'no host
  pin' decision left a gap : no client checks the leaf name against the
  host it dialled, so with only an owner pin ANY host the owner certified
  [ a compromised `beta` ] could answer on `atom:port` with its valid
  `beta.cube` chain. now : first owner-verified contact WRITES the host
  pin, holding the host-root key id AND the leaf name [ `atom.cube` ].
  a later host-root change is accepted [ level 0 log, pin rewritten ]
  only when an owner pin covers the new chain AND the leaf name equals
  the pinned name ; otherwise refused as today.
- an owner key id is NEVER pinned from first contact [ an anchor's
  implicit scope is `*` : one TOFU would grant authority over every
  name ] -- owner pins come only from an explicit command. TOFU without
  an owner pin pins the leaf's issuer [ the host-root ], as in step 1.
- a pinned NAME never changes : a matching host-root presenting another
  leaf name is accepted but the pin is not rewritten [ level 0 note ] --
  otherwise one statement from atom's host-root naming `beta.cube` would
  relabel the atom pin and make beta's chain rotate it. only a step 1 pin
  [ no name ] gains its name.
- rotation is FORWARD only : the pin keeps `since` [ line 3 : the
  not_before of the owner-verified statement certifying the pinned
  host-root, 0 when never owner-verified ] ; a rotation needs a strictly
  later certifying statement. a compromised OLD host-root under a still
  valid owner statement [ 365 days, no revocation ] cannot rotate back.
- pin file : line 1 key id, line 2 leaf name, line 3 since [ lines 2
  \ 3 optional ; discover and the C client read line 1 only ].
- the pin decision [ verdict + what to write : none \ new \ replace ] is
  `trust.pin_decide` \ the helper's `pin_decide`, shared test vectors in
  `bin/test-scripts/trust-pin-vectors.pl` [ host pin none \ match \
  mismatch \ step 1 x owner pin none \ covers \ foreign x distrust,
  rename, rotate back \ forward ] ; the io layers only do what it says.

## management tools [ landed 2026-10-08 ]

`p7-keys certify-host \ accept-owner \ owner-pin \ owner-unpin \
owner-pins \ distrust \ undistrust`, `p7c v7-zenki.delegation-issue`.
every removal or replacement [ `remove known:<host>`, `owner-unpin`, a
distrust list rewrite, a replaced owner statement ] goes to the trash :
`~/.n/remote-keys/trash/<kind>/<name>.<epoch>.mxz.B32` [ xz + b32, 0600,
decoded back and compared BEFORE the original goes ]. `undo-remove
<[kind:]name> [stamp]` brings it back -- a live file is trashed first, so
an undo is undoable ; `removed` lists the trash. auto-purge is the
exception : only entries older than 90 days AND not among the newest 3
of their name ; asked interactively [ a TTY, at most daily, default keep
] or `removed purge ::yes::` -- never silently.

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
`p7-keys distrust <key id>` writing a local deny file every
verifier checks ]. proposal : yes, local only, cheap.

## later : a dns back channel [ user, 2026-10-08 -- design only ]

a signed, read-only query channel at the lowest protocol level : any
fqdn extended with a NETWORK TIMESTAMP label marks protocol activity
without colliding with a real subdomain [ no real host is named after an
ntime ], and dns passes where proxies do not.

- **name** : `[<arg>.]<command>.<ntime-bucket>.<fqdn>` -- TXT. the bucket
  is the network time [ b32, lowercase on the wire ] rounded to a bucket
  length ; a client accepts answers for buckets within +- N of its own
  network time [ the validation range ; also a coarse clock-skew check ].
  a new name per bucket defeats stale resolver caches past one bucket.
- **commands** : a fixed allow-list of READ-ONLY, PUBLIC queries --
  `revoked` [ the owner-signed distrust \ revocation head ], `rotation.
  <host>` [ host-root rotated, since X -- feeds forward-only rotation ],
  `head.<log>` [ a key-activity \ transparency head ], `time` [ the
  answering bucket ]. never anything that changes state.
- **integrity from signatures, never from dns** [ no DNSSEC assumed ] :
  the answer is a signed statement over the WHOLE query name [ command,
  args, bucket ] -- an answer cannot be replayed under another bucket or
  served for another command \ host. verified against what the client
  already pins [ owner \ host-root key ids ].
- **size** : compact form in one 255 char TXT string -- a bmw384 digest
  [ 77 ] + an Ed25519 signature [ 103 b32 ] ~ 180 chars ; the full content
  [ the list itself ] over a normal link when the head changes. a 77 char
  key id exceeds the 63 char label limit : short form in the name, the
  full key id inside the signed answer.
- **hygiene** : TTL <= the bucket length ; small answers + per-source rate
  limiting [ TXT answers are larger than queries : amplification ] ;
  larger replies over tcp or a link. best effort only -- a resolver that
  drops answers blocks it, so it is never the only path. no SRV with
  real ports [ the same exposure kept out of the repo ] -- discovery, if
  ever, as signed opaque TXT.
- **where** : the nameserv zenka [ authoritative, Net::DNS ] already routes
  one query-name prefix to a computed answer [ `_protocol7._tcp.*` ->
  nameserv.handler.p7ref_lookup ] -- the back channel is a second computed
  route, keyed on the ntime label.

## later : self-propagating statements [ user, 2026-10-07 ]

optional propagation of authoritative statements in EITHER direction
during a connect, so that afterwards a node can prove its trust chain
STANDALONE -- even when the node that signed it is offline again.

- statements are self-contained [ signed bytes, issuer pub inside, an
  expiry ] : anyone may store and forward them, nobody can alter them ;
  verifying needs only the anchor pin, never the signer online
- **upward** : a node collects the statements ABOVE it [ host-root's
  owner statement from the owner, a group's statement from the group ]
  and presents the full chain itself from then on
- **downward \ sideways** : a peer that verified a chain keeps it [ by
  statement checksum, until not_after ] and may hand it on -- e.g. B
  vouches for C's chain to A while C's issuer is unreachable ; A still
  verifies every signature itself, the forwarder is never trusted
- store : verified statements under a per-node cache [ keyed by
  checksum, dropped at not_after, never a pin ] ; presenting = picking
  the shortest chain from the cache up to any anchor the peer pins
- OPTIONAL per node and per direction [ a node may refuse to collect \
  forward ] ; propagation is offered, never required for a connect
- open : how a peer says which anchors it pins without leaking its pin
  list [ offer all held chains vs a key id hint ] ; cache bounds ;
  interaction with a future revocation list [ a forwarded statement
  outlives a revocation only until its not_after -- short lifetimes
  keep that window bounded ]

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
4. emergency local distrust [ `p7-keys distrust <key id>` ] : yes
5. passphrase-derived \ plain owner keys : the existing 13-char prompt
   minimum stays ; beyond it a WARNING only, never a refusal [ refusing
   gets circumvented or blocks adoption ]
6. [ 2026-10-07 ] owner-pinned first contact : name-bound host pin with
   automatic host-root rotation [ see 'pins' ] -- replaces 'no host pin'

## direction [ user, 2026-10-07 ]

multiple hosts by DEFAULT : complete the missing links of the chain and
add the management tools around it [ certify, accept, pin, distrust,
list ] ; if needed the user-edit zenka is cloned into a host-edit zenka ;
plus resilient initial transport types, so adding a host to a network
[ and everything around that ] becomes one smooth interaction.

#,,.,,,,,,..,,..,,,..,,..,...,...,...,...,,..,..,,...,...,.,.,,..,..,,.,.,,.,,
#APX7ZPMET6CWCA4IURQSBVZRQ7U6BKAC3V4BUU4PYQOZOIMDL7VXZ56CFUU6W4DRNGWWSMGD25Y3Y
#\\\|KJJFFCROVAHPRJ3GCQTZBJYLML74YN6XO6FG4Q26OKV45ABVS2Y \ / AMOS7 \ YOURUM ::
#\[7]7UZ5HLE4JOYDWCUETRQFF5ZYVN446GHETISNUJAW5WFF5NEZJUCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
6. scope is DOWNWARD and immutable : a subject's scope must be strictly
   narrower than its issuer's [ or empty ] -- no equal re-delegation

#,,,.,,,.,.,,,..,,...,.,,,.,.,...,,,,,,.,,,,,,..,,...,...,...,.,,,.,,,...,,,.,
#NS32KX5SCIEUJ6EKEDXWW5YFNCB5HNNUWUUOEO5MYBTRLXBG3MZ3NHLINPBKBPBZCAQ6WDLEF2ANE
#\\\|SZU223C5Z6RMM4QJUVBW5PVATYUWHOGKWWMO5MPUN5U7LFDF2PV \ / AMOS7 \ YOURUM ::
#\[7]2675AZYCQ32IBMBMR2SCPG5UC4RIQADSNGH2IDN5KZAGFP4SQ2CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
