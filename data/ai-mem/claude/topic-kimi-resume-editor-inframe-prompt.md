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
- **Two design questions kimi's own reasoning surfaced but did not
  resolve** -- worth the resumed session revisiting explicitly, not
  assuming its own tentative answers were right:
  1. Ctrl-C while a prompt is open would currently be silently swallowed
     -- it reasoned this as "consistent with pre-existing plugin-mode
     behaviour" but never implemented or tested it.
  2. Possible reentrancy: `crypt.C25519.gen_keys`'s internal
     `event.once(0.007)` polling loop might let the STDIN watcher fire
     reentrantly mid-submit -- reasoned as probably-safe, never verified.

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

#,,.,,,..,,..,,..,,,.,,..,,..,,,,,,.,,,.,,.,.,..,,...,...,...,...,.,,,,,.,...,

#,,,.,.,.,,,.,.,,,,,.,,.,,...,.,.,.,.,.,.,..,,..,,...,...,.,.,..,,...,.,.,,..,
#52K57G4RTTW6AQC5MKZD44IYL5JPAKF3I3TZAVV5PXDHA5OAQBXWYQJW224JJOBQMNCOGD5QWKGNC
#\\\|YTBI4TYKTGZEZ6VN6GAAQFENH3CONYZCFWGDBGG4AQHI5JVJZQN \ / AMOS7 \ YOURUM ::
#\[7]E6JZEP7U34YZI5OAVBHKMG4UHICOMS7VTVRKROSNZY7IGADM5MBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
