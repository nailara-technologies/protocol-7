---
module: v7-zenki.sub-process.get_children
generated_at: 2026-09-09T23:01:09
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 1291b30cf92eaedefcf8fbd24854bd86f9f967ef
source_lines: 76
dep_graph_callers: 9
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1215
usage_completion_tokens: 615
---

# review: v7-zenki.sub-process.get_children

## Purpose
This module retrieves all descendant child process IDs of a given parent process ID, traversing the process tree recursively. It returns them sorted by start time in descending order.

## Interface
- **Argument:** `$chk_pid` — a numeric parent process ID (required, validated against `^\d+$`)
- **Return:** A list of child process IDs, sorted by start time (newest first), or `undef` if the parent PID is invalid

## Role & dependencies
Fits into the AMOS7 process management subsystem. Notable callees include:
- `v7-zenki.process.pt` — Proc::ProcessTable for process enumeration
- `v7-zenki.child` — child process registry lookup
- `base.exists.sub-process` — existence verification
- `v7-zenki.instance_ids` / `v7-zenki.zenka.instance` — instance metadata resolution
- `v7-zenki.instance_child_pids` — instance-level child PID retrieval

## Observations
- **Validation failure:** The deterministic check reports a missing `descr` metadata field — a compliance violation.
- **Fragile coupling:** The module depends on `Proc::ProcessTable` and multiple internal AMOS7 modules. If any of these change behavior, this module breaks.
- **Inefficient traversal:** The recursive child-finding uses a breadth-first loop with repeated key scans over `%ppids`, which is O(n²) in the worst case.
- **Style:** The module uses AMOS7-specific syntax (`<v7-zenki.child>`, `<[base.exists.sub-process]>`) which is non-standard Perl and may hinder portability.
- **Magic numbers:** The `5` in `== 5` check for `v7-zenki.zenka.instance` is opaque without documentation.

## Confidence
Unclear whether the `reverse sort` at the end correctly handles ties in start time. Also unclear if `v7-zenki.instance_child_pids` is guaranteed to return a list reference or a bare list.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'v7-zenki.sub-process.get_children':

ERRORS:
  ✗ missing or invalid metadata field 'descr'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,,.,...,.,.,..,,,..,,,.,.,.,...,,..,,,,,.,,,..,,...,...,,,.,.,,,..,,,.,,,,.,
#3JAEY2POKBEWH4PRP2LYRPWEYBRA4QM3FML6VEJEJNL66Q3OGPGOE4YEV577FWUFWT6SZENPXYTCK
#\\\|YG23EYK3DRNZIVV23D2RGNM2LHYK2GK57WELZLVTBWUCZU6HSDZ \ / AMOS7 \ YOURUM ::
#\[7]CEA7PEJ7XCJB6YTR6VRQ4JLIUVFTBVIWXLIRZUZEPNQINHUFU6AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
