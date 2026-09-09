---
module: jobqueue.move_job
generated_at: 2026-09-09T10:12:44
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 63f5b3f5a352e1789d33d007e1dc0314af6d0796
source_lines: 63
dep_graph_callers: 22
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1056
usage_completion_tokens: 619
---

# review: jobqueue.move_job

## Purpose
This module moves a job from one queue to another within the jobqueue system. It validates the job exists, checks that source and target queues differ, then reorders the job in both queue data structures and updates its status and timestamp.

## Interface
Takes two parameters: `$job_id` (integer) and `$target_queue` (string). Returns `warn` on invalid input, `warn` if the job doesn't exist, `warn` if the target queue doesn't exist, or `warn` if source equals target. Otherwise performs the move silently.

## Role & dependencies
Called by 22 modules (static literal calls). It depends on `jobqueue.joblist.by_id` (job lookup), `jobqueue.joblist` (queue state), `base.logs` (logging), `base.log` (logging), and `base.ntime` (timestamp generation). It mutates shared queue structures (`$job_list`) and the job registry (`$jobs`).

## Observations
- **Fragility**: The module mutates shared data structures (`$job_list`, `$jobs`) without returning a value, making it hard to verify success. The `return if $source_queue eq $target_queue` silently skips the move without logging.
- **Style**: Uses `<[base.logs]>` and `<[base.log]>` syntax (Protocol-7's call syntax). The `map { splice(...) }` idiom is unconventional and potentially fragile.
- **Warnings**: The `format.log_singular` warning at line 30 suggests a formatting issue in the log message. The validation reports a "missing signature footer" — the AMOS7 signature block is present at the bottom, so this may be a validator quirk.
- **Coupling**: Tightly coupled to the internal structure of `jobqueue.joblist` (e.g., `by_priority`, `by_timestamp` keys).

## Confidence
Unclear whether the "missing signature footer" warning is a false positive, since the AMOS7 signature block is visibly present. Also unclear if the `map { splice(...) }` pattern is intentional or a bug.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'jobqueue.move_job':

ERRORS:
  ✗ missing signature footer

WARNINGS:
  ⚠ format.log_singular : 1 occurrence [ first at line 30 ]
```

#,,,,,...,,,,,.,,,,,,,,,,,..,,.,.,,..,,,.,.,.,..,,...,...,...,,.,,...,.,.,..,,
#3AHQS44CGS5UNSHRTKC5L6MMFILPIFDTIUNEQ7PL6UH52GGO24ZTD55SA372DDCMNDMCJ7IAWOBTS
#\\\|Y2TBFPWSYDCP5357WSZREQAWQDMWCMMHE4ZAS7TN7E2P5O65MTQ \ / AMOS7 \ YOURUM ::
#\[7]BXQ7ZYGTYVDWCGPVQLE46EKAJE4KARCGYTVWKH4HRDWYGZR63EAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
