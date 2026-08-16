# editor.*: event-loop-safe in-frame prompt primitive (text + masked)

## archive: DONE ✓ — 2026-08-16
## commit: b056a04c4 — user-edit: event-loop-safe in-frame prompt primitive, fix loader deferred-compile bugs
## notes: editor.control.prompt.* built and live-verified; two follow-up fixes landed same session -- cursor now uses the shared \x01 placeholder + .cursor_char convention instead of a stale hardcoded pipe, and Left-arrow only cancels the prompt on a genuinely empty buffer instead of unconditionally (see data/ai-mem/claude/feedback-modal-prompt-navigation-never-loses-content.md); became the shared foundation create/rename/delete all build on

**Read first:**
- `data/ai-mem/kimi/coding-style.md` and `data/ai-mem/kimi/MEMORY.md` -- P7
  module conventions, common mistakes to avoid.
- `data/ai-mem/claude/reference-console-question-ask-primitive.md` --
  **read this in full before designing anything.** It maps FIVE places
  interaction code already lives in this codebase and says explicitly: do
  not add a sixth. This task's whole job is filling in medium #5
  (`editor.control.*` + `editor.input.next_key` + the
  `event.add_io`/`add_var` pair -- "the event-driven one"), which that file
  already flags as the gap: `base.term.ask` is BLOCKING and cannot run
  inside a running event loop, and "an event-loop-safe prompt (needed for
  `masked` credential entry *inside* user-edit's form) is a SEPARATE, still-
  unbuilt thing" -- documented since 2026-08-12, still true.
- `data/ai-mem/claude/project-frictionless-control-zenki-vision.md` -- why
  this is being built now: `user-edit` and related zenki are becoming
  central control points and need to be frictionless by default, per user
  direction, with more passes like this one expected.
- `data/tasks/completed/user-edit-key-actions-create.md` -- the task that
  built the CURRENT key-create flow this one replaces the guts of. Read it
  for context on `user-edit.excursion.key_create` and
  `user-edit.check_pending_excursions`, both of which this task's own
  `## What this REPLACES` section below covers.
- `modules/user-edit.excursion.key_create`, `modules/user-edit.
  check_pending_excursions`, `modules/plugin.user-edit.key-actions.*` --
  read the CURRENT working implementation before changing it. It is real,
  live-tested, committed code (`551414c5e`) -- understand it fully before
  ripping any of it out.
- `modules/editor.control.create`, `modules/editor.control.process_key`,
  `modules/editor.buffer.memory.create`/`.insert`/`.delete`/`.load`,
  `modules/editor.control.get_display_value`, `modules/user-edit.handler.
  stdin_key` (the plugin-mode routing block specifically), `modules/editor.
  ui.ascii_frame.render_form` -- the primitives this task composes. All
  already exist and are not being redesigned, only reused in a new
  combination.

## Goal

Right now, `user-edit`'s key-actions "create a new key" flow gets its two
prompts (key name, then passphrase) by **leaving the event loop entirely**:
`Event::unloop()`, restore the terminal to normal mode, run a BLOCKING
`base.term.ask` (name) then `keys.console.create`'s own blocking
`AMOS7::TERM::read_password_repeated` (passphrase), then re-init raw mode
and re-enter the loop. It works (live-verified, committed), but the prompts
print as plain, unstyled terminal output that visually breaks out of the
`ascii.frame` box the rest of the form renders inside -- jarring, and not
the shape a "frictionless control point" should have per the direction
above.

Build a **real, event-loop-safe, in-frame prompt primitive** in the shared
`editor.*` namespace -- not `user-edit`-specific -- general enough to serve:
1. a plain TEXT prompt (this task's immediate use: the key name)
2. a MASKED prompt (this task's immediate use: the key passphrase)
3. future `masked`/credential FIELD entry inside a running form -- flagged
   as blocked on exactly this same gap in `data/ai-mem/claude/project-
   credential-types-into-user-edit.md`, not this task's job to wire up, but
   the primitive must not be shaped in a way that only works for key-actions

Then convert `user-edit`'s key-create flow to use it, end to end.

## What this REPLACES, not extends

**Do not build the in-frame prompt ON TOP OF the existing excursion
mechanism.** Once every prompt this flow needs is answered in-loop, nothing
ever needs to leave the loop for this feature at all, which means:

- `user-edit.check_pending_excursions`, `<user-edit.pending.key_create>`,
  and the two `<[user-edit.check_pending_excursions]>;` call sites added to
  `user-edit.console.start` and `user-edit.offer_create` become dead code
  for THIS feature and should be removed (they were purpose-built for the
  blocking-excursion shape this task retires). Check whether anything else
  in the codebase came to depend on `check_pending_excursions` existing as
  a general mechanism before deleting it outright -- if it is genuinely
  key-actions-only, remove it; if something else now also uses it, leave it
  and just stop routing key-actions through it.
- `user-edit.term_restore`/`user-edit.term_init` stay -- they are the real
  raw-mode toggle used for the whole session, not excursion-specific -- but
  `user-edit.excursion.key_create` should no longer call them itself, since
  nothing it does anymore needs the terminal out of raw mode.
- `user-edit.excursion.key_create`'s call to `keys.console.create` goes
  away too -- see "the passphrase prompt, and closing the base.exit risk
  for real" below.

## Design anchor 1 -- render inside the triggering field's own row

Per user direction: reuse the field that triggered the prompt (`key_actions`
in this task's case) to display it, rather than opening a separate UI
region. Concretely: while a prompt is open, that field's rendered content
temporarily becomes the prompt's own label + live buffer content + cursor,
using the SAME bracket/`|`-cursor styling `editor.ui.ascii_frame.render_form`
already gives every ordinary focused field -- not a new visual language.
Read `render_form`'s existing focus/cursor-bracket logic and its
`display_override` mechanism (`plugin.user-edit.key-details.render`'s own
header explains the `$field_def` mutation pattern already in use for
carrying extra state from schema-build time into render time) before
deciding exactly how the prompt's state reaches render time -- there is
already a working pattern for "a field's render output depends on state
beyond its own buffer," reuse it rather than inventing a second one.

## Design anchor 2 -- masked prompts reuse the EXISTING masking machinery

Do not build new masking logic. `editor.buffer.memory.create` already
builds `mask_stars` for `type => 'masked'`, and `editor.control.
get_display_value` already renders it as a run of `*` characters (read both
-- lines ~84-91 of `get_display_value` specifically). A masked in-frame
prompt is a buffer created with `type => 'masked'`, same as any masked
field would be -- the display layer needs no new masking code, only a new
place to CALL it from (the prompt's own render path, per anchor 1 above).

## Design anchor 3 -- the passphrase prompt, and closing the `base.exit` risk for real

`user-edit-key-actions-create.md`'s own task file flagged an accepted,
un-pre-emptable residual risk: `keys.console.create`'s password guard
(`AMOS7::TERM::read_password_repeated` returning undef/too-short) still
calls `<[base.exit]>` -- `CORE::exit` -- because the password is read
INSIDE that module, where user-edit cannot validate it first. Building a
real in-frame masked prompt removes this call to `keys.console.create`
entirely, which removes the risk with it, not just works around it:

Read `modules/keys.console.create` in full -- its OWN body, past the
guards `user-edit.excursion.key_create` already pre-empts, is short:
`<[crypt.C25519.gen_keys]>->($name)` then `<[crypt.C25519.write_keys]>->(
$name, $key_password )`. Call THOSE two directly from `user-edit`'s own
excursion code instead of `keys.console.create`, with `$key_password`
collected via this task's new in-frame masked prompt and validated by
`user-edit` itself (non-empty, minimum length -- match whatever
`keys.console.create`'s own guard required, read it exactly, don't guess
at the threshold) BEFORE calling `write_keys`. This closes the very last
`base.exit`-reachable path in the whole key-create flow -- confirm that
directly, don't just assume it, by re-reading `crypt.C25519.gen_keys` and
`crypt.C25519.write_keys` themselves for any `base.exit` call of their own
first.

## Design anchor 4 -- `gen_keys`'s own reentrancy hazard, confirmed live, must carry over

**Read `modules/crypt.C25519.gen_keys` and `modules/base.event.once` before
writing any submit-handling code for the new prompt.** `gen_keys` retries in
a `while (not $TRUE) { <[event.once]>->(0.007); ... }` harmonic-truth loop,
and `base.event.once` is literally `return Event::loop($timeout);` -- a
REAL, reentrant Event pump, not a sleep. This means while generation is
retrying (not instant -- can take several iterations), a keypress arriving
in one of those 7ms windows CAN dispatch the STDIN watcher a second time,
reentrantly, from deep inside `gen_keys`, before the first submit has
finished. Confirmed live and already fixed once for the CURRENT (soon to be
replaced) excursion shape: `user-edit.check_pending_excursions` and
`plugin.user-edit.key-actions.handler.key` now carry a `<user-edit.
key_actions.busy>` guard set around the `gen_keys`/`write_keys` call,
checked before arming another submit -- read both as the precedent for the
shape of the fix, not just as code being deleted. **The new in-frame prompt
needs the equivalent protection**: whatever handles Enter/submit on the open
prompt must ignore a reentrant trigger while `gen_keys`/`write_keys` are
still running for a PRIOR submit -- a busy flag scoped to the prompt's own
state (not necessarily the same global keyword name) is the obvious shape,
but design it deliberately, don't assume unloop/re-entrant complexity
disappearing (this task removes the blocking EXCURSION, it does not remove
`gen_keys`'s own internal Event pump, which is unrelated and stays exactly
as reentrancy-hazardous as before).

## Design anchor 5 -- Ctrl-C while the prompt is open must cancel the PROMPT, not the form

Read `user-edit.handler.stdin_key`'s `elsif ( $action eq qw| signal | )`
branch (confirmed live): ordinary Ctrl-C in NORMAL mode calls `user-edit.
form.quit->('cancelled','no-op')`, which flushes the draft, restores the
terminal, and **ends the whole zenka process** (`form.quit` ends in
`<[base.exit]>`). If the new prompt's own key-handling ever falls through to
this same path -- e.g. by not claiming `\x03` explicitly and letting it
propagate as an advisory `signal` action the same way ordinary field editing
does -- pressing Ctrl-C mid-passphrase-entry would silently end the entire
session, not just back out of the prompt. That is very likely not what a
user expects from Ctrl-C inside a small nested prompt, and is a real
foot-gun, not a cosmetic detail. **Required**: the prompt's own key handler
must claim `\x03` explicitly and treat it exactly like Esc/Left -- cancel
the PROMPT only, return focus to wherever it was (e.g. `key_actions`,
un-entered), no form-wide quit, no data loss beyond the prompt's own
in-progress buffer.

## Explicitly out of scope

- Wiring `masked`/credential FIELD entry (ordinary schema fields, not this
  prompt) to the new primitive -- that is
  `project-credential-types-into-user-edit.md`'s own future task, this one
  only needs to build the primitive in a shape that COULD serve it later,
  not actually wire it up now.
- Rename/remove key actions, identity-switching -- unrelated, still out of
  scope per the original task file.
- `-U`/unencrypted key creation -- the user asked for this separately (see
  this session's own chat log) but it is a distinct, small addition on top
  of a working encrypted flow, not part of THIS task. Land the in-frame
  prompt first.
- Any change to `plugin.user-edit.address-cluster` or other existing
  plugins beyond what's needed to keep them working unchanged.

## Acceptance checks -- write these as END-STATE checks, not action-fired checks

**The single lesson from the last round of this feature, stated plainly so
it does not repeat**: the previous task's live acceptance checks proved the
key WAS created (verified via `keys list`) and treated that as sufficient.
It was not -- the form's own POST-CREATE DISPLAY never got checked, and
that gap was the actual bug the user hit live afterward (`user_keys` not
refreshing). Every check below must verify the FORM'S OWN STATE afterward,
not just that the underlying action succeeded.

Use `script -qec` (a real pty) -- this feature is fundamentally about how
prompts LOOK and behave inside the frame, which no scripted/headless driver
can meaningfully verify.

1. Trigger create, type a key name in the prompt: confirm the prompt
   renders INSIDE the frame's border (capture the actual rendered frame,
   compare against a baseline capture from before this task -- the border
   lines must be in the same place, same width), with visible cursor
   feedback as you type, not a bare terminal echo.
2. Confirm Esc/Left cancels the name prompt cleanly: the form returns to
   its normal state, `key_actions` shows whatever its normal unfocused
   text is, no stray buffer/state left over, and typing in OTHER fields
   immediately after works identically to before this task existed.
3. Continue past the name prompt into the masked passphrase prompt:
   confirm it visually masks input (no plaintext echoed anywhere,
   including in any log this session produces) and that the SAME
   cancel/Esc behavior from check 2 holds here too.
4. Complete a real create end to end: confirm the new key exists via
   `keys list` AND confirm `user_keys` in the form reflects it immediately
   afterward with no extra keypress or reload (this is the exact gap the
   previous round's checks missed -- do not repeat that miss here).
5. Attempt create with a duplicate name: confirm the zenka is still alive
   afterward (`ps`, as its own separate check per this project's testing-
   harness gotcha -- never combine a `ps`/`kill` check with a command whose
   text contains "user-edit" in the same shell invocation) and the form is
   still fully interactive -- Tab, typing, and a SECOND create attempt in
   the same session all still work.
6. Attempt create with an empty/whitespace-only passphrase at the masked
   prompt: confirm this is now handled WITHOUT killing the zenka -- this is
   the specific case design anchor 3 above exists to close. If it still
   kills the zenka, the task is not done, regardless of how the rest looks.
7. Confirm nothing about ordinary field editing regressed: Tab navigation,
   an ordinary text field's own edit-and-submit round trip, and
   `address-cluster`'s own plugin-mode entry/exit all still work exactly
   as before this task (a quick pass, not a full re-run of every prior
   session's acceptance suite -- just confirm this task's changes to
   shared `editor.*`/`stdin_key` code didn't leak into unrelated paths).

Report actual captured output for each check, not "passed" -- this project
always re-verifies the diff and live behaviour independently of any self-
reported summary, and the previous round of this exact feature is the
concrete reason why.

## Footer reminders, same as every task file in this series

- `sprintf( qw| foo bar %s |, $x )` breaks on multi-word `qw()` in scalar
  context -- single-word `qw| ... |` is fine.
- No fake/placeholder AMOS7 signature blocks -- the human signs files.
- Module calls use `<[module.name]>->(...)` syntax with args, or the BARE
  `<[module.name]>` form (no `->()`) when calling with none -- this
  project just did a cleanup pass removing exactly this redundancy, don't
  reintroduce it in new code.
- When done, write a short note to `data/ai-mem/kimi/coding-style.md` or
  `data/ai-mem/kimi/MEMORY.md` on whatever the render-anchor-field
  mechanism actually ended up looking like, and on the
  `gen_keys`/`write_keys` base.exit findings from design anchor 3 --
  both are exactly the kind of non-obvious, load-bearing findings future
  work in this area (the deferred `masked`-field task) will need.

#,,.,,,,.,..,,.,,,.,.,,,.,.,,,,,.,...,,,.,,,.,..,,...,..,,,..,,..,,.,,,,.,,.,,
#LMCCUC4FYBPJXBY46XYOCZ74CR3SSJO7MXTVLTS6YQRQPJ64SI5GK4BWN5HCMSXDPDRXWG7TQRXMQ
#\\\|SHEELDW2UE5373OSCD6KI6LJKOKYQIYKSKN2KSAGZFLJTNPCX7A \ / AMOS7 \ YOURUM ::
#\[7]GPJHHJVPOKMUDGD4ENYYV4SXA2BLZGVXSQG32GWE2XX35BVEWOAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
