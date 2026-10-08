# host-edit zenka : records + form [ lane B1 ]

**base : b282f8fce** [ form.* engine extracted ]. no zenka restart ; a
console zenka runs as a fresh process per invocation.

## read first

- `data/md/design/HOST-SETUP.md` -- decisions, 'host record', 'add-host
  flow' [ B1 = records + form only ; the flow's ACTIONS are lane B2 ]
- `data/tasks/form-engine-extraction.report.md` -- what form.* still
  names user-edit [ display strings, `<user-edit.cfg.*>`, the namespace
  vocabulary of form.menu.namespaces \ menu.records ]
- `src/user-edit.init_code` -- the `<form.source>` table [ senders +
  default_record \ allow_create \ tag_record ] ; `src/user-edit.source.*`
  -- the senders ; `src/form.handler.*_reply` -- the reply shapes the
  engine expects
- `cfg/zenki/user-edit/zenka.v7` -- the start file to mirror
- CLAUDE.md [ module format, `<a.b>` \ `<[x.y]>` syntax, style ]

## do

1. **zenka** : `cfg/zenki/host-edit/zenka.v7` [ + start.cfg if user-edit
   has one ] mirroring user-edit's, loading `form` + `host-edit` [ + what
   form needs ]. console commands come from form.* [ start, show-form,
   browse, commands ] -- check `p7-host-edit commands` [ v7-zenki installs
   the p7-<zenka> link on its start ; until then `bin/Protocol-7
   host-edit <cmd>` ].
2. **records** : one file per host under the zenka's data dir
   [ `<[file.zenka_dir.data_path]>` -> /var/protocol-7/host-edit/,
   VAR_P7 keyword like user-edit ] -- `hosts/<name>.json`, written temp +
   rename, 0600. fields [ HOST-SETUP.md 'host record' ] : name, addresses
   [ list ], link_user, ssh [ user@host, port ], transports [ ordered
   list ], owner [ owner pin name ], roles [ list ]. a name rule like the
   trust name rule [ `[a-z0-9][a-z0-9._-]{0,62}` ].
3. **the record source** : `host-edit.source.*` senders registered in
   `host-edit.init_code` as `<form.source>`. they do LOCAL file io and call
   the given reply handler with the SAME reply shape the users zenka gives
   [ read form.handler.value_get_reply etc. ] -- deferred to the next
   event tick [ a 0 s timer, as the network reply would be ], never
   inline. secret_hold \ secret_release : host records hold no secrets ->
   reply 'not supported' in the shape the engine handles.
4. **read-only trust columns** : the form shows, per host, the pin state
   from the CLIENT pin store [ `keys.list_remote_keys`-style read of
   `~/.n/remote-keys/servers/<name>_<port>.public` : key id label, leaf
   name, since ] and whether an owner pin exists -- NEVER stored in the
   record [ HOST-SETUP.md : pins are the single source of truth ]. no pin
   -> 'not yet contacted'.
5. **form.* genericity** : make the user-edit-only parts of form.*
   parameters of `<form.source>` or the zenka cfg [ frame title, frame
   name, menu fallback, the namespace vocabulary ] -- user-edit passes its
   current values so its output stays BYTE-IDENTICAL.

## prove it

- user-edit unchanged : BEFORE your first edit `p7-user-edit show-form
  taeki > /tmp/ue-form-before.txt` + `p7-user-edit commands > /tmp/ue-
  cmds-before.txt` ; AFTER : cmp both, byte-identical. delete the /tmp
  files at the end [ they hold a real user record ].
- host-edit : create a TEST record `zz-test` [ address 127.0.0.1:42 ] via
  the form or a small harness ; show-form it ; the trust column for
  127.0.0.1:42 reads the existing pin. remove `zz-test` at the end.
- a test harness `bin/test-scripts/test-host-edit-records.pl` [ stubs
  only, temp dirs ; the record source : get \ set \ all \ create_default,
  name rule, temp + rename, 0600, the deferred reply ]
- `bin/format-code -c` on every touched src file [ NEVER plain perl -c ]

## rules

- touch only host-edit.*, form.* [ genericity only ], user-edit.init_code
  [ new table keys ], cfg/zenki/host-edit/*, the new test ; `git status`
  before finishing
- regenerate ONLY host-edit's + user-edit's whitelists
- no real hostnames \ ports \ ssh details in any repo file [ examples
  use zz-test, 127.0.0.1 ]
- `qw| a b |` is a LIST ; `<word>` needs a dot ; test packages `use
  English` ; local ok() with a ($;$) prototype
- budget : batch edits, do not re-read files you already know [ the last
  lane hit the 100 step limit ]
- do NOT commit ; write `data/tasks/host-edit-zenka-records.report.md`

#,,,.,,,,,.,.,..,,,.,,,,.,,,,,...,,..,,,.,,..,..,,...,...,,.,,,..,,.,,,,,,,.,,
#5VR2FWVUNUE2654FST3MRWYHVYJKQ6IBHWEM2YTZZPZS2FQFPCQ5Q2NR2G4IBSCHBGKIFARVKZKAQ
#\\\|Q54DFNTRZCGVINWJ7XD43I332RMPEHDADA6WGNUPZD5Q5PFWZKX \ / AMOS7 \ YOURUM ::
#\[7]PLZGTAC5ALBBLTRCRORMF43ECWOWBXKEEEZYFT5IYZQE374IPACY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
