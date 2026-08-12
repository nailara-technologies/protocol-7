---
name: reference-editor-add-field-cycler
description: "inline add-a-field cycler (now '+a+|b') + users.record.optional_fields — the two traps a synthesised row exposes (never reaches storage, schema def needs a buffer), why the frame's width is set by ascii.frame.render's own row-overflow detection and NOT by build_frame's min_width (which only predicts it), the padded-internal-token-name technique that follows from that, and the Esc-on-expanded-list bug"
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

Cost of the full-vocabulary reservation, measured — and NOT a flat number, which
is how it was first [ wrongly ] reported here. 46 vs 73 compared a steady state
against the transient pre-round-trip one. The real shape:

| record | row shows | natural | reserved |
|---|---|---|---|
| fresh, 3 fields | all 4 options | 73 | 73 — no cost |
| `taeki`, carries phone + shell | 2 options | 50 | 70 |

Zero on an empty record, growing as the record fills up: you pay for the options
already taken, worst when one remains. The cycler row is inherently wide [ 46
columns at four options ] and is the width-determining row either way.

Two decisions live in here and are worth keeping apart. Reserving while the row
is TRANSIENTLY absent — before the round trip, during a list expansion — is
cheap and worth keeping unconditionally. Reserving at the FULL vocabulary rather
than at the options still addable is the part that costs, and what it buys is a
frame that does not resize on every add and every remove.

User accepted it 2026-08-12 after seeing the corrected figures: "for now it is
totally acceptable". If it ever needs narrowing, change ONLY the second decision
— one line in `build_frame`'s `display_length` closure, measuring the addable
set instead of the whole vocabulary — and expect a resize per add/remove back.

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

## 2026-08-12, session two — density/compaction pass, landed in three commits

Per user, a long iterative pass over the same form's visual density, mostly
driven by live screenshots from their own interactive session rather than
headless captures. Landed as `d483d9550`, `c0cbd90b8`, `cff9866af`,
`c90b66b32`.

**What changed, briefly** (each is small on its own, the cumulative effect is
what mattered): list-row labels drop the `_0`/`_1` suffix on every row of an
expanded group, not just the first (`label_of`, `user-edit.form.build_frame`
— `list_row_of` present → its source field's name, on every row, including
`label_width`'s own measurement, which is what let it reclaim columns rather
than just hide the suffix). The cycler dropped its `+ ` prefix and switched
from `[choice]`/`+choice+` — nested brackets under the frame's own focus
brackets read as a typo. A collapsed list's summary is `':..N entries..:'`,
not `'.. N entries ..'` — borrows the frame's own `:`/`.` vocabulary so it
reads as chrome, and sits 2 columns closer to its label than a real value
(`editor.ui.ascii_frame.render_form`'s `list` branch drops both the inner
leading pad and the outer `pad_l` — relies on a list never being rendered
focused-while-collapsed, which `user-edit.form.sync_list_mode` already
guarantees by always expanding on arrival). An end-of-field cursor sits flush
against the closing bracket now (`'[ Taeki Ten_]'`, not `'[ Taeki Ten_ ]'`) —
a deliberate reversal of an earlier decision the file used to warn against;
confirmed with the user before landing since it undid something already
decided once. `note` moved from `users.record.default_fields` to
`users.record.optional_fields` — no reason it was the one mandatory field
with no story. `full_name` split into `full_user_name` / `full_real_name`; a
live record's existing value was moved with `users.cmd.value-set` (the whole
fields hash), never a hand-edit of the checksummed yaml. An expanded list
group gets a blank line ahead of its first row, compacted away when the row
above is already blank (typically another list's own collapsed-state
reserved trailing blanks) — same guard now shared with the add-a-field row's
existing blank-line-before-it rule, which had the identical gap and got the
same compaction.

## the ctrl-? cmd-list toggle, and drawing INSIDE a border row

Hidden by default; toggled with `Ctrl-?` (sent as `Ctrl-/`, `\x1f` — added to
`editor.input.parse_key_spec`'s key_map, both names). A one-line discovery
hint shows until the first keystroke of an opened card
(`<user-edit.form.hint_seen>`, reset in `value_get_reply`, set — and a
repaint forced — on the very first key in `stdin_key`'s loop, not tied to
paint count, since a round-trip repaint would otherwise make it flash once
and vanish before the user could read it).

First version printed the hint as a SEPARATE line below the card's own
closing border. User: "it draws a second one now, instead of replacing it" —
two dotted rows in a column reads as a doubled border. Fixed by splicing the
hint INTO `@frame_lines[-1]` (the plain render, before colourisation) instead
of printing anything extra — measuring the just-rendered frame's own width
and margin directly off that array rather than reserving anything for it in
`build_frame`.

Two more rounds after that: the exact dot-spacing had to match the user's
own hand-typed mockup letter-for-letter (`'ctrl-?'` keeps `-?` glued to the
`l` with no dot, unlike every other character — not a generatable rule,
hand-copied as a literal constant) including a **leading dot** right after
the border colon that was missed the first time ("still one character too
far left"). And the text came out **white** — the shared colouriser
(`ascii.frame.render.color`) classifies a line as border-vs-content by DOT
DENSITY across the WHOLE line, which a letter-heavy message can tip either
way depending on how much of the frame's width the trailing fill consumes —
and even on the border path, `ascii.frame.render.color.border_line` has no
case for a bare LETTER inside a fill run, passing it through with no colour
at all. Fixed by colouring the row BY HAND (matching
`configuration/ascii-frame`'s own `fill.single`/`fill.dot` mapping) and
shielding it from the automatic classifier with a **single otherwise-unused
byte** (`\x06`) standing in for the finished row until AFTER colourisation —
a length-1 line survives `content_line`'s classifier completely untouched
(its first/last/body slicing all degrade to returning that one raw byte when
`length <= 1`), so nothing the classifier does needs undoing on substitution.
This is a REUSABLE technique for injecting hand-coloured content into an
otherwise auto-coloured frame: build a sentinel placeholder, let the normal
pipeline run over it harmlessly, substitute the real (pre-coloured) content
back in afterward with a literal regex match.

## Esc on an expanded list needed pressing TWICE — root cause, not a timing bug

Reported as: press Esc once, nothing visible happens but you can still move
around; a second Esc then exits. First hypothesis was the bare-Esc debounce
timer (`user-edit.handler.esc_timeout`, 50ms) misfiring — WRONG, and it
matters why: `user-edit.form.escape`'s generic "leave a sub-mode" branch
(`if ($mode ne 'insert') { $editor_state->{mode} = 'insert'; ... }`) was
written when the module's own header comment said "nothing sets a non-base
mode yet" — true at the time, false since `editor.control.list.expand`
started setting `mode = 'list:<field>'`. Esc on an expanded list matched that
generic branch, which just RELABELS mode back to `'insert'` without ever
calling `editor.control.list.collapse` — so the schema keeps `'<field>_0'`,
`'<field>_1'` .. as permanent fields (`user-edit.form.sync_list_mode`'s own
collapse only runs on a `field_next`/`field_prev` TRANSITION, which Esc is
not), and the NEXT Esc, now genuinely in `insert` mode, exits outright. Fixed
by giving `list:` mode its own branch, ahead of the generic one, that calls
`editor.control.list.collapse` the same way `sync_list_mode` does. The stale
comment was corrected in place rather than left standing.

**Testing gotcha worth remembering**: this is NOT reproducible via
`char-add`. Its own driving loop
(`while (length(<user-edit.form.input_buffer>)) { stdin_key; event.once(0.02);
}`) re-invokes `stdin_key` every ~20ms for as long as an unresolved lone
`\e` sits in the buffer — and `stdin_key` unconditionally CANCELS any
pending esc-timer at its own top, every time it runs, regardless of whether
genuinely new bytes arrived. Since the timeout is 50ms and the loop's own
gap is 20ms, the timer never gets an uninterrupted window and never fires
within one `char-add` call, at all — confirmed empirically, not just
reasoned. Logic bugs reachable via `esc_timeout` have to be traced by
reading, then confirmed live, not through this harness.

## the width investigation, and what it settled for good

A long back-and-forth (user, rightly, did not accept "it's necessary" on
faith) traced the add-a-field row's width reservation all the way down to
two separate facts worth keeping:

**`build_frame`'s `min_width` does not ADD width — it only PREDICTS what
`ascii.frame.render` will conclude on its own.** The mockup is built ONCE, at
a width driven purely by the longest LABEL (`$inner_width` from `@bodies`,
completely separate from `$min_width`) — the add-field row's placeholder
token (`{{name}}`) gets whatever trailing space that narrow build happens to
leave it. At render time, `ascii.frame.render` computes
`row_width = prefix + REAL_value + suffix` from that already-fixed suffix,
completely independent of whatever `min_width` build_frame separately set —
proven by reading `ascii.frame.parse`'s own slot extraction
(`suffix = substr($line, $pos + length($match))`, taken straight off the
narrow mockup). So even with `min_width` deleted entirely, `ascii.frame.
render`'s own per-slot overflow detection (`$required_width = $row_width if
$row_width > $required_width`) would arrive at the identical final width —
`min_width` exists purely to avoid a RESIZE-ON-COLLAPSE/EXPAND jitter
elsewhere, not to inflate this row.

**The label baseline and the cycler's real-content overshoot ADD, not
`max()`.** Because every row shares ONE `$inner_width` for mockup
construction, a wider label column (e.g. `full_user_name`, needing ~40) gives
EVERY row a wider trailing suffix too — including the add-field row, whose
own body is tiny (~16). That inherited slack doesn't help it; the row's real
value (44 chars) still overflows prefix+suffix, and the overflow amount is
added ON TOP of the label-driven baseline: `70 ≈ 40 (label baseline) + 30
(cycler overshoot)`, not `max(40, 46)`. Verified by hand-computing the
identity (`row_width = inner_width + display - len(name) - 4`) against
several live captures until the numbers matched exactly, including one where
the add-field row was entirely INVISIBLE (a list was expanded over it) yet
the frame was still the full width — the reservation applies the moment the
vocabulary round trip lands, independent of whether the row is currently
attached to the schema.

**The actual, implemented fix**: the add-field row's schema field name
(`'_add_field'`, 10 chars) is purely internal — never shown to the user — but
its LENGTH is exactly what sets the mockup placeholder's assumed size, per
the identity above. Padded it to 30 characters (`user-edit.form.
add_field_name`, a new shared module so `build_frame`'s reservation tuple and
`add_field_row`'s real field can't drift apart — same reasoning `editor.
control.list.summary` exists for). 30 was chosen as roughly the average
cycler width across a 2-4 remaining-choice steady state for this vocabulary
(measured: 24 / 35 / 46 columns for 2/3/4 choices) — narrows the common case
substantially (73→53 columns in the reported case) without ever
under-reserving (a real value SHORTER than the padded token just leaves
unused suffix, harmless; only a value LONGER re-triggers some overshoot, and
still does at the full-vocabulary extreme). **This is a general technique**:
when a synthesised row's real rendered content is much longer than its own
field name, and that gap is producing unwanted width, padding the INTERNAL
identifier (never shown, must stay `^\w+$`) is a legitimate, low-risk lever
— because the identity ties the mockup's assumed size directly to
`len(name)`, nothing else changes it.

**Also confirmed, not a divergence**: `show-form` (one-shot) looks much
narrower than `start` (interactive) on identical data — not a bug, `show-form`
prints and exits before the optional-field vocabulary round trip can ever
land, so `@vocabulary` stays empty and the add-field row's reservation never
fires at all. It is missing a whole feature, not computing a tighter answer.

**Also worth remembering**: killed the user's own live interactive session
by mistake mid-session, via a cleanup loop that excluded one hardcoded PID —
the PID had changed (session restarted) and the exclusion silently stopped
matching. Fixed by filtering on the TTY column (`awk '$7 == "?"'`, only kill
processes with NO controlling terminal) instead of a PID, going forward.

#,,,.,,,.,,,.,.,,,,,,,...,.,.,...,..,,,.,,...,..,,...,...,.,.,..,,...,,,,,.,.,
#BT7LXVH3TOJ5HWG3TLQO2WEXVMAORSTIWBQWCBRY3GYBYD5UC7JQXAJL4M7F6KCVENOIEUZL6TKD6
#\\\|FLXI2RHVKVIL2TEQBGGYV6UOONJALGGMTOCYFGPNWJNA6JYHQNC \ / AMOS7 \ YOURUM ::
#\[7]ASVATWBEX25X7W6BMYMI67GAZZ6ISUG37JVOVGR65JIUT3GGNOCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
