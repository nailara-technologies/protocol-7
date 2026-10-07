# tests : v7-zenki liveness sweep + Perl link-upgrade client

two TEST-ONLY scripts for code verified only live or by hand on
2026-10-05 \ 06. no change to anything under `src/` or `cfg/` -- if a
test reveals a real bug, STOP, describe it in the report [ inputs,
expected, actual ], do not fix it.

do NOT start, restart or reload any zenka, no sudo, no commit, do NOT
try to sign files.

harness pattern : copy the setup of `bin/test-scripts/test-prng-entropy.pl`
[ `compile_module` via `AMOS7::Protocol::P7Syntax::p7_syntax__translate`,
`%code` \ `%data`, `TRUE => 5`, `FALSE => 0`, the `ok()` helper, exit code ].
`<a.b.c>` in modules = `$data{'a'}{'b'}{'c'}`, `<[x.y]>` = `$code{'x.y'}`.

## 1. bin/test-scripts/test-v7-liveness-sweep.pl

module : `src/v7-zenki.handler.liveness_sweep` [ read its header ]. compile
it and `v7-zenki.child.add` for real ; stub `base.logs` [ record ],
`base.ntime`, `v7-zenki.instance_ids` [ returns your test instance ids ],
`v7-zenki.handler.sig_chld` [ RECORD ( pid, exit ) calls, do nothing else ].
`v7-zenki.sub-process.pid_alive` : compile the real one [ it checks /proc ].

instances live in `$data{'v7-zenki'}{'zenka'}{'instance'}{<iid>}` with
`{ zenka_name, process => { id => <pid> } }` ; a pending restart is
`{ timer => { restart => <object with is_active> } }` ; a stop in
progress is `$data{'zenka'}{'instance'}{'shutdown'}{<iid>}` ; child
entries are `$data{'v7-zenki'}{'child'}{<pid>}`.

real pids : a DEAD pid = fork a child that exits, `waitpid` it ; a ZOMBIE
= fork a child that exits, do NOT waitpid until the end [ /proc/<pid>/stat
state Z ] ; a LIVE pid = `$$` or a sleeping child. reap everything at
the end.

checks :
- live pid : no sig_chld call, no child entry added
- dead pid, no child entry, not stopping : child entry added
  [ instance_id + liveness flag ] AND sig_chld( pid, -1 ) recorded ;
  return value counts it
- zombie : treated like dead
- dead pid, instance stopping : sig_chld recorded, NO child entry added
- dead pid with a pending restart timer [ is_active true ] : skipped
- dead pid still tracked on the NEXT sweep : one level-0 "still tracked"
  log, no second sig_chld ; on the third sweep : silence
- a pid no instance tracks any more is forgotten from
  `$data{'v7-zenki'}{'liveness'}{'recovered'}`
- non-numeric \ < 2 pids ignored

## 2. bin/test-scripts/test-link-upgrade-client.pl

modules : `protocol.protocol-7.link-upgrade.handshake`,
`protocol.protocol-7.link-upgrade.client_activate`,
`protocol.protocol-7.encryption.init` [ read all three headers ; the
server side for reference : `src/base.handler.link-upgrade`,
`src/cube.cmd.link-upgrade` ].

handshake over a `socketpair` [ AF_UNIX, SOCK_STREAM ] ; the fake SERVER
runs in a forked child and speaks the exact server lines :
`link-upgrade` -> `TRUE link-upgrade OK <its curve25519 pub, B32>` ;
`link-pub-key <b32>` -> `SIZE 0` [ it computes the DH ] ;
`link-confirm-encoding none` -> `encoding-confirmed` ;
`link-complete <n>` -> `link-complete-ok`. the child reports its shared
secret + the received nonce sid back [ temp file or pipe ].

checks :
- success : ( 1, { shared_secret, nonce_sid } ), secret == the server's
  DH result, 32 bytes ; nonce_sid in 1 .. 2**32-1 and == what the server
  received
- each wrong answer [ no OK in the first line, not `SIZE 0`, not
  `encoding-confirmed`, not `link-complete-ok`, an invalid B32 key ] ->
  ( 0, { error } ), no die
- a silent server -> fails within the timeout [ pass `{ timeout => 1 }` ],
  never hangs [ guard the test itself with `alarm` ]
- client_activate on a minimal session : stub `base.session.init_state`
  to call the compiled `protocol.protocol-7.encryption.init` with
  ( sid, mode, 3 ) ; stub what encryption.init needs [ `base.logs`,
  `base.perlmod.loaded` \ `.load` ] -> `link_role` client,
  `link_nonce_dir_write` == 1, `link_nonce_dir_read` == 2, the dh secret
  deleted afterwards ; wrong-length secret or missing nonce sid -> FALSE
- encryption.init with `link_role` server -> write 2 \ read 1 ; with no
  role -> returns FALSE [ refuses ]
- bonus if it stays simple : a frame produced by a client session's
  writer [ the `base.handler.link-upgrade.frame-<id>` sub encryption.init
  installs ] decrypts with the SERVER's read nonce [ direction 1 ] and
  NOT with direction 2

## pitfalls [ hit in this codebase this week ]

- `AMOS7::Assert::Truth::is_true` returns a LIST in list context -> wrap
  in `scalar()` inside `ok( .. )`
- `ok( .. ) or say .. for @list` loops the WHOLE statement -- write the
  `for` as its own statement
- `my $x = a and b` parses as `( my $x = a ) and b` -- use if-conditions
- stub `base.s_warn` and `base.caller` when a module may complain
- every new package in a test needs its own `use English`
- `$ARG` not `$_`, lowercase comments, `[ ]` not `( )`

## report

both scripts' full output, what each check proves, anything that looked
like a real bug [ described, not fixed ]. write it as soon as both pass.

#,,..,...,,,.,..,,.,.,,,.,,.,,...,.,,,,,.,...,..,,...,...,..,,,,,,,..,..,,,,,,
#FJQ5AARXTREM6DEIZSWKWTEUYDVFR5E7JFIGMTQRJ25QLGBHESO7SHELUP4Q2CIMXKT4YT6LZJ7ZU
#\\\|SH4YC6DQJ7LOB7GD74AND7DFC7UJ6HDJXQFFN3AKZGMNFTAJPH5 \ / AMOS7 \ YOURUM ::
#\[7]SOO5OBTORUPBICTQY2ARFYIIBXRTBEUNMCNKHEE636NDQSJHGSBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
