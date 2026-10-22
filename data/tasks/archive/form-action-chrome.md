# form.action.send + form.chrome [ lane B2a ]

**base : da5a50396**. small, focused lane -- stay well under the step
limit : read the few files named, batch edits.

## read first

- `data/md/design/HOST-SETUP.md` -- section 'reuse'
- `src/vault-edit.send_action`, `src/vault-edit.handler.reply`,
  `src/vault-edit.process_input_buffer` [ the busy flag ] -- the action
  pattern
- `src/vault-edit.render_chrome`, `src/vault-edit.repaint` -- the chrome
- `src/form.render`, `src/form.handler.stdin_key` -- where the form
  draws and decodes keys

## do

1. **form.action.send** `( $command, $args, $on_reply )` : sends ONE
   routed command [ `protocol-7.command.send.local`, the
   `<form.cube_sid>` prefix like the user-edit senders ], sets
   `<form.busy>` with a label, and on the reply clears it and calls
   `$on_reply` [ a module name ] with the reply. a second send while busy
   is refused [ returns FALSE ]. a timeout [ default 30 s, a parameter ]
   clears busy and calls `$on_reply` with a timeout marker.
2. **key decoding while busy** : form.handler.stdin_key ignores keys
   [ except quit ] while `<form.busy>` is set -- vault-edit's discipline.
3. **form.chrome** : a footer status line the form draws on every render
   [ `<form.status>` text + the busy label with a spinner-free marker ;
   the key-hint line stays ]. `form.chrome.set_status( $text )` updates
   it and repaints. existing form output must not change while no status
   is set.
4. vault-edit is NOT migrated in this lane.

## prove it

- user-edit unchanged : `p7-user-edit show-form taeki` before \ after,
  `cmp` byte-identical [ delete the snapshot files afterwards -- real
  user data ]
- a harness `bin/test-scripts/test-form-action.pl` [ stubs only ] :
  send -> busy set, second send refused, reply -> busy cleared + on_reply
  called, timeout path, keys ignored while busy except quit,
  set_status -> footer line present, no status -> render unchanged
- `bin/format-code -c` on every touched src file

## rules

- touch only form.* [ new + render \ stdin_key ], the new test ;
  `git status` before finishing ; regenerate user-edit + host-edit
  whitelists only
- `qw| a b |` is a LIST ; `<word>` needs a dot ; local ok() ($;$)
- do NOT commit ; write `data/tasks/form-action-chrome.report.md`

#,,,.,.,,,,,.,,,.,.,,,,..,,,.,..,,.,.,,.,,,..,..,,...,...,.,.,...,.,,,,.,,..,,
#QPL35QV7SBWTEQBHBZKB2JU435MXMHMELO5ORNDHFKAYJBQX7XCRWWH4ENGHBBK2JGYOHNBGC3TV4
#\\\|GZLUZTE5RFAFI4T4ULHGSS5EA75NG6ZNB4MK75MOJYMCDZVNB5U \ / AMOS7 \ YOURUM ::
#\[7]YVW6WNCK2HWFNYO4QJU7U2JXGLMRXKH33LABHXQCQFWBM4GDGEAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
