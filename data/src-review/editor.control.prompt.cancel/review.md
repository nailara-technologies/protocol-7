---
module: editor.control.prompt.cancel
generated_at: 2026-09-09T23:05:42
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: af175a558c7982bdb258b00fae1080371f1e5cb5
source_lines: 33
dep_graph_callers: 8
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 754
usage_completion_tokens: 509
---

# review: editor.control.prompt.cancel

## Purpose

This module closes an open in-frame prompt without submitting it. It fires an optional `on_cancel` callback before dropping the prompt state, ensuring the callback still sees which prompt it was canceling.

## Interface

**Input:** `$editor_state` — expected to be a HASH containing a `'prompt'` key whose value is also a HASH.

**Return:** `TRUE` on success, `FALSE` if either the editor state or prompt is not a HASH.

## Role & dependencies

Called by 8 modules (per the dep-graph). It relies on `%code` — a global hash resolving callback names to subroutines — the same mechanism used by `on_submit` callbacks. The module is a terminal action in the prompt lifecycle, paired with `editor.control.prompt.submit`.

## Observations

- **Fragility:** The `%code` hash is a global lookup resolved at call time, making the callback resolution opaque and hard to trace statically.
- **Coupling:** The module assumes the existence of a global `%code` hash without declaring it, which is a common AMOS7 pattern but reduces portability.
- **Style:** The module uses a single close path for all cancel keys (Left, Ctrl-C, Esc), which simplifies logic but centralizes a single point of failure.
- **Validation:** The `module_convention_check` passed with no violations, and `validate_module` passed, though the "not found in subroutine whitelist" warning suggests it may not be formally registered in the module registry.

## Confidence

Unclear whether the `%code` hash is guaranteed to exist in all execution contexts, or whether the whitelist warning implies a missing registration step that could cause runtime issues.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'editor.control.prompt.cancel'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,,.,.,.,.,.,..,,..,,,.,,...,.,,,.,,,,..,.,.,..,,...,...,,,,,,.,,...,,..,,,,,
#J4DA3ZXNPMFM35EV4Y5IFTM5KYZEYSRR6V3LJO4O6PAXHAUSK4DSTOL4XK57K5JGD6S6LJ2XLLLX4
#\\\|7LQRV3J6OFGPQMWGFE4J37VDDDCTIOXIR3NS72NUV45AKGAWAZI \ / AMOS7 \ YOURUM ::
#\[7]6LSFW5KIPBWAQXI55WIUAXDUTYZ6MWZFG2IRQEZXN6LOSWY34AAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
