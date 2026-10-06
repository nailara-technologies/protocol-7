# auth-keypair + link-upgrade mutual binding : PERL side [ lane P ]

implement `data/md/design/AUTH-LINK-BINDING.md` [ read ALL of it first,
including "hardening rules" and the test vector ] for the server and the
Perl client. security-critical : read before you write, keep every
change minimal and fail closed. NO backwards compatibility [ v1 auth
lines and link-complete without a signature are refused ].

do NOT start, restart or reload any zenka, no sudo, no commit, no
signing, no real network. never read real key dirs [ `~/.n/`,
`/home/protocol-7/.n/` ] -- tests use tempdirs. another agent edits
`bin/c_src/p-7-r.c`, `bin/p7-auth-keypair-helper.pl`,
`bin/p7-link-upgrade-helper.pl` in parallel : do not touch those three.
no git command that changes the tree.

## files you own

server :
- `src/auth.auth_select` [ auth-keypair branch : nonce + stored key name
  + S_pub, reply `TRUE <S_pub> <nonce>` ]
- `src/plugin.auth.auth-keypair` [ v2 message only ]
- `src/base.handler.auth` [ 'pending' instead of 'yes' for auth-keypair ;
  factor the user-registration block into a new sub both paths call ]
- the state 1 command gate : find where a state 1 command line is
  dispatched [ the handler comes from `$data{'protocol'}{'protocol-7'}
  {'state'}{1}{<mode>}{'handler'}`, see `base.session.init_state` ] and
  allow ONLY `link-upgrade` while `{'link_binding'}` eq 'pending'
- `src/cube.cmd.link-upgrade`, `src/protocol.protocol-7.link-upgrade.init`
  only if needed, `src/base.handler.link-upgrade` [ client eph kept,
  required nonce_sid + client_bind_sig at link-complete, server_bind_sig
  appended, binding done -> authenticated yes + registration, nonce
  deleted on every path ]

client :
- `src/auth.client.auth-keypair.authenticate` [ pin check on the select
  reply BEFORE sending auth ; v2 auth_sig ; return the binding context --
  callers today treat its return as a boolean-ish defined value, keep
  them working ]
- `src/protocol.protocol-7.link-upgrade.handshake` [ takes the context,
  sends + verifies the bind sigs ]
- `src/external.link.open`, `src/users.remote_fetch.run` [ the latter
  must now link-upgrade before anything else, mirror external.link.open ]
- new shared modules allowed [ e.g. `auth.binding.message` building the
  exact bytes for all three messages -- ONE place for the pack templates,
  used by both server and client ; `auth.client.server_pin.check` ]. new
  modules need their `cfg/zenki/<zenka>/subroutines.load-early` \ deps
  entries wherever the callers are loaded [ grep how existing ones are
  listed, e.g. `protocol.protocol-7.link-upgrade.handshake` ].

tests :
- update `bin/test-scripts/test-link-upgrade-client.pl` and
  `bin/test-scripts/test-external-link.pl` to the new call shapes
- new `bin/test-scripts/test-auth-link-binding.pl` : the test vector from
  the spec reproduced by your message builder [ hex + all three sigs ] ;
  server plugin accepts the v2 line and refuses a v1 line, a wrong nonce,
  a wrong S_pub ; link-complete refuses a missing \ wrong client sig and a
  missing nonce_sid and disconnects ; the state 1 gate refuses any
  non-link-upgrade command while pending ; pending sessions are invisible
  to route_to_target's check and send.local's check ; client refuses a
  pin mismatch BEFORE sending auth, pins on first contact [ stub
  `base.get_homedir` to a tempdir ], refuses a bad server_bind_sig.

## P7 pitfalls

- modules have no `sub {}` ; `<a.b>` = `$data{'a'}{'b'}`, `<[x.y]>` =
  `$code{'x.y'}`, `<[x.y]>->( $arg )` with args ; `TRUE => 5`, `FALSE => 0`
- `.cmd.` modules get `$call` ; reply `{ mode => 'true'|'false', data => STRING }`
- runtime swaps `base.file.*` -> `file.*` ; `base.path.*` does not swap
- `my $x = a and b` parses as `( my $x = a ) and b`
- `$ARG` not `$_`, lowercase comments, `[ ]` not `( )`, 78 columns
- the production runtime loads `use bytes` -- `length` on binary is bytes
- syntax : `bin/format-code -c <files>`, never bare `perl -c` ; run
  `bin/format-code <files>` on every file you touch
- new files start with the `## [:< ##` + `# name =` header ; leave
  signature blocks to the signing tool

## report

write `data/tasks/auth-link-binding-perl.report.md` : every file changed
and why, where the state 1 gate went and how you found it, every test
output, open questions. anything in the spec that turns out wrong or
ambiguous : STOP on that point and report it instead of improvising.

#,,.,,.,.,,,,,,..,...,,..,.,.,,.,,.,,,,..,...,..,,...,...,...,.,.,,,,,,,,,..,,
#Z6MQSF5S6KEZXRNTB23QWFLMLJMMHMI3ER5G47XMMDUCMZGQCRX33Y3XEBHIA7VCPVNGJUFDUYBZ6
#\\\|7UI24RXCNCE3QJUEWBOD6CYRBXRYAXUFCUUDGY3RH3JWRUOWSRU \ / AMOS7 \ YOURUM ::
#\[7]DFT3EXK4OT4PGKSRXXDUWTGLYHV3SPCOHCZ4K4H2Q7YNPIFNO6DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
