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

## CLOSED 2026-08-12 — the shape limitation, and the vocabulary is now two-way

`users.cmd.field-options` returns `<name> <shape>` pairs (`list` / `line`),
user-edit asks for it WITHOUT a username — the whole vocabulary, filtered
locally by `user-edit.form.addable_fields` — and `add_field` honours the
shape. Verified: `phone` (declared `[]`) comes back as a real list field.

Asking unfiltered is what made REMOVAL possible: the part the server-side
filter threw away (the optional fields a record already has) is exactly the
set that may be given back.

**Del on an empty optional field removes it** (`user-edit.form.remove_field`,
guarded by `user-edit.form.removable_field`). No wire command was needed:
`users.cmd.value-set` hands its json to `users.record.build` as the WHOLE
fields hash, so a field absent from the schema is absent from the record on
the next submit. Verified: add → submit → stored, empty → Del → submit →
key gone.

Two traps that shaped it:

- **sample emptiness BEFORE `process_key`.** On a one-character field Delete
  removes the character; a check made after would then see an empty field and
  remove the FIELD. One keystroke, two effects. Verified the other way: nine
  Deletes empty a nine-character field without removing it, the tenth removes.
- **Delete is TRAP 3 again** — `process_key` has an explicit `\e[3~` branch,
  so it never arrives as `passthrough`. Matched on `$key`.

Sampling the def before `process_key` is safe because `process_key` only READS
`active_field` and never assigns it — no branch of it can move focus under the
caller.

**A LIST-shaped optional field is only ever on screen under another name.**
Focus arriving on `phone` expands it, so the row under the cursor is `phone_0`
and the mode is `list:phone`. A guard written only for a plain collapsed row
therefore makes a list-shaped optional field addable and NEVER removable — add
it by mistake and it is permanent. Caught by testing it; the line-shaped cases
(`shell`, `full_name`) all passed and hid it.

`removable_field` therefore returns the NAME to remove rather than a yes/no:
for an expanded list it returns the SOURCE field, counting it empty when no row
of it holds anything (the trailing 'new entry' row is always there and is not
content). `remove_field` collapses first, exactly as `submit` does and for the
same reason. Verified both ways: an empty expanded list is removed by Delete,
one holding an entry loses a character instead.

## VERIFIED end-to-end 2026-08-12 (post-compaction)

Driven headlessly via `char-add`, which is better than a pty here because it
returns the rendered form after every key -- navigate by FEEDBACK instead of
guessing a tab count. Right/Left cycle and wrap, Enter replaces the row with
a real focused field and re-offers the remainder minus the one taken, the
value submits, and `_add_field` does NOT appear in the stored record.



## the frame stopped moving sideways — and the identity that made it possible

Three separate jumps, all fixed 2026-08-12:

1. **the cycler jittered.** `[full_name]` is two columns wider than
   `full_name`, so every choice to its right shifted on every keypress. Fixed
   in `editor.control.cycler.render` with the rule `render_form` already uses
   for focus: brackets when current, MATCHING SPACES when not. The cells alone
   make the width constant — every choice pays for two either way. Padding the
   choices out to the longest as well is a *second, unrelated* effect and costs
   real width (9 columns on the four-option vocabulary), so it is not done.

2. **`_add_field` inflated the label column.** `build_frame` took
   `$label_width` over every name including a row that has no label at all.

3. **expand/collapse resized the frame.** `build_frame` now reserves width for
   BOTH renderings and sets `min_width` on the descriptor (`ascii.frame.render`
   already honours it; units are INNER content width — borders excluded,
   lpad/rpad included).

**The identity, and why the obvious approach fails.** Traced through
build_frame's own mockup (`prefix = label_width + 6`, `body = label_width +
len(name) + 10`, `suffix = inner_width - body`) and render's per-slot sum
(`prefix + value + suffix + lpad + rpad`, with `parse` stripping exactly the
lpad/rpad render adds back):

```
row_width = inner_width + len(display) - len(name) - 4
```

It holds for label-less rows too. **Both** `inner_width` and `len(name)` differ
between the two renderings (`{{contact}}` is 11, `{{contact_0}}` is 13), so
walking the CURRENT mockup's parsed slots cannot predict the other state — it
comes out wrong in both directions. The whole row set has to be rebuilt for
each rendering and measured with one shared helper.

Also required, and each one is its own jump if missed:

- `build_frame` takes the **STATE**, not the schema — an expanded list's
  original field list lives on `list_source`, which is what collapse rebuilds
  from and therefore the only exact source for the other direction.
- `$label_width` is taken over both renderings, so a collapsed `contact`
  reserves for the `contact_0` its expansion produces. Otherwise the frame
  border holds still while the `:` column steps sideways.
- the add-a-field row is reserved for **even when it is not there** — it
  arrives a round trip after the first paint, is absent while a list is
  expanded, and comes and goes as fields are added and removed. Measured at
  the FULL vocabulary, never at the options currently left.
- `field_options_reply` rebuilds the frame even when it cannot ATTACH the row
  (mode is not `insert`), or the reservation waits for whatever later collapse
  happens to rebuild next.
- `render_form`'s `$only_field` branch must carry `min_width` across, or a
  single-row redraw renders narrower than the frame it patches.

Cost of the full-vocabulary reservation, measured: a three-field record renders
73 columns wide instead of 46. That is the price of a frame that only moves
when the user types.

## a capture must not have a cursor overlaid into it

`user-edit.cmd.char-add` called `render_form` with default marks, so its reply
carried a literal `|` OVERLAID onto the value — `[ |170-1234 ]` for a field
holding `0170-1234`. It corrupts the very value a capture exists to show.

`user-edit.form.render` already reaches this conclusion for a non-terminal
STDOUT and restores the character; a network reply is that same case, always.
char-add now sets the marker TO the character underneath, overlaying it with
itself. Focus is not lost: the row keeps its framing brackets and the active
field is named below the frame.

The three render paths and how they differ: `console.start` (interactive) and
`console.show-form` (one-shot) both go through `user-edit.form.render`, which
gives the cursor inverse video on a terminal and a green underscore on an empty
cell. `cmd.char-add` renders its own frame and is always a capture.

## a stale comment sent one reader chasing a jump that was already gone

`render_form`'s header warned that frame width could shift up to 3 columns
across focus changes. True once; not true since `pad_l`/`pad_r` came to match
the brackets and the cursor started overlaying a reserved cell. Corrected in
place — a width note that no longer describes the code is worse than none.

#,,..,,..,.,.,,..,.,.,...,.,,,,.,,...,,.,,,.,,..,,...,...,,,.,.,.,.,,,,,.,,,.,
#7Q3XYJBHO3Z22NQUQ6GRCRIGH6L5L7JJ742YIKXRKTMWAO6DSFMKIPHEZPQPBU3UFCAO5W3JPOEFM
#\\\|ZB6INFBNEDNM3EOGICPZFRVPDNFW6KDBPTAPRSCK75XKZOBATWO \ / AMOS7 \ YOURUM ::
#\[7]MSOXUUXK5VLWKVUNNWGZ5S3NGP5YA5AUCOODLDQ3PNPXZPZJEQCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
