# user-edit console zenka — draft storage primitives

**Read first, both required:**
- `data/ai-mem/kimi/coding-style.md` and `data/ai-mem/kimi/MEMORY.md` — P7 module
  conventions. Pay attention to the "swapped module families" section —
  `base.file.*` calls at runtime as `file.*` (no `base.` prefix), `base.path.*`
  does NOT swap (keep the prefix).
- `data/yaml/coding-tasks/user-edit-console-zenka.yaml` — read `draft_auto_save`
  specifically (search for that key). The rest of the doc (rendering, the actual
  form/submit flow, users-zenka integration) is NOT in scope here.

Three prior phases already exist and are committed — read the most recent one
closely, it's your primary precedent:
- `configuration/zenki/user-edit/`, `modules/user-edit.init_code` (skeleton,
  registers `VAR_P7`/`ETC_P7`/`HOME_N` path keywords — do not touch this file)
- `modules/user-edit.outbox.write`, `.list`, `.clear` — the outbox module set.
  **This task builds the same shape for drafts, under a different directory.**
  Read all three outbox files closely and mirror their structure, conventions,
  and id-validation exactly — you are not designing something new, you are
  applying an already-approved pattern to a second use case.

## Goal

Build draft storage primitives — `user-edit.draft.write`, `.load`, `.clear` —
under `[VAR_P7]/draft/` (a sibling directory to `[VAR_P7]/outbox/`, same
keyword, different subpath). This is infrastructure only, same as the outbox
task was: there is no live editor UI yet to call these. Do NOT wire up the
end_code shutdown callback, the periodic backstop timer, or the
field_next/field_prev trigger — none of them have a real caller yet (no
editor_state exists in this codebase — that's phase 2/3, not built). Building
those now would be dead code with nothing to test it against. This task is
strictly: given an id and a data structure, write/load/clear a draft file.

## Key difference from the outbox task: the empty-state guard

Per `draft_auto_save` in the design doc, mirroring `mpv.snapshot.write`'s
precedent (`modules/mpv.snapshot.write` if it still exists under that name —
search for it, read it): a draft write must NOT overwrite an existing good
draft with blank/empty data. The outbox module you're mirroring did NOT need
this (a submit always carries real values by definition) — a draft write might
be called with a still-mostly-empty form. `user-edit.draft.write` needs an
extra check the outbox write doesn't have:

- if the data structure passed in is not a hashref, or is a hashref with no
  keys, or every value in it is undef/empty-string, DO NOT write — return a
  distinct result indicating "skipped, nothing to save" (not the same return
  shape as a real write failure, and not silently identical to success either
  — pick a clear third state and say what it is in your summary, e.g.
  `(SKIPPED, 'no data to save')` alongside the write module's existing
  `(TRUE/FALSE, $msg)` wantarray convention — use your judgment on the exact
  spelling, just make it distinguishable from both TRUE and FALSE for a caller
  that cares)
- if `mpv.snapshot.write` exists and has this exact guard already, mirror its
  approach precisely rather than inventing your own — if it doesn't exist
  (may have been renamed/refactored since the design doc was written), fall
  back to the guard behavior described above and note that in your summary.

## What to build

1. `modules/user-edit.draft.write` — params: an entry identifier and a data
   structure (hashref). Same path-resolution/mkdir/write shape as
   `user-edit.outbox.write`, but resolving `[VAR_P7]/draft/<id>.yaml`, and with
   the empty-state guard described above added before the write.
2. `modules/user-edit.draft.load` — params: an entry identifier. Resolves
   `[VAR_P7]/draft/<id>.yaml` and loads it via `format.yaml.load_file` (mirror
   `format.yaml.load_keyword_path`'s resolve-then-load shape, same as the
   outbox precedent's write-side equivalent). Returns undef if no draft exists
   for that id (not an error — a fresh session has no draft, that's normal).
3. `modules/user-edit.draft.clear` — identical shape to
   `user-edit.outbox.clear`, just pointed at `[VAR_P7]/draft/<id>.yaml`
   instead.

Same id validation as the outbox modules (no `/`, no `..`) — copy that logic
exactly, don't rewrite it differently.

## Explicitly out of scope — do not implement

- end_code callback registration (`push <callbacks.end_code>->@*, ...`) —
  no live draft-holding caller exists yet to flush on exit
- the periodic backstop timer (`user-edit.draft_save_interval_seconds`)
- the field_next/field_prev trigger wiring — that requires an actual
  editor_state from editor.control.*, which nothing in this zenka creates yet
- `restore_on_startup` UX (prompt vs auto-load) — no startup flow exists to
  hook this into
- any `phase_2_rendering`, `phase_3_form`, or `users.*` integration
- do not touch `modules/user-edit.init_code`, `modules/user-edit.outbox.*`,
  or `configuration/zenki/user-edit/start`

## Verification

- `bin/dev/ptd -c` each of the three new module files, confirm syntax ok
- state in your summary the exact resolved path shape for an example id
  (e.g. `"test-user-42"` → `/var/protocol-7/user-edit/draft/test-user-42.yaml`)
- state clearly what `draft.write` returns for: a real non-empty write, an
  empty/skip case, and a real failure — three distinguishable outcomes
- no live filesystem/zenka execution — static correctness + syntax check only

## P7 pitfalls (from prior kimi sessions, avoid these)

- swapped module families: `base.file.*` → `file.*` at runtime (no `base.`
  prefix); `base.path.*` does NOT swap, keep the full prefix
- use `base.logs` (list form), not `base.log` (singular) unless confirmed
  otherwise by precedent
- never redeclare `my $call`
- `TRUE` = 5, `FALSE` = 0 in this codebase — if you introduce a third
  "skipped" state, it must not collide with either of those values
- no fake/placeholder AMOS7 signature blocks — the human signs files
- `sprintf( qw| foo bar %s |, $x )` breaks on multi-word `qw()` in scalar
  context — single-word `qw| ... |` (no internal whitespace) is fine and is
  what the outbox modules already use, copy that pattern exactly
- module calls use `<[module.name]>->(...)` syntax (or bare `<[module.name]>`
  when no args)

When done, write a short note to `data/ai-mem/kimi/coding-style.md` or
`data/ai-mem/kimi/MEMORY.md` if you hit anything non-obvious (e.g. what you
chose for the "skipped" return value and why, or if `mpv.snapshot.write`
turned out not to exist under that name).

#,,,,,,..,,..,,.,,.,,,,,.,,,.,...,,,,,.,,,,,,,..,,...,...,...,,.,,..,,,,,,,,,,
#3JBQ4LFUCLJ2NJ5EJVZGA7BWAFQLZGZL6GBHV375XVLWE4BXOCEJ27PPMKFS4PBLEW7WH3MDO3ST6
#\\\|U4QMFZMTYE5GHVSMOK6M3A7ICGRPK5GSCJHOMAM4HM3DZCQ7EGR \ / AMOS7 \ YOURUM ::
#\[7]34IM2XI64EENUF276KVMU6Q4PJBU5ENYID2HZFTZPJK2EWMMR6BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
