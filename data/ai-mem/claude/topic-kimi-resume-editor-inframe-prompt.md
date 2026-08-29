---
name: topic-kimi-resume-editor-inframe-prompt
description: "resume note for the editor-inframe-prompt-primitive.md dispatch -- kimi session e7943192 hit its account usage-limit mid-design with zero code written, ~2hr cooldown from termination (2026-08-16 ~00:40 local); read THIS file to resume cheaply instead of replaying the full session transcript"
metadata:
  type: project
---

**Purpose of this file**: a cheap catch-up point so resuming this dispatch
later does not require re-reading the full prior conversation (~430k
tokens) or the kimi session's own ~87K-char burned transcript. Read this,
then act -- do not re-derive the below from scratch.

## What to do when the cooldown clears

`SendMessage` or call `mcp__protocol-7__kimi_continue` with:
- `session_id`: `e7943192-1407-4c55-86b4-24d2c93f6c64`
- `model`: `k3-256k` **explicitly** -- even though `mcp-server-p7` now
  defaults kimi tools to `k3-256k` (commit `c79e87b87`), the ORIGINAL
  dispatch also explicitly requested `k3-256k` and still ran as full k3
  (unresolved bug, see below) -- being explicit again doesn't hurt and
  costs nothing.
- prompt, roughly: *"Continue from where you left off. You had already
  read the support modules (`user-edit.form.schema_from_record` and
  others) and reached a coherent design for `editor.control.prompt.*`
  before hitting your own usage limit -- zero code was written. Do not
  re-read everything again; proceed directly into implementation per your
  own 17-step plan from before the cutoff. Re-confirm your `gen_keys`/
  `write_keys` no-`base.exit` finding is still what you're relying on, then
  start writing code."*

**After it finishes**: do NOT trust its self-reported summary at face
value -- this project's own established norm, reinforced twice already
this session (once when the summary WAS accurate, once when a `100%`
step-limit run claimed "acceptance checks complete" while having done real
live testing, and once when THIS run burned its whole budget on reasoning
alone). Independently verify: `git status`/`git diff` in
`/data/projects/protocol-7`, and re-check the acceptance checks' actual
captured evidence, per `data/tasks/editor-inframe-prompt-primitive.md`'s
own "write these as END-STATE checks" section.

## What NOT to redo -- already covered, in the task file or below

- Full task spec: `data/tasks/editor-inframe-prompt-primitive.md`. Read
  THAT for the actual scope/design anchors, not this file.
- Kimi's own burned-session design conclusions (extracted from its
  transcript, not yet implemented): a single-field `editor.control.
  prompt.*` sub-state, reusing `process_key`/`get_display_value`
  wholesale rather than inventing new dispatch machinery; a render branch
  added to `render_form` for the active-prompt case; Left/Esc cancel
  semantics worked out.
- Confirmed (by kimi's own grep, independently spot-checked earlier in
  this session too): neither `crypt.C25519.gen_keys` nor
  `crypt.C25519.write_keys` calls `base.exit` -- design anchor 3's premise
  holds.
- **Both design questions kimi's own reasoning surfaced are now RESOLVED,
  not just flagged** -- `data/tasks/editor-inframe-prompt-primitive.md`
  gained two new sections since kimi's session started, read them, do not
  re-derive:
  1. **Design anchor 5**: Ctrl-C must cancel the PROMPT only, same as
     Esc/Left -- NOT fall through to ordinary Ctrl-C's form-wide
     `user-edit.form.quit` (confirmed live: that ends the whole process via
     `base.exit`). This was NOT "probably fine to swallow" -- letting it
     fall through would silently kill the session mid-passphrase-entry, a
     real foot-gun.
  2. **Design anchor 4**: the reentrancy concern was CONFIRMED real, not
     speculative -- `base.event.once` is literally `Event::loop($timeout)`,
     and `crypt.C25519.gen_keys`'s harmonic-truth retry loop calls it
     repeatedly, so a keypress during generation genuinely can dispatch the
     STDIN watcher reentrantly. **Already fixed once**, live, in the
     CURRENTLY SHIPPED code (commit to follow this note) via a `<user-edit.
     key_actions.busy>` guard in `user-edit.check_pending_excursions` +
     `plugin.user-edit.key-actions.handler.key` -- read both as the shape
     of the fix. The new in-frame design needs the EQUIVALENT protection
     around its own submit handling, not a copy of the same globals
     necessarily, but the same guarantee.

## Why this dispatch failed -- do not repeat the diagnosis

Full account: `project-coding-zenka-bug-catalog-2026-08-15.md`'s
"`kimi_dispatch`'s `model` parameter was not honoured" entry. Short
version: `mcp-server-p7`'s alias resolution and shell-command construction
for `--model kimi-code/k3-256k` were independently verified CORRECT
(config file confirms the model entry is real and properly scoped to a
256k ceiling); the session nonetheless reported a 1M-token context window
(`context: 14.7% (154k/1m)`), meaning full k3 actually ran. Root cause is
inside `kimi-legacy` itself, not diagnosed further. `c79e87b87` (committed,
not yet pushed) adds a `log_msg` warning for unrecognised model aliases and
switches the tool's own default to `k3-256k` -- neither directly explains
or fixes THIS specific mismatch, both are still worth having.

## Repo state as of this note

`base` is 1 commit ahead of `hub/base` (`c79e87b87` not yet pushed -- user
had not yet said whether to push it when this note was written). Everything
through `c79e87b87` is already committed and signed:
`551414c5e` (key-actions create tab + rescue fixes + path-keyword bugs),
`1367163cf` (this task file itself), `c79e87b87` (mcp-server-p7 model
default/warning). Nothing else is staged or in flight.

#,,..,,,.,.,,,...,...,...,,,,,...,...,.,,,,..,..,,...,..,,.,.,...,,.,,..,,,,,,
#ZFPK3HXKAHI2H46UDKHACM3BCJQ6E4VOZ6IWAO45Z53AN73EDNPJ5SEBFT7PNC5K75CBRECLHERCK
#\\\|B7V3X2IIHKW6QNNX5FCILFW3QP4MBSF4OVHTHOIFPFGXNUGNJ72 \ / AMOS7 \ YOURUM ::
#\[7]KZIY3CGJDI65VCP442IJIIPW3AUTVGFIMSDWOY6NWTIDZRMWPQCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
