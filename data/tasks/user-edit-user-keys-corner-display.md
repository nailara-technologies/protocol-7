# user-edit user_keys field — opt-in corner-checksum display mode

## Goal

Add a SECOND, opt-in display mode for `user-edit`'s `user_keys` field,
selected via a new zenka config toggle, alongside the existing inline
mode which stays the unchanged default. Read
`modules/user-edit.form.schema_from_record`'s `user_keys` field def (the
`## SYNTHESISED` section building `@other_keys_lines`) first — that is the
CURRENT, working, just-landed inline mode this task must not regress.

**Inline mode (today, default, unchanged)**: each row shows `<name>
<checksum>` on one line, name shortened via `base.parser.ellipse_center`
to `<user-edit.cfg.user_keys_name_width>` (defaults 20) so a long
checksum (an encrypted key's `<::[enc-key]::CCCCCCC:>` shape, 23 chars)
doesn't force the row past the multiline viewport floor. Landed this
session, commits `0e3e84cd0` / `aa9048869` — read
`data/ai-mem/claude/bug-crypt-c25519-key-vars-base-identity-hijack.md`'s
RESOLVED sections for the full account of what was tried and what the
actual bug was (a display-width truncation, not a data bug — the
checksum computation itself has been correct the whole time and needs no
further work here).

**Corner mode (new, opt-in)**: each row shows ONLY the key name (no
inline checksum, so `ellipse_center` truncation is rarely if ever needed
— names are short). The CURRENTLY SELECTED entry's checksum instead
renders in a fixed corner of the form frame — top-right or bottom-right,
chosen by the selected entry's position in the list, so the checksum
never sits directly next to the row it belongs to. Per the project
owner's own framing: with 3 entries, selecting entry 3 (the LOWER one)
shows its checksum in the TOP-right corner; selecting entries 1-2 (the
UPPER ones) shows in the BOTTOM-right corner — i.e. the checksum always
appears in the corner FARTHEST from the current selection, never
crowding it.

## Toggle

New zenka config var, matching the exact precedent
`user-edit.cfg.user_keys_name_width` set this session:

```
user-edit.cfg.user_keys_display_type = inline   ## or 'corner' ##
```

Default `inline` (via `//=` in the code) when unset — every existing
`user-edit` deployment keeps today's behavior with zero config changes.
Add it to `configuration/zenki/user-edit/start`, matching that file's
existing `user_keys_name_width` entry's comment style and placement
(commented-out example line showing the default, same as that one).

## Why this needs new frame plumbing, and where it's bounded

`modules/user-edit.form.build_frame` builds this zenka's frame layout
PROGRAMMATICALLY per record (no static `.mockup`/template file exists for
`user-edit` — confirmed, searched `data/yaml/ascii-frames/` and found
none). So corner slots are not "add two tokens to a template file," they
are "emit two additional frame tokens into the layout `build_frame`
already constructs." Read `modules/ascii.frame.compose` and
`modules/ascii.frame.parse` to understand how `build_frame`'s existing
row tokens get embedded, before designing how the two new corner tokens
get added the same way — reuse that same mechanism, do not invent a
parallel one.

**Scope this to `user-edit`'s own two files** — `user-edit.form.build_frame`
and `editor.ui.ascii_frame.render_form` (only the `multiline` block already
there, `modules/editor.ui.ascii_frame.render_form:94-256`) — even though
the underlying mechanism (a fixed corner slot showing detail for a list's
current selection) could plausibly generalize to other zenki someday. Do
NOT attempt that generalization here; a second real consumer should exist
before extracting a shared primitive.

## What to build

1. `user-edit.form.build_frame`: when `user-edit.cfg.user_keys_display_type`
   is `'corner'`, reserve two additional named frame tokens (naming your
   choice, e.g. `user_keys_corner_top`, `user_keys_corner_bottom`) at the
   top-right and bottom-right of the frame's own border, sized to fit the
   longest checksum shape (23 chars, `<::[enc-key]::CCCCCCC:>` — same
   figure the just-landed viewport-floor fix used). When the toggle is
   `'inline'` (default) these tokens must not be reserved at all — no
   frame-shape change for the common case.

2. `editor.ui.ascii_frame.render_form`'s multiline block: when this field
   is `user_keys` AND the toggle is `'corner'` AND the field is active
   (`$is_active`), use the already-computed `$cursor_line` (see the
   existing `editor.control.multiline.cursor_line` call in that block) to
   determine which entry is selected, compute ITS checksum (the data is
   already available via the same `keys.checksum_href` call
   `schema_from_record` already makes — do not recompute it a second way),
   and write it into whichever corner token is farther from the selected
   row's position (selection in the upper half of the visible window →
   bottom corner; lower half → top corner). Leave the OTHER corner token
   blank. When the field is not active, both corner tokens go blank (no
   stale checksum left showing after focus moves away).

3. Rows render name-only in corner mode — no `ellipse_center` truncation
   call needed for the common case, though leave it in place as a safety
   cap for a pathologically long key name (don't remove that call, only
   change what's appended after the name).

## Explicit out of scope

- Do not touch `crypt.C25519`, `key_vars`, `key_checksums`, or any
  checksum-computation code — confirmed correct already, not the bug here.
- Do not remove, deprecate, or change default behavior of inline mode.
- Do not generalize the corner-slot mechanism into shared `ascii.frame`/
  `editor.ui.*` code — keep it in `user-edit`'s own two files.
- Do not add a THIRD display mode, pagination, or corner placement for
  more than the two corners described above (e.g. no "middle" corner, no
  configurable corner choice beyond the automatic farthest-from-selection
  rule).

## Acceptance checks — all live, required

1. **Regression, hard gate**: with the toggle unset (or explicitly
   `'inline'`), `user_keys` renders BYTE-IDENTICAL to today's committed
   behavior. Use the same `-no-tty`/`char-add` technique documented in
   `data/ai-mem/claude/reference-user-edit-headless-driving.md` — expand
   `user_keys` for `taeki`'s real record and confirm the row still reads
   `proto-7.sourcecode <::[enc-key]::MI4B6FA:>` exactly.
2. Set `user-edit.cfg.user_keys_display_type = corner`, restart the zenka
   (config changes need a fresh process, same as any other `user-edit`
   code change per the reference doc), open `taeki`'s form, expand
   `user_keys` — rows show name-only, no checksum inline.
3. With at least 2 keys in the list (use a throwaway second key if needed,
   `taeki` currently has exactly one other key besides identity —
   `proto-7.sourcecode` — so either add a temporary test key via
   `keys.console.create` and remove it afterward, or reason about the
   single-entry case explicitly and note the limitation), navigate the
   cursor between entries and confirm: selecting a LOWER entry shows its
   checksum in the TOP-right corner; selecting an UPPER entry shows it in
   the BOTTOM-right corner; the corner not in use is blank.
4. Move focus OFF `user_keys` entirely (Tab/arrow to another field) and
   confirm both corner tokens go blank — no stale checksum left over.
5. Toggle back to `'inline'` (or unset it) and confirm behavior matches
   check #1 again — the toggle is fully reversible, not a one-way
   migration.

Report each check's actual result, not just "passed" — this project
distrusts self-reported dispatch summaries and always independently
re-verifies the diff and live behavior after any dispatch.

## Model

K3 (default, full reasoning quality) — this is new interaction/layout
design work in a shared rendering path, not pattern-mirroring against an
existing precedent file. Higher risk of scope creep than this session's
other dispatches; the out-of-scope section above is not optional guidance.

#,,..,.,.,,,.,,,.,,,.,,,.,.,.,..,,,.,,.,.,,.,,..,,...,...,..,,,,.,,..,,.,,..,,
#GNUO7VQEADWHX5FLUP324CQQUHNIG2JCPLOSNRHSTGFOO4M5GELJCNGMO75JATUX3GGKYP4N4JOYK
#\\\|LSZJWCJMOVOLGTSD2WYGQQM7UMDMHDNMY42AUKRMW23A4ER2BDV \ / AMOS7 \ YOURUM ::
#\[7]7LQUIIKCT6MZWMSPATTGV4U5SUVDIIOJ6DBYN7M37QD6XG42CKBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
