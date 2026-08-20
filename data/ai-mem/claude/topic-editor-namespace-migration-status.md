---
name: topic-editor-namespace-migration-status
description: editor.* namespace migration -- design doc reviewed twice, step_0/step_1/step_2 landed and live-verified; step_4 (multi-field) also found already landed 2026-08-10, only step_3 (multiline) remains unbuilt
metadata:
  type: project
---

Building a generic `editor.*` module namespace to unify nshell's line
input, a future settings/`user-edit` form, and multiline chat-style input
(coding zenka / `bin/chat`) behind one field-based schema. Full design:
`data/yaml/coding-tasks/editor-namespace-interface-design.yaml` (revision
2 — reviewed once by an Opus pass, once by direct code-archaeology against
`AMOS7::TERM.pm`/`nshell.*`/`pager.editor.integration`/`base.editor.*`
stubs; both passes found and fixed real errors in revision 1, including a
field-name-vs-index type bug and a wrong model of amos-term's 3D Z-axis
as a field dimension when it's actually output scrollback). Companion:
`data/yaml/coding-tasks/generic-editor-namespace-and-hybrid-zenka.yaml`
(original, broader vision doc this narrows down).

**Landed** (both dispatched to Kimi on `kimi-code/k3-256k`, session
`5319f5b5-299b-4b9e-8e6d-70d5db45a2cd`, both independently verified against
the actual diff/test output, not just the auto-summary):
- `step_0` (commit `290a8f72f`): ported `nshell.*`'s direct
  `$editor->{buffer}`/`{cursor_pos}` hash touches to new
  `AMOS7::TERM::editor_get_cursor`/`editor_set_cursor` accessors. Zero
  behavior change, verified byte-identical before/after transcript replay.
  Also deleted two lines in `nshell.editor.process` that were redundant
  (already covered by `editor_submit`'s internal `editor_reset` call).
- `step_1` (commit `e039f1912`): built new, isolated
  `src/editor.buffer.memory.*` (8 files) and `src/editor.control.*`
  (11 files) — a single-field (`freeform_line`) implementation ported from
  `AMOS7::TERM::editor_process_key`'s byte-offset key-dispatch logic to
  character offsets, with a semantics-only `process_key` return contract
  (no baked ANSI/`%colors`, matches the design's `control_ui_boundary`
  decision). Does NOT touch `nshell.*` or `AMOS7::TERM.pm` at all — proven
  correct by a parity test (`bin/test-scripts/test-editor-control-parity.pl`,
  334/334 checks) against the existing `AMOS7::TERM` behavior instead of
  live nshell verification, since nothing calls the new modules yet.
- `step_2` (commit `47a2bf87e`): switched `nshell.editor.process` and its
  supporting modules (render.viewport/cursor, ctrl_o handlers, history
  navigation, search.handler, read_from_buffer — 13 files total) to call
  `editor.control.*` directly, dropping the `AMOS7::TERM` indirection.
  Object shape changed entirely (flat `{buffer,cursor_pos,...}` hash →
  schema-based `{fields=>{command=>...}}`), so every remaining direct
  hash-key touch had to be found, not just the old `AMOS7::TERM::editor_*`
  call sites — including two lines in `nshell.read_from_buffer` step_0 had
  correctly left alone (shape hadn't changed yet at that point), now
  converted to `editor.control.reset`'s per-field mode specifically (not
  `load_field`, which has different `kill_buffer`-clearing semantics).
  Character-offset editor state crosses back to nshell's byte-oriented
  terminal/history/execution paths via explicit `utf8::encode()` at each
  boundary — necessary because `nshell.init_code` deliberately reverts
  STDOUT/STDIN/STDERR to raw bytes (`binmode($ARG)` with no layer),
  overriding `bin/Protocol-7`'s earlier `:encoding(UTF-8)` setup, verified
  by reading both files directly rather than assuming. Required an
  additional deployment fix beyond the code itself — see
  [[reference-new-module-namespace-existing-zenka]] — caught live by a
  real Up-arrow runtime error after first restart, fixed and confirmed
  working. Verified independently: zero remaining `AMOS7::TERM::editor_*`
  or raw editor-hash touches anywhere in `src/nshell.*`, step_1's
  parity test still 334/334, and live nshell exercise after restart.

**Status: step_0/1/2 landed and live-verified, and step_4 also found
already landed** (checked 2026-08-10, while scoping the new `user-edit`
console zenka — see [[topic-user-edit-console-zenka-status]]):
`editor.control.create()` already accepts multi-field schemas (no length
restriction), `active_field` is tracked and authoritative,
`process_key` already returns `field_next`/`field_prev` on Tab/Shift-Tab
correctly gated on `scalar(@{$schema->{fields}}) > 1`, and
`editor.control.active_buffer`/`load_field`/`get_value`/`get_cursor`/
`reset`/`submit` all exist and are multi-field-aware (`submit` iterates
every field, not just one). This was NOT expected — this memory
previously said step_4 "remains, only when a real consumer needs
[it]... neither has a concrete consumer yet" — but the code was already
there by the time `user-edit` went looking for it, landed by someone
between this memory's last update and 2026-08-10, without a
corresponding memory update. Lesson: don't trust this memory's "not
built yet" claims about `editor.*` without re-checking the live code —
confirmed stale once already.

Only `step_3` (multiline field type) remains genuinely unbuilt, still
gated on a real multiline consumer (chat-style input to coding zenka) —
see the design doc's `migration_path` for sequencing. `user-edit` is
now the real multi-field consumer step_4 was waiting on; it does not
need step_3 (its fields are single-line per the current design).

Also separately tracked: `data/tasks/spdx-license-string-cleanup.md`
([[reference-spdx-marker-flags-suspect-session]]) flags that
`pager.editor.integration`/`base.editor.*` (an existing dead-stub
integration point this design's `editor.buffer.virtual` type is meant to
eventually un-stub) are among the files from a prior low-quality session —
treat their existing code as unverified scaffolding, not a design
reference, until that cleanup task reviews them.

#,,..,...,,.,,,,.,,,.,,..,,.,,,.,,,,.,..,,...,..,,...,...,...,..,,,,,,.,.,,,,,
#UVFZZRVC4OHUD43ERMHFPI3D2P4ZWE6ZHOPLMTNMF7TLMH6P26FXAHXFEMCE62L2267BQFZIM6BM4
#\\\|UQH5M3TUS7D3EIOBTMZEB3QPDCRXCXL6IS26WTLW4N3ZZHVO2YT \ / AMOS7 \ YOURUM ::
#\[7]J5A6FAYRKQUHQPC3WN4LWYGB35I2KXN26FUBURNJ4GLIYBOLEOBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
