# user-edit: key-actions "delete an existing key" (in-frame, confirmation-gated)

## archive: DONE ✓ — 2026-08-16
## commit: e8ad5ce96 — user-edit: land key delete (kimi K2.7), fix pre-existing unload_key crash
## notes: dispatched to kimi K2.7, died mid-turn at its step ceiling (same as rename) before whitelist/live-verify/memory-note; finished directly -- whitelisted, live-verified via script -qec with real filesystem checks at every step (wrong-confirmation attempts leave files on disk, correct confirmation removes them, self-identity refused before stage 2 opens, cancel at every stage leaves files untouched). Also found and fixed a real pre-existing crash, unrelated to this task's own code: crypt.C25519.del_keys_hash_entry's first live exercise of its "loaded-keys table but not in %keys" branch crashed the zenka -- a same-line trailing comment between a <[module.name]> bracket and its next-line ->() args made the translator silently auto-insert an empty ->(), whose return value then got invoked as a subroutine -- see data/ai-mem/kimi/coding-style.md's delete-flow note for the full mechanism

**Read first:**
- `data/ai-mem/kimi/coding-style.md` and `data/ai-mem/kimi/MEMORY.md` -- P7
  module conventions, common mistakes to avoid.
- **Style/shape reference -- read these FOUR files in full before writing
  anything, they are the actual template this task copies, not just
  background**: `src/plugin.user-edit.key-actions.handler.key`,
  `src/plugin.user-edit.key-actions.render`, `src/user-edit.
  key_actions.submit_name`, `src/user-edit.key_actions.submit_passphrase`.
  These just shipped (commit `b056a04c4`), are independently live-verified
  (real pty, not headless), and are the CURRENT correct shape for everything
  this task needs. Do not invent a new shape -- copy this one's conventions
  exactly, including its comment style.
- `data/tasks/user-edit-key-actions-rename.md` -- a SIBLING task, same field,
  same trigger-key-registration pattern, same file-enumeration question
  [ `crypt.C25519.keyfiles` ]. Read it even if rename lands first or never --
  the two tasks must pick DIFFERENT, non-colliding trigger keys on the same
  `key_actions` field, and whichever lands second should reuse whatever
  answer the first one found for the checksum-cache-invalidation question
  rather than re-deriving it.
- `data/tasks/editor-inframe-prompt-primitive.md` -- the primitive itself
  (`editor.control.prompt.*`) and its five design anchors. Already built,
  already handles reentrancy, Ctrl-C-cancels-prompt-only, and content-safe
  Left-arrow navigation for you. This task does not touch any of that, only
  calls `editor.control.prompt.open` with its own `on_submit` chain.

## Goal

Add a THIRD trigger key to `key_actions` [ Enter = create, and whatever
`user-edit-key-actions-rename.md` claims for rename -- pick a THIRD, still
unclaimed key for delete, suggest `x` or `d` if rename does not already take
`d` ]: deleting an existing C25519 key, entirely in-frame, gated behind an
explicit typed confirmation phrase so an accidental keypress sequence can
never delete real key material.

**This is the one action in the key_actions family that destroys data with no
undo.** Every guard below exists because of that, not out of excess caution --
treat "am I SURE this cannot fire on anything but a deliberate, fully-typed
confirmation" as the standard to hold every line of this task's code to.

## Stage 1 -- which key to delete

Trigger key opens a prompt, same shape as create's / rename's stage 1:
```perl
<[editor.control.prompt.open]>->(
    $editor_state,
    {   qw| field |     => qw| key_actions |,
        qw| label |     => q| delete which key [ esc : cancel ] |,
        qw| type |      => qw| freeform_line |,
        qw| on_submit | => qw| user-edit.key_actions.submit_delete_name |,
    }
);
```

`user-edit.key_actions.submit_delete_name`'s guards [ same `$fail`-closure
shape as `submit_name`/rename's stage 1 ]:
1. non-empty
2. the name must actually EXIST -- `crypt.C25519.key_exists`
3. refuse the SELF IDENTITY key and any `remote-host.*` key, same exclusion
   `user-edit-key-actions-rename.md`'s stage 1 guard 3 already specifies --
   read that task's own reasoning for WHY [ `crypt.C25519.user_key_name` /
   `crypt.C25519.base_key_name` ] rather than re-deriving it, the answer is
   identical here

On success, open stage 2 with the target name carried in `data`:
```perl
qw| data | => { qw| name | => $name },
```

## Stage 2 -- the confirmation phrase [ the safety gate ]

Open a SECOND prompt, masked-prompt SHAPE but **not actually masked** [ this
is confirmation text, not a secret -- use `type => 'freeform_line'`, not
`'masked'` ; the user needs to SEE what they are typing to be sure it is
right ]. Label should name the key being deleted, so the confirmation is
visibly tied to what is about to happen, not a generic "are you sure":
```perl
qw| label | => sprintf( q|type 'delete key' to confirm removing '%s' [ esc : cancel ]|, $prompt->{'data'}{'name'} ),
```

`user-edit.key_actions.submit_delete_confirm`'s guard is a single exact-match
check, nothing else:
- the typed value must equal the literal string `delete key` **exactly**
  [ case-sensitive, no trimming of extra whitespace into a false match --
  `zz-verify-real ` with a trailing space or `Delete Key` must both FAIL,
  not silently pass ]. Read `$done`/`$fail`'s closure shape from
  `submit_passphrase` for the rejection path : on mismatch, cancel the
  prompt and set `<user-edit.key_actions.last_result>` to something explicit
  like `sprintf( q|confirmation text did not match, '%s' NOT deleted|, $name
  )` -- the user must be able to tell from the message alone that nothing
  happened, not have to guess.
- **do not soften this into "starts with" or "case-insensitive" or any other
  fuzzy match.** the entire point of this stage is that it cannot fire by
  accident; a fuzzy match defeats that.

On an EXACT match only: read `crypt.C25519.keyfiles($name)` [ same
enumeration `user-edit-key-actions-rename.md` uses -- do not hardcode file
suffixes ] and unlink every file it returns. Read `crypt.C25519.unload_key`
first and call it if the key is currently loaded in memory [ deleting the
on-disk files while a loaded copy still sits in `%data`/`%code` state would
leave the running zenka's own view of the world stale until restart -- confirm
live whether this is actually reachable for a key `user_keys` would ever list,
read `crypt.C25519.load_keypair`/`crypt.C25519.load_single` to understand
when a key becomes "loaded" before deciding this is or is not a no-op here ].

Then refresh `user_keys`, same refresh block `submit_passphrase`/rename's
stage 2 already use.

Report success via `<user-edit.key_actions.last_result>`:
`sprintf( q|deleted '%s'|, $name )`.

## Explicitly out of scope

- Deleting the self identity key -- see stage 1's guard 3.
- Any "undo" / trash / soft-delete mechanism -- the confirmation phrase IS
  the safety mechanism this task is asked to build, not a second one on top.
  If the user wants recoverable delete later, that is a separate task.
- Rename -- separate task, `data/tasks/user-edit-key-actions-rename.md`.

## Acceptance checks -- write these as END-STATE checks, not action-fired checks

Same standing project norm as every task file in this series: this project
always re-verifies the diff and live behaviour independently of any
self-reported summary. Use `script -qec` [ real pty ]. Use throwaway key
names for EVERY check below, never `taeki.base` or any real identity key --
this task deletes real files, get this wrong once and it is unrecoverable.

1. Create a throwaway key [ reuse the existing create flow ], trigger delete
   on it, type the name, confirm the SECOND prompt opens with the target
   name visible in its own label text.
2. Type anything OTHER than the exact phrase `delete key` [ try a close-but-
   wrong string, try the right phrase with trailing whitespace, try different
   casing ] and submit. Confirm: the key's files are STILL on disk afterward
   [ check the actual files, not just the UI message ], a clear "did NOT
   delete" message appears, zenka still alive [ separate `ps` check, per this
   project's own testing-harness gotcha ], form still fully interactive, and
   a SECOND delete attempt in the same session still works correctly
   afterward.
3. Type the EXACT phrase `delete key` and submit. Confirm: all of that key's
   files are gone from `crypt.C25519.get_usr_keys_dir`'s directory [ check
   the filesystem directly, not just `user_keys`' display ], `user_keys`
   drops the entry immediately with no extra keypress, and a fresh `keys
   list`-equivalent check no longer shows it.
4. Attempt delete on the self identity key. Confirm stage 1 refuses it before
   the confirmation stage ever opens -- the destructive path must be
   unreachable for that key, not just discouraged.
5. Esc/Left/Ctrl-C cancel at EACH stage independently, including cancelling
   AT the confirmation stage after having already typed the correct phrase
   but before submitting. Confirm the key's files are untouched in every
   case, and the form is fully interactive immediately after.
6. No regression: Tab navigation, an ordinary field's own edit-and-submit
   round trip, and both the create and rename flows still work exactly as
   before this task.

Report actual captured output for each check, not "passed" -- for THIS task
specifically, "the files still exist on disk, confirmed via `ls`" is the kind
of evidence that actually matters, not a UI message alone.

## Footer reminders, same as every task file in this series

- `sprintf( qw| foo bar %s |, $x )` breaks on multi-word `qw()` in scalar
  context -- single-word `qw| ... |` is fine.
- No fake/placeholder AMOS7 signature blocks -- the human signs files.
- Module calls use `<[module.name]>->(...)` syntax with args, or the bare
  `<[module.name]>` form (no `->()`) when calling with none.
- When done, add a short note to `data/ai-mem/kimi/coding-style.md` on
  whatever the exact-match confirmation shape ended up looking like, and on
  the `crypt.C25519.unload_key` / loaded-key finding.

#,,,.,..,,.,.,.,.,...,..,,,,.,.,.,,..,.,.,..,,..,,...,...,...,,,,,...,..,,,..,
#ABY46IYISO6WEKIPKTJZBDJJTL7GXWWYRKCDVY5Q2MAMGIHPTQNUZPJGFMHXRXFP72555XPTDSJTK
#\\\|DU3IF4T2ERFTDBORRSFCSRDEFCVZF7LTZABIZCBEASGICKXIEC2 \ / AMOS7 \ YOURUM ::
#\[7]37PASQRGRTPKOSBM2PGQWCSAMBNKKCN4G2XE3HGOTZQTCCBONKCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
