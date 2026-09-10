---
module: memory.tree.flow
generated_at: 2026-09-09T23:25:51
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 60bf9c7888b1e1cb62d473fa8d01b92e7ecabd01
source_lines: 51
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 940
usage_completion_tokens: 605
---

# review: memory.tree.flow

## Purpose
This module performs a bottom-up traversal of a node tree, computing `flow_count` (number of descendant leaves) and `flow_focus` (a weighted focus score) for each node. It is designed to be called before `memory.tree.score` whenever the focus changes.

## Interface
**Input:** A hash reference with a `node` key containing a node object (with `children`, `type` fields).
**Output:** The same node object, mutated with `flow_count` and `flow_focus` fields populated.

## Role & dependencies
This module serves as a preparatory step for `memory.tree.score`. It depends on:
- `memory.focus` — retrieves the current focus context
- `memory.focus.matches` — matches a node against a focus topic
- `memory.tree.score.focus_matches_stub` — fallback stub for match failures
- Recursively calls itself on child nodes

## Observations
- **Line length violation:** The comment on line 5 exceeds 78 characters (79 > 78), flagged by `module_convention_check`.
- **Fallback coupling:** The `eval` block with `focus_matches_stub` suggests `memory.focus.matches` may fail or be stubbed; this creates a fragile fallback path.
- **Whitelist warning:** The module is not in the subroutine whitelist, which may indicate it's not yet fully integrated or is considered internal.
- **Division by zero risk:** If `$focus` is empty, `$m` remains `1.0` and `$node->{'flow_focus'}` becomes `0.0` — this may be intentional but is worth noting.

## Confidence
Unclear whether `memory.focus.matches` is expected to always succeed or if the `eval`/stub pattern is a known workaround for a broader system issue. The whitelist warning also suggests the module may not be production-ready.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
## convention violations [ 1 files scanned, 1 issues ] ##

[src/memory.tree.flow]
  L5     line_too_long     79>78  # descr = (focus excess). call before memory.tree.score whenever focus
```

### validate_module

```
Validation PASSED for 'memory.tree.flow'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,.,,.,,,,..,,,,,..,,.,.,...,...,.,,,,,,,,,.,..,,...,...,..,,..,,,,.,..,,..,,
#Q4CWOUSLD42ITEPTS6RTSRN6TWMNSVRTPNO4FJHIUKTLG2URHJBZMVP7ISS3AJ42TJ7QAEGXM446A
#\\\|ISHNLPDXK2BRZ2BIQHDFV755X2GN6WYIZZAC2FJYK23RSTK7OJH \ / AMOS7 \ YOURUM ::
#\[7]BBOJFPEXTA52P2NYHGGQIKFJAAVNAM5P5NB2EK3MFOWP7CMTUSAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
