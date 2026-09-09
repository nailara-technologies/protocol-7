---
module: jobsite.job.write
generated_at: 2026-09-09T10:20:53
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: a14a42206fef369cde4811cad37b1395a04e5575
source_lines: 233
dep_graph_callers: 16
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 3005
usage_completion_tokens: 620
---

# review: jobsite.job.write

## Purpose
This module writes a single job record to the status-directory storage system, atomically transitioning a job between statuses (blocked, deleted, trash, or default) while maintaining an in-memory and on-disk index.

## Interface
Takes two parameters: `$job_id` (string) and `$job` (hashref). Returns `FALSE` on failure (encoding error, write failure, orphan cleanup failure) or `TRUE` on success.

## Role & dependencies
Serves as the write-side counterpart to `jobsite.job.load`. It orchestrates:
- Path resolution based on job status
- Directory creation via `<file.make_path>`
- Orphan file detection via glob scans
- Tombstone logging via `<jobsite.removed_log.append/prune>`
- Atomic index updates via temp-file + rename

Notable callees: `<system.path.zenka-dirs>`, `<base.vax-int.encode>`, `<base.ntime.epoch_timestamp>`, `<base32.encode>`, `YAML::XS::Dump/DumpFile`, `IO::Compress::Xz::xz`.

## Observations
- **Fragility**: The orphan scan relies on glob patterns that assume a single-level directory structure for plain statuses but two-level for epoch-bucketed ones. Rapid multi-step status transitions could leave stale files undetected.
- **Coupling**: Heavily depends on `<jobsite.job.index>` as both reader and writer, creating a circular dependency risk.
- **Style**: The signature footer is missing (validation FAILED), and `<truefalse.bool_assign>` is used at line 33, which the validator flags as a warning.
- **Style**: The signature footer is missing (validation FAILED), and `<truefalse.bool_assign>` is used at line 33, which the validator flags as a warning.
- **Potential issue**: The tombstone logic assumes `jobsite.sync.push` will handle forwarding; if that module is unavailable or misconfigured, tombstones may not propagate correctly.

## Confidence
Unclear whether `<jobsite.removed_log.prune>` is idempotent or if multiple rapid status transitions could cause duplicate tombstone entries. Also unclear if the glob-based orphan scan is performant at scale.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'jobsite.job.write':

ERRORS:
  ✗ missing signature footer

WARNINGS:
  ⚠ truefalse.bool_assign : 1 occurrence [ first at line 33 ]
  ⚠ module not found in subroutine whitelist
```

#,,,,,...,,,,,...,.,.,..,,.,.,,,.,.,,,...,.,,,..,,...,...,.,,,,,,,,,.,,.,,.,,,
#BFPGFH2IWZQ6SV5EDB2E7V5IK4NRAR5Z6MAUMQK3D2Q4H3DAPIC3YKUSQI6EYVMZWYOTNZLP6RNL2
#\\\|353S35FB5IXBNSBKSDGLNMYQMW4B4WYFJVFPMHFU3S23AU5X5XZ \ / AMOS7 \ YOURUM ::
#\[7]OOSDDDQ3MWQLFDZ7LGIEU6UJGUSXWYQUWXB47ACMG5VISRLNTKBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
