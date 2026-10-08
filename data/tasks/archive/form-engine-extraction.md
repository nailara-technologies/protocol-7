# form engine : extract user-edit's record-independent part into form.*

**base : ask for the hash** [ the commit carrying data/md/design/
HOST-SETUP.md ]. no zenka restart ; the user-edit console zenka is a
fresh process per run, so live checks are safe.

## why [ read first ]

- `data/md/design/HOST-SETUP.md` -- decision 1 : ONE form engine. a new
  host-edit zenka will edit host records with the SAME terminal form
  user-edit uses for user records. this task only extracts ; host-edit
  itself is a later lane.
- CLAUDE.md [ module format, `<a.b>` \ `<[x.y]>` syntax, style ]
- `cfg/zenki/user-edit/zenka.v7` [ modules.load, plugins.load ]

## today

68 `user-edit.*` modules. 29 touch user records \ usernames [ users zenka
commands, `<user-edit.unix_user>`, record schema ] :

    console.browse console.show-form console.start form.addable_fields
    form.add_field form.build_frame form.collapse_summary_field_names
    form.field_changed form.multiline_field_names form.parse_field_options
    form.removable_field form.remove_field form.render
    form.schema_from_record form.submit form.submit_note_value_set_result
    handler.create_default_reply handler.field_options_bootstrap_reply
    handler.secret_hold_reply handler.submit_secret_hold_reply
    handler.value_all_reply handler.value_get_reply handler.value_set_reply
    init_code menu.open_record menu.records menu.select offer_create
    setup_stdin_watcher

the other 39 [ term_init \ term_restore, draft.*, outbox.*, form.escape
\ scroll_* \ resort_list \ sync_list_mode \ quit, handler.stdin_key \
esc_timeout \ term_resize, key_actions.*, message, .. ] are generic.

## do

1. **move the generic modules** to `form.<same sub path>` [ git mv,
   `user-edit.form.escape` -> `form.escape`, `user-edit.draft.write` ->
   `form.draft.write`, .. ] and rewrite every reference [ `<[..]>`,
   `$code{'..'}`, handler names in timer \ watcher registrations ].
   their state keys move too : `<user-edit.x>` -> `<form.x>` where the
   state belongs to the engine [ terminal, cursor, list mode, drafts ].
2. **the record source** : every place a coupled module calls the users
   zenka [ value-get, value-all, value-set, field-options,
   create-default, secret hold \ release ] goes through ONE callback
   table the zenka registers at init :
   `<form.source> = { value_get => <module>, value_set => .., .. }`
   [ user-edit.init_code fills it with its users-zenka senders ]. the
   coupled modules that are then record-independent move to `form.*` ;
   what stays genuinely users-specific stays `user-edit.*`.
3. user-edit's `modules.load` loads `form` + `user-edit` ; plugins
   [ plugin.user-edit.* ] keep working unchanged [ their hooks are
   called by name -- check every call site ].
4. regenerate ONLY user-edit's whitelist : `bin/dev/gen-sub-whitelist
   user-edit`.

## behaviour must not change -- prove it

- BEFORE any edit : `p7-user-edit show-form taeki > /tmp/form-before.txt`
  [ and `p7-user-edit commands > /tmp/cmds-before.txt` ]. AFTER : the
  same commands, `cmp` both -- byte-identical [ if a difference is
  intended, explain it in the report ].
- the headless driver : `p7-user-edit start -no-tty` + `p7c
  taeki[user-edit].char-add <key>` [ see user-edit.cmd.char-add ] --
  open a record, move, add a field to the DRAFT, quit WITHOUT submit.
  never submit, never change a real record.
- `bin/format-code -c` on every touched src file [ NEVER plain perl -c ].
- the form shows a REAL user record [ names, addresses ] : never paste
  form output into the report or any repo file -- report only 'cmp :
  identical' \ the differing line NUMBERS

## rules

- touch only user-edit.*, the new form.*, cfg/zenki/user-edit/* and
  plugin.user-edit.* call sites ; `git status` before finishing
- `qw| a b |` is a LIST ; `<word>` needs a dot ; new test packages
  `use English`
- do NOT commit ; write `data/tasks/form-engine-extraction.report.md` :
  moved \ split \ kept per module, the callback table, the before \ after
  cmp results, open questions

#,,,,,,.,,.,.,.,.,.,.,,,,,,,,,,,,,...,,..,,.,,..,,...,...,..,,.,.,..,,...,,,.,
#LREDAIMHYMOWJGUHM4HJI3XQWNPXHIVFEGNRKQCEMBJXQ5QGZAIHMGOHZANFTJK36UIZHG677LYNO
#\\\|6VX3R6Z7WRZ3XB7CALUBCKDSODIZYI53O36UNJQIXG7UBELDOPL \ / AMOS7 \ YOURUM ::
#\[7]37NIILYF4MPQJ4RPE6VZBIOTVJBSNDPP5U56CBO53QEMKBYAJKDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
