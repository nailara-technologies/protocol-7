---
name: topic-editor-namespace-migration-status
description: editor.* namespace migration -- design doc reviewed twice, step_0 and step_1 landed, step_2 (wire nshell to the new modules) is next
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

**Next**: `step_2` — switch `nshell.editor.process` to call
`editor.control.process_key` directly (drop the `AMOS7::TERM` indirection),
still single-field. This is the first step that touches nshell's live
input path again, so it needs the same live-behavior verification rigor as
step_0, not just a parity test. `step_3` (multiline field type) and
`step_4` (multi-field schema) come after, only when a real consumer needs
them — see the design doc's `migration_path` for the full sequencing and
its explicit "don't build speculatively" guardrails.

Also separately tracked: `data/tasks/spdx-license-string-cleanup.md`
([[reference-spdx-marker-flags-suspect-session]]) flags that
`pager.editor.integration`/`base.editor.*` (an existing dead-stub
integration point this design's `editor.buffer.virtual` type is meant to
eventually un-stub) are among the files from a prior low-quality session —
treat their existing code as unverified scaffolding, not a design
reference, until that cleanup task reviews them.

#,,.,,,,,,,.,,.,.,,.,,.,,,,..,,,,,.,,,,..,,.,,..,,...,..,,.,.,,,,,,..,.,.,...,
#4BZTYNR6UFZFXSO6INIYNBPY2AZZE5YIBPOAFA5MEVR7PP7GGMK7MBOGGAQJXTXQJL4XXUUY2P2GK
#\\\|IDS3EOSQNBXQNDSQ3QCB4VRX5UXAXXN5GHVEWVJRMJLZ4TAWXZH \ / AMOS7 \ YOURUM ::
#\[7]YSOYXOGFRUXY6PSPHWNPW3RR72Z26G4Q4SQZZXT4QC7AOZTB26CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
