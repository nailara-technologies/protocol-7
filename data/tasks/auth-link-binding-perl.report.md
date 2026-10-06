# auth-link-binding : PERL side [ lane P ] -- report

implements `data/md/design/AUTH-LINK-BINDING.md` [ wire v2 ] for the
server and the Perl client. nothing committed, signed, started or
reloaded ; signature blocks of every touched file are now stale.

## files changed

new :
- `src/auth.binding.message` -- the ONE place for the three pack
  templates [ kind auth \ client \ server ]. every field is checked
  first [ 32-byte binaries, nonce_sid 1 .. 2**32-1 digits only,
  printable-ascii strings 1 .. 65535 bytes, wide chars refused ] since
  `a32` pads \ truncates and `N` wraps silently. returns undef otherwise.
- `src/auth.client.server_pin.check` -- `~/.n/remote-keys/servers/
  <host>_<port>.public` [ home via `base.get_homedir` ]. first contact :
  dirs 0700, O_EXCL 0600 pin, log level 0 `pinned server key <b32>`.
  mismatch \ unreadable \ garbled \ dangling-symlink pin : refused, never
  re-pinned. host must match `[a-z0-9][a-z0-9.:-]*` with no `..`.
- `src/base.session.register_authenticated` -- the factored registration
  block : `authenticated = yes`, `$data{'user'}{<n>}{'session'}{<id>}`,
  `connected_since`, `initialized` [ not for zenka ], auth timeout
  disarmed. called by base.handler.auth [ non-auth-keypair ] and by
  base.handler.link-upgrade once the binding verifies.
- `bin/test-scripts/test-auth-link-binding.pl`

server :
- `src/auth.auth_select` -- a fresh select drops earlier binding
  material ; auth-keypair : key name from `crypt.C25519.key_vars` [ same
  source get-public-key used ], raw S_pub from `$keys{'C25519'}{name}`,
  32-byte nonce from `base.prng.bytes` [ length asserted ], all three
  stored under `$session->{'auth'}` ; reply `TRUE <S_pub> <nonce>` built
  from the stored bytes.
- `src/plugin.auth.auth-keypair` -- verifies auth_sig over the v2
  message [ no nonce selected -> refused ] ; success stores the C pub as
  `{'auth'}{'client_pub'}` and sets `link_binding = pending` ; every
  refusal path deletes the binding material.
- `src/base.handler.auth` -- unauth-client cleanup kept inline for both
  paths ; auth-keypair : requires `link_binding eq pending` [ else
  disconnect ], sets `authenticated = pending`, NOT registered, NOT
  initialized, auth timeout stays ARMED [ that is what kills a silent
  pending session and with it the nonce ] ; other methods call
  base.session.register_authenticated [ unchanged behaviour ].
- `src/base.handler.command` -- the state 1 gate [ below ].
- `src/cube.cmd.link-upgrade` -- any false return on a pending session
  sets `flush_shutdown` and drops the nonce [ no retry from state 1 ].
- `src/base.handler.link-upgrade` -- on pending sessions : strict b32 +
  32-byte client eph [ kept as `link_client_eph`, second link-pub-key
  refused ], exact encoding string kept [ `none` too ], link-complete
  REQUIRES `<nonce_sid 1..2**32-1> <client_bind_sig>` verified with the
  stored C pub before any answer, asserts the loaded key for the stored
  name eq the stored S_pub [ + private loaded ] before signing,
  `link-complete-ok <server_bind_sig>`, state 3, then `link_binding =
  done` + register_authenticated. every failure [ incl. timeout,
  unexpected line ] returns 2 and drops the nonce. non-pending sessions
  keep plain `link-complete-ok` [ a stray sig is ignored, log level 1 ].
  the strict `[A-Z2-7]` alphabet check binds pending sessions only ; for
  everyone a non-32-byte eph key and a non-numeric nonce sid now
  disconnect [ before : any non-empty key, an unmatched line hung ]. the
  C client [ is_b32, B32_32_LEN ] and the Perl helper [ encode_b32r ] send
  strict uppercase unpadded b32, so no current sender is affected.
- `src/protocol.protocol-7.link-upgrade.init` -- not changed [ not needed ].

client :
- `src/auth.client.auth-keypair.authenticate` -- new 5th param `{ host,
  port }` [ missing -> refused ] ; select reply must be `TRUE <b32>
  <b32>`, both 32 bytes ; pin checked BEFORE anything is signed or sent ;
  v2 auth_sig ; returns the context `{ server_nonce, server_pub,
  username, base_key_name }` [ hash ref, so `defined` checks still work ].
- `src/protocol.protocol-7.link-upgrade.handshake` -- `{ binding }`
  option REQUIRED [ nothing is sent without it ] ; sends `link-complete
  <sid> <client_bind_sig>`, requires `link-complete-ok <sig>` and
  verifies it with the pinned server_pub.
- `src/external.link.open` -- passes host \ port, requires a context,
  hands it to the handshake.
- `src/users.remote_fetch.run` -- now authenticate -> handshake ->
  session.init -> state 1 -> client_activate [ shutdown on failure ]
  before the command is sent, eval + close-on-die like external.link.open.
  `authenticated` left undef as before.

lists :
- `cfg/zenki/*/subroutines.load-early` [ 123 files ] -- each new module
  inserted right after its caller's line [ auth.binding.message,
  auth.client.server_pin.check : 123 ; base.session.register_authenticated :
  122 ]. gen-sub-whitelist NOT run.
- `src/base.list.subroutines` NOT edited : generated by
  `sourcecode.console.update-sub-list` ; only that module and
  `sourcecode.console.subroutine-list` reference it -- `bin/Protocol-7`,
  `base.zenka.load_sub_list` and `base.reload_whitelist` do not, so it
  does not gate loading. left to the release flow.

tests :
- `bin/test-scripts/test-link-upgrade-client.pl` -- fake server verifies
  the client_bind_sig over its own pack of the transcript and answers
  with a server_bind_sig ; new : wrong-key \ missing \ non-b32
  server_bind_sig refused, no context -> nothing sent.
- `bin/test-scripts/test-external-link.pl` -- auth returns a context,
  host \ port + binding pass-through checked, non-context return refused.
  [ bin/format-code reflowed this file noticeably. ]

## the state 1 gate

`protocol.protocol-7.init_code` : state 1 input handler is
`base.handler.command` [ the handler `base.session.init_state` installs ;
state 3's `base.handler.link-upgrade.input` also ends in it ]. the gate is
at the very TOP of `base.handler.command`, right after `$input` \ `$output`,
before ignore_bytes, multi-line, SIZE \ STRM, !TRM!, reply processing,
the protocol-error branch [ which returns 0 without disconnecting ],
reroute and aliases : while `link_binding eq pending` an incomplete line
waits [ 1 ], the first line must match
`\Alink-upgrade(?:[ \t]+[a-z0-9-]+)?[ \t]*\n`, anything else ->
`FALSE link binding pending [ link-upgrade only ]` + log 0 + return 2.
a second check after alias \ reroute resolution refuses a pending
session whose `$cmd` is no longer `link-upgrade`. the command still
passes `base.has_access` normally -- which reads only
`<access.cmd.regex.usr>` for the session user, none of the deferred
registration \ authenticated \ initialized state.

## test output

```
test-auth-link-binding.pl   : passed : 144  failed : 0   [ exit 0 ]
test-link-upgrade-client.pl : 43 ok, all checks passed    [ exit 0 ]
test-external-link.pl       : passed : 84  failed : 0    [ exit 0 ]
```

mutation checks [ src temporarily edited, restored byte-identical ] :
gate removed -> 12 FAIL ; client sig unchecked -> 10 ; S_pub assert
removed -> 3 ; pending path registering -> 4 ; pin check skipped -> 9.

a bad \ missing server_bind_sig is refused in both the new script and
test-link-upgrade-client.pl [ the real handshake against a forked fake
server ]. route_to_target is covered by
its actual check [ `base.cfg_bool('pending')` false ] + the session not
being registered under the user name ; send.local is compiled and driven
[ by sid and by user name ].

## open points [ none blocked the work ]

1. lane C : the gate accepts only bare `link-upgrade` [ optional encoding
   arg ], no `(id)` command-id prefix ; non-pending sessions still get a
   plain `link-complete-ok`.
2. a zenka other than cube that offers auth-keypair but has no
   `link-upgrade` command can never complete the binding [ fails closed ].
3. cube must have the PRIVATE half of its announced key loaded at
   runtime, or every binding fails closed at link-complete -- not
   verifiable here.
4. `base.cfg_bool('pending')` returns undef via `s_warn` : correct but it
   warns on every routing pass that meets a pending session.
5. `base.session.check.close` [ not mine ] : closing a pending session
   whose user has no registered session records `last_seen` for that user
   [ cosmetic ].
6. pre-existing, not changed : in plugin.auth.auth-keypair an unexpected
   `validate-incoming-tofu` result [ undef \ 3 ] falls through to success.
7. spec wording : "an auth line with fewer than three fields after the
   user" -- the wire has two fields after the user [ session_pub, sig ] ;
   implemented as the wire says [ exactly `auth <user> <pub> <sig>` ].
8. pin log fingerprint = the full S_pub b32 [ directly comparable with
   `crypt.C25519.cmd.get-public-key` on the server ].
9. `src/crypt.C25519.gen_keys` and `bin/test-scripts/test-host-root-keygen.pl`
   show worktree changes I did not make [ another agent \ the user ].

## full test output

### test-auth-link-binding.pl

```
: test vector [ auth.binding.message ]
  ok   : C pub b32
  ok   : S pub b32
  ok   : auth msg hex
  ok   : auth_sig b32
  ok   : client message = label . transcript hex
  ok   : server message = label . transcript hex
  ok   : client_bind_sig b32
  ok   : server_bind_sig b32
: builder refuses invalid fields
  ok   : client : short server_nonce
  ok   : client : long server_eph
  ok   : client : nonce_sid 0
  ok   : client : nonce_sid 2**32
  ok   : client : nonce_sid not digits
  ok   : client : empty encoding
  ok   : client : username with space
  ok   : client : wide char username
  ok   : client : undef client_eph
  ok   : unknown kind
  ok   : auth : short session_pub
  ok   : auth and client messages differ
: server plugin [ plugin.auth.auth-keypair, v2 only ]
  ok   : v2 line : accepted
  ok   : v2 line : AUTH_TRUE
  ok   : v2 line : link_binding pending
  ok   : v2 line : C public key kept for link-complete
  ok   : v2 line : nonce kept for link-complete
  ok   : v1 line [ sig over the bare session pubkey ] : refused [ 2 ]
  ok   : v1 line [ sig over the bare session pubkey ] : no binding state
  ok   : v1 line [ sig over the bare session pubkey ] : nonce deleted
  ok   : wrong nonce : refused [ 2 ]
  ok   : wrong nonce : no binding state
  ok   : wrong nonce : nonce deleted
  ok   : wrong S_pub : refused [ 2 ]
  ok   : wrong S_pub : no binding state
  ok   : wrong S_pub : nonce deleted
  ok   : no nonce selected : refused
  ok   : two fields : protocol mismatch, refused
  ok   : two fields : nonce deleted
: base.handler.auth [ pending : not authenticated, not registered ]
  ok   : auth-keypair pending : state change [ 0 ]
  ok   : authenticated = pending
  ok   : not initialized
  ok   : not registered for the user
  ok   : removed from the unauthenticated user
  ok   : auth timeout stays armed
  ok   : state 1 entered
  ok   : auth-keypair without pending binding : disconnect
  ok   : auth-keypair without pending : never authenticated
  ok   : unix method : authenticated yes [ unchanged ]
  ok   : unix method : registered for the user
  ok   : unix method : initialized
  ok   : unix method : auth timeout disarmed
: state 1 gate [ base.handler.command ]
  ok   : pending : 'list users\n' refused [ FALSE + disconnect ]
  ok   : pending : 'exit\n' refused [ FALSE + disconnect ]
  ok   : pending : 'TRUE something\n' refused [ FALSE + disconnect ]
  ok   : pending : '(12)link-upgrade\n' refused [ FALSE + disconnect ]
  ok   : pending : 'link-upgrade+\n' refused [ FALSE + disconnect ]
  ok   : pending : 'link-upgrade-x\n' refused [ FALSE + disconnect ]
  ok   : pending : '!TRM!\n' refused [ FALSE + disconnect ]
  ok   : pending : 'link-pub-key AAAA\n' refused [ FALSE + disconnect ]
  ok   : pending : 'link-upgrade utf7 extra\n' refused [ FALSE + disconnect ]
  ok   : pending : 'cube.link-upgrade\n' refused [ FALSE + disconnect ]
  ok   : pending : 'SIZE 3\nabc' refused [ FALSE + disconnect ]
  ok   : pending : incomplete line waits [ 1 ]
  ok   : pending : 'link-upgrade\n' passes the gate
  ok   : pending : 'link-upgrade utf7\n' passes the gate
  ok   : pending : aliased link-upgrade refused after resolution
: link-complete [ base.handler.link-upgrade ]
  ok   : pub key + encoding accepted
  ok   : client eph key kept
  ok   : valid client_bind_sig : complete [ 0 ]
  ok   : reply : link-complete-ok <server_bind_sig>
  ok   : server_bind_sig verifies with S over the same transcript
  ok   : state 3 entered
  ok   : link_binding done
  ok   : authenticated yes
  ok   : registered for the user
  ok   : nonce deleted [ single-use ]
  ok   : auth timeout disarmed once bound
  ok   : nonce sid stored
  ok   : missing client_bind_sig : disconnect [ 2 ]
  ok   : missing client_bind_sig : no link-complete-ok
  ok   : missing client_bind_sig : no state 3
  ok   : missing client_bind_sig : nonce deleted
  ok   : missing client_bind_sig : still not authenticated
  ok   : missing nonce_sid : disconnect [ 2 ]
  ok   : missing nonce_sid : no link-complete-ok
  ok   : missing nonce_sid : no state 3
  ok   : missing nonce_sid : nonce deleted
  ok   : missing nonce_sid : still not authenticated
  ok   : client_bind_sig by another key : disconnect [ 2 ]
  ok   : client_bind_sig by another key : no link-complete-ok
  ok   : client_bind_sig by another key : no state 3
  ok   : client_bind_sig by another key : nonce deleted
  ok   : client_bind_sig by another key : still not authenticated
  ok   : client_bind_sig over another nonce_sid : disconnect [ 2 ]
  ok   : client_bind_sig over another nonce_sid : no link-complete-ok
  ok   : client_bind_sig over another nonce_sid : no state 3
  ok   : client_bind_sig over another nonce_sid : nonce deleted
  ok   : client_bind_sig over another nonce_sid : still not authenticated
  ok   : nonce_sid 0 : disconnect [ 2 ]
  ok   : nonce_sid 0 : no link-complete-ok
  ok   : nonce_sid 0 : no state 3
  ok   : nonce_sid 0 : nonce deleted
  ok   : nonce_sid 0 : still not authenticated
  ok   : nonce_sid 2**32 : disconnect [ 2 ]
  ok   : nonce_sid 2**32 : no link-complete-ok
  ok   : nonce_sid 2**32 : no state 3
  ok   : nonce_sid 2**32 : nonce deleted
  ok   : nonce_sid 2**32 : still not authenticated
  ok   : client_bind_sig not base32 : disconnect [ 2 ]
  ok   : client_bind_sig not base32 : no link-complete-ok
  ok   : client_bind_sig not base32 : no state 3
  ok   : client_bind_sig not base32 : nonce deleted
  ok   : client_bind_sig not base32 : still not authenticated
  ok   : loaded server key ne announced S_pub : refused
  ok   : pending state 2 : unexpected line disconnects, nonce deleted
  ok   : pending : link-complete before negotiation refused
  ok   : pending : timeout disconnects, nonce deleted
  ok   : client eph key not 32 bytes : refused
  ok   : non-pending : link-complete without sig unchanged
: pending sessions invisible to send.local \ route_to_target
  ok   : route_to_target check : cfg_bool( pending ) is false
  ok   : route_to_target check : yes is true
  ok   : send.local : pending session skipped
  ok   : send.local : pending session not reachable by user name
  ok   : send.local : control [ yes ] sent
: client [ auth.client.auth-keypair.authenticate + server pin ]
  ok   : first contact : binding context returned
  ok   : first contact : pin file written
  ok   : pin file mode 0600
  ok   : pin file holds S_pub b32
  ok   : pinned : logged at level 0
  ok   : context : server_nonce, server_pub, username, base_key_name
  ok   : auth line carries the v2 auth_sig
  ok   : signed with the explicit base key name
  ok   : pinned key matches : accepted
  ok   : pin mismatch : refused
  ok   : pin mismatch : nothing signed, no auth line sent
  ok   : pin mismatch : pin NOT replaced
  ok   : select reply without nonce : refused, no auth line
  ok   : short nonce : refused, no auth line
  ok   : no host \ port for the pin : refused
  ok   : host with a path : refused, nothing written
  ok   : unreadable pin file : refused
  ok   : garbled pin file : refused
: client handshake refuses a bad server_bind_sig
  ok   : server_bind_sig by the pinned S : accepted
  ok   : server_bind_sig by another key : refused
  ok   : link-complete-ok without server_bind_sig : refused

passed : 144  failed : 0
```

### test-link-upgrade-client.pl

```
: handshake success
  ok   : handshake success : ( 1, { .. } )
  ok   : shared secret is 32 bytes
  ok   : shared secret == the server DH result
  ok   : nonce sid in 1 .. 2**32-1
  ok   : nonce sid == what the server received
  ok   : client_bind_sig verifies with C over the server-side transcript
  ok   : client signed with the context base key name
: binding failures
  ok   : server_bind_sig by another key : ( 0, { error } ), no secret handed out
  ok   : link-complete-ok without sig : ( 0, { error } ), no secret handed out
  ok   : server_bind_sig not base32 : ( 0, { error } ), no secret handed out
  ok   : no binding context : ( 0, { error } )
  ok   : context with a short server_pub : refused
  ok   : nothing sent without a valid context
: wrong answers
  ok   : wrong answer [first line has no OK] : ( 0, { error } ), no die
  ok   : wrong answer [server key is invalid base32] : ( 0, { error } ), no die
  ok   : wrong answer [answer to link-pub-key is not SIZE 0] : ( 0, { error } ), no die
  ok   : wrong answer [answer to encoding is not encoding-confirmed] : ( 0, { error } ), no die
  ok   : wrong answer [answer to link-complete is not link-complete-ok] : ( 0, { error } ), no die
: silent server
  ok   : silent server : fails instead of hanging
  ok   : silent server : failed within the timeout [ 1s ]
: client_activate on a minimal session
  ok   : client_activate : TRUE
  ok   : link_role client recorded
  ok   : client writes direction 1
  ok   : client reads direction 2
  ok   : dh secret deleted after key derivation
: client_activate input validation
  ok   : wrong-length secret : FALSE
  ok   : missing nonce sid : FALSE
  ok   : unknown session : FALSE
: encryption.init roles
  ok   : server-role encryption.init : TRUE
  ok   : server role : write 2, read 1
  ok   : no link role : refused
  ok   : no link role : complains
  ok   : missing dh secret : refused
: encrypted frame direction [ bonus ]
  ok   : frame handler produced a frame
  ok   : frame length prefix matches
  ok   : client frame decrypts with the server read nonce [ direction 1 ]
  ok   : same frame does NOT decrypt with direction 2
: fail closed [ never plaintext on an encrypted link ]
  ok   : no key : nothing sent, never the plaintext, no die
  ok   : no key : session shut down
  ok   : no key : complains
  ok   : invalid key : nothing sent, never the plaintext, no die
  ok   : invalid key : session shut down
  ok   : invalid key : complains

all checks passed
```

### test-external-link.pl

```
  ok   : regex.base.usr taken from the real base.regex module
external.link.open : argument validation
  ok   : missing name -> false
  ok   : missing name -> no base.open call
  ok   : missing host -> false
  ok   : missing host -> no base.open call
  ok   : missing port -> false
  ok   : missing port -> no base.open call
  ok   : non-numeric port -> false
  ok   : non-numeric port -> no base.open call
  ok   : empty args -> false
  ok   : empty args -> no base.open call
  ok   : invalid link name 'bad name' -> false
  ok   : invalid link name 'bad/name' -> false
  ok   : invalid link name '-lead' -> false
  ok   : invalid link name 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' -> false
  ok   : invalid link name 'a[b]' -> false
  ok   : invalid names -> no base.open call
  ok   : a valid name passes the name check
  ok   : no as_username and no cfg.link_user -> false
  ok   : no identity -> no base.open call
external.link.open : failure paths close the socket
  ok   : base.open undef -> false "cannot connect"
  ok   : open failure -> auth not attempted
  ok   : auth undef -> false
  ok   : auth undef -> socket closed
  ok   : auth undef -> no handshake
  ok   : auth dies -> die propagates
  ok   : auth dies -> socket closed
  ok   : handshake ( 0, { error } ) -> false with the error text
  ok   : handshake failure -> socket closed
  ok   : handshake failure -> no session
  ok   : handshake dies -> die propagates
  ok   : handshake dies -> socket closed
  ok   : session.init undef -> false
  ok   : session.init undef -> socket closed
  ok   : session.init undef -> no init_state
  ok   : client_activate false -> false
  ok   : client_activate false -> session.shutdown( id ) once
  ok   : client_activate false -> no link registered
  ok   : auth returns no binding context -> false
  ok   : no binding context -> socket closed
  ok   : no binding context -> no handshake
external.link.open : success and reuse
  ok   : success -> ( true, sid )
  ok   : auth got as_username and the link name
  ok   : auth got { host, port } for the server key pin
  ok   : handshake got the binding context auth returned
  ok   : base.open got ip.tcp output host port
  ok   : session.init got the link name as session name
  ok   : init_state( id, 1 ) called
  ok   : client_activate got id and the handshake link
  ok   : session marked authenticated = yes
  ok   : external.links entry = { sid host port user }
  ok   : success -> socket left open
  ok   : reuse : same name host port -> same sid
  ok   : reuse -> no new base.open
  ok   : same name other host -> false "link lnk is open to .."
  ok   : same name other port -> false
  ok   : conflict -> no new base.open
  ok   : conflict -> old entry kept
  ok   : stale entry -> a new link is opened [ new sid ]
  ok   : stale entry -> one new open
  ok   : stale entry replaced by the new link
  ok   : as_username //= external.cfg.link_user
external.cmd.connect
  ok   : args '' -> false usage
  ok   : args 'onlyname' -> false usage
  ok   : usage failure -> no timer
  ok   : no reply_id -> false
  ok   : no reply_id -> no timer
  ok   : valid -> mode deferred
  ok   : ONE timer with after 0
  ok   : timer carries a callback
  ok   : link.open not called before the timer fires
  ok   : no reply before the timer fires
  ok   : cb -> link.open called once
  ok   : link.open got { name host port as_username }
  ok   : link.open true -> cmd_reply( reply_id, true, "linked .. session N" )
  ok   : port defaults to 42 when unset
  ok   : as_username undef when not given [ link.open applies cfg ]
  ok   : port defaults to protocol-7.remote.default-port when set
  ok   : bare-string args without reply_id -> reply route error
  ok   : link.open false -> that false result passed through
  ok   : link.open dies -> cb itself does not die
  ok   : link.open dies -> cmd_reply false "link setup failed : <msg>"
  ok   : die message trailing whitespace trimmed
  ok   : link.open returns undef -> still a reply [ "no result" ]

passed : 84  failed : 0
```

#,,,.,...,.,,,...,,..,...,.,.,.,,,.,.,,,.,,.,,..,,...,..,,.,.,,,.,,,.,.,.,,,.,
#ZZANUXETPNSTV3IJYSIBEVAC5LQ573FLT7DXXAYV76JM6343QT7Y4R3CPOJNJAMMNR6JXT6WCIR6A
#\\\|ZNGF7MVBWBWDLZEWG6WBD63C7V4NAXWYSDIIH4HAMOBFWDSNXQT \ / AMOS7 \ YOURUM ::
#\[7]AGCLU2XI6UCQJ5BS2PDNL2J456H3JHSU4SMN2Y2ABHDTGL2SKIBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
