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
- **pin** = the host-root KEY ID [ bmw384 B32 of the host-root
  public key, 77 chars -- the osf-cache id format ], not S. the full
  host-root pub travels in the statement ; the key id authenticates
  it.
- **verify** [ client, every connection ] : key id(issuer pub) ==
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
  holds the host-root KEY ID [ 77 chars ] -- **[ decide ]** keyed by
  host:port [ as now ] or by the key id's claimed name [ one pin
  per host for all ports ] ; proposal : keep host:port for this step.
- first contact : pin the key id, log level 0 with the key id +
  the delegated name, so it can be checked out of band [ `p7c
  crypt.C25519.host-root-id` on the server -- new command ].
- S may change freely [ rotation ] as long as host-root delegates it.
- Perl : `auth.client.server_pin.check` + `auth.client.auth-keypair.
  authenticate` ; C : `p7-auth-keypair-helper.pl check-pin` [ same
  verify, one shared statement parser per language ].

## trust.verify [ generic, the vision's verifier ]

this step needs ONE hop. build it as the generic walker anyway, with a
one-hop chain as its first user :

```
trust.verify( { chain => [ statement, .. ], anchors => [ key id, .. ],
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

## decisions [ user, 2026-10-06 ]

1. the delegation travels as a REQUIRED 4th field of the select reply
   [ no compatibility ]
2. lifetime 30 days, v7-zenki renews when < 7 days remain
3. host name = `<system.node.name>` lowercased [ `hostname()` without the
   domain, set by `bin/Protocol-7` ; `<system.hostname>` is never set ] ;
   `not_before` = issue time - 300 s [ client clock skew ]
4. pins stay keyed by `<host>_<port>`, content = host-root key id
5. v7-zenki runs as ROOT, cube as the backend user [ `protocol-7` ].
   host-root lives in the BACKEND user's key tree, in a root-held
   subdirectory : `user-keys/root/` [ below ]
6. finding : host-root was NEVER created -- `crypt.C25519.post_init`
   returns early when `auto_load_keys` is off, and v7-zenki sets
   `crypt.C25519.auto_load_keys = 0` [ cfg/zenki/v7-zenki/zenka.v7, every
   start profile ]. host-root creation must not depend on that switch.

## root-held keys : `user-keys/root/`

`<backend home>/.n/user-keys/root/` holds every key only root may use
[ host-root first ; later owner \ group roots ]. `<backend home>` =
home of `<system.amos-zenka-user>` -- the SAME tree whichever user the
process runs as.

- **marker = location** : a key is root-held iff its files are in
  `root/`. no list of names.
- **ownership rule** [ checked on EVERY read, fail closed ] : `root/` is
  a real directory [ not a symlink ], owned by uid 0, mode 0700 [ no
  group \ other bits ] ; each key file a regular file [ not a symlink ],
  uid 0, mode 0600 [ public may be 0644 ]. anything else -> refuse +
  level 0 log. a protocol-7 process can rename \ delete `root/` [ it
  owns the parent ] but cannot create a root-owned replacement -> the
  worst case is a fresh host-root nobody knows [ clients refuse :
  denial of service, never impersonation ].
- **creation** : only when running as root ; `mkdir 0700` + chown 0:0 ;
  files written via temp + rename inside `root/`, 0600, owner 0.
- **non-root processes** [ cube ] never read `root/` -- they read only
  public artefacts written OUTSIDE it [ the `.dlg` statement ].

### resolver API [ fixed here so lanes can build in parallel ]

```
<[crypt.C25519.key_path]>->( <key name>, { holder => 'root' } ? )
  -> { key_dir, key_basepath, key_filename => { secret private public
       virtual }, holder => 'user'|'root' }   or undef [ + logged why ]
```

- no `holder` option : `root` if `<backend key dir>/root/<name>.public`
  or `.secret` exists, else `user` [ today's key dir, unchanged ]
- `holder => 'root'` : forces `root/` [ used to CREATE host-root ]
- for `root` : the ownership rule is checked here ; violated -> undef
- `crypt.C25519.key_vars` uses it for `key_dir` \ `key_basepath` \
  `key_filename` ; `key_exists`, `keyfiles`, `load_keypair`,
  `write_keys` go through key_vars \ key_path -- no other place builds
  a key file path
- `crypt.C25519.root_key_dir` : `<backend key dir>/root` [ for listing ]
- as built [ 2026-10-07 ] : for `root` the checked root/ is held OPEN ;
  `key_basepath` \ `key_filename` go through it [ `key_dir_fd` =
  `/proc/self/fd/<n>` ] so a swap of root/ after the check cannot
  redirect a read or write. `key_dir` stays the PLAIN path [ display,
  comparisons ] -- never build a key file path from it. no /proc :
  root-held keys refused. as non-root a root-held name resolves to
  `user` [ root/ 0700 : the kernel decides ], forcing `root` is refused.

## delegation file

- `<backend key dir>/<S name>.dlg` [ e.g. `protocol-7.base.dlg` ], one
  line = the wire b32 ; written by v7-zenki [ root ] via temp + rename,
  chown to the backend user, 0644
- v7-zenki issues it at post-drop startup and from a daily timer
  [ NOT in init_code : it runs before drop_privs, see ai-mem
  `feedback-init-code-runs-before-drop-privs` -- v7-zenki stays root
  anyway, but keep the issuing in a post-init \ startup callback ]
- cube reads it at select time, every time [ no caching across renewals ]

## host-root key id

`bmw384` of the 32-byte public key, `encode_b32r` -> 77 chars [ the
osf-cache id ; use the same Digest::BMW call osf-cache uses ]. new cube
command `crypt.C25519.cmd.host-root-id` returns it from the
`.dlg` [ cube cannot read root/ ] so it can be compared out of band.

## acceptance rules [ shared by the Perl and C clients, 2026-10-06 ]

1. **pin file** : `~/.n/remote-keys/servers/<host>_<port>.public` holds
   exactly `<77 char host-root key id>\n`, key id =
   `encode_b32r( bmw_384( <raw 32 byte issuer pub> ) )`. an existing 52
   char [ old S_pub ] pin is REFUSED -- never migrated, never re-pinned.
   unreadable \ empty \ corrupt pin : refused.
2. **delegation acceptance order** : exact parse [ the literal bytes
   `p7 delegation v1\0`, every length checked, NO trailing bytes,
   canonical b32 ] -> sig under the issuer pub -> `not_before <=
   not_after` and `not_before <= now <= not_after` [ both inclusive ] ->
   subject eq the announced S_pub -> name charset -> scope. in THIS step
   the leaf statement's scope must be EMPTY [ non-empty : refused ] ; the
   anchor's scope is `*`. scope grammar beyond `''` \ `*` is not defined
   yet : any other value refuses.
3. **size** : the 4th select field is at most 2048 b32 chars ; longer is
   refused by the client and never emitted by the server.
4. **name** : `^[A-Za-z0-9][A-Za-z0-9._-]{0,254}$` [ safe to print ] ; NOT
   bound to the connected host [ IP connects must work ], no `.cube`
   suffix requirement on the client.
5. an invalid delegation is a refusal BEFORE any auth line is sent ; the
   pin is written only after the delegation verified.

## modules [ Perl ]

- `trust.statement` : `( 'build', { issuer_pub subject_pub name
  not_before not_after scope } )` -> statement bytes ;
  `( 'parse', <bytes> )` -> fields hash ; `( 'parse_wire', <b32> )` ->
  fields + `statement` + `sig` ; `( 'wire', <statement>, <sig> )` -> b32.
  undef on any invalid input [ list context : `( undef, reason )` ]
- `trust.key_id( <32 byte pub> )` -> 77 chars
- `trust.verify( { chain anchors subject now } )` -> `{ name anchor
  issuer_pub not_after }` or undef [ list : `( undef, reason )` ]

## test vector [ Perl and C MUST reproduce it byte for byte ]

throwaway keys from fixed seeds [ `Crypt::Ed25519::generate_keypair` of
32 x `\x03` = host-root, 32 x `\x02` = S -- the AUTH-LINK-BINDING S ] --
test only, never real.

```
name        = test-host.cube
not_before  = 1700000000      not_after = 1702592000 [ + 30 d ]
scope       = ''

host-root pub b32 : 5VESRRRI2HBMN2XJAM4JAWMVMEUVSJZ2LRR7SNRWYFDBJLEHG7IQ
S pub b32         : QE4XODVIPULV6VVDKRTMGTD6ZTFY3CURWTXDPIS56YHVXD6JWOKA
statement hex     : 70372064656c65676174696f6e20763100ed4928c628d1c2c6eae90338905995612959273a5c63f93636c14614ac8737d18139770ea87d175f56a35466c34c7ecccb8d8a91b4ee37a25df60f5b8fc9b394000e746573742d686f73742e637562656553f100657b7e000000
sig b32           : LAL3UIQD4LJVCGNJWXL3TO7DZUD2PCAJ43B2XXPTNWQAQZDDX7GPYH3DYOFIJZUJEUDB2MKQSBZ4HSXBGCQX4GM5LOA4IOSEBMPFQAQ
wire b32 [ 274 ]  : OA3SAZDFNRSWOYLUNFXW4IDWGEAO2SJIYYUNDQWG5LUQGOEQLGKWCKKZE45FYY7ZGY3MCRQUVSDTPUMBHF3Q5KD5C5PVNI2UM3BUY7WMZOGYVENU5Y32EXPWB5NY7SNTSQAA45DFON2C22DPON2C4Y3VMJSWKU7RABSXW7QAAAAFQF52EIB6FU2RDGU3LV5ZXPR42B5HRAE6NQ5L3XZW3IAIMRR37TH4D5R4HCUE42ESKBQ5GFIJA46DZLQTBIL6DGOVXAOEHJCAWHSYAI
key id       : ZF3ZY24EH66GU56YWPU2R2ZOXZLRVEUQJGHM3AWUQWVUNEJIYFOXRWF4XUSHAAXSUFOXWG2JGKC7G
```

computed independently [ hand-written pack ] and by `trust.statement` ;
identical to lane 3's self-built vector.

#,,.,,.,.,,.,,,,.,,,.,,.,,,..,,..,...,,,.,,,.,..,,...,...,,.,,...,,..,,..,,,.,
#3I7DU44CUYBA32USQJ5WAR3Y2R6BUXH4ST6QZIS6UGSLVMUF4WCNOZ7F4JTUOUSELSLUOZMH2OXDW
#\\\|QHC24BFQSQM7A5TOPBIGHJFFBGACGYSX4FWYDKOBBFU67EX2PNK \ / AMOS7 \ YOURUM ::
#\[7]T4KSFXFYQCVWCN6IHC3LL24KVA5QNIWR4KTJLJUR5SWTDXMVYGAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
