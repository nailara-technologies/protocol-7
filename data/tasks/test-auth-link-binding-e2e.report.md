# report : test-auth-link-binding-e2e [ auth-keypair v2 + link-upgrade binding, end to end ]

2026-10-07, against commit `1adb45b02` [ host-root delegation on top of the
binding wire ]. ONE new script : `bin/test-scripts/test-auth-link-binding-e2e.pl`
[ test only — nothing under `src/`, `cfg/` or the helpers was changed ].

## what this proves that the spec test [ test-auth-link-binding.pl ] cannot

the spec test compiles the server modules and the Perl client separately,
each against stubs of the other side. this test runs the REAL server modules
and the REAL client modules against each other over a `socketpair(AF_UNIX,
SOCK_STREAM)`: the CHILD is a tiny hand-rolled server loop [ read into
`$data{'session'}{$id}{'buffer'}{'input'}` -> call the current state's
handler -> write `{'buffer'}{'output'}` back ], no event loop, no zenka ;
the PARENT runs the REAL `auth.client.auth-keypair.authenticate` and
`protocol.protocol-7.link-upgrade.handshake`. whatever either side puts on
the wire is what the other side actually parses — the two implementations
must agree byte for byte or the run fails.

## the wire as tested [ note : changed while this task was running ]

the task file + `data/md/design/AUTH-LINK-BINDING.md` describe the select
reply as 3 fields :

```
<- TRUE <S_pub b32> <server_nonce b32>
```

while the test was being written, the tree landed commit `1adb45b02`,
implementing `data/md/design/HOST-ROOT-DELEGATION.md` : the select reply is
now 4 fields and the delegation is REQUIRED, no compatibility :

```
-> select auth-keypair
<- TRUE <S_pub b32> <server_nonce b32> <delegation b32>
-> auth <username> <session_pub b32> <auth_sig b32>
<- AUTH_TRUE =)
-> link-upgrade
<- TRUE link-upgrade OK <server_eph b32>
-> link-pub-key <client_eph b32>
<- SIZE 0
-> link-confirm-encoding <enc>
<- encoding-confirmed
-> link-complete <nonce_sid> <client_bind_sig b32>
<- link-complete-ok <server_bind_sig b32>
```

[ inputs : the task description + the 3-field design ; expected at task
start : the 3-field wire ; actual : the landed code requires the 4th field,
the client refuses a 3-field reply before sending auth. this is a designed
protocol extension committed as `1adb45b02`, not a bug — the e2e test was
adapted to the landed wire, which is the only wire the real modules speak.
the pin also changed meaning : the pin file now holds the 77-char
`bmw384` FINGERPRINT of the host-root, not S's 52-char b32. ]

## the server child : real modules driven, stubs only for the edges

compiled REAL, driven by the child's read -> handler -> write loop :

- `auth.auth_select` — incl. the delegation check : reads `<S>.dlg` through
  the REAL `crypt.C25519.delegation_file`, parses + verifies it with the
  REAL `trust.statement` / `trust.verify` / `trust.fingerprint`, refuses
  [ `FALSE server key not available` ] on missing \ unparsable \ expired \
  wrong-subject, BEFORE any nonce is drawn
- `plugin.auth.auth-keypair` — the v2 `auth` line only
- `base.handler.auth` — binding PENDING : `authenticated = pending`, not
  registered, auth timeout stays armed
- `base.session.register_authenticated` — compiled REAL
- `base.session.init_state` — compiled REAL [ the task allowed either ] :
  with handle mode `input` it sets `$session{'input'}{'handler'}` from the
  state table on every transition, so the child loop just follows it. the
  protocol state table mirrors the production shape from
  `src/protocol.protocol-7.init_code` : `{ input => { handler }, init,
  read-mode }` — `init` sits at the TOP level of the state entry, next to
  the per-mode `input`/`output` handler hashes
- `base.handler.command` — full module, exercised through the binding gate
  [ a pending session may send exactly `link-upgrade` ] and, for the passed
  gate, through the real single-line command dispatch down to the real
  `cube.cmd.link-upgrade` [ compiled with the `.cmd.` `$call` header ]
- `cube.cmd.link-upgrade`, `protocol.protocol-7.link-upgrade.init`,
  `base.handler.link-upgrade` — the whole state 2 negotiation incl. the
  bind-transcript verification, the server_bind_sig and the registration

the one deliberate non-real init : state 3's `init` is a stub `sub {
return TRUE }` — the REAL `protocol.protocol-7.encryption.init` arms
ChaCha20 framing + event watchers around the event loop; this wire test ends
at `link-complete-ok` [ still plaintext ], so nothing beyond it is under
test. the wire-visible behaviour up to and including state 3 entry is real.

## the parent : real client calls

- `auth.client.server_pin.check` — REAL, incl. the delegation verify under
  the pinned host-root fingerprint; its home comes from a stubbed
  `base.get_homedir` -> a File::Temp dir, so the pin store is
  `$home/.n/remote-keys/servers/test-host_4242.public` and real `~/.n` is
  never touched
- `auth.client.auth-keypair.authenticate` — REAL, host `test-host`, port
  4242
- `protocol.protocol-7.link-upgrade.handshake` — REAL, with the binding
  context authenticate returned
- delegation statements in the test are built + signed with the REAL
  `trust.statement` [ `build` + `wire` ], Ed25519-signed by throwaway
  host-root keys [ seeds `\x04` x 32 = H, `\x05` x 32 = H2 ], written into
  the throwaway backend key dir as `<S>.dlg` — exactly the artefact
  `v7-zenki.delegation.issue` writes

## stubs [ only what is NOT under test ]

logging `base.logs` \ `base.log` \ `base.s_warn` \ `base.caller` \
`base.ntime` \ `base.str.eval_error` ; `base.is_defined_recursive` ;
`base.s_read` [ readline ] ; `base.net.send_to_socket` [ syswrite ] ;
`base.get_homedir` [ tempdir ] ; `base.prng.bytes` \ `base.prng.chars-anum`
[ real randomness ] ; `base.code.exists` \ `base.code.call_optional` ;
`base.reverse-sort` \ `auth.auth_list` \ `base.list_matches` [
`auth.auth_select`'s method list ] ; `base.has_access` \ `base.gen_id` \
`base.handler.hooks.has_hooks` \ `base.sprint_t` \ `base.logt` \
`base.format_error` \ `base.parser.ellipse_center` \ `base.cnt_s` [
`base.handler.command` surroundings, never on the assertions' path ] ;
`base.stream.emit` [ TRUE \ FALSE \ WAIT reply framing, template J4UEBUA
`%s%s %s\n` with an empty reply id ] ; `base.session.user` \
`base.session.calc_cmd_stats` ; `base.handler.write` [ flush to the child
socket — the REAL `base.handler.link-upgrade` calls it before state 3 ] ;
`base.clean_hashref` ; `crypt.C25519.key_vars` [ -> the scenario's server
key name ] ; `crypt.C25519.root_key_dir` [ -> a per-scenario tempdir ending
in `/root`; the REAL `crypt.C25519.delegation_file` derives the `.dlg` path
from it ] ; `crypt.C25519.sign_data` [ throwaway in-memory C identity, the
explicit base key name is recorded and asserted ] ; `crypt.C25519.key_exists
\ load_keypair \ gen_keys \ write_keys` [ stubbed to die — the session key
is pre-seeded so the disk path must never run ] ;
`auth.client.zenka.process_auth_reply` [ parses the AUTH_TRUE line, records
it ] ; `plugin.auth.auth-keypair.validate-incoming-tofu` [ -> 0 ; unix link,
never on the wire ] ; state 3 `init` [ see above ].

keys are five fixed-seed throwaway Ed25519 pairs [ C `\x01`, S `\x02`,
X `\x03`, H `\x04`, H2 `\x05` ] ; C's public half is on the server as
`$keys{'authorized-remote'}{'test-user'}`, S/X in the server key table,
the C25519 session pubkey is `\x22` x 32 [ stable TOFU material ].

## the checks, and what each one proves

1. **success** — client gets `( 1, { shared_secret, nonce_sid } )`; server
   session ends `link_binding = done`, `authenticated = yes`, registered
   under the user, single-use nonce deleted, `link-complete-ok
   <server_bind_sig>` sent; BOTH shared secrets are EQUAL [ the curve25519
   DH agrees across the wire ] and the nonce_sid matches. the pin file
   exists, mode 0600, one 77-char line == the host-root fingerprint.
2. **pinned re-run, same home** — full authenticate + handshake passes
   again; pin content, mtime and inode unchanged [ no rewrite ].
3. **rotated S, same host-root** — the server announces X instead of S with
   a delegation H -> X ; the client ACCEPTS [ the pin is on the host-root,
   S may rotate ], completes the binding, pin unchanged.
4. **different host-root** — same S, delegation by H2 ; the client refuses
   BEFORE anything is signed or sent: no `auth` line reaches the server
   child, the pin is not replaced.
5. **expired .dlg** — the server refuses AT SELECT [ `FALSE server key not
   available`, no nonce drawn, no nonce stored ]; the client never enters
   the auth phase.
6. **unknown client key** — the client signs with a key the server does not
   hold for `test-user`; the server answers `AUTH_ERROR` and disconnects,
   no binding state.
7. **mitm relay** — a relay process between two socketpairs flips the first
   char of the server's eph pubkey in `TRUE link-upgrade OK`. the
   transcripts diverge: the server refuses the client_bind_sig [ never
   `done`, no `link-complete-ok`, nonce dropped ] and the client gets a
   disconnect instead of the completion — BOTH sides refuse.
8. **replay** — the exact `auth` line from run 1, sent verbatim into a
   fresh session [ fresh 4-field select reply with a fresh nonce ] :
   refused `AUTH_ERROR`, disconnected. one observed line authenticates
   nothing.
9. **pending gate** — after `AUTH_TRUE` the client sends `list users`
   instead of `link-upgrade`: `FALSE link binding pending` + disconnect;
   the session stays `pending` forever, never authenticated.
10. **link-complete without the client sig** — disconnect, no
    `link-complete-ok`, nonce gone, never registered.

## findings against the landed code

none. every refusal [ delegation mismatch, expiry, unknown key, tampered
eph, replay, gate, missing sig ] and every acceptance [ success, re-run, S
rotation ] matches `AUTH-LINK-BINDING.md` + `HOST-ROOT-DELEGATION.md`
[ acceptance rules, sections "wire change", "acceptance rules" ] as landed
in `1adb45b02`. the cross-check against the sibling lane's
`data/tasks/host-root-delegation-perl.report.md` agrees on the wire shape,
the pin content and the rotation \ mismatch semantics.

## test-side pitfalls hit while writing this [ fixed in the test itself ]

- `ok( COND and COND2, 'label' )` : `and` binds looser than the comma, so
  ok() receives ONE argument and the label is lost [ or worse, becomes the
  condition ]. every multi-condition check is hoisted into a variable.
- on this perl [ 5.42.3 ], `ok( $var =~ m{...}, 'label' )` loses its label
  when `$var` holds a constant-foldable value and the regex uses `{}`
  delimiters — the comma binds inside the match. all matches are hoisted.
  [ `$var =~ m|...| , 'label'` parses correctly, but hoisting is clearer. ]
- the tamper relay originally flipped the first b32 char with
  `$first eq 'A'` where `$first` was the whole 52-char string — always
  false, so the "tampered" key started with 'A'; when the genuine key also
  started with 'A' [ 1/32 of runs ] the tamper was a no-op and the
  handshake legitimately succeeded — a ~10 % flaky failure. fixed to
  compare the first CHARACTER. not a src bug.
- `base.session.init_state` expects the PRODUCTION state shape
  [ `input`/`output` per mode, `init` beside them ] with handle mode
  `input`; a hand-rolled `{server => {handler}}` shape silently skips the
  state's `init` [ session mode `server` would skip everything ].
- `alarm` guards the whole run [ 120 s ] and each scenario [ 20 s ] — a
  hung child can never stall the test; every child is reaped, every socket
  end closed in both processes.

## full output [ 2026-10-07, commit 1adb45b02, perl 5.42.3 ]

```
: e2e success : real client <-> real server over a socketpair
  ok   : authenticate : binding context returned
  ok   : handshake : accepted [ 1 ]
  ok   : handshake : shared_secret returned [ 32 bytes ]
  ok   : handshake : nonce_sid returned
  ok   : client_bind_sig signed with the explicit base key name
  ok   : server : link_binding done
  ok   : server : authenticated yes after binding
  ok   : server : session registered for the user
  ok   : server : single-use nonce deleted
  ok   : server : link-complete-ok <server_bind_sig> sent
  ok   : both shared secrets equal [ dh agrees on the wire ]
  ok   : nonce_sid equal on both ends
: pin file
  ok   : pin file exists
  ok   : pin file mode 0600
  ok   : pin file : one 77-char line == the host-root fingerprint
  ok   : host-root fingerprint is 77 chars [ bmw384 b32 ]
: second run against the SAME pinned home
  ok   : pinned re-run : authenticate + handshake pass
  ok   : pinned re-run : server bound again
  ok   : pin unchanged : content
  ok   : pin unchanged : not rewritten
: rotated S, delegated by the SAME pinned host-root
  ok   : rotated S : accepted under the same host-root [ rotation ]
  ok   : rotated S : the new S reached the client
  ok   : rotated S : server bound
  ok   : rotated S : pin unchanged [ pinned to host-root ]
: a DIFFERENT host-root : refused before any auth line
  ok   : different host-root : client refuses [ no context ]
  ok   : different host-root : nothing signed, no auth phase entered
  ok   : different host-root : the server child saw no auth line
  ok   : different host-root : pin NOT replaced
: expired .dlg : the server refuses at select, no nonce drawn
  ok   : expired : banner consumed first
  ok   : expired : select answered FALSE, no nonce drawn
  ok   : expired : client never sent an auth line
  ok   : expired : no nonce stored for the session
: client signs with a key the server does not hold
  ok   : unknown client key : authenticate refused
  ok   : unknown client key : server answered AUTH_ERROR
  ok   : unknown client key : refused at auth, no binding state
: mitm : one byte of the server eph pub tampered in transit
  ok   : tampered eph key : client refuses the link [ no link-complete answer ]
  ok   : tampered eph key : client returns no shared secret
  ok   : tampered eph key : server never reaches done
  ok   : tampered eph key : no link-complete-ok answered
  ok   : tampered eph key : nonce dropped with the refused binding
: replay : the run 1 auth line verbatim in a fresh session
  ok   : replay : run 1 auth line captured
  ok   : replay : banner consumed first
  ok   : replay : fresh 4-field select reply carries a fresh nonce
  ok   : replay : verbatim auth line refused [ new nonce ]
  ok   : replay : server disconnected after the refusal
: pending gate : anything but link-upgrade after AUTH_TRUE
  ok   : gate : authenticate reached AUTH_TRUE
  ok   : gate : other command answered FALSE
  ok   : gate : server disconnected
  ok   : gate : session stayed pending, never authenticated
: link-complete without the client sig
  ok   : no sig : authenticate reached AUTH_TRUE
  ok   : no sig : disconnect, no link-complete-ok
  ok   : no sig : nonce gone
  ok   : no sig : binding never done
  ok   : no sig : never registered for the user

passed : 54  failed : 0
```

stability : 23 consecutive full runs green [ 15 + 8 ], no leaked child
processes, `bin/format-code -c` clean [ syntax valid ].

#,,,.,,,.,..,,,.,,,..,.,.,.,,,,..,..,,.,.,,.,,..,,...,...,...,.,,,.,.,,,.,..,,
#EEQVSEWIP7JYPZ4G4HN5HO3PZPLR7XXVN44EEEK7VKHWTVJ2G2JIWEFWLLLCRF4APC4KFZQYX5272
#\\\|SHG743KHLKOSUY3ZW537NOYXUDWYUEN42ART3OX2OFNFQPQ4XCS \ / AMOS7 \ YOURUM ::
#\[7]F73AX4QSAVGGH3ZS6NRZ6DAQ2CUKUJH2GOVL27VLBADCX4HSTEDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
