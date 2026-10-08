# form engine extraction : report

lane A of `data/md/design/HOST-SETUP.md` [ decision 1 : ONE form engine ].
base commit `c103c9f38`, branch `base`. no commit made. no zenka restarted ;
all live checks ran against fresh per-invocation user-edit console processes.

## verdict

- `p7-user-edit show-form taeki` : BEFORE vs AFTER **byte-identical** [ `cmp` ]
- `p7-user-edit commands` : BEFORE vs AFTER **byte-identical** [ `cmp` ]
- headless driver [ below ] : open / move / add-field-to-draft / quit-without-
  submit all work ; the real user record was NOT touched [ re-ran show-form
  after : still identical ] ; outbox stayed empty
- `bin/format-code -c` : all 99 touched src files `syntax valid`, 0 reflow

## moved : 67 modules `user-edit.*` -> `form.*` [ git mv ]

### engine core [ was `user-edit.form.*`, now bare `form.*` ]

per the task's own mapping `user-edit.form.escape -> form.escape` the old
`form` subnamespace merges into the new top-level `form` namespace :

    escape addable_fields add_field add_field_name add_field_row build_frame
    build_user_keys_field collapse_summary_field_names field_changed
    multiline_field_names parse_field_options quit removable_field
    remove_field render resort_list schema_from_record scroll_list
    scroll_multiline submit submit_maybe_finish submit_note_secret_result
    submit_note_value_set_result sync_list_mode

### console + menu [ was `user-edit.console.*` / `user-edit.menu.*` ]

    console.browse console.show-form console.start
    console.test-secret-roundtrip
    menu.namespaces menu.open_record menu.open_rows menu.records menu.select
    menu.show_key

### handlers [ was `user-edit.handler.*` ]

    browse_start_reply create_default_reply esc_timeout
    field_options_bootstrap_reply field_options_reply secret_hold_reply
    secret_release_reply stdin_key submit_secret_hold_reply term_resize
    value_all_reply value_get_reply value_set_reply

### terminal / drafts / outbox / misc

    term_init term_restore
    draft.clear draft.load draft.write
    outbox.clear outbox.list outbox.write
    key_actions.submit_delete_confirm submit_delete_name submit_name
    key_actions.submit_passphrase submit_rename_from submit_rename_to
    message parse_params setup_stdin_watcher cmd.char-add
    test.secret_send_hold

### state keys moved with them

`<user-edit.form.*>` -> `<form.*>` ; `<user-edit.{menu,mode,term,esc,test,
cube_sid,create,pending,offer,key_actions,plugin}.*>` -> same path under
`<form.*>` [ raw `$data{'user-edit'}{...}` paths rewritten to match, incl.
the two reference-taking sites in form.handler.stdin_key and
form.setup_stdin_watcher ].

deliberately KEPT as `<user-edit.cfg.*>` : the five `cfg` keys
[ user_keys_display_type / user_keys_name_width / identity_key_name_threshold
/ esc_timeout / clear_scrollback ] -- `editor.ui.ascii_frame.render_form`
reads `<user-edit.cfg.user_keys_display_type>` directly and is outside this
task's file scope, and the keys are set by user-edit's own start file.

## split : the record source [ NEW `user-edit.source.*` ]

7 sender modules, registered by `user-edit.init_code` in ONE callback table :

    <form.source> = {
        default_record => <user-edit.unix_user>,          # bare show-form/start target
        allow_create   => unix_user eq <system.admin-user>,# create-offer gate
        tag_record     => <system.admin-user>,             # :create-admin: tag gate
        value_get      => 'user-edit.source.value_get',    # users.value-get
        value_all      => 'user-edit.source.value_all',    # users.value-all
        value_set      => 'user-edit.source.value_set',    # users.value-set
        field_options  => 'user-edit.source.field_options',# users.field-options
        create_default => 'user-edit.source.create_default',# users.create-default
        secret_hold    => 'user-edit.source.secret_hold',  # sessions.hold
        secret_release => 'user-edit.source.secret_release'# sessions.release
    };

form.* modules invoke them with the variable-call form `<[$sender]>->(...)`
[ note : the translator only accepts `<[$var]>` with NO spaces ]. every
cross-zenka send in the engine now goes through this table -- including the
secret-roundtrip harness, which previously sent sessions.hold/release
directly. call sites converted : form.console.{show-form,start,browse},
form.menu.{select,open_record}, form.offer_create,
form.handler.{value_get_reply x3, create_default_reply},
form.form.submit [ value-set + secret hold ], form.test.secret_send_hold,
form.handler.secret_hold_reply. send-result plumbing preserved [ submit's
fan-in bookkeeping reads the same return values ].

the three policy knobs that were hardcoded unix_user/admin-user reads inside
coupled modules [ username fallback, create-offer gate, create-admin tag
gate ] moved into the table as data, keeping the moved modules
record-independent.

## kept : still `user-edit.*`

    init_code          # unix_user/auth_name/paths + fills <form.source>
    source.value_get value_all value_set field_options create_default
    secret_hold secret_release

68 - 1 + 7 = user-edit keeps 8 modules.

## cfg / plugins / whitelist

- `cfg/zenki/user-edit/zenka.v7` : `modules.load` now `... keys form
  user-edit` ; plugin loading untouched [ plugins.load identical ].
- `plugin.user-edit.*` : names unchanged ; their 8 engine state-key
  references repointed [ `<form.state>` etc. ] ; live `on_submit` handler
  names in key-actions.handler.key repointed to `form.key_actions.*` ;
  comment references updated. plugin hooks are resolved by name from
  `<form.plugin.registry.*>` [ renamed state, same mechanism ] -- every call
  site checked [ form.cmd.char-add, form.form.{add_field,render,
  schema_from_record}, form.handler.stdin_key ].
- `bin/dev/gen-sub-whitelist user-edit` regenerated : 63 `form.*` + 8
  `user-edit.*` entries, 0 stale. ONLY user-edit's whitelist touched.

## headless driver proof [ no real record touched ]

`p7-user-edit start taeki -no-tty` [ fresh process ] then
`p7c 'taeki[user-edit].char-add' ...` :

    '[Down]'                                 -> field 2 of 11, repaint ok
    ':Down x9:' / ':Down x3:' / '[Down]'     -> list expand/collapse/resort
                                                transitions, add-a-field row
    '[Enter]' on the add-a-field row         -> optional field added to the
                                                DRAFT only [ 12 fields ]
    '[Ctrl+c]'                               -> '<< cancelled >>', clean exit

the draft checkpoint side effect was expected [ design : draft survives ] ;
/var/protocol-7/user-edit/draft/taeki.yaml existed before the test and was
restored to its exact pre-test bytes [ md5 verified ] afterwards. outbox
stayed empty throughout. no form output is reproduced here by design.

## out-of-scope working-tree changes [ NOT mine -- do not attribute ]

`git status` shows a concurrent lane's staged work that appeared in this
tree at 02:31, one minute after the base commit and before my first edit
[ my initial status was clean ] : the `keys -> keystore` module renames,
`src/v7-zenki.{backend.read_small,backend.run,cmd.owner-statement}`,
`src/v7-zenki.delegation.issue`, `src/keys.console.*`,
`cfg/zenki/{keys,v7-zenki}/*`, `bin/c_src/p-7-r.c`,
`bin/test-scripts/test-*`, `data/md/design/HOST-SETUP.md`,
`data/md/documentation/module-dependency-graph.asc`,
`src/base.list.subroutines`. these match the design doc's claude lane
[ host-side owner-statement command ] and were left untouched -- reverting
another active lane's staged work would destroy it. every change of MINE is
inside : `src/form.*`, `src/user-edit.*`, `src/plugin.user-edit.*`,
`cfg/zenki/user-edit/*`.

## open questions / notes

1. `cfg/zenki/user-edit/subroutines.load-early` is regenerated but UNSIGNED
   : `bin/Protocol-7 sourcecode update-signatures` aborts here [ "source
   signature key not loaded" ]. functionally inert [ the loader strips `#`
   lines ] but should be signed where the proto-7.sourcecode key lives.
2. `src/base.list.subroutines` still lists the old `user-edit.*` names and
   lacks `form.*` -- it is a generated registry owned by the sourcecode
   zenka [ vault-edit's addition was handled the same way ] ; regenerate
   with `sourcecode update-sub-list` outside this lane, or leave stale [
   nothing at runtime consumes it for loading ].
3. `cfg/zenki/user-edit/deps/src-used/form` appeared untracked : runtime dep
   self-registration at zenka start [ same mechanism that maintains the
   other src-used entries ].
4. `<user-edit.cfg.*>` keys stay user-namespaced [ external
   editor.ui.ascii_frame.render_form read ] : host-edit will inherit the
   defaults `//=` unless its own start file sets them -- acceptable for the
   later lane, flagged here.
5. form.menu.namespaces / menu.records still hardcode the `host-system` and
   `keys` namespace vocabulary [ user-edit semantics ] ; host-edit may want
   its own namespace list -- a data-table candidate, left as-is to keep
   behaviour byte-identical.
6. display values [ frame title 'user-edit : %s', frame name
   'user-edit-form', menu fallback 'user-edit' ] intentionally unchanged :
   they are output, not references, and the cmp proof depends on them.

#,,,,,,..,,,,,,,,,..,,..,,.,.,,,,,,.,,,,.,,,.,..,,...,..,,,.,,..,,,.,,...,...,
#TCTYNYMRQ7YF35RT4VIQAMCYG2GKT4LPH373HTFIYFWQ46L4LGLK7CDIZBII4JZJT63X5IJ5Z6JY4
#\\\|LQS4PI75TLHYUMT4RVEK774GHVT2FVTLKNVB2N74RLDG7U74DW7 \ / AMOS7 \ YOURUM ::
#\[7]PBNHWEDSQXNVK77X5JEZ5Z3J2H7ADPFL3JDMA6MEOV2QPLNIEQBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
