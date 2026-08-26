# task: zenka-side stdio multiplex emitter

## relation

depends on `data/tasks/completed/stdio-multiplex-type-tag-codec.md` and
`data/tasks/completed/stdio-multiplex-unix-socket-transport.md`. is the
send-side counterpart of `data/tasks/v7-console-stdio-multiplex-demux.md`
[ already landed: `v7.handler.stdio_multiplex_demux`,
`v7.handler.stdio_multiplex_listen`, `v7.handler.stdio_multiplex_scope` ].

## the gap

v7's new listener opens `/dev/shm/.7/STDIO/<zenka>` for any zenka with
`stdio.multiplex = yes` in its start config, and knows how to demux
typed runs once it receives them — but no zenka ever connects to that
socket or emits a typed run. this task ships the client side: a zenka
that opts in connects to its own multiplex socket and emits its
stdout/stderr as typed-run frames.

## scope

### `base.stdio_multiplex.connect`

```
# name  = base.stdio_multiplex.connect
# descr = connect this zenka to its v7-side multiplex listener, if
#         opted in via start config
```

- reads `<stdio.multiplex>` from this zenka's own start config via
  `<[base.cfg_bool]>`; return early [ no-op ] if not enabled.
- socket path: `/dev/shm/.7/STDIO/<system.zenka.name>` [ same path
  v7's listener binds, per `v7.handler.stdio_multiplex_listen` ].
- connects via `<[base.stdio.transport.connect]>`, storing the
  resulting connection handle under
  `<base.stdio_multiplex.conn>` for use by the emit helpers below.
- on_record callback: handle inbound SIN replies [ prompt answers
  routed back from v7 ] — for this task, log + stash into
  `<base.stdio_multiplex.inbound_sin>` queue; consumption by callers
  is a non-goal here.
- call from deferred init [ push onto `system.callbacks.initialized`,
  per [[feedback-deferred-init]] ], so the listener side has had a
  chance to bind first.

### `base.stdio_multiplex.emit_eout`

```
# name  = base.stdio_multiplex.emit_eout
# param = $fd, $bytes_sref
# descr = emit an EOUT typed run for the given fd [ 1 = stdout,
#         2 = stderr, >=3 = sub-tree ]
```

- no-op if `<base.stdio_multiplex.conn>` is not connected.
- builds the frame via `<[base.stdio.frame.encode]>->('EOUT', 'nibble',
  $bytes_sref->$*, { fd => $fd })` and writes it with
  `<[base.stdio.transport.emit]>`.

### `base.stdio_multiplex.emit_str` / `base.stdio_multiplex.emit_num`

```
# name  = base.stdio_multiplex.emit_str
# param = $name, $value
# descr = emit a named STR typed run [ stdout.value.<name> slot ]
```

```
# name  = base.stdio_multiplex.emit_num
# param = $name, $value
# descr = emit a named NUM typed run [ stdout.metric.<name> slot ]
```

both: no-op if not connected; encode via `base.stdio.frame.encode`
with `header => { name => $name }`, `nibble` encoding, write via
`base.stdio.transport.emit`.

## non-goals

- no automatic redirection of the existing per-zenka stdout/stderr
  filehandles — these are opt-in helper calls, not a transparent
  shim. wiring an existing zenka's actual stdout into
  `emit_eout` is a separate follow-up.
- no META scope-enter/scope-leave emission [ nested-scope provenance
  is for relay zenki, not leaf emitters — defer until a concrete
  relay use case exists ].
- no SIN/RIN/TOUT emit helpers yet — only EOUT/STR/NUM, the
  highest-value cases for a first opt-in zenka.
- no migration of any existing zenka to use these helpers.

## acceptance criteria

- a test zenka with `stdio.multiplex = yes` connects successfully
  when v7's listener is up [ verify via v7 log:
  "stdio multiplex listener opened for <zenka>" ].
- `emit_eout(1, \"hello\\n")` from that zenka results in v7's
  `<zenka>.stdout` slot content containing "hello".
- `emit_num('latency_ms', 42)` results in
  `<zenka>.stdout.metric.latency_ms` slot content reflecting the
  value.
- zenki without `stdio.multiplex = yes` are unaffected [ helpers
  remain no-ops ].

## signatures note

no `#,,..` stubs. do NOT run update-signatures. do NOT modify
subroutine whitelists beyond what's needed for the test zenka.
lowercase comments, `[ word ]` annotations, `$ARG` not `$_`,
one-sub-per-file [ no inline `sub {}` helpers ].

#,,,,,.,.,,,.,.,.,,..,..,,,,.,,,.,,..,,,,,,..,..,,...,..,,...,.,.,,..,..,,,,,,
#QM776FRRL34FI7RZILRPJFO7NIUUNPVVJRMBE2227NKLZPOBH64BQVHMBDIEAEP6S5N4B6RZTCNLI
#\\\|BFQK3C52DVNWV42XKYBXALWOBAXTANZP3RQC2BZ6ZFKBXUFGFDN \ / AMOS7 \ YOURUM ::
#\[7]VJLSIBC3IETMHEFBSFIHH5TQNBQ62Y6HGYY3WB74AHVI326MO6DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
