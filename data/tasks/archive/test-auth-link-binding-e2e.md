# test : auth-keypair v2 + link-upgrade binding END TO END [ in-process ]

ONE new test script : `bin/test-scripts/test-auth-link-binding-e2e.pl`.
TEST ONLY -- no change under `src/`, `cfg/`, `bin/c_src/` or the helpers.
if a test reveals a real bug, STOP, describe it in the report [ inputs,
expected, actual ], do not fix it.

do NOT start, restart or reload any zenka [ a live render is running ],
no sudo, no commit, no signing, no real network, no git command that
changes the tree. never read real key dirs [ `~/.n/`,
`/home/protocol-7/.n/` ] -- use throwaway keys + tempdirs.

## why

`bin/test-scripts/test-auth-link-binding.pl` [ commit ad31ddd5a ] tests
the server modules and the Perl client SEPARATELY, each against stubs of
the other side. nothing yet proves the REAL server code and the REAL
client code agree on the wire. this test runs both against each other.

## read first

- `data/md/design/AUTH-LINK-BINDING.md` [ the wire, incl. test vector ]
- `bin/test-scripts/test-auth-link-binding.pl` -- REUSE its harness
  [ `compile_module`, FakeWatcher, stubs, the `ok()` helper ] : copy the
  setup, do not import from it
- server : `src/auth.auth_select`, `src/plugin.auth.auth-keypair`,
  `src/base.handler.auth`, `src/base.handler.command` [ the gate only ],
  `src/cube.cmd.link-upgrade`, `src/protocol.protocol-7.link-upgrade.init`,
  `src/base.handler.link-upgrade`, `src/base.session.register_authenticated`
- client : `src/auth.client.auth-keypair.authenticate`,
  `src/protocol.protocol-7.link-upgrade.handshake`,
  `src/auth.client.server_pin.check`, `src/auth.binding.message`

## shape

`socketpair( AF_UNIX, SOCK_STREAM )` ; fork. the CHILD is the server : it
drives the REAL server modules with a tiny loop of its own [ read what
arrived into `$data{'session'}{$id}{'buffer'}{'input'}`, call the
current state's handler, write `{'buffer'}{'output'}` back to the
socket ] -- no event loop, no zenka. the PARENT runs the REAL client
calls : authenticate [ host 'test-host', port 4242, stubbed
`base.get_homedir` -> a tempdir ] then handshake with the returned
binding context. guard the whole test with `alarm` -- it must never hang.

stub only what is NOT under test [ logging, ntime, perlmod lookups,
`base.net.send_to_socket` -> syswrite, `base.handler.write` -> flush,
the TOFU validator -> return 0 ; for `base.session.init_state` either
compile the real one or set the state's handler directly -- say which ].
keys : server S and client C as throwaway Ed25519 pairs in `%keys`
[ C's public half as `$keys{'authorized-remote'}{'test-user'}` on the
server side ].

## checks

- success : client gets ( 1, { shared_secret, nonce_sid } ) ; server
  session ends `link_binding` 'done', `authenticated` 'yes', registered
  under the user ; both shared secrets equal ; the pin file exists [ 0600,
  one 52-char b32 line == S pub ]
- second run with the SAME tempdir home : passes, pin unchanged
- server announces a DIFFERENT S : client refuses BEFORE sending auth
  [ the server child sees no `auth` line ]
- client signs with a key the server does not hold for test-user :
  refused at auth
- MITM-ish : tamper one byte of the server's eph pub in transit [ a relay
  process between two socketpairs ] -> both sides refuse at link-complete,
  server never reaches 'done'
- replay : capture the client's `auth` line from run 1, send it verbatim
  in a fresh session -> refused [ new nonce ]
- pending gate : after AUTH_TRUE send `list users` instead of
  link-upgrade -> FALSE + disconnect
- a link-complete WITHOUT the client sig -> disconnect, nonce gone

## pitfalls [ hit in this codebase this week ]

- `ok( .. ) or say .. for @list` loops the WHOLE statement
- `my $x = a and b` parses as `( my $x = a ) and b`
- keep `use bytes` like the precedent ; `$ARG` not `$_` ; lowercase
  comments, `[ ]` not `( )`
- `bin/format-code -c <file>` for syntax, never bare `perl -c`
- reap every child ; close every socket end in both processes

## report

`data/tasks/test-auth-link-binding-e2e.report.md` : full output, what each
check proves, which stubs you used and why, any real bug [ described,
not fixed ]. write it as soon as the script passes.

#,,,,,.,,,.,.,,.,,,,,,,,,,.,.,..,,.,,,,..,,.,,..,,...,...,,,,,..,,,,,,...,.,.,
#IAVYBKAS7SOY2MDIVMGYS2I2A2RR3TZOIQJJODBRUZG4FIXG2V52GCODJ7L4RZCVE3Y5A5ABRUMNO
#\\\|QYDVCP7EK7EE2KLMWJILOH2AS27TT2MLWF7XUZBKQZ5OTHQSHJM \ / AMOS7 \ YOURUM ::
#\[7]SZNEB4MA5VNEUMTYMTT4OKYFI3CFMBPG2VSQ7LM2K4VH3IGMDEAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
