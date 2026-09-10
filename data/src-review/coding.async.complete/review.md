---
module: coding.async.complete
generated_at: 2026-09-09T23:12:21
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: ba61e8eaf4ab3addd5e7cdad6025642ccea438b3
source_lines: 697
dep_graph_callers: 7
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 3479
usage_completion_tokens: 664
---

# review: coding.async.complete

## Purpose

This module handles completion callbacks for deferred async coding tasks. It retrieves stored state, releases backend locks, cleans up async state, and either completes the task directly or resumes a parent task depending on whether the task was a compaction or chunked-summary subtask.

## Interface

**Arguments:** `$task_id` (string), `$result` (hashref with `success` and `result` keys).

**Returns:** A hashref `{ success => BOOL, error => STRING }` on failure; on success it performs side effects (state updates, task completion, parent resumption) and returns implicitly.

## Role & dependencies

This is Phase 1 of a deferred inference pipeline. It depends heavily on `coding.async.state_manager`, `coding.task.queue`, `coding.task.parent`, `coding.async.backend_release`, `coding.task.complete`, `coding.idiom.gate`, and `coding.task.enqueue`. It acts as a bridge between the async inference backend and the task lifecycle manager.

## Observations

- **Truncation risk:** The source is cut off mid-string in the chunked_summary branch (line ~14000/697). The `child_prompt` construction and subsequent enqueue logic are incomplete, making the chunked summary path unreviewable.
- **Heuristic fallbacks:** The "no state" branch uses heuristic assumptions (e.g., `compaction_pending` matching `$task_id`) to unblock parents. These are fragile and could misfire if state was deleted for unrelated reasons.
- **Coupling:** The module tightly couples to internal state manager APIs (`coding.async.state_manager`, `coding.async.task_state`) which are not part of a public interface.
- **Style:** The `<[module]>` syntax is consistent with AMOS7 conventions. The `qw| ... |` quoting style is used throughout.
- **Logic complexity:** The chunked_summary branch performs dynamic chunk splitting with token estimation — a complex algorithm that's hard to reason about without the full implementation.

## Confidence

I am uncertain about the exact behavior of the compaction subtask when `$n_compacted == 0` (the `splice` won't execute but state is still deleted). I also cannot verify the correctness of the chunk splitting algorithm since the source is truncated. The `coding.idiom.gate` call references `$code` which is undefined in the provided snippet — unclear if this is a lexical scoping issue or a module-level variable.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'coding.async.complete'
No issues found.
```

#,,,.,.,.,,,,,,,,,,,.,.,.,,,,,..,,..,,,,,,,,,,..,,...,...,,,,,..,,...,..,,,.,,
#6WABV244GAC4VZ6Z5XBVI5QYCJRJ54WETS5F5WDJW4LRDOTBKN2XQY4UXZNXGK4DOSOP7ZAFDWCB2
#\\\|AOOT3NH56X56TLCKRSAWGEUF7EQ6UNE6HW5H5DEL3B3NEAYLNGI \ / AMOS7 \ YOURUM ::
#\[7]CEVWEHJN7TRWQNRPIJEHJJ5KHUL7HOJMVF4ICPILG3H4RGZPRGCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
