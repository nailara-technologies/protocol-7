---
name: topic-editor-namespace-migration-status
description: editor.* namespace migration -- design doc reviewed twice, step_0/step_1/step_2 all landed and live-verified; nshell's live editing path now runs on editor.control.*
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
  `modules/editor.buffer.memory.*` (8 files) and `modules/editor.control.*`
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
  or raw editor-hash touches anywhere in `modules/nshell.*`, step_1's
  parity test still 334/334, and live nshell exercise after restart.

**Status: all three steps landed and live-verified.** `step_3` (multiline
field type) and `step_4` (multi-field schema) remain, only when a real
consumer needs them (chat-style input / a settings form) — see the design
doc's `migration_path` for the full sequencing and its explicit "don't
build speculatively" guardrails. Nothing currently blocks either; neither
has a concrete consumer yet.

Also separately tracked: `data/tasks/spdx-license-string-cleanup.md`
([[reference-spdx-marker-flags-suspect-session]]) flags that
`pager.editor.integration`/`base.editor.*` (an existing dead-stub
integration point this design's `editor.buffer.virtual` type is meant to
eventually un-stub) are among the files from a prior low-quality session —
treat their existing code as unverified scaffolding, not a design
reference, until that cleanup task reviews them.

#,,.,,..,,.,,,,.,,...,...,.,.,.,.,,,.,,,.,.,.,..,,...,...,...,,.,,.,.,...,,,,,
#6RJFSOPW3DBJHNUEINUF7AEJXDXNUTLYQJLLUCSVQYBKBJXRGJQEFD3WBETWUEFQJMQKYWR7ORFYC
#\\\|CYDUGLKPN2GXC3BK2VBUX6YQR7JHKJEJLX4JAOYXNK232SMBM2U \ / AMOS7 \ YOURUM ::
#\[7]OG3NQITHLOEWEFS5DF5ID7PNHSLEA46FWYHW464IHA775XW6FMDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
