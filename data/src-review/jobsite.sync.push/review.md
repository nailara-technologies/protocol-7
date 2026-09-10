---
module: jobsite.sync.push
generated_at: 2026-09-09T23:47:06
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 30969abd110c6f439bc620c10dd6e5d1791dd505
source_lines: 181
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 2408
usage_completion_tokens: 589
---

# review: jobsite.sync.push

## Purpose
This module initiates chunked async HTTP pushes of changed jobs to remote sync URLs. It filters jobs modified since the last sync watermark, handles terminal-state removal signals, and pings the web side when no local changes exist.

## Interface
- **Arguments**: `event_object` (optional), `force` (boolean, optional)
- **Return**: None (side-effect module; sets global state variables)

## Role & Dependencies
Acts as the push-side sync initiator. Heavily coupled to:
- `jobsite.job.load_all` / `jobsite.job.index` — job data access
- `base.ntime.*` — timestamp encoding/decoding
- `jobsite.removed_log` — tombstone tracking
- `base.logs` — logging
- `jobsite.sync.*` global state variables (progress tracking, queue management)

## Observations
1. **Force bypass is aggressive**: `$last_ntime_num = 0 if $force` resets the watermark entirely, causing a full re-push of all jobs regardless of actual changes.
2. **Terminal-state pruning is defensive but brittle**: The cross-check against `jobsite.job.index` assumes the index is always current; a race between `job.write` and this module could cause missed tombstones.
3. **Chunking logic is opaque**: `splice @changed, 0, $chunk_size` mutates the array in-place, which is fine but not immediately obvious.
4. **Empty queue still pings**: Even with `@push_queue` empty, it still iterates URLs to send empty chunks — this is intentional for reverse sync but adds unnecessary HTTP calls.
5. **No error handling**: The module sets `push_in_progress = TRUE` but never clears it on failure, potentially blocking retries.
6. **`validate_module` warns**: Module is not in the subroutine whitelist — unclear if this is expected or a configuration gap.

## Confidence
Unclear whether the `force` flag's behavior (resetting watermark to 0) is intentional or a bug — it would cause massive re-syncs on manual force. Also unclear if the ping on empty queue is always desired or should be conditional.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'jobsite.sync.push'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,,.,,,,,,,,,,,.,,..,..,,..,,.,,,.,,,,..,,,.,..,,...,...,,.,,,..,...,.,.,,.,,
#PJADNYEU745O6DF5TY5GZKN5FIKC7MCARTAPBF32KWS77O4HYFNIPT3R2Z5QRYJA6NQGAPAMJ4AG6
#\\\|VEL637F4EFZZPPKGSOHQS4ZCBIAUWZFC22JJYH437K2VX4A2DRG \ / AMOS7 \ YOURUM ::
#\[7]UJ6BI3WQPMMI2K6FSWJ6D46EP2ZLT5HKMF2LXT6BLG2KJLE4L4AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
