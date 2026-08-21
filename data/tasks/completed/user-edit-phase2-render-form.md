# user-edit console zenka — phase 2: editor.ui.ascii_frame render backend

**Read first, both required:**
- `data/ai-mem/kimi/coding-style.md` and `data/ai-mem/kimi/MEMORY.md` — P7 module
  conventions. Pay attention to the "swapped module families" section —
  `base.file.*` calls at runtime as `file.*` (no `base.` prefix), `base.path.*`
  does NOT swap.
- `data/yaml/coding-tasks/user-edit-console-zenka.yaml` — read `phase_2_rendering`
  and `amos_term_plugin_overlap` specifically (search for those keys).
  `amos_term_plugin_overlap` is RESOLVED as of this task: terminal/ascii.frame
  only, no amos-term dependency at all — an amos-term-hosted GUI backend is
  planned for later, as a fully separate, additive piece, not something to
  build toward or leave hooks for here.
- `data/yaml/coding-tasks/editor-namespace-interface-design.yaml` — read the
  `editor.ui.*` section specifically for the contract this module implements
  (`render_field`, `render_form`, `update_cursor`, `refresh_display`, the
  `$viewport` shape). This is the authoritative interface spec — the design
  doc above references it but doesn't restate it in full.

Four prior phases already exist and are committed (skeleton, path registry,
outbox, draft storage) — none of them are directly relevant to this task
(this is pure rendering, no filesystem I/O), but do not touch any of their
files: `src/user-edit.init_code`, `src/user-edit.outbox.*`,
`src/user-edit.draft.*`, `cfg/zenki/user-edit/zenka.v7`.

## Goal

Implement `editor.ui.ascii_frame` — a rendering backend that takes a live
`editor.control.*` `$editor_state` and produces terminal-ready ascii-art
output via the existing `ascii.frame.*` mockup/render engine. There is NO
real settings field list to render yet (that depends on the `users.*`
command surface, which does not exist — see `users-zenka.yaml`, todo 5PN,
still design-only). Do not invent one. Build this against a SYNTHETIC test
fixture instead (see below) — a generic, reusable rendering backend, not a
form for any particular set of fields.

## Read this precedent closely before writing anything

- `data/yaml/ascii-frames/user-profile.yaml` — an EXISTING mockup file using
  the exact `{{SLOT}}` placeholder + `slots:` metadata format this task's
  test fixture should follow. It's a read-only display frame (no live
  editing), but the mockup FORMAT is exactly what you need — read it in full.
- `src/ascii.frame.load` — loads a named frame from
  `data/yaml/ascii-frames/<name>.yaml`, parses the mockup, returns a cached
  descriptor. This is how you'll load your test fixture.
- `src/ascii.frame.render` — takes `{ descriptor => ..., values => {
  slot_name => 'text', ... } }`, returns the fully rendered ascii-art string.
  Read this file in FULL — it's long but everything you need to know about
  how slot values become rendered output is in it (field/block/composed slot
  types, width computation, padding). Note: it takes a plain hashref of
  current values, not a live-binding mechanism — `ascii.frame.slot.bind`
  (scalar-ref binding) exists but is NOT what you should use here; simpler
  and more correct for this contract is to build a fresh `values` hash from
  `editor.control.get_value` on every render call.
- `src/editor.control.get_value`, `.get_cursor`, `.active_buffer` — the
  accessors you'll call per field to build the `values` hash and to know
  which field is currently active (`$editor_state->{active_field}`, an
  index into `$editor_state->{schema}{fields}`).

## What to build

1. `src/editor.ui.ascii_frame.render_form` — the primary deliverable.
   Signature: `render_form( $editor_state, $frame_name )` (or a params
   hashref if that fits this codebase's conventions better — check a few
   `editor.control.*` module signatures for the prevailing style and match
   it). Behavior:
   - `ascii.frame.load($frame_name)` to get the descriptor
   - for each field in `$editor_state->{schema}{fields}`, call
     `editor.control.get_value` to build the `values` hash, keyed by field
     name (must match the mockup's slot names — that's the caller's
     responsibility to keep in sync, not something to validate here)
   - **focus indication**: the active field (per `$editor_state->{active_field}`)
     needs to be visually distinguishable from inactive fields. `ascii.frame`
     slot prefix/suffix are static (part of the descriptor, not the values),
     so the simplest correct approach is to wrap the ACTIVE field's value
     itself before putting it in the `values` hash (e.g. bracket it) —
     inactive fields render their plain value. Implement this, and say in
     your summary exactly what wrapping you chose and why.
   - **cursor position**: this is explicitly an OPEN QUESTION in the design
     doc — `ascii.frame.render`'s width/alignment math was not verified
     against inserting a cursor marker character into a field's live value.
     Try inserting a marker character (e.g. `|`) at the correct character
     offset (from `editor.control.get_cursor`) into the ACTIVE field's value
     before rendering, and check by tracing `ascii.frame.render`'s width
     computation by hand whether this breaks alignment (the marker adds one
     character to that field's content width — does the frame's computed
     `required_width` account for it correctly, or does it need the marker
     stripped from width calculation but kept in display?). Report your
     finding clearly in your summary — if it doesn't work cleanly, document
     why and leave cursor display as a known limitation rather than shipping
     something subtly broken.
   - call `ascii.frame.render` with the built descriptor + values, return
     the resulting string
2. `src/editor.ui.ascii_frame.render_field` — single-field variant (for
   a single-field schema, or re-rendering just the active field without a
   full form redraw). Reasonable to implement as a thin wrapper around the
   same logic scoped to one field, or delegate to render_form and extract —
   use your judgment, but don't duplicate the focus/cursor logic wholesale.
3. A test fixture: `data/yaml/ascii-frames/user-edit-test-form.yaml` — a
   NEW file, 2-3 fields, modeled directly on `user-profile.yaml`'s format.
   This is a TEST fixture only, not a real settings form — name it clearly
   as such in its own `descr:` field. Do not modify `user-profile.yaml`.

## Explicitly out of scope — do not implement

- `update_cursor`/`refresh_display` as separate functions with their own
  contract compliance — cursor handling is folded into `render_form` above
  (re-render whole form each call) rather than incremental update, since
  there's no live terminal loop yet to make incremental updates meaningful
- any amos-term integration of any kind — resolved out of scope, see above
- the actual interactive read-key loop, `phase_3_form`'s submit flow, or
  any `users.*` integration
- `editor.ui.gtk3`/`editor.ui.vterm` or any other backend — ascii_frame only
- do not touch `src/user-edit.init_code`, `src/user-edit.outbox.*`,
  `src/user-edit.draft.*`, `cfg/zenki/user-edit/zenka.v7`, or
  `data/yaml/ascii-frames/user-profile.yaml`

## Verification

- `bin/dev/ptd -c` both new module files, confirm syntax ok
- construct a synthetic `$editor_state` by hand (via `editor.control.create`
  against a 2-3 field schema matching your test fixture's slots) in your
  own reasoning/trace — this zenka is not network-reachable, so no live
  execution; trace the call chain by hand and state in your summary what
  the final rendered string would look like for a specific example (which
  field active, what cursor position, what values)
- state clearly, per the cursor-position investigation above, whether it
  works or is a documented limitation

## P7 pitfalls (from prior kimi sessions, avoid these)

- swapped module families: `base.file.*` → `file.*` at runtime; `base.path.*`
  does NOT swap
- use `base.logs` (list form), not `base.log` (singular) unless confirmed
  otherwise by precedent
- never redeclare `my $call`
- `TRUE` = 5, `FALSE` = 0 in this codebase
- no fake/placeholder AMOS7 signature blocks — the human signs files
- `sprintf( qw| foo bar %s |, $x )` breaks on multi-word `qw()` in scalar
  context — single-word `qw| ... |` is fine
- module calls use `<[module.name]>->(...)` syntax (or bare `<[module.name]>`
  when no args)

When done, write a note to `data/ai-mem/kimi/coding-style.md` or
`data/ai-mem/kimi/MEMORY.md` on the cursor-position finding specifically —
this is genuinely useful for whoever builds the interactive loop next,
whether it worked or not.

#,,..,.,.,.,,,,.,,...,..,,..,,,.,,.,.,,..,,,.,..,,...,...,..,,.,,,,,.,.,.,,..,
#VKAD5IGNIUDXVZDNVGZK22DBNA3PU22XXQLW2HMNP722SYG6QHRR2CSCMTZFHSML3EBBIZOBKSS36
#\\\|O75IY7XQPU2FNOX3BUGIBQKXXHWVWFXM5N5ZVMIXUK4INUGGDHV \ / AMOS7 \ YOURUM ::
#\[7]VPGHJWX2K6DTWOEE3ZEWZSBYHHRXB7IP5BFATBOGKUSQZFVBV2DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
