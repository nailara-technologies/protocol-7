# host-root delegation : PERL core [ lane 1 ]

implement `data/md/design/HOST-ROOT-DELEGATION.md` [ read ALL of it,
especially "decisions", "root-held keys", "resolver API", "delegation
file", "host-root fingerprint" ] plus the base it builds on,
`data/md/design/AUTH-LINK-BINDING.md` [ live since ad31ddd5a ].
security-critical : fail closed, minimal diffs. spec wrong or ambiguous
on a point -> STOP on that point and report it, do not improvise.

do NOT start, restart or reload any zenka, no sudo, no commit, no
signing, no real network, no git command that changes the tree. never
read real key dirs [ `~/.n/`, `/home/protocol-7/.n/`, `/root/` ] -- tests
use tempdirs ; ownership checks are tested by stubbing the stat call or
the uid, never by chown on real files.

## parallel lanes -- do NOT touch their files

- lane 2 [ keys support ] : `src/keys.*`, `src/work.console*`,
  `src/source.load_signature_key`, `src/sessions.holder*`,
  `src/session.console*`, `src/p7-log.anon*`, `src/base.root*`
- lane 3 [ C ] : `bin/c_src/p-7-r.c`, `bin/p7-auth-keypair-helper.pl`,
  `bin/p7-link-upgrade-helper.pl`
- kimi : `bin/test-scripts/test-auth-link-binding-e2e.pl` [ in progress,
  written against the CURRENT wire -- leave it ; list in your report what
  it will need ]

## yours

resolver + keys :
- NEW `src/crypt.C25519.key_path`, `src/crypt.C25519.root_key_dir`
  [ API exactly as in the spec ]
- `src/crypt.C25519.key_vars`, `.key_exists`, `.keyfiles`,
  `.load_keypair`, `.write_keys` -> through the resolver ; NO other place
  in these builds a key file path
- `src/crypt.C25519.post_init` : host-root creation independent of
  `auto_load_keys`, in `root/`, only when zenka is v7-zenki AND running as
  root [ else : level 1 log, skip ] ; the ownership rule enforced

delegation :
- NEW statement builder \ parser [ one module, e.g. `trust.statement`
  with build \ parse ; the exact pack template from the spec, every field
  checked like `src/auth.binding.message` does ]
- NEW `trust.verify` [ generic walker per the spec ; one-hop chains are
  its first user ]
- NEW issuing [ e.g. `v7-zenki.delegation.issue` ] : signs cube's S
  [ the backend user's `<user>.base` public key, read from its PUBLIC
  file ] with host-root, writes `<backend key dir>/<S name>.dlg` [ temp
  + rename, chown backend user, 0644 ], renews at < 7 d of 30 d ; called
  from a post-init \ startup callback in `cfg/zenki/v7-zenki/zenka.v7`
  [ see how `[usage.startup]` \ `[universal.startup]` are wired ] + a
  daily timer
- NEW `src/crypt.C25519.cmd.host-root-fingerprint` [ cube : from the .dlg ]
- `src/auth.auth_select` : 4th select field = the .dlg content ; missing \
  unparsable \ expired \ subject != announced S -> refuse auth-keypair
- client : `src/auth.client.auth-keypair.authenticate` +
  `src/auth.client.server_pin.check` : parse + `trust.verify` the 4th
  field, pin = host-root FINGERPRINT [ 77 chars ], subject must equal the
  announced S BEFORE anything is signed or sent

lists + tests :
- `cfg/zenki/*/subroutines.load-early` + deps for every new module
  [ lane 2 adds NO modules ; if it reports needing one, it is yours ]
- update `bin/test-scripts/test-auth-link-binding.pl`,
  `test-host-root-keygen.pl`, `test-external-link.pl`,
  `test-link-upgrade-client.pl` to the new shapes
- NEW `bin/test-scripts/test-host-root-delegation.pl` : resolver
  [ holder detection, every ownership-rule violation refused, symlinked
  dir \ file refused, non-root cannot create ], post_init creates
  host-root with auto_load_keys = 0 as root and skips as non-root,
  statement build \ parse round trip + every field refusal, trust.verify
  [ ok, wrong fingerprint, bad sig, expired, not yet valid, subject
  mismatch, scope violation ], issuing [ renew threshold, atomic write ],
  select refuses a missing \ expired \ mismatched .dlg, client pins the
  fingerprint and refuses a different host-root, ACCEPTS a rotated S
  delegated by the same host-root. include ONE fixed test vector
  [ fixed-seed throwaway keys, fixed times ] : statement hex, sig,
  fingerprint -- lane 3 must reproduce it ; put it in the spec under
  "test vector" as well.

## P7 pitfalls

- `<a.b>` = `$data{'a'}{'b'}`, `<[x.y]>` = `$code{'x.y'}`, `<[x.y]>->( $arg )`
- `.cmd.` modules get `$call`, reply `{ mode => 'true'|'false', data => STRING }`
- init_code runs BEFORE drop_privs ; deferred work goes in startup callbacks
- `my $x = a and b` parses as `( my $x = a ) and b`
- `$ARG` not `$_`, lowercase comments, `[ ]` not `( )`, 78 columns
- `bin/format-code -c` for syntax, `bin/format-code` on every touched file

## report

`data/tasks/host-root-delegation-perl.report.md` : files changed + why,
the test vector, all test output, mutation checks [ break the ownership
rule check, the fingerprint compare, the expiry check, the subject check
-- each must fail tests -- restore byte-identical ], open questions.

#,,,.,..,,.,,,.,.,..,,.,,,..,,..,,,,,,..,,...,..,,...,..,,...,.,,,,,,,,,.,,..,
#YFQWOMPBFVKPKXJ63TKTJZORTUH4H274JV3DIUITQKNDQJ7SA3FKQSXHJXFOB4CGQKZPMLD35BMWY
#\\\|DAGMTDD3OR4KVD42QA3TLAEMIIACIBYF5NXFOAIUC5BIAG2COHJ \ / AMOS7 \ YOURUM ::
#\[7]SQ5D45I7YT2STAEWQ334UOVFNWY76UV3GOIBZMSZHRBA5QJGNUBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
