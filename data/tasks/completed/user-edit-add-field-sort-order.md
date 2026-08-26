# user-edit: sort field row order immediately on add, not only after reload

## Goal

When a field is added via the add-a-field cycler (`user-edit.form.
add_field`), its vertical row position in the form must reflect the same
display-order rule the record uses on a fresh load — immediately, not only
after save + exit + reload.

## The gap, and its precedent

This is the SAME gap class `src/user-edit.form.add_field` has already
hit and fixed four times — read that file's own header comments first,
they document the pattern explicitly: `sort_on_focus` (contact/phone),
`multiline` (address/note), `collapse_summary`, and plugin-pinned fields
all needed to "ALSO apply the FIRST time a field is added here, not only
once it round-trips through a save+reload." Field ROW ORDER never got the
same treatment — it's the fifth instance of the identical gap, not a new
kind of bug.

**Root cause**: `add_field` builds its new `@fields` array by copying every
existing field_def in `$editor_state->{'schema'}{'fields'}`'s CURRENT
in-memory order (`foreach my $field_def ( $editor_state->{'schema'}
{'fields'}->@* ) { ...; push @fields, {...}; }`), then pushes the newly
chosen field onto the end of that same array. It never re-derives order —
so the new field lands wherever `push` puts it (effectively last among
real fields), not where `base.reverse-sort` would place it.

**The correct order**, established by `src/user-edit.form.
schema_from_record` (read it first): field names run through
`<[base.reverse-sort]>->($fields)` — length descending, alphabetical
descending tiebreak (the codebase's own `base.sort`/`base.reverse-sort`
idiom, not a plain alphabetical sort — see `base.each_sort`/`base.
diff.hash_keys` for the same idiom elsewhere, and see this same file's own
2026-08-13 "Display order" work for a worked, hand-verified example of
what the correct order looks like for a real field set).

## The one real wrinkle — `identity_key` must stay pinned last

If the `key-details` tab is present (self-record session — see `plugin.
user-edit.key-details.*` and the `identity_key` synthetic field_def in
`schema_from_record`), it is ALSO copied into `add_field`'s `@fields` array
by the same loop (nothing currently filters it out, only the `add_field`
row itself is filtered). `identity_key` must NOT be swept into the
name-based resort — `schema_from_record` always appends it unconditionally
AFTER the sorted real fields, and `add_field` must preserve that same
contract, or adding a field to your own record would shuffle the key
details tab into the middle of the form.

## What to build

In `user-edit.form.add_field`, after the existing copy-loop finishes
building `@fields` (which already excludes the `add_field` row) and after
the new chosen field has been pushed onto it, but BEFORE the call to
`<[editor.control.create]>`:

1. Split `@fields` into two groups: the `identity_key` entry, if present
   (there will be at most one), and everything else.
2. Re-sort the "everything else" group by `name` using
   `<[base.reverse-sort]>`, the same call shape `schema_from_record` uses
   (`<[base.reverse-sort]>->($fields)` takes a hashref and returns sorted
   keys — build a `{ name => field_def }` lookup hash from the group, sort
   its keys, then rebuild the array in that order via the lookup).
3. Reassemble `@fields` as: sorted real fields, then `identity_key` (if it
   was present) appended last.

**Do not touch the existing active-field relocation logic** (the loop right
after `editor.control.create` that finds `$chosen`'s new index by NAME and
sets `active_field` to it) — it already locates the added field by name
after the schema is finalized, so once `@fields` is correctly ordered
before `create` runs, that existing lookup will land on the right
(sorted) position automatically. No separate cursor-preservation logic is
needed for this fix, unlike the list-entry resort work
(`user-edit.form.resort_list`) — this is a simpler case because rows are
already located by name here, not by index.

## Acceptance checks — run live via the `-no-tty`/`char-add` driver

Read `reference-user-edit-headless-driving.md` in `data/ai-mem/claude/`
first. Use a throwaway record (`p7c users.create-default zz-sortadd-test`),
clean it up afterward with `p7c users.remove zz-sortadd-test`.

1. On the throwaway record (no `identity_key` present — different username
   than whoever drives the test), add two or three fields via the cycler
   in an order that would NOT already be sorted-by-construction (e.g. add
   a short-named field, then a longer one that should sort ABOVE it) —
   confirm each new field's row appears in its correctly-sorted position
   immediately after being added, not at the bottom, without saving or
   reloading. Capture the actual rendered form after each addition.
2. On `taeki`'s own real record (or a throwaway record whose name matches
   the invoking Unix user, so `identity_key`/the key-details tab is
   present), add a new field via the cycler — confirm the key-details tab
   stays in its last position and the newly added field sorts correctly
   among the OTHER real fields, not relative to `identity_key`.
3. Confirm nothing regressed for the existing four gap-fixes this file
   already has: a newly-added `contact`/`phone` field still gets
   `sort_on_focus`; a newly-added `address`/`note` still renders
   multiline; collapse-summary and plugin-pinned fields still get their
   flags on first add. (These were already working before this change —
   just confirm the reorder didn't break their OTHER per-field metadata,
   not that you need to re-derive them.)
4. Save/submit after adding fields in check 1, then reopen the record —
   confirm the order is unchanged after the round trip (it already worked
   after reload before this fix; this just confirms the fix didn't
   introduce a mismatch between the immediate order and the
   after-reload order — they must be identical, since both now use the
   same sort rule).

Report actual captured output for each check, not just "passed."

## Explicitly out of scope

- Do not touch `user-edit.form.schema_from_record`'s own sort — it's
  already correct, this task only brings `add_field` in line with it.
- Do not touch list-entry ordering within a single list field
  (`contact`/`phone`'s own entries) — that's `sort_on_focus`/`editor.
  control.list.expand`'s job, already built, unrelated to this task.
- Do not generalize the `identity_key` exclusion into a registry-driven
  "which fields are synthetic" mechanism — one hardcoded name check is
  the right amount of abstraction for the single synthetic field that
  exists today.

#,,.,,..,,,,,,,..,,,.,,..,,.,,,.,,.,.,,.,,,.,,..,,...,...,,,.,,.,,,,.,,,.,,.,,
#3GZXAOQDGSZP54QBKWMNYTNTTEUF3S2DJAMYUTNYSRTD7XFVQUU5ZYBO52AS6TLFBATQSO75NPN2C
#\\\|J6F7TT77MOCKMXEIDCCPNWQHV3ISTASH2UOCBJOYXDGHYYOMQTS \ / AMOS7 \ YOURUM ::
#\[7]AY3E2WURSM4UKZQECDZAFF5FPEUDSQE46KLQRR33574BDBRR2OCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
