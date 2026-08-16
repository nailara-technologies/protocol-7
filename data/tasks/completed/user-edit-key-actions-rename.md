# user-edit: key-actions "rename an existing key" (in-frame, multi-stage)

## archive: DONE ✓ — 2026-08-16
## commit: 67d10c587 — user-edit: land key rename (kimi K2.7), fix last_result status-freeze bug
## notes: dispatched to kimi K2.7, died mid-turn at its step ceiling before whitelist/live-verify/memory-note; finished directly -- whitelisted, live-verified via script -qec (existing/duplicate/self-identity/remote-host targets, cancel at both stages). Also root-caused+fixed a real bug found during verification: <user-edit.key_actions.last_result> was never cleared, freezing the key_actions row on its last status message until zenka exit (affects create's guards too, fixed generically at the plugin-mode entry trigger in user-edit.handler.stdin_key) -- see data/ai-mem/claude/topic-rename-empty-target-stuck-state-investigation-2026-08-16.md. Also found crypt.C25519.keyfiles($name) only returns the FIRST matching file, not the full set -- see coding-style.md note

**Read first:**
- `data/ai-mem/kimi/coding-style.md` and `data/ai-mem/kimi/MEMORY.md` -- P7
  module conventions, common mistakes to avoid.
- **Style/shape reference -- read these FOUR files in full before writing
  anything, they are the actual template this task copies, not just
  background**: `modules/plugin.user-edit.key-actions.handler.key`,
  `modules/plugin.user-edit.key-actions.render`, `modules/user-edit.
  key_actions.submit_name`, `modules/user-edit.key_actions.submit_passphrase`.
  These just shipped (commit `b056a04c4`), are independently live-verified
  (real pty, not headless), and are the CURRENT correct shape for everything
  this task needs: opening a prompt from a plugin's `handler.key`, chaining a
  second prompt stage from the first stage's `on_submit`, guard-and-fail
  closures, and refreshing `user_keys` after a change. Do not invent a new
  shape -- copy this one's conventions exactly, including its comment style.
- `data/tasks/editor-inframe-prompt-primitive.md` -- the primitive itself
  (`editor.control.prompt.*`) and its five design anchors. Already built,
  already handles reentrancy (design anchor 4), Ctrl-C-cancels-prompt-only
  (design anchor 5), and content-safe Left-arrow navigation for you -- this
  task does NOT need to re-derive or touch any of that, only call
  `editor.control.prompt.open` with its own `on_submit` chain, exactly like
  `submit_name` already does to open the passphrase stage.

## Goal

Add a second trigger key to the `key_actions` field/plugin, alongside the
existing Enter [ create ]: renaming an EXISTING C25519 key, entirely in-frame,
using the SAME two-stage prompt-chain shape `submit_name` -> `submit_
passphrase` already established for create -- just with different prompts and
a different terminal action (rename files, not generate a keypair).

Pick an unclaimed trigger key for rename [ suggest `r` -- confirm it does not
collide with anything else `plugin.user-edit.key-actions.handler.key`'s
`if (ref $editor_state->{'prompt'} eq HASH)` / Left / Enter branches already
claim, and that it is not eaten earlier by `user-edit.handler.stdin_key`'s own
key-dispatch before reaching the plugin ].

## Stage 1 -- which key to rename

Trigger key opens a prompt exactly like `submit_name`'s pattern:
```perl
<[editor.control.prompt.open]>->(
    $editor_state,
    {   qw| field |     => qw| key_actions |,
        qw| label |     => q| rename which key [ esc : cancel ] |,
        qw| type |      => qw| freeform_line |,
        qw| on_submit | => qw| user-edit.key_actions.submit_rename_from |,
    }
);
```

`user-edit.key_actions.submit_rename_from`'s guards, copying `submit_name`'s
shape [ same `$fail` closure pattern, same `<[editor.control.prompt.cancel]>`
call on failure ]:
1. non-empty
2. the name must actually EXIST as a key -- `crypt.C25519.key_exists`,
   inverted from create's guard [ create refuses an EXISTING name, rename
   requires one ]
3. refuse the SELF IDENTITY key and any `remote-host.*` key -- read `user-
   edit.form.build_user_keys_field`'s own filtering [ it excludes
   `$identity_name` and `remote-host.*` from the list shown at all ] and
   apply the SAME exclusion here, with a clear failure message, not a silent
   no-op. Renaming your own identity key out from under `<crypt.C25519.user_
   key_name>` is a different, much bigger operation [ every signature/session
   tied to that name would need updating too ] and explicitly out of scope --
   `<crypt.C25519.user_key_name>`/`<crypt.C25519.base_key_name>` are `%data`
   keywords, not modules [ read `user-edit.form.build_user_keys_field`'s own
   lines 22-23 for exactly how the identity name is derived from them ]
   before deciding exactly how to detect "is this the identity key" so the
   check is correct, not guessed.

On success, open stage 2 with the old name carried in `data`, exactly like
`submit_name` carries the key name forward to `submit_passphrase`:
```perl
qw| data | => { qw| name | => $name },
```

## Stage 2 -- the new name

`user-edit.key_actions.submit_rename_to`'s guards:
1. non-empty
2. `crypt.C25519.validate_keyname` -- same call `submit_name` already makes
3. must NOT already exist -- `crypt.C25519.key_exists`, same guard `submit_
   name` already makes for create
4. new name must actually differ from the old one -- renaming a key to its
   own name is a no-op, fail it explicitly with a clear message rather than
   silently "succeeding" at nothing

On success, the actual rename: read `crypt.C25519.keyfiles` in full first --
call it with the OLD name to get every on-disk file for that key [ same
enumeration `crypt.C25519.write_keys`'s own file-suffix scheme already uses,
confirmed from this session's own live testing : `<name>.private`,
`<name>.public`, `<name>.secret` ], then rename each file, swapping only the
`<name>` portion. Do not hardcode the three suffixes yourself if `keyfiles`
already gives you the real, current file list -- a future key format with a
different file set should not silently break this.

Read `crypt.C25519.cached_chksum` / `crypt.C25519.chksum_cache.add` /
`crypt.C25519.chksum_cache.retr` before deciding whether the checksum cache
needs an explicit invalidation call after a rename, or whether it already
re-derives fresh [ `keys.checksum_href` re-scans `crypt.C25519.all_key_names`
on every call, per its own source -- confirm live whether that alone is
enough, or a stale cache entry under the OLD name lingers ]. Do not guess --
read the actual cache-key scheme.

Then refresh `user_keys`, copying `submit_passphrase`'s own refresh block
exactly [ find the existing `$user_keys_def` by name in the live schema
array, `%$user_keys_def = %$fresh_def`, swap in a fresh buffer via `editor.
buffer.memory.create` ] -- this is the exact mechanism that closed the
post-create display gap the previous round of the create feature shipped
with a bug in; reuse it, do not re-derive it.

Report success via `<user-edit.key_actions.last_result>`, same convention
`submit_passphrase` already uses: `sprintf( q|renamed '%s' to '%s'|, $old,
$new )`.

## Explicitly out of scope

- Renaming the self identity key -- see stage 1's guard 3 above.
- Any change to `plugin.user-edit.key-actions.render`'s hint text beyond
  adding the new key to it [ read its current `.,. left : back`-style hint
  line and extend it, do not redesign the hint format ].
- Delete -- separate task, `data/tasks/user-edit-key-actions-delete.md`.

## Acceptance checks -- write these as END-STATE checks, not action-fired checks

Same standing project norm as the primitive's own task file: this project
always re-verifies the diff and live behaviour independently of any
self-reported summary. Use `script -qec` [ real pty -- the no-tty `char-add`
driver cannot exercise real ANSI cursor styling or the bare-Esc debounce, see
`data/ai-mem/claude/reference-user-edit-headless-driving.md` ]. Use throwaway
key names for every check below, never `taeki.base` or any real identity key.

1. Create a throwaway key first [ reuse the ALREADY-WORKING create flow ],
   then trigger rename on it. Confirm stage 1's prompt renders inside the
   frame exactly like create's name prompt does, cursor visible, Left-arrow
   navigable without losing typed text [ same check the primitive's own task
   file already proved for create -- confirm it holds here too, this is
   inherited from the shared primitive, not re-implemented, so a failure here
   would mean something in THIS task's code is bypassing the shared handler ].
2. Rename to a genuinely new throwaway name. Confirm: the OLD name's files
   are gone from `crypt.C25519.get_usr_keys_dir`'s directory, the NEW name's
   files exist with the same content [ compare file sizes/checksums before
   and after, not just presence ], `user_keys` reflects the new name
   immediately with no extra keypress, and the OLD name no longer appears
   anywhere in the list.
3. Attempt rename-to-an-existing-name [ e.g. the identity key's own name, or
   another throwaway key already present ]. Confirm a clear failure message,
   zenka still alive [ separate `ps` check, per this project's own testing-
   harness gotcha -- never combine a `ps`/`kill` check with a command whose
   text contains "user-edit" in the same shell invocation ], no files touched
   on disk.
4. Attempt to rename the self identity key. Confirm stage 1 refuses it with a
   clear message before stage 2 ever opens.
5. Esc/Left/Ctrl-C cancel at EACH stage independently. Confirm no partial
   rename ever happens [ the old key's files must still be fully intact,
   never partially renamed ], and the form is fully interactive immediately
   after each cancel.
6. No regression: Tab navigation, an ordinary field's own edit-and-submit
   round trip, and the create flow from the previous task all still work
   exactly as before this task -- a quick pass, not a full re-run.

Report actual captured output for each check, not "passed".

## Footer reminders, same as every task file in this series

- `sprintf( qw| foo bar %s |, $x )` breaks on multi-word `qw()` in scalar
  context -- single-word `qw| ... |` is fine.
- No fake/placeholder AMOS7 signature blocks -- the human signs files.
- Module calls use `<[module.name]>->(...)` syntax with args, or the bare
  `<[module.name]>` form (no `->()`) when calling with none.
- When done, add a short note to `data/ai-mem/kimi/coding-style.md` on
  whatever the file-rename mechanism and checksum-cache finding actually
  ended up looking like -- the delete task will want the same file-
  enumeration answer without re-deriving it.

#,,..,.,.,.,.,.,.,,.,,,,,,,,.,...,,.,,.,,,...,..,,...,..,,...,.,.,,..,,,,,,,.,
#IWGHPI3EEW4HOTHQ3FCQ2FKKRHE3KKITBOOF5CFREIZKBS7T26KSF7DCBRVTTO5FIJICNKJSFY7NG
#\\\|MKQUQMG2OK6CRYBW76QU7KENRHQPXNGVK53MNHEZ7ZVNWIDRXEE \ / AMOS7 \ YOURUM ::
#\[7]GSQZZR3DEEM4ASS44GJZFSZHZOKULZZBCQDTZAJQ7HLYC22XNWAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
