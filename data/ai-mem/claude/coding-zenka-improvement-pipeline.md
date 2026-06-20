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

[[resonance-field-emergence]]

#,,,.,,,.,,,,,..,,..,,..,,,..,,,.,.,,,.,.,,,.,..,,...,...,...,...,,,,,,.,,,,,,
#725OVXW7YZBYEAJJVYOZU7MSVWAJDOF7WH6GEPVCXP5YBO3YCGIP7REL5RFOAX5C2SMX23O4E3HLM
#\\\|J74AAX56XDXVXGJCWAXHBRZ2OBFYQNIWKYGSSLZPGA464ML2NJF \ / AMOS7 \ YOURUM ::
#\[7]6C3NCL22CEXPS5N3WG4DTFXFJ3EIUYL2TQESYJWPAGARD2UDQCBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
