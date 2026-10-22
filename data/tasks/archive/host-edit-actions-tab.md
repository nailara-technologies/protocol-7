# host-edit actions tab [ lane B2c-ui ]

**base : 76a6c289c** [ host-edit.flow.* landed ]. small lane : read the
named files, mirror the existing plugin, batch edits.

## read first

- `src/host-edit.flow.start` \ `.step` \ `.passphrase` \ `.cancel` -- the
  flow API [ state in `<host-edit.flow>->{<name>}` : step, status,
  key_id, leaf_name ; steps connect .. done \ error \ need_passphrase ]
- `src/plugin.user-edit.key-actions.*` [ tab_info, render, handler.key,
  cursor_char, init_code ] + `src/plugin.user-edit.registry.post_init` --
  THE pattern to mirror [ a pinned synthesised field, Enter opens an
  in-frame `editor.control.prompt`, masked for a passphrase ]
- `src/form.schema_from_record` [ how the synthesised field is pushed ],
  `cfg/zenki/host-edit/zenka.v7` + `cfg/zenki/user-edit/zenka.v7`
  [ plugins.load \ [load_plugins:..] ]

## do

`plugin.host-edit.actions.*` [ + `plugin.host-edit.registry` if the
registry is per zenka ] : a 'host actions' tab on every host record.

- **render** : the flow's step + status for this record, the pinned key
  id label [ host-edit.trust.pin_state ] and the next key hint
- **Enter** : no flow \ done \ error -> `host-edit.flow.start(<name>)` ;
  `need_passphrase` -> open a MASKED `editor.control.prompt` ; its submit
  -> `host-edit.flow.passphrase(<name>, <value>)`, then close the prompt
- **c** : `host-edit.flow.cancel(<name>)`
- the frame repaints while a flow runs [ the status line already does
  via form.chrome.set_status -- check the tab body follows ]
- the tab is driven by keys from the terminal OR `char-add` alike

## prove it -- NEVER run a real flow

a live flow would write REAL pins into the user's pin store. so :

- a harness `bin/test-scripts/test-host-edit-actions-tab.pl` [ stubs
  only : host-edit.flow.* stubbed, record stubbed ] : render per step,
  Enter -> start called, need_passphrase -> masked prompt opens, submit ->
  flow.passphrase gets the value, prompt closed, 'c' -> cancel
- live : ONLY `bin/Protocol-7 host-edit show-form` of a temp `zz-test`
  record [ render the tab ], never Enter on it ; remove `zz-test` after
- user-edit unchanged : `p7-user-edit show-form taeki` before \ after,
  `cmp` byte-identical, snapshots deleted [ real user data ]
- `bin/format-code -c` on every touched src file

## rules

- touch only plugin.host-edit.*, cfg/zenki/host-edit/zenka.v7, the new
  test [ + form.* only if the plugin hook needs a generic parameter --
  user-edit output must stay identical ] ; `git status` before finishing
- regenerate ONLY host-edit's whitelist
- NEVER end a new module with a decorative signature-like line [ `#,,..`
  ] -- the sign run adds the real block
- `qw| a b |` is a LIST ; local ok() ($;$) ; do NOT commit
- write `data/tasks/host-edit-actions-tab.report.md`

#,,.,,...,.,,,,.,,,,,,,..,.,.,,.,,.,.,,,,,.,,,..,,...,...,...,,..,,,,,.,,,,..,
#UKYATK2V4ET3LLDKA4DBQPE2XHNLUVXO3IOKJYVBQL6TM2ARJCZ2UEB25RKDIWM4MHHSTH53O6F4G
#\\\|DR7XR4VTH3K6K5JALD67JXO4IUXNINZ2ZAAIAYGQI5K23VFGIPJ \ / AMOS7 \ YOURUM ::
#\[7]FJNSVXYUKLUGVW3FJZIZGOP2B2XEYYECCXZZBONUNQ3RLHVWRIBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
