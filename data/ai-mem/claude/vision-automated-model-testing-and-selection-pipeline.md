---
name: vision-automated-model-testing-and-selection-pipeline
description: "the roadmap the user described 2026-09-17 (resilient downloads -> discovery/categorization/scoring -> success stats -> automated selection) is NOT a fresh idea -- it's data/md/design/AUTONOMOUS-MODEL-MANAGEMENT.md, already fully designed 2026-09-04 with two split-off docs; this file just adds the concrete motivating gap and one real correction to how today's work maps onto it"
metadata:
  type: project
---

**Read `data/md/design/AUTONOMOUS-MODEL-MANAGEMENT.md` first** (410
lines, 2026-09-04) — four-layer architecture (discovery -> benchmarking
-> consensus -> management), with an "implementation sequence" checklist
(all unchecked as of 2026-09-04) and a "relation to existing work" table
mapping every layer to real, already-shipped code. Two foundational
pieces have already been split into their own docs:
[`MODEL-BENCHMARK-HARNESS.md`](../../md/design/MODEL-BENCHMARK-HARNESS.md)
(multi-parameter scoring: correctness + ttft + tokens/sec + memory via
`base.curve.*`) and
[`MODEL-STATUS-TRACKING.md`](../../md/design/MODEL-STATUS-TRACKING.md)
(coarse `untested`/`functional`/`inference-failures`/`startup-failure`
state + async sweep iterator -- smaller, prerequisite-free, buildable
before the full harness). This is not a "someday" seed -- it's a real,
detailed, already-decomposed design waiting on implementation, and
should be the starting point for any future work in this area, not a
from-scratch scoping exercise.

**The concrete gap that makes this urgent, cited by the user 2026-09-17**:
a LoRA was trained for the *currently selected default* coding model
(`coding-lora-p7-idioms.md`'s thread), but that default itself was never
validated with real work, while many other models already in the
project's registry sit in exactly the `untested` state
`MODEL-STATUS-TRACKING.md` already names. This is real, current evidence
for why layer 1 (status tracking specifically, the smaller prerequisite-
free piece) is worth prioritizing -- not a new requirement, just fresh
confirmation of the existing doc's own stated rationale.

**Second correction, more precise than the first (2026-09-17, same
exchange)**: `invoke-model-recover` isn't just an older sibling
mid-migration toward `fetch.file.huggingface.*` -- it was written in
response to a real, specific incident (a ~500GB InvokeAI model-store
wipe), and it manages InvokeAI's own model directory
(`/mnt/ext-xfs-data/models-invoke`, confirmed in
`MODELS-PATH-ADAPTERS.md`). **The coding zenka does not use any of
those InvokeAI-managed models at all** -- it only uses models from
`/mnt/ext-xfs-data/models-lmstudio` (the directory `fetch.file.
huggingface.*` and the 2026-09-10 corrupted-shard incident both live
in), a directory `invoke-model-recover` cannot use or address (it's a
different host convention -- uuid-based InvokeAI dirs vs. flat GGUF
files). This isn't "two implementations converging via migration," it's
two adapters for two genuinely separate, permanently coexisting model
populations -- exactly the split `MODELS-PATH-ADAPTERS.md` (2026-08-26)
already designed around (`models.storage.adapter.invoke.*` vs.
`models.storage.adapter.lmstudio.*`), so
[[feedback-parallel-redundancy-during-migration-is-deliberate]]'s
"eventual convergence onto whichever proves better" framing does NOT
apply to these two specifically -- neither one replaces the other, both
persist by design.

**The genuinely open question this leaves, worth flagging when the
lmstudio adapter is actually built**: `MODELS-PATH-ADAPTERS.md`'s own
plan for `models.storage.adapter.lmstudio.install` was to "reuse
invoke-model-recover download_file (with a :raw fix)" as a *shared*
download primitive across both adapters -- written 2026-08-26, before
`fetch.file.huggingface.*` existed in its current hardened form
(checksum verification landed 2026-09-17, native async transport
in progress). That original plan has not been revisited since
`fetch.file.huggingface.*` became the more resilient implementation.
Whoever builds `models.storage.adapter.lmstudio.install` should
explicitly decide whether to follow the original doc (reuse
`invoke-model-recover`'s `download_file`) or point it at the now more
hardened `fetch.file.huggingface.*` path instead -- don't assume either
without checking which one is still true when that work starts.

**Retirement plans for both external hosts, stated by the user
2026-09-17 (later in the same exchange)**:

- **LM Studio**: retirable once P7's own downloader+discovery surpasses
  "lm-studio through proxychains" -- at that point the storage structure
  converts to whatever P7 can use more natively, keeping the `lmstudio`
  adapter code around only to still understand the format, not to keep
  running LM Studio itself. The main reason to keep it (GPU offloading)
  is already gone now that P7 has partial GPU offloading support
  ([[topic-coding-cpu-spawn-day-2026-08-26]] landed GPU/CPU parallel
  inference serving). The one LM-Studio-only feature left: running
  multiple models on-demand in parallel as memory allows -- user says
  "not far from there either" since GPU and CPU servers already run in
  parallel smoothly.
- **InvokeAI**: harder, needs an actual replacement zenka (this is what
  [[topic-invoke-model-manager]] and `data/tasks/torch-worker-zenka-
  foundation.md` are for). The enabling finding, already verified live
  2026-09-10/11 (read the task file in full, don't re-derive): `Inline::
  Python` + torch/CUDA works from a forked P7 child, with one hard
  constraint -- exact CPython version match. `libinline-python-perl`
  links against **libpython3.14** fixed, no override; a matching venv
  (`python3.14 -m venv` + `pip install torch`, pulls a real CUDA build,
  `2.14.0+cu130` confirmed) is required, and fork-after-embed-before-
  CUDA discipline is proven safe (parent never touches CUDA before the
  fork that spawns each worker). Torch builds exist for 3.14, so this
  constraint is satisfiable, not a blocker -- just a hard pin to respect
  when building the actual worker.

**CORRECTION, 2026-09-17, later same day**: `MODEL-STATUS-TRACKING.md`
is NOT an open next step -- it was fully built the same day it was
designed (`2ef45a999` + `8c765db92`, both 2026-08-27), just never marked
done in the doc itself, which is why it read as still-open three weeks
later. Confirmed live: `p7c coding.model-status` / `coding.model-sweep-
status` are real, working, already-populated commands. **The actual gap
is usage, not code**: only 6 of ~90 registry entries have ever been
tested, the cpu sweep stalled at `idx=0/28`, gpu sweep never started.
Before recommending ANY future doc in this area as "still open," check
live command availability first (`p7c coding.commands`, grep `src/` for
the module names the doc's own "existing foundation"/"write sites"
sections name) -- don't trust a design doc's own apparent completeness
state without that check, even one that looks detailed and unfinished.
`MODEL-BENCHMARK-HARNESS.md` (multi-parameter scoring) WAS checked the
same way and is confirmed still genuinely unbuilt (`grep -rl "models.
benchmark" src/` — zero hits) -- that's the real next design-doc target
if a coding dispatch is wanted, though it needs real design decisions
settled first (canonical workload yaml schema, `base.curve.*` weighting)
rather than being narrow-dispatch-ready as-is.

**How to apply**: when picking up model-management work, start from
`AUTONOMOUS-MODEL-MANAGEMENT.md`'s six-topic decomposition (section
"subsystem decomposition", in dependency order) and `MODELS-PATH-
ADAPTERS.md`'s adapter split -- but verify each topic's real
implementation state live before treating the doc's own checklist as
current, per the correction above.

#,,..,,.,,.,.,..,,..,,..,,..,,.,.,.,,,,,,,.,.,..,,...,...,.,,,,,,,...,,.,,,,,,
#ZXKXSCT2DTLYGE6ITD2RGJBZ5K4FY5PASKAQMYDSBS7QMSUK4BNQXGEE43FYHP3LZ37P3S5ETQ6VU
#\\\|KSXSPAZLVPQJUGPDIEMLNE7V4PBI7XNCWBOGWWKJBRQK7WH32FB \ / AMOS7 \ YOURUM ::
#\[7]KSRPK5OM6VMVASRGJDNZIVAWM6OVUL3ZSNIGIG6YTRIFORMZPCBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
