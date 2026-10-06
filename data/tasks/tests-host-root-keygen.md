# tests : host-root key creation [ crypt.C25519 ]

ONE test-only script for code verified only live [ `25a60f33b`,
2026-10-05 ]. no change to anything under `src/` or `cfg/` -- if a test
reveals a real bug, STOP, describe it in the report [ inputs, expected,
actual ], do not fix it.

do NOT start, restart or reload any zenka, no sudo, no commit, do NOT
try to sign files. NEVER read, list, copy or write anything under any
real key dir [ `~/.n/`, `/home/protocol-7/.n/`, any `user-keys` ] --
every key dir in this test is a fresh `File::Temp` tempdir.

you write exactly one new file : `bin/test-scripts/test-host-root-keygen.pl`.
a second agent works in parallel on `bin/test-scripts/test-external-link.pl`
-- do not touch it, and touch no other file.

harness pattern : copy the setup of `bin/test-scripts/test-link-upgrade-client.pl`
[ BEGIN lib path, `compile_module` via `AMOS7::Protocol::P7Syntax::
p7_syntax__translate`, `%code` \ `%data` \ `%keys`, `TRUE => 5`,
`FALSE => 0`, the `ok()` helper, exit code ]. `<a.b.c>` in modules =
`$data{'a'}{'b'}{'c'}`, `<[x.y]>` = `$code{'x.y'}`.

## modules

- `src/crypt.C25519.gen_keys` [ read it fully : the `$fresh_secret`
  path when neither passphrase nor secret is given ]
- `src/crypt.C25519.post_init` [ the host-root block at its end ]
- for reference : `crypt.C25519.key_exists`, `crypt.C25519.write_keys`,
  `crypt.C25519.key_vars`, `base.prng.*` [ `src/base.prng.*` ]

compile the REAL `gen_keys` and the real `base.prng.*` modules it needs
[ reseed \ bytes \ add_entropy \ entropy_pool -- see what
`bin/test-scripts/test-prng-entropy.pl` compiles and how ]. stub
`crypt.C25519.key_vars` to return a hash pointing into the tempdir.

## checks

gen_keys :
- `gen_keys('host-root')` with no passphrase \ secret -> a key pair in
  `$keys{'C25519'}{'host-root'}` [ private 32 bytes, public 32 bytes,
  public == curve25519 public of private ; check the real stored format
  first, it may be encoded ]
- two fresh generations [ delete the entry in between ] give different
  private keys ; 8 generations : all distinct
- same passphrase twice -> same key [ deterministic path untouched ]
- a 31-byte secret -> undef ; secret + passphrase -> undef ; an already
  loaded name -> FALSE, existing key unchanged
- `$harmoic_public_keys` : if gen_keys loops until the public key passes
  a truth check, check the result passes it [ `AMOS7::Assert::Truth`,
  wrap `is_true` in `scalar()` ]

post_init host-root block [ compile the real post_init only if its
stubs stay manageable ; otherwise extract nothing and test the block's
DECISION by stubbing `gen_keys` \ `write_keys` \ `key_exists` as
recorders and driving post_init with `auto_load_keys` on ] :
- zenka name `v7-zenki`, no host-root on disk -> gen_keys('host-root')
  + write_keys('host-root') called once each
- zenka name anything else [ `cube`, `httpd` ] -> neither called
- host-root already exists -> neither called
- `<crypt.C25519.cfg.create_host_root_key>` set to FALSE -> neither called
- host-root already in `%keys` but not on disk -> write_keys only

## pitfalls [ hit in this codebase this week ]

- `AMOS7::Assert::Truth::is_true` returns a LIST in list context -> wrap
  in `scalar()` inside `ok( .. )`
- `ok( .. ) or say .. for @list` loops the WHOLE statement -- write the
  `for` as its own statement
- `my $x = a and b` parses as `( my $x = a ) and b` -- use if-conditions
- the production runtime loads `use bytes` transitively -- the precedent
  test mirrors it, keep that
- stub `base.s_warn` and `base.caller` when a module may complain
- `$ARG` not `$_`, lowercase comments, `[ ]` not `( )`
- `bin/format-code -c <file>` for syntax checks, not bare `perl -c`

## report

write `data/tasks/tests-host-root-keygen.report.md` : full script
output, what each check proves, anything that looked like a real bug
[ described, not fixed ]. write it as soon as the script passes.

#,,.,,...,,..,,,,,,..,...,,,,,,,,,,..,.,.,.,,,..,,...,...,...,..,,,..,...,,,.,
#67IJVXV74MMN7SYBEEVG3KBIYNSM3TSAGAS5PWDHPJVGTSXK2FPDX7GVCLYWXTSPJGZK3J2BPBD7M
#\\\|KF2GO63IKMTJZ4NGHOIFRVBFZG6TFJKOTUFX67ZTTDMXBGB4P4Y \ / AMOS7 \ YOURUM ::
#\[7]WYEIA5WIWMN2T3TRTRDSHSJTVVX32HTQ4F72FAOSMAGGM3RVTCDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
