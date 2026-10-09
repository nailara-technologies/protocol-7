# host-edit zenka : records + form [ lane B1 ] : report

lane B1 of `data/md/design/HOST-SETUP.md`. base commit `b282f8fce`,
branch `base`. no commit made. no zenka restarted ; all live checks ran
against fresh per-invocation console processes.

## verdict

- `p7-user-edit show-form taeki` : BEFORE vs AFTER **byte-identical** [ `cmp` ]
- `p7-user-edit commands` : BEFORE vs AFTER **byte-identical** [ `cmp` ]
- `bin/Protocol-7 host-edit commands` : loads, lists the form.* console
  commands [ start / show-form / browse / test-secret-roundtrip among them ]
- `bin/Protocol-7 host-edit show-form zz-test` : renders `host-edit : zz-test`
  with the trust column `key <label> · <node>.cube · since 0` --
  read live from the EXISTING client pin `~/.n/remote-keys/servers/
  127.0.0.1_42.public`. zz-test was created through the real compiled
  record source [ small /tmp harness, since deleted ] and removed after ;
  `/var/protocol-7/host-edit/hosts/zz-test.json` confirmed gone
- `bin/test-scripts/test-host-edit-records.pl` : 42 checks, all passed
- `bin/format-code -c` : all 25 touched src files `syntax valid`, 0 reflow

## new zenka : host-edit [ 15 modules + start file ]

- `cfg/zenki/host-edit/zenka.v7` : mirrors user-edit's start [ same hybrid
  loop note, same access.cmd.usr.cube list, no plugins.load line ] ;
  `modules.load = ... keys form host-edit`
- `src/host-edit.init_code` : `<form.source>` table [ senders + policy ] +
  `VAR_P7/ETC_P7/HOME_N` keywords + best-effort data-dir creation ;
  `system.auth-user = <unix-user>[host-edit]`
- record layer : `host-edit.record.{name_valid,path,read,write,field_names,
  default_fields}` -- one file per host, `[VAR_P7]/hosts/<name>.json`,
  name rule `[a-z0-9][a-z0-9._-]{0,62}` [ trust rule, dns-label length ],
  write is temp-file-in-same-dir + rename, chmod 0600, envelope
  `{name,created,updated,fields}`
- record source : `host-edit.source.{value_get,value_all,value_set,
  field_options,create_default,secret_hold,secret_release}` -- LOCAL file
  io, replies deferred to the next event tick on a 0 s timer [ never
  inline ], same `{sid,cmd,call_args,params,data?}` shape the users zenka
  gives : SIZE carries the record yaml in `data` [ parsed by
  form.handler.value_get_reply ], TRUE/FALSE carry the message in
  `call_args->{'args'}`. secret_hold/release reply the engine-detected
  failure shape [ `<<`-prefixed SIZE data ] : host records hold no secrets
- `host-edit.trust.pin_state` : the read-only trust columns, computed from
  the CLIENT pin store [ keys.list_remote_keys-style 3-line read of
  `~/.n/remote-keys/servers/<host>_<port>.public` : label, leaf, since ;
  address stem first, record-name stem second [ tunnel naming ] ; owner
  pin presence from `~/.n/remote-keys/owners/<name>.public` ; no pin ->
  `not yet contacted` ]. value_get injects them into the DISPLAY payload
  only ; value_set re-filters against `host-edit.record.field_names`, so
  they can NEVER reach disk [ HOST-SETUP.md : the pin is the single
  source of truth ]

## form.* genericity [ user-edit's strings became <form.source> data ]

new `<form.source>` keys, with user-edit.init_code passing its historical
values [ output byte-identical by construction ] :

    title_fmt       => 'user-edit : %s'      # frame title
    frame_name      => 'user-edit-form'      # ascii frame name
    menu_fallback   => 'user-edit'           # browse menu titles
    namespace_main  => 'host-system'         # records namespace key
    namespace_keys  => 'keys'                # read-only keys view ; '' drops it
    not_found_fmt   => "user '%s' not found" # create-offer match string

touched form.* modules [ genericity only ] : form.console.{show-form,
start,browse}, form.menu.{open_record,namespaces,records},
form.handler.{value_get_reply,value_all_reply,field_options_reply,
field_options_bootstrap_reply}. every other `// qw| user-edit-form |`
fallback site keeps working because value_get_reply still seeds
`<form.frame_name>` from the source before any render.

host-edit passes its own vocabulary : `host-edit : %s`, `host-edit-form`,
`host-edit`, `hosts`, `keys`, `host '%s' not found`.

## user-edit.init_code

the six vocabulary keys above added to its `<form.source>` table ; nothing
else changed.

## whitelists

`bin/dev/gen-sub-whitelist user-edit host-edit` : host-edit 703 subs
[ new file ], user-edit unchanged. no other zenka's whitelist touched.

## test : bin/test-scripts/test-host-edit-records.pl

stubs only, File::Temp dirs : stubbed path resolution [ VAR_P7 -> tempdir
], pin store, and an event.add_timer queue that PROVES the deferral [ the
reply must not exist before the drain, the timer must be `after => 0` ].
42 checks : the name rule, create_default [ deferral, TRUE, on-disk
envelope, 0600, no temp leftovers, refuses existing ], value_get
[ not-found wording, SIZE payload, trust columns absent from disk ],
value_set [ re-filter of unknown + forged trust keys, created preserved,
0600 kept, invalid name rejected ], trust columns [ label/leaf/since from
a stubbed pin, owner-pin presence, 'not yet contacted' after removal ],
value_all [ sorted newline-joined ], field_options [ shapes, trust never
advertised ], secret senders [ `<<` failure shape ].

## notes

1. `qw| a b |` is a LIST : bit twice during the lane [ a sprintf format
   and two hash literals in host-edit.trust.pin_state ] -- caught by the
   harness and format-code, all fixed.
2. `form.handler.value_get_reply`'s frame-name fallback and the render
   paths' literal `user-edit-form` fallbacks stay as defaults ; a zenka
   that never sets them behaves exactly as before.
3. `default_record => ''` for host-edit : a bare show-form asks with an
   empty name and the create-offer answers [ allow_create is TRUE -- the
   host store is this host's own record of who it talks to ].
4. the form's vertical viewport may not show every injected row in a
   one-shot show-form ; the owner_trust column is covered by the harness.
5. out-of-scope working-tree changes NOT mine, left untouched :
   `data/ai-mem/claude/project-2026-10-08-trust-chain-step2-landed.md`
   [ pre-existing before this lane ] and `data/md/design/HOST-SETUP.md`
   [ a 'reuse' section appeared mid-session -- a concurrent lane's edit ].

#,,,.,.,,,.,,,,..,,,.,,.,,,,,,,,,,,,.,,,.,..,,..,,...,..,,.,,,...,,,.,,..,,,.,
#UE7G5IJFPCPEI3435EP7JKICIU35E3CUGVV4YCQQ2FZNI2DXOHFXC3LKRD2NEHKXYBVFOGZRA6Y2O
#\\\|TXS3LRXGUILE3XDOTF6B3Y6FDFNV6OL725K6CUSA6QKBJOMQTTF \ / AMOS7 \ YOURUM ::
#\[7]QZUGROIGMLM3UXKQAFNHY3GSLGIEY52MXPFZOKTRCOLTPGGYTYDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
