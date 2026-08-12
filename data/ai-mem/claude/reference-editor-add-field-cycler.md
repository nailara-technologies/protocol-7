---
name: reference-editor-add-field-cycler
description: "inline add-a-field cycler ([ + a | b ]) + users.record.optional_fields — and the two traps it exposed: a synthesised row must NEVER reach storage, and a schema def appended after editor.control.create has no buffer"
metadata:
  type: reference
---

Built 2026-08-12, after the namespace menu. **Mid-flight at time of writing —
see "state" at the end.**

## the two selection styles, now both real

Per user, chosen by CARDINALITY (recorded in
`editor-namespace-interface-design.yaml`'s `selection_styles` amendment):

- **inline cycler** — few known options, stays on its own row, Left/Right
  cycle in place. `editor.control.cycler.set( $state, $field, +1/-1 )`,
  wrapping. Choices live on the field def (`choices` + `choice` index), the
  buffer is NOT the value — same shape the LIST type uses for `entries`.
  Rendered by `editor.control.get_display_value` as `+ [a] | b | c`.
- **focused row list** — many or screen-sized, `editor.control.menu.*`.

## the add-a-field row

`user-edit.form.add_field_row` appends a row named `_add_field` offering the
optional fields a record does not yet carry; `user-edit.form.add_field` turns
the current choice into a real field and re-offers what is left.

Vocabulary comes from the AUTHORITY, per user:
`users.record.optional_fields` (name => starting SHAPE, where `[]` makes a
list field and `''` a plain line) exposed as `users.cmd.field-options
[<user>]`, which filters to what that record lacks. Field names must match
`^\w+$` — they become ascii.frame slot tokens — so `full_name`, never
`full-name`.

user-edit requests it AFTER the form renders (progressive enhancement: the
vocabulary costs a round trip and the row is only occasionally used), stores
it in `<user-edit.form.field_options>`, and **re-applies the row after every
list collapse** — a collapse rebuilds the schema from the one captured at
expand time, which never carried the row.

## TRAP 1 — a synthesised row must NEVER reach storage

`editor.control.submit` collects EVERY schema field, so the add-a-field row
was written into the record as `_add_field: ''`. It then became a real
record field, and because `_` sorts before letters it appeared FIRST in the
form and permanently blocked a fresh row from being offered (`add_field_row`
refuses to add a second one).

**Rule: any row that is an ACTION rather than data must be excluded in
`user-edit.form.submit` AND `user-edit.form.field_changed`** — the same rule
list rows (`list_row_of`) already follow. Check this for every future
synthesised row.

Recovering a polluted record: read fields, delete the key, `value-set` back.

## TRAP 2 — appending a schema def after create leaves no buffer

`editor.control.create` builds `$state->{'fields'}` (name => buffer) only for
the fields present when it runs. Pushing a def onto
`$state->{'schema'}{'fields'}` afterwards gives a field with a def but NO
buffer, so `editor.control.get_value` returns undef and the row renders
EMPTY with no error anywhere.

`add_field_row` therefore takes the STATE, not the schema, and creates the
buffer itself via `editor.buffer.memory.create`. Any other code that grows a
live schema must do the same (or rebuild through `create`, which is what
`list.expand` / `menu.open` do).

## also landed here

- `readonly` now blocks ALL mutating keys in `editor.control.process_key`
  (it only guarded the printable branch, so Backspace/Delete/Ctrl-k/u/w and
  yank still mutated a "read-only" field). This is what makes menu and
  cycler rows inert.
- The terminal's own cursor is hidden during raw mode (`\e[?25l`/`\e[?25h`,
  nshell's approach) — user reported two visible cursors.
- Rows that display something other than editable text (`list`, `menu_row`,
  `add_field`) are NOT cursor-bearing; the focus framing alone marks them.
- The add-a-field row has no label column and no `:` separator — it is an
  action, not a name/value pair (per user).

## testing gotcha, cost real time twice

**`users.*` changes need `v7.restart users` before they are exercised.** The
form side reloads per invocation; the zenka does not. A fresh record came out
with the old scalar shape and looked like the change had not worked.

Also: the number of Tabs needed to reach a given row CHANGES as data changes
(an expanded list is entries + 1 rows, and collapsing mid-sequence alters the
count). A hardcoded tab count in a test silently stops testing what it thinks
it does — this produced two false "it is broken" conclusions.

## state at time of writing

Working: vocabulary command, cycler primitive (verified standalone: cycles,
wraps both ways, renders bracketed), row appears after collapse, row excluded
from storage, polluted record cleaned.

NOT yet verified end-to-end: Left/Right cycling and Enter-to-add driven at a
pty. `user-edit.form.add_field` is written but its live path has not been
confirmed working.


## TRAP 3 — Left/Right never arrive as 'passthrough'

`editor.control.process_key` has explicit branches for Left/Right (cursor
movement), so they RETURN before the passthrough fallback and a host can
never claim them that way. Up/Down have no branch and DO fall through --
which is why field navigation worked while cycling silently did nothing.

Claim Left/Right by matching `$key` directly. Safe on a cycler row because
the built-in claim is a no-op there: the buffer is empty and the value is a
choice index, not text.

**General form:** `passthrough` only carries keys `process_key` did not
handle. Before claiming a key in a host, check whether it already has a
branch there -- a silent no-op is the failure mode, not an error.

## KNOWN LIMITATION — an optional field's declared SHAPE is ignored

`users.record.optional_fields` declares a starting shape (`[]` = list,
`''` = line), but user-edit receives only NAMES over the wire, so
`user-edit.form.add_field` assumes a plain line. A field declared `[]`
is therefore stored as a scalar and only becomes a list if something later
writes an array to it. Verified: `phone => []` stored as a string.

Fix when it matters: have `users.cmd.field-options` return name+shape pairs
rather than bare names, and honour the shape when building the new field.

## VERIFIED end-to-end 2026-08-12 (post-compaction)

Driven headlessly via `char-add`, which is better than a pty here because it
returns the rendered form after every key -- navigate by FEEDBACK instead of
guessing a tab count. Right/Left cycle and wrap, Enter replaces the row with
a real focused field and re-offers the remainder minus the one taken, the
value submits, and `_add_field` does NOT appear in the stored record.

#,,,,,..,,,,.,..,,,,.,.,.,.,,,.,,,.,,,,..,.,.,..,,...,...,...,,..,,,.,.,.,...,
#6LFD6OZH3GFFNYQSUL5BYJ53DE2CNEA6YK5OKHCNOJ2P3XJVMINUDVG6IWLP3MO55DXUHFFKJUXYK
#\\\|CVWRGDRWS376K7JOMH7YMK4OS6BN7RATX5U32TY2QGUX2FMBT2P \ / AMOS7 \ YOURUM ::
#\[7]NNZK3AUW37SYIB3NDX2NE4RRGPOXBTNRCWV5OKNT7DT7NW6HDUCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
