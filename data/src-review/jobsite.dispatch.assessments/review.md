---
module: jobsite.dispatch.assessments
generated_at: 2026-09-09T23:14:26
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 1d3784f054a5f3490737dd0db41145cad120c5af
source_lines: 229
dep_graph_callers: 7
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 3115
usage_completion_tokens: 668
---

# review: jobsite.dispatch.assessments

## Purpose
This module collects new untracked jobs from the per-file store, filters them through checksum and description quality gates, and queues them for LLM-based assessment. It manages the assessment cycle state and dispatches tasks sequentially.

## Interface
No explicit arguments or return value. It mutates global state (`<jobsite.cycle>`, `<jobsite.assess_queue>`, `<jobsite.tasks>`) and writes jobs via `<jobsite.job.write>`.

## Role & dependencies
Called by 7 other modules (dep-graph). Key callees: `<jobsite.cycle>`, `<jobsite.job.load_all>`, `<jobsite.checksum.index>`, `<jobsite.util.description_ok>`, `<jobsite.assert.init>`, `<jobsite.util.build_prompt>`, `<jobsite.dispatch.next>`, `<jobsite.state.persist>`, `<base.logs>`, `<base.vax-int.encode>`, `<system.path.zenka-dirs>`.

## Observations
- **Re-entrant safety**: The `$was_idle` guard prevents double-dispatch when a previous batch is mid-flight.
- **Orphaned file bug**: Blocked jobs are removed via `unlink` on the new path, but the comment flags a race condition where the index may point to an old location, causing the file to be orphaned and re-detected forever.
- **Description quality gate**: A two-attempt refetch mechanism prevents infinite retries on broken sources. The `desc_check_failed` flag surfaces issues without polluting the primary view.
- **Persistent store patch**: The code manually patches `<jobs.store>` because `job-upsert`'s whitelist reads a stale global reference, not the fresh `$store` from disk.
- **Style**: Heavy use of `<[...]>` macro-style calls; line length is tight but within the 78-char limit.

## Confidence
Unclear whether `<jobsite.cycle>` is a global variable or a module function — the syntax `<jobsite.cycle>` suggests a variable, but the dep-graph shows it as a callee, which is contradictory. Also unclear if `<jobsite.state.persist>` returns a value or is a side-effect-only call.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'jobsite.dispatch.assessments'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,,,,.,,,,..,,..,,.,,.,,,...,,.,,..,,,,,,..,,..,,...,...,,..,...,,,.,,..,.,.,
#PBXK6P246X6T4XEIOXD7XFZBYGAQIFYY2TZJLWPGUWK3Q2F7JQOTAUSWQZF57RJFEHDVODBELEUMG
#\\\|M23B5ML4CBJRFJGVDFYEV7DKV4GGRI2WDLNKQHUCZ46IG6IMQAI \ / AMOS7 \ YOURUM ::
#\[7]GPQUPMZWEUJUFHWHOCLZF4N2P5WSL2YRI6RPUDU75OPE3V2OGSDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
