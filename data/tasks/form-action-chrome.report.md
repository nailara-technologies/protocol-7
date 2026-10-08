# form.action.send + form.chrome [ lane B2a ] -- report

base : c36161645. done per data/tasks/form-action-chrome.md.

## what was built

- `src/form.action.send` `( $command, $args, $on_reply, $timeout )` --
  refuses a second send while `<form.busy>` is set [ returns FALSE ],
  otherwise sets `<form.busy>` = `{ label => $command, on_reply =>,
  timer => }`, sends ONE routed command through
  `protocol-7.command.send.local` with the `'<form.cube_sid>.'` prefix
  [ user-edit.source.value_get shape ], and arms a timeout timer
  [ default 30 s, parameter ]. a non-positive send.local result clears
  busy at once [ no reply will ever arrive -- vault-edit.send_action's
  own documented check ].
- `src/form.handler.action_reply` -- the send.local reply handler :
  cancels the timer, clears busy BEFORE the callback, calls
  `$on_reply` with the reply.
- `src/form.handler.action_timeout` -- clears busy and calls `$on_reply`
  with a timeout marker `{ timeout => TRUE }`.
- `src/form.handler.stdin_key` -- busy discipline : every key is dropped
  while `<form.busy>` is set except ctrl-c [ quit ]. an Esc-quit still
  works because a bare Esc never reaches the key loop [ esc_timeout's
  debounce calls form.escape directly ].
- `src/form.chrome` -- footer status line on the key-hint block's own
  `:` gutter tone : `<form.status>` text plus the busy label in a static
  `[ label ]` marker [ spinner-free ]. prints NOTHING -- not even a
  blank line -- while neither is set.
- `src/form.chrome.set_status` `( $text )` -- sets `<form.status>` and
  repaints by bumping `<form.dirty>` [ the same watcher path a
  keystroke takes ].
- `src/form.render` -- one added `<[form.chrome]>;` call before
  `STDOUT->flush()`, in BOTH interactive and one-shot modes ; a no-op
  print when nothing is set.

vault-edit NOT migrated, per the lane.

## proof

- `p7-user-edit show-form taeki` before \ after : `cmp` BYTE-IDENTICAL
  [ snapshots taken, compared, deleted -- real user data ].
- `bin/test-scripts/test-form-action.pl` [ stubs only, mirrors
  test-editor-control-parity.pl's translate-and-eval loader ] :
  **31 passed, 0 failed** -- covers send -> busy set, second send
  refused [ never reached send.local ], cube_sid route prefix,
  default 30 s + explicit timeout parameter, reply -> busy cleared +
  on_reply called, timeout marker path, send.local failure -> busy
  cleared, stray reply no-op, keys ignored while busy except ctrl-c
  quit, keys decoded again once busy clears, chrome prints nothing
  with no status, footer shows status / busy label / combined,
  set_status updates + repaints + clears.
- `bin/format-code -c` : all 7 touched src files `syntax valid`.
- `bin/dev/gen-sub-whitelist user-edit host-edit` : regenerated only
  [ user-edit 724 subs, host-edit 714 subs, 2 updated ].

## notes

1. new src modules + regenerated whitelists are UNSIGNED :
   `bin/Protocol-7 sourcecode sign` aborts here [ "sourcecode not
   loaded" -- the proto-7.sourcecode key does not live on this host ].
   same state the form-engine-extraction lane reported ; sign with
   `sourcecode update-signatures` where that key exists.
2. `git status` before finishing : my scope is exactly the 7 src files
   above + the new test + the 2 regenerated whitelists. a concurrent
   lane's staged host-edit.* files + test-host-edit-transport.pl are
   present in the index and were left untouched ; not committed, per
   the lane rules.
3. no zenka restarted, no form submitted, no commit.

#,,,.,..,,,,.,,..,.,.,,.,,,,,,,.,,..,,,,.,,,,,..,,...,...,,,,,,..,,..,.,,,.,,,
#Y7DJIXANX5CDSBMU5A2HMWFH2LMUT5MKBRXBSJ6UBE6IJDZAW7I6AXZFK7MHZXRIE2464MULSNDRO
#\\\|CQKNOLZHVUGP7GYSG76WRMG4VU5ROAG7RGZMQWZXID2PPG6AV6I \ / AMOS7 \ YOURUM ::
#\[7]DPAJ2OW437YJP5UEDLHD5GOHDHWYU2AP2PAGXZHIOII6PLYPWKDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
