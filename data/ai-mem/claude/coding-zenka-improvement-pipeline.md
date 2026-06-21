---
name: coding-zenka-improvement-pipeline
description: root index for the coding zenka self-test/self-error/change-accounting pipeline; check here first for tier status before resuming this work
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0167cea8-7299-4bd1-b3b4-a507800e7687
---

File: `data/md/design/CODING-ZENKA-IMPROVEMENT-PIPELINE-INDEX.md`

Root index written 2026-06-20, applying the catch-all/bounded-nesting
completeness principle from `CODING-CHANGE-ACCOUNTING-ARCHITECTURE.md`
to the design-doc set itself, so this cluster of docs doesn't become
the kind of orphaned/forgotten reference the mechanism exists to
prevent.

Tier status as of last update (re-check the index file itself, this is
a point-in-time snapshot):
- tier 0 (LANDED): X-11 `WM.update` before/after `ConfigureWindow` fix
  (set_geometry, move-window, screen_change) — confirmed live by user
- tier 1 (DONE, live-validated 2026-06-21): `coding.self_test.*` +
  `coding.tools.http_inference_client` — three real passes total; first
  two dispatches fixed syntax/structural bugs, but two more bugs only
  surfaced under an actual live run (monitor_inference_startup calling
  self_test.run before the model_id field was set; max_tokens=128
  starving a reasoning model's answer). both fixed, confirmed live
  "2/2 passed" with clean logging added. also confirmed: the
  extract-inline-subs coding-task template works correctly end-to-end.
- tier 2 (NOT READY): `coding-self-error-processing-cycle.md` — 3 open
  decisions block dispatch (error-surfacing hook point, confidence
  threshold mechanism, assertion-criteria rubric format)
- tier 3 (GATED): `CODING-CHANGE-ACCOUNTING-ARCHITECTURE.md` — awaiting
  tier 2 stability milestone (a confirmed-pattern library entry actually
  promoted upstream)

Lateral docs in the same cluster: `TASK-CUBE-CONSENSUS-ARCHITECTURE.md`
(BFT consensus + rotation scheduling, extended by tier 3's priority
queue), `NETWORK-RESOURCE-TOKEN-ARCHITECTURE.md` + `NRT.NRD.asc`
(epoch-scoped archival shape origin), `demystification-through-
correspondence.yaml` (the discipline this whole cluster's design work
was produced under).

**How to apply**: before resuming any of this pipeline work in a future
session, read the index file first — it has the authoritative tier
status. This memory note is a pointer, not the source of truth.

**Tier 1.5 added and DONE (2026-06-21)**: task-level model pinning
(`:model:CHECKSUM:` marker) — see `data/tasks/coding-task-model-pinning.md`.
Was genuinely half-built (parsed, never enforced), plus the upstream
intake parser was silently destroying the marker before it ever
reached working code. Also found+fixed a deep pre-existing bug:
`coding.handler.await_resources` (a `:twin:`-handover watchdog) never
retired itself and got re-armed on every `coding.reload`, silently
substituting the boot-default model during any switch while showing a
correct-looking label — this is why earlier passes at pinning LOOKED
done while actually running the wrong model. Verified via direct
`/proc/<pid>/cmdline` inspection, not by trusting labels/self-test
alone — that discipline is what actually caught it.

**NOT YET IMPLEMENTED, designed and captured (2026-06-21, end of
session, context-limit handover)**: generic `result_constraint` +
tiered escalation for tasks whose answer doesn't match a required
format (word-count/numeric/sprintf) but may be substantively correct
(e.g. DVEAZIA answering "## Solution... 91" instead of "91"). Two-tier:
cheap same-context reformat request first, full semantic judgment only
if that fails — and the semantic judgment, when a model switch
happened, runs AFTER switch-back, making it cross-model assertion for
free. Full design captured in `coding-model-self-test-cycle.md`'s
"generic result-constraint + tiered escalation" section — read that
first before implementing, it's intent-level, not yet a precise spec.

**Gotcha confirmed live 2026-06-21**: the `model` field in
`coding.tools.http_inference_client`'s request body does NOT switch
models — `llama-server` serves exactly one model, fixed at process-
spawn time (`--model <path>`, see `coding.spawn_inference_server`).
Model selection is by which port you connect to (8000=gpu, 8001=cpu),
not by anything in the request body. `model_id` flowing through
`self_test.*` is a label for logging/archival only. Relevant if the
model-fallback-chain feature in `coding-model-self-test-cycle.md` ever
gets built — "switching" there means spawning a different server
process on that port, not changing a request parameter.

[[resonance-field-emergence]]

#,,..,..,,,.,,,.,,.,.,.,.,.,,,...,,,,,,,,,.,.,..,,...,..,,,..,,,,,,.,,.,.,...,
#QTQESMM5RVUZF5FTVMMQPLLQT42RFHF7232ZV35PC74LLS4DZRGZJB57F6XUGLSQ63M6BODLOLS26
#\\\|OP5I7MFUWRLJ6YCVPO75KZHQS52KP3KL7ADJ2T7X2XDOWDIIV6S \ / AMOS7 \ YOURUM ::
#\[7]WKT4VTRKYB2L54DTTALLDTLRRLME46YBUL6ZIQI2DMBBJGY66WBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
