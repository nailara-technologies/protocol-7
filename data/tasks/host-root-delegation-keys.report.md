# host-root delegation : keys \ key-path call sites [ lane 2 ] -- report

no zenka started \ reloaded, no sudo, no commit \ signing, no real key dir
read. every changed file passes `bin/format-code -c` [ syntax valid ] and was
run through `bin/format-code`. file-end AMOS7 signatures of every touched
src file are now STALE [ re-sign needed ].

resolver contract used [ spec API, lane 1 ] : `crypt.C25519.key_path(name)`
-> `{ key_dir key_basepath key_filename holder }` or undef, and
`crypt.C25519.root_key_dir`. every guard calls `key_path` DIRECTLY [ does
not assume `key_vars` returns `holder` ] ; undef -> refuse.

## guard added [ non-root + holder 'root' -> refuse, exit 0020, before any prompt \ key load \ file change ]

keys.console : change-passwd, enc-key, dec-key, downgrade-enc-status,
split-keypair, get-encoded-key, enc-key-chksum, remove [ not for a `known:`
pin ], remove-type, remove-signature [ key AND signature key ], sign-key
[ signer AND signed key ], rename [ source ].
keys.backup : create, restore, rollback, remove [ return undef + level 0 log ].
unresolvable key path [ undef ] -> refuse in all of them, even as root.

## other changes

- keys.console.list : `'<name>' [ root-held ]` group. root : names + files
  read from `root_key_dir` ; non-root : only
  `[ root-held : not readable as <user> ]` and the dir is never opened. root
  paths are filtered out of the user group in case lane 1 makes `keyfiles`
  return them. no checksum is shown for root-held keys. `:sigs:` view skips
  the root group.
- keys.console.remove, remove-type : as root on a root-held key the files
  are enumerated from the resolved root dir [ `keys.get_keyfiles` knows user
  keys only ].
- keys.console.rename : used the BASE key's `key_vars` for the file list and
  dir [ pre-existing bug : only worked for the base key ] ; now
  `key_vars($srckey)`. needed for root-held rename, fixes user keys too.
- keys.console.duplicate : a root-held source \ target is refused for EVERYONE
  [ root too ] : the copy would land in the user dir, readable \ deletable by
  the backend user. there is no API to place a copy in root/ [ would need
  `holder => 'root'` on key_vars ].
- keys.console.decrypt-archive : an archive entry named like a root-held key
  aborts the whole import [ files restore by basename into the USER dir ].
- keys.backup.list : scans `root/` only when root and no name filter ; with a
  root-held name filter its dir comes from the resolver [ as non-root : empty
  list, root/ not opened ] ; entries carry `holder`. create \ rollback work
  inside the resolved dir [ root/ for a root-held key ], rename keeps owner
  0 + mode ; restore additionally refuses a backup whose directory differs
  from the live key's directory.
- p7-log.anon.key : built `<EUID home>/.n/user-keys/<name>.secret` itself ->
  now `key_path($key_name)->{key_filename}{secret}`. behaviour note : home is
  the resolver's [ backend user ], not the EUID user's ; identical when p7-log
  runs as the backend user. `crypt.C25519.key_path` must be in
  `cfg/zenki/p7-log/subroutines.load-early` [ lane 1 : cfg ].

## call sites left [ and why ]

- keys.console.authorize \ drop-authorized \ incoming \ list-authorized :
  work on pin dirs [ incoming \ authorized ] by `<zenka>:<user>`, no key file.
- keys.console.create \ create-stub-key \ gen-file-seed-key \ gen-pwd-keyfile
  \ get-sp-pub-key : new keys are never created in root/ [ resolver picks
  root/ only for an existing root-held name ] ; a name collision is refused by
  `key_exists` [ as root ; non-root cannot see root/ , the user-dir key would
  be shadowed by the root-held one in resolution ].
- keys.console.path \ clear-chksums \ github-pat : dir name only \ cache.
- keys.console.list-upgradable \ encoding-upgrade : go through
  `keys.get_keyfiles` ; encoding-upgrade <name> not guarded -- OPEN, see below.
- keys.console.keys-backup-archive + keys.write_key_archive_file +
  keys.pack_format.user_key_archive : NOT edited [ outside my list ] -- OPEN.
- src/source.load_signature_key : `$key_dir` \ `$key_basepath` are assigned
  and never used ; everything else is key_vars \ key_exists \ load_keypair.
  no change.
- src/work.console.* : key_vars only [ import-dev-key mkdir -p's the user
  key dir, copies a public key into `key_filename{public}` ]. no change.
- src/sessions.holder.* : the identity is `holder-identity.secret` in the
  zenka dir, not a key-tree file. no change.
- src/session.console.setup-keys, src/base.root.check_system_user : create \
  chmod the `user-keys` DIRECTORY only. no change [ root/ is created by
  post_init \ resolver when root ].
- user-edit : `form.build_user_keys_field`, `key_actions.submit_rename_to`,
  `key_actions.submit_delete_confirm` build NO key paths themselves : they
  use `crypt.C25519.keyfiles` [ + `key_vars`-style names ]. no change
  needed IF lane 1's `keyfiles` stays user-dir only ; if `keyfiles` starts
  returning `root/` paths, user-edit would list \ rename \ delete root-held
  keys as non-root [ fails on perms, harmless but noisy ] and as root it
  would operate on them -- open question below.

## test

`bin/test-scripts/test-keys-root-held.pl` : 121 checks, 0 failed. compiles
the REAL modules against a stubbed resolver ; effective uid faked by rewriting
`$EFFECTIVE_USER_ID` in the compiled text [ test-only ]. covers : 13 guarded
console ops x [ non-root refused + clear message + nothing reached, root
passes, user key not refused, unresolvable refused ], tree unchanged,
duplicate, `known:` pin, rename key_vars arg, decrypt-archive refusal, list
as root \ non-root, backup list rules, create \ restore \ rollback \ remove
refusals, restore keeps mode \ owner inside root/, cross-dir restore refused,
p7-log.anon.key via resolver. mutation checks [ restored byte-identical ] :
dropping the EUID check in enc-key \ backup.list \ console.list and the dir
check in backup.restore each fail the test.

## open questions

1. non-root detection : `root/` is 0700 uid 0, so a non-root `-e root/<n>.public`
   fails -> `key_path` likely reports holder 'user' for a root-held name as
   non-root. my guards fire only when the resolver reports 'root'. as
   non-root the op then runs against the user dir and says "not found" [
   safe, kernel perms enforce it ; clarity only ]. what should `key_path`
   return on EACCES inside `root/` -- should it say `holder => 'root'` when
   `root/` exists and the name is not in the user dir ?
2. `keyfiles` \ archive : if lane 1 includes `root/` paths in
   `crypt.C25519.keyfiles` [ its own todo ], then `keys-backup-archive` as
   root would pack root-held secrets into the user archive and
   `decrypt-archive` would restore them by basename into the user dir [ I now
   refuse such entries on import, but the export side is
   keys.pack_format.user_key_archive, not in my list ]. needs a filter there
   [ skip paths under `root_key_dir` ] -- who edits it ?
3. `encoding-upgrade <name>` and list-upgradable via `keyfiles` : same
   dependence on question 2 ; unguarded for a named root-held key as root
   [ allowed as root anyway ]. non-root : -r check skips unreadable files.
4. duplicate of a root-held key is refused even for root. acceptable, or add
   `holder` to the key_vars API so root can clone within root/ ?
5. test-only rewrite of `$EFFECTIVE_USER_ID` : a shared `base.root.is_root`
   helper [ new module, not allowed to me ] would make this stubbable.

#,,,.,,,.,.,.,.,,,...,,.,,,,.,,,,,,..,,,.,,,,,..,,...,...,.,.,,.,,,,.,...,,,.,
#X32PHNWJTXA4HLR27F24D7BB6XQR2L6GVMSDMBRLIVWPLQJP62GLTOXEIKL6BZG5DQVRP23CYGXDS
#\\\|OVCBUTEBB3MCMERNVECD53VEWL7FFB6DTPNLVB7RZ27SGVEI2GU \ / AMOS7 \ YOURUM ::
#\[7]BPPBVDDTOOGE7KR726FPHCSW2RCIE3WCAR5Y6DDSWQAP7ZMXSIAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
