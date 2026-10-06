# host-root delegation : chaining the server key to host-root [ draft ]

draft 2026-10-06. the step after [ `AUTH-LINK-BINDING.md` ]
[ `ad31ddd5a` ] in the trust chain build order
[ `data/ai-mem/claude/vision-2026-10-05-generic-trust-chain.md`, step 1 ].
DESIGN ONLY -- open decisions are marked **[ decide ]**.

## why now

auth-link binding makes the server PROVE it holds S [ the cube's
`<user>.base` key ], and clients pin S per host:port. pinning S is the
leaf-level TOFU the vision wants to avoid:
- S can't rotate without every client failing closed [ mismatch ]
- every service on a host [ cube, later other zenki \ hosts behind one
  owner ] is a separate pin
- nobody has pinned anything yet [ binding is not live ] -> changing what
  the pin MEANS now costs nothing. after the live check, every client has
  an S pin to migrate.

## shape

- **anchor** = `host-root` [ Ed25519, random per host, created by
  v7-zenki's first start ; `crypt.C25519.post_init` ]. its secret stays
  where it is ; only v7-zenki loads it.
- **delegation statement** : host-root signs "key S is `<host>.cube`
  until T". stored next to S, sent by the server inside the select reply.
- **pin** = the host-root FINGERPRINT [ bmw384 B32 of the host-root
  public key, 77 chars -- the osf-cache id format ], not S. the full
  host-root pub travels in the statement ; the fingerprint authenticates
  it.
- **verify** [ client, every connection ] : fingerprint(issuer pub) ==
  pin ; statement sig valid under issuer pub ; subject == the S that
  then signs the link transcript ; name within the issuer's scope ; not
  expired. then the existing binding checks run unchanged with S.

## statement [ binary, exact bytes ]

```
statement = pack( 'Z* a32 a32 n/a* N N n/a*',
    'p7 delegation v1',
    issuer_pub,          # host-root public key
    subject_pub,         # S
    name,                # '<host>.cube'
    not_before,          # unix seconds
    not_after,           # unix seconds
    scope )              # what subject may certify : '' = nothing
sig = Ed25519_sign( host-root, statement )
wire = b32( statement . sig )
```

- one label [ distinct from the auth \ link-bind labels : no signature is
  valid as another kind ]
- times as unix seconds [ the link code already uses `time()` ; ntime is
  for display ]
- `scope` empty in this step [ S certifies nothing ] ; the field exists
  so step 2 [ host-root certifying zenka keys, owner root above ] does
  not need a v2 statement

## wire change [ on top of auth-keypair v2 ]

```
<- TRUE <S_pub b32> <server_nonce b32> <delegation b32>
```

**[ decide ]** a 4th field in the select reply [ simplest, one round
trip, keeps the pin check BEFORE auth ] vs a separate pre-auth command.
proposal : the 4th field, required -- no compatibility [ same rule as v2 ].

the bind transcript does not change : S already signs it. the delegation
is bound because the client only accepts S if the statement verified.

## server side

- statement file : `<key_dir>/<S name>.dlg` [ the wire b32, one line ]
- **issued by v7-zenki** [ holds host-root ] : at start and from a daily
  timer, for every local service key it manages [ this step : cube's S
  only ], when missing or within the renewal margin of `not_after`.
  written atomically [ temp + rename ], readable by the cube user.
- cube reads the `.dlg` at select time ; missing \ expired \ subject !=
  announced S -> refuse auth-keypair [ fail closed, level 0 log ].
- **[ decide ]** lifetime : proposal 30 days, renewed when < 7 days left.
  short enough to matter as a revocation substitute for now, long enough
  that a v7-zenki outage of days does not cut hosts off.
- **[ decide ]** `<host>` : `<system.hostname>` lowercased. or a
  configured `host.name` [ multi-homed \ renamed hosts ] ?

## client side

- pin file stays `~/.n/remote-keys/servers/<host>_<port>.public` but now
  holds the host-root FINGERPRINT [ 77 chars ] -- **[ decide ]** keyed by
  host:port [ as now ] or by the fingerprint's claimed name [ one pin
  per host for all ports ] ; proposal : keep host:port for this step.
- first contact : pin the fingerprint, log level 0 with the fingerprint +
  the delegated name, so it can be checked out of band [ `p7c
  crypt.C25519.host-root-fingerprint` on the server -- new command ].
- S may change freely [ rotation ] as long as host-root delegates it.
- Perl : `auth.client.server_pin.check` + `auth.client.auth-keypair.
  authenticate` ; C : `p7-auth-keypair-helper.pl check-pin` [ same
  verify, one shared statement parser per language ].

## trust.verify [ generic, the vision's verifier ]

this step needs ONE hop. build it as the generic walker anyway, with a
one-hop chain as its first user :

```
trust.verify( { chain => [ statement, .. ], anchors => [ fingerprint, .. ],
                subject => <pub>, now => <unix> } )
  -> { name => .., anchor => .. }  or  undef + reason
```

walk from the anchor down : each statement's issuer == the previous
subject [ or an anchor for the first ], sig valid, now within
[ not_before, not_after ], name within the issuer's scope [ the anchor's
scope = '*' for this step ], last subject == `subject`.

## not in this step

- owner root above host roots, node groups, rings [ vision steps 2-4 ]
- revocation lists [ short expiry stands in ]
- "offer the HIGHEST verified parent for trusting" UI
- the sourcecode key \ public-network context

## open questions for the user

1. the 4th select field vs a separate command
2. lifetime 30 d \ renew at 7 d
3. host name source : `<system.hostname>` vs a configured name
4. pin keyed by host:port [ now ] vs by name
5. which unix user v7-zenki runs as vs cube : the `.dlg` must be
   written by v7-zenki and read by cube [ same `protocol-7` user ? verify
   on atom before building ]

#,,.,,,.,,.,,,,,,,.,.,...,.,,,.,.,.,.,,.,,,,,,..,,...,...,.,.,.,,,.,.,.,.,...,
#5FD54OT7IYPRTTU7SVIQHSWAQCWIJZ6R4F7CH5MIERJBQUXLNF6YPHCQVNND4VI3PLLZRBRNK3PHW
#\\\|YJS5KTMULN4OTNWMC4DNL4XNGBTVZVNNQYR75GO7PPPHF6CZKRZ \ / AMOS7 \ YOURUM ::
#\[7]KBTU2AJLXAP3WJXU4I5K6ZN73SYUVY4TPHNX7Q7J6DNOX3LFEKAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
