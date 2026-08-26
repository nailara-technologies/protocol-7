# user-edit: `user_keys` field -- list the invoking user's other C25519 keys

## Goal

A new synthesized, read-only, self-record-only field `user_keys`, showing
every OTHER named C25519 key the invoking Unix user holds (i.e. every key
except the current identity shown in `identity_key`), as a multiline list —
one key name per line. Per user: this should include something like the
`proto-7.sourcecode` signing key, alongside `identity_key`. Per user, a
LATER feature (explicitly NOT this task) will let one of these be selected
to become the active `identity_key` — this task only needs to list them.

Read `data/tasks/user-edit-key-details-tab.md` and `topic-user-edit-console-
zenka-status.md` in `data/ai-mem/claude/` first for the `identity_key`
precedent this extends.

## Why this does NOT reuse `identity_key`'s `display_override` mechanism

Read `src/editor.ui.ascii_frame.render_form`'s multiline block first
(search for `$field_def->{'multiline'}`). It calls `<[editor.control.
get_value]>->($editor_state, $name)` directly for the text to render —
**not** `get_display_value`, which is the only accessor that honours
`display_override`. So a synthesized field using `multiline => TRUE`
together with `display_override` would silently render blank (the
override is never called; the raw, empty `default` buffer is what shows).

**Do not touch `render_form`'s multiline block to fix this** — that is
shared machinery every multiline field in every zenka goes through, and
extending it for one synthesized field is a bigger, riskier change than
this task needs.

**The correct approach**: this field's content never changes while the
form is open (the on-disk key list isn't going to move mid-session the way
`taeki.base`'s live state theoretically could), so there is nothing to
gain from `display_override`'s per-repaint freshness. Compute the joined
key-name text ONCE, at the same point `identity_key` is synthesized in
`schema_from_record`, and put it directly in the field def's `default` —
an ordinary readonly multiline field, using 100% already-proven machinery
(the SAME collapse/expand/windowing `note`/`address` already exercise),
with no plugin, no display_override, no new rendering code at all.

## Data source — already whitelisted, use these

All of the following are ALREADY in `user-edit`'s `subroutines.load-early`
— confirmed, no new whitelist entries needed for this task at all:

- `<[crypt.C25519.keyfiles]>->()` — returns every keyfile PATH for the
  current user (private/secret/public files, multiple per key name).
- `<[crypt.C25519.get_keyname]>->($file_path)` — extracts the bare key
  name from one keyfile path (memoized internally, safe to call
  repeatedly).
- `<[crypt.C25519.key_vars]>->{'key_name'}` — the identity key's own name
  (same call `identity_key`'s render already uses), to exclude it.
- `<[base.sort]>->(@names)` — length-ascending, alpha-descending tiebreak,
  this codebase's standing idiom (see `user-edit.form.addable_fields`'s
  own recent use of it for the same reasoning) — use this, not a plain
  `sort`, for the final display order.

Build the list: call `keyfiles`, map every path through `get_keyname`,
dedupe (`grep`/hash-uniq — multiple files share one key name), exclude the
identity key's own name, and exclude any hostkey-shaped name (matches
`^remote-host\.`) — those are TOFU host pins, a different category of
thing than a "your key" list, out of scope for this basic version. Sort
what's left via `base.sort`. Join with newlines for the multiline buffer.

If nothing is left after exclusion (the invoking user has no other keys),
the field should still exist but show a short explicit "no other keys"
line rather than an empty buffer — check `editor.control.multiline.
summary`'s handling of a single short line to confirm this collapses
sensibly (should read as `:..1.line..:` like any other one-line multiline
content, this is not a special case to build, just confirm it degrades
gracefully).

## What to build

1. **`src/user-edit.form.schema_from_record`** — inside the SAME
   `if ( <user-edit.unix_user> eq ( $record->{'name'} // '' ) ) { ... }`
   block that currently only pushes `identity_key`, ALSO push a
   `user_keys` field_def, inserted BEFORE `identity_key` in that block (so
   the final row order is: sorted real fields, then `user_keys`, then
   `identity_key` last — `identity_key` staying last is existing, already
   -verified, already-documented behavior; do not change that):

   ```perl
   push @field_defs, {
       qw| name |      => qw| user_keys |,
       qw| type |      => qw| freeform_line |,
       qw| multiline | => TRUE,
       qw| readonly |  => TRUE,
       qw| default |   => $other_keys_text,   # computed as described above
   };
   ```

2. **`src/user-edit.form.submit`** — `user_keys` must never reach
   `users.value-set`, same treatment as `identity_key` (read that block
   first — it's currently one hardcoded `delete $values->{'identity_key'};`
   line with a comment; add a second line for `user_keys` right next to
   it, do not generalize into a list for two entries either, matching this
   file's own established "one name check per synthetic field" precedent).

3. **`src/user-edit.form.add_field`** — the resort fix from the
   PREVIOUS dispatch (`data/tasks/user-edit-add-field-sort-order.md`,
   already landed) currently pulls out and re-appends ONLY `identity_key`
   by name before resorting the rest. Now there are TWO synthetic fields
   to keep out of the resort. Read that code first (search for
   `identity_key` in this file). Extend it to pull out BOTH `identity_key`
   and `user_keys` (if either/both are present — a non-self session has
   neither), sort everything else exactly as before, then re-append in the
   SAME order `schema_from_record` establishes: sorted real fields, then
   `user_keys` (if present), then `identity_key` (if present) last. Do not
   generalize this into a registry-driven "synthetic field names" list —
   two hardcoded names, consistent with this file's own stated convention
   for this exact class of thing.

## Acceptance checks — run live via the `-no-tty`/`char-add` driver

Read `reference-user-edit-headless-driving.md` first. Use throwaway
records where the task calls for a non-self session; clean up afterward
via `p7c users.remove <name>`.

1. Open `taeki`'s own real record (or any record whose name matches the
   invoking Unix user) — confirm `user_keys` appears, collapsed to a
   `:..N.lines..:` summary when unfocused, positioned directly above
   `identity_key` (which stays last). Enter it and confirm the expanded
   view lists the OTHER key names — cross-check against a direct
   `./bin/Protocol-7 keys list` run for the same Unix user: every named
   key shown there except the identity key and any `[hostkey]` entries
   should appear in `user_keys`'s content, and `taeki.base` (or whichever
   key `identity_key` shows) must NOT appear in `user_keys`.
2. Open a throwaway record whose name does NOT match the invoking Unix
   user — confirm neither `user_keys` nor `identity_key` appears at all.
3. Confirm `user_keys` is genuinely readonly: try typing into it while
   focused/expanded — the buffer must not change. (It's fine, and
   expected, if Up/Down/PgUp/PgDn still scroll a long list — that's
   ordinary multiline navigation, not an edit.)
4. On the self-record session from check 1, add a new REAL field via the
   add-a-field cycler — confirm both `user_keys` and `identity_key` stay
   in their correct relative positions (user_keys then identity_key, both
   after the sorted real fields) and the new field sorts correctly among
   the real fields, not relative to either synthetic one. This is
   specifically testing the `add_field` fix in step 3 above.
5. Submit a change on the self-record session with `user_keys` present in
   the schema, then read the record's `details.yaml` directly on disk —
   confirm no `user_keys` key was written anywhere in it.

Report actual captured output for each check, not just "passed."

## Explicitly out of scope

- No key-selection/switch-identity feature — this task only lists keys,
  it does not make any of them selectable or active. That's explicitly
  future work per the user.
- No changes to `render_form`'s multiline block or to `get_display_value`
  — this task's whole design point is avoiding that path, not fixing it.
- No hostkey (`remote-host.*`) entries in the list — named keys only.
- No changes to `identity_key`'s own existing render/plugin mechanism.

#,,.,,...,,.,,...,.,,,.,,,,.,,...,,.,,.,.,...,..,,...,...,,.,,,,.,.,,,...,.,.,
#CW76ZEOEWVYVFC5ZDLMCXISVKDXXXEN4FDSUWXMGX7CXS65RW77KFBC6AR6BIUDBGC7BMMJDRGUXM
#\\\|DZWXGRWNO34YZI47JPDHNWDSEABTBQCLMY3HNHGMYL4FTBAJ2GL \ / AMOS7 \ YOURUM ::
#\[7]73YO7SSMD6G65KXUFFJ7ZD46P6S6IQP3MPQ4DFA5ERUQ32F3SOBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
