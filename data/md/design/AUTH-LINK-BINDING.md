# auth-keypair + link-upgrade : mutual binding [ wire v2 ]

decided 2026-10-06 [ user : fold the replay fix into the server proof,
NO backwards compatibility -- v1 lines are refused ]. first build step of
the trust chain [ `data/ai-mem/claude/vision-2026-10-05-generic-trust-chain.md` ].

## the gaps this closes

1. **replayable client auth** : `auth <user> <session_pub> <sig>` signs only
   the client's stable session pubkey -- no server nonce, plaintext -> one
   observed line authenticates from anywhere, forever
   [ `data/ai-mem/claude/project-2026-10-06-auth-keypair-replayable.md` ].
2. **unproven server** : the server announces `TRUE <pub>` and never proves
   it holds the key ; the link-upgrade DH is ephemeral-only -> an active
   MITM runs separate DH with each side.
3. **relayed auth** : even with a nonce, a live MITM can relay the auth
   exchange to the real server and KEEP the authenticated session [ plain
   state 1, or upgraded with its own DH ]. so a nonce alone is not enough :
   the client identity must be bound to the link-upgrade DH, and an
   auth-keypair session must not be usable before that binding completes.

## keys

- **server identity** `S` : the key cube already announces in the select
  reply [ `crypt.C25519.cmd.get-public-key`, `<user>.base` of the cube's
  unix user ] -- Ed25519. [ chaining S to `host-root` is the NEXT step,
  out of scope here. ]
- **client identity** `C` : the client's `<user>.base` key, whose public
  half the server holds as `$keys{'authorized-remote'}{<username>}`.
- the C25519 "session" key stays in the auth line as before [ TOFU
  material ], unchanged in meaning.
- link-upgrade ephemeral keys : unchanged [ curve25519, per link ].

## wire

```
-> select auth-keypair
<- TRUE <S_pub b32> <server_nonce b32>               [ nonce : 32 random bytes ]
-> auth <username> <session_pub b32> <auth_sig b32>
<- AUTH_TRUE =)                                      [ session state 1, BINDING PENDING ]
-> link-upgrade                                      [ the only command accepted now ]
<- TRUE link-upgrade OK <server_eph b32>
-> link-pub-key <client_eph b32>
<- SIZE 0
-> link-confirm-encoding <enc>
<- encoding-confirmed
-> link-complete <nonce_sid> <client_bind_sig b32>
<- link-complete-ok <server_bind_sig b32>            [ still plaintext ]
   [ state 3, encrypted ; binding complete ]
```

refuse [ disconnect, log level 0 ] : an auth line with fewer than three
fields after the user or a bad sig ; `link-complete` without a valid
client_bind_sig on a binding-pending session ; ANY command other than
`link-upgrade` [ and the state 2 negotiation lines ] while binding is
pending. a select reply without the nonce field -> the client refuses.

## signed messages [ exact bytes ]

all fields fixed length except the length-prefixed strings ; `pack`
templates given so Perl and C produce identical bytes.

```
auth_sig        = Ed25519_sign( C,
    pack( 'Z* a32 a32 a32 n/a*',
        'p7 auth-keypair v2', server_nonce, S_pub, session_pub, username ) )

bind_transcript = pack( 'a32 a32 a32 a32 N n/a* n/a*',
        server_nonce, S_pub, server_eph, client_eph, nonce_sid,
        encoding, username )

client_bind_sig = Ed25519_sign( C, pack( 'Z*', 'p7 link-bind v1 client' ) . bind_transcript )
server_bind_sig = Ed25519_sign( S, pack( 'Z*', 'p7 link-bind v1 server' ) . bind_transcript )
```

- `Z*` = the label plus ONE \0 byte ; `n/a*` = 16-bit big-endian length,
  then the bytes ; `N` = 32-bit big-endian.
- `encoding` = the exact string sent in `link-confirm-encoding` [ `none`
  when none ].
- distinct labels per message and per role : no signature is valid as
  another kind [ also not as a `crypt.C25519.sign_keys` `.sig.*` file,
  which signs a bare 32-byte pubkey ].
- server verifies client_bind_sig with `authorized-remote{username}` ;
  client verifies server_bind_sig with the S_pub it PINNED [ below ].

## server state

- `auth.auth_select` [ auth-keypair ] : 32 bytes from `base.prng.bytes`
  -> `$data{'session'}{$id}{'auth'}{'server_nonce'}` ; also store the raw
  S_pub sent.
- `plugin.auth.auth-keypair` : v2 message only ; on success set
  `$data{'session'}{$id}{'link_binding'} = qw| pending |` and keep the
  verified username's C public key reachable for link-complete.
- state 1 command dispatch : while `link_binding` is `pending`, only
  `link-upgrade` passes ; anything else -> FALSE + disconnect.
- `base.handler.link-upgrade` : keep the client eph pubkey [ it is decoded
  there today ] ; at `link-complete` verify client_bind_sig BEFORE
  answering ; append server_bind_sig to `link-complete-ok` ; then
  `link_binding = done`. the server nonce is single-use : delete it after.
- sessions authenticated by other methods [ unix, zenka ] : unchanged,
  no binding requirement.

## client side

- pin store : `~/.n/remote-keys/servers/<host>_<port>.public` [ S_pub b32 ].
  first contact : pin it, log level 0 `pinned server key <fingerprint>` ;
  later mismatch -> refuse [ fail closed ], never re-pin automatically.
  a pin file exists but is unreadable -> refuse.
- Perl : `auth.client.auth-keypair.authenticate` builds the v2 auth_sig
  and RETURNS the binding context [ server_nonce, S_pub, username, the C
  key name ] ; `protocol.protocol-7.link-upgrade.handshake` takes it,
  sends `link-complete <n> <client_bind_sig>` and verifies the server's
  sig ; any failure -> ( 0, { error } ). callers : `external.link.open`,
  `users.remote_fetch.run` [ which must now also do the link-upgrade
  before sending anything -- reuse handshake + client_activate the way
  external.link.open does ].
- C : `bin/c_src/p-7-r.c` + `bin/p7-auth-keypair-helper.pl` +
  `bin/p7-link-upgrade-helper.pl` [ new helper verbs that take the
  context fields as b32 args and print b32 ].

## not in this step

- chaining S to host-root \ delegation statements \ `trust.verify`
- re-keying, revocation
- the fresh C25519 session key per connection [ stays stable, TOFU ]

## hardening rules [ review 2026-10-06 ]

- **fail closed on "pending"** : a binding-pending session must look
  UNAUTHENTICATED to everything that trusts the flag -- set
  `{'authenticated'} = qw| pending |` [ never `yes` ] in `base.handler.auth`
  for auth-keypair, and defer the `$data{'user'}{<name>}{'session'}{<id>}`
  registration ; readers today : `base.handler.command.route_to_target`
  [ cfg_bool -> false for 'pending' ], `base.protocol-7.command.send.local`
  [ ne 'yes' ], `base.cmd.exit` [ exists ]. both flip to `yes` \ registered
  only after client_bind_sig verifies [ factor the registration block out
  of base.handler.auth into one sub both paths call ].
- **sign with exactly the announced key** : at select time store the
  KEY NAME and raw S_pub together ; at link-complete sign with that name
  and first assert the loaded public key eq the stored S_pub [ refuse
  otherwise ] -- never rely on `sign_data(undef)` resolving the same way.
- `nonce_sid` is REQUIRED on a pending session, 1 .. 2**32-1.
- any state 2 failure on a pending session DISCONNECTS [ never a fallback
  to state 1 ].
- the server nonce is deleted on EVERY exit path [ success, failure,
  timeout, disconnect ].
- client order : check the pin when the select reply arrives, BEFORE the
  auth line is sent.
- helper verbs [ C client ] take only PUBLIC values on argv -- secrets via
  stdin or a 0600 temp file.

## test vector [ both implementations MUST reproduce it byte for byte ]

throwaway keys from fixed seeds [ `Crypt::Ed25519::generate_keypair` of
32 x `\x01` = C, 32 x `\x02` = S ] -- test only, never real.

```
server_nonce = 32 x \x11      session_pub = 32 x \x22
server_eph   = 32 x \x33      client_eph  = 32 x \x44
nonce_sid    = 305419896 [ 0x12345678 ]
encoding     = none           username    = test-user

C pub b32        : RKEOHXLUBHYZL7KS3MWTZOS5OLFGOCN7DWKBEG7TOSEADNAPN5OA
S pub b32        : QE4XODVIPULV6VVDKRTMGTD6ZTFY3CURWTXDPIS56YHVXD6JWOKA
auth msg hex     : 703720617574682d6b6579706169722076320011111111111111111111111111111111111111111111111111111111111111118139770ea87d175f56a35466c34c7ecccb8d8a91b4ee37a25df60f5b8fc9b39422222222222222222222222222222222222222222222222222222222222222220009746573742d75736572
auth_sig b32     : NJHBPUDRFYSLYCCZ57DJN5OVNOIWSNWGU7QZZJU26ZT445Q3PBQOUCUQS36W5KFEFYIBSDSY4XZD6FCWC6TETBCBSQWI7ICVRMTCUCI
transcript hex   : 11111111111111111111111111111111111111111111111111111111111111118139770ea87d175f56a35466c34c7ecccb8d8a91b4ee37a25df60f5b8fc9b394333333333333333333333333333333333333333333333333333333333333333344444444444444444444444444444444444444444444444444444444444444441234567800046e6f6e650009746573742d75736572
client_bind_sig  : ANRNMKHTKZ6QDI2EJOUZYXZSNKLQQY3TF57NXSNREYEX3PDVL6KEVQ2LLLTS3V26U4GSKYVC6XCFO2U7BU5JQXEGLHCGPKDJ6HLYSDA
server_bind_sig  : KLXXZEZPHTKESLFK7NLYD4VZBXWEEP3WQG4T62UKGIFHNUOUW3A7ZEVM4BIFC5TQUW3DJJG37XQYJRZFSVXWHPYZZYJ5RWJDVPKHUDA
```

b32 = `Crypt::Misc::encode_b32r` [ RFC 4648 alphabet, no padding ].

#,,,,,.,.,,,,,..,,..,,,,,,.,,,,.,,.,,,.,,,.,.,.,.,...,...,..,,,..,...,,.,,...,
#AGMGR53VFTPN7K32M24H44PVCA2SOZFRMMO4WVSWVML2ZDC5NBK67EZHXWGT5XVPA6EVP2DO67HO2
#\\\|MN67EP7KLOMMKRTPTSWM6TBCAAD6NIXVCX6MJ762FD3ZASDZMER \ / AMOS7 \ YOURUM ::
#\[7]7ZJDM6IQBFCHRDTSJZKUIRFAX7W3RMIB6N2RUDJQRLYL4NJ24GBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
