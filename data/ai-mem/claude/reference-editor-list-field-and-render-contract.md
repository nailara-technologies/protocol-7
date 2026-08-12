---
name: reference-editor-list-field-and-render-contract
description: "collapsible LIST field type (expand rewrites the schema) plus render_form's cell/marker contract — the reserved cursor cell, symmetric pads, one-char markers, and the two hazards (submit-while-expanded, active_field is an index)"
metadata:
  type: reference
---

Landed `f0d15bd28`. Generic editor infrastructure, not user-edit-specific.

## the LIST field type

A field holding several values renders compact when unfocused —
`[ .. 2 entries .. ]` — and **expands into one editable row per entry**
when entered, with a trailing EMPTY row meaning "new entry". Leaving it
collapses back, **dropping blanks** so the trailing row never accumulates.

**Expansion REWRITES THE SCHEMA** (user's decision, and the right one):
entries become real schema fields, so navigation, editing, cursor and every
renderer keep working unmodified.

- `editor.control.list.expand` / `.collapse` — go through
  `editor.control.create` with a NEW schema rather than hand-patching
  `{schema}{fields}` and `{fields}`. Nothing in `editor.control.*` caches a
  field list, but there is **no add/remove-field primitive**, so recreating
  reuses every guard `create` already has.
- Row names must stay `^\w+$` — `contact_0`, never `contact[0]` — because
  they become `ascii.frame` slot tokens (`schema_from_record`'s rule).
- `editor.control.create` accepts only `freeform_line`/`masked`, so a list
  field is a `freeform_line` def carrying `list => TRUE` + `entries`.
  `entries` on the field def is authoritative while collapsed.
- The collapsed summary lives in `editor.control.get_display_value`, whose
  header already stated the contract: a type that renders differently from
  how it is stored extends THAT module, not the renderers.
- Noun is a **STEM plus two suffixes** — English plurals are not all `+s`:
  `'entr'+'y'/'ies'`, `'address'+''/'es'`. `base.cnt_s($n,$plural,$singular)`
  returns the **suffix only**, count first, and its default `'s'` is wrong
  for "address**es**".
- First real consumer of `$editor_state->{'mode'}`, which
  `editor.control.create`/`.reset` had always SET and nothing ever read.

**`user-edit.form.sync_list_mode`** drives it: expands when focus lands on
a collapsed list, collapses when focus leaves an expanded one, and
**rebuilds the frame** — `user-edit.form.build_frame` assigns
`<ascii.frame.cache>` unconditionally and IS the invalidation primitive,
while `ascii.frame.load` returns its cache blindly, so a stale descriptor
renders new rows nowhere and leaves ghost rows behind.

## the two hazards — designed for, do not "simplify" them away

1. **Submit while expanded would corrupt the record.** `form.submit`
   collects one string per schema field, so an expanded list would write
   `contact_0`, `contact_1` as separate top-level fields and permanently
   replace the array — and **Enter submits from ANY field**. So
   `form.submit` collapses **unconditionally as its first action**
   (collapse is a no-op when nothing is expanded), *before*
   `editor.control.submit`, which resets fields on success.
2. **`active_field` is an INDEX, not a name.** Any field-count change
   silently relocates the cursor. Every rewrite recomputes it from the
   intended NAME. Collapse parks on the collapsed field — right when
   backing out, wrong when tabbing PAST it — so `sync_list_mode` restores
   the field you navigated to when it survived the rebuild.

## render_form's cell / marker contract

Values render as **`<pad><value><cursor cell><pad>`** inside their framing,
a constant width whether focused or not:

- the **cursor cell** gives an end-of-line cursor somewhere to live.
  Without it the marker is APPENDED, growing the value and stepping the
  closing bracket — and the whole frame — right as soon as you reach the
  end of a field.
- the **trailing pad must come AFTER the cursor cell**, or an end-of-line
  cursor eats it and the bracket sits flush against the marker. Most
  visible on an empty field, which rendered as `[ _]`.
- inactive values get the matching pads, so text does not shift sideways as
  focus moves; labels gained a pad either side of their separator to match.

**The 4th parameter is a marker hashref** — `cursor`, `focus_l`, `focus_r`,
`pad_l`, `pad_r` — each validated to **exactly one character**, because the
required-width computation and the fill padding both measure them with
`length()`. A colourising caller passes one-char placeholders, colourises
the finished frame, then substitutes coloured glyphs (ANSI occupies zero
columns, so alignment survives). `char-add` passes nothing and gets plain
glyphs, keeping wire replies readable.

**A collapsed list shows no inline cursor** — a summary has no meaningful
character position, and the marker was overwriting its own first character
(`[_. 2 entries ..]`). Cursor-bearing is a property of the field.

`ascii.frame.render` already implements **vertical padding** (blank content
rows inside the border, the analogue of its lpad/rpad) — `build_frame` just
sets `padding.top`/`.bottom`; no rendering change was needed.

## the draft question — RESOLVED, and it was a bad test

A collapsed list appeared to be missing from the draft. It was not: the
record under test had grown to three entries, so it expands to
`<field>_0..<field>_3` and the three Tab presses never LEFT the list — no
collapse fired, so there was correctly nothing to checkpoint yet. With
enough tabs to leave it, the list is drafted under its own name with its
entries joined.

Worth keeping as the lesson: **the number of tabs needed to leave an
expanded list is entries + 1**, and it changes as the data changes. A test
that hardcodes a tab count silently stops testing what it thinks it does.

## width, if it ever misbehaves

`build_frame` derives the mockup from field NAMES only, but the `{{token}}`
does not survive into the descriptor — `ascii.frame.render` recomputes row
width from the **values** (`required_width`; `fill_width` clamps at 0) and
**nothing truncates**. So a long value expands the whole frame and an
over-wide one wraps and destroys it. There is no tty clamp in that path.


## an overlay must ask whether the output is INTERACTIVE

The cursor is drawn by OVERLAYING the character it sits on. That aids a
user at a terminal and silently **corrupts the data** everywhere else — a
piped `show-form` rendered `[ _emote-fetch self-test ]`, eating the first
character of the focused field.

Reasoned into that once and got it wrong: the trade-off looked like
"showing the cursor position vs. losing one readable character", so the
marker won. But in a pipe **nothing is navigating**, so the cursor marks
nothing, while the corruption is real — and a capture is exactly the case
where the VALUES are the point.

Three output modes, and they are genuinely three:

| mode | cursor on a char | cursor past end |
|---|---|---|
| colour tty | inverse video + colour resume | phosphor green `_` |
| `-nc` tty | inverse video, no colour codes | plain `_` |
| **not a tty** | **the character itself** | space |

`-nc` blanks COLOURS but is not a request for plain text — `bin/Protocol-7`
keeps `clear_screen` as a real escape in that same branch, and inverse
video is an ATTRIBUTE, not a colour. Only a non-tty STDOUT must be
escape-free. Gate on `-t STDOUT` for "may I emit escapes at all" and on
`length $colors{'reset'}` for "are colours on" — they are different
questions.

**Generalises past this form:** any renderer that overlays, truncates or
decorates in place has to ask whether its output is interactive, because
the same transformation that helps a user damages a capture.

## `ascii.frame` label colouring — the flush-colon constraint is GONE

`ascii.frame.render.color.content_line` used to match a field label as
`[\w][\w\-\.]*:` — colon **flush** against the word. A mockup that
column-aligns by padding the name (`  contact   : {{X}}`, the obvious way
to write a form) matched nothing, so the whole row silently fell through to
the value colour with no hint why. It looked like broken colour config.

Relaxed to `[\w][\w\-\.]*\s*:`. Every pre-existing frame puts its padding
AFTER a flush colon (`role:    {{ROLE}}`), so `\s*` consumes nothing there
and they render byte-identically — the change only ADDS matches. Verified
that a line with no label still falls through, and that a value CONTAINING
a colon still binds the label at the leftmost word (`note:  meeting : 3pm`
→ label `note:`).

**Commit `69ca66fa4`'s message states the old rule** ("put the colon flush
against the label or the colouriser will not recognise it") — that is
history now, not guidance. Padded labels work.

user-edit keeps right-aligned labels anyway, because aligned colons read
well, but it is no longer forced to.

#,,,,,.,.,,,.,...,,,.,,.,,.,,,...,.,.,,..,,.,,..,,...,...,...,,,,,,,.,,.,,,..,
#T7XMLV7T4F3P6CMEHI7GEO4LCWK5KCZMABNHZNSHGWEBYRTVI5E2GKZE5RV43V4BXCXYECUJ7MLP4
#\\\|PNGBGA2Y6YHE3553ZG5AA6KH2FOX74GYF2DGV2NMWBNSQ3BLOBF \ / AMOS7 \ YOURUM ::
#\[7]AIUCHLWYKEKJGS7XNNET2K3IUOVVLY2ZDT7WRXO6XTZGOS7KDCCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
