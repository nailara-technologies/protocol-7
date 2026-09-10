---
module: base.is_defined_recursive
generated_at: 2026-09-09T22:35:40
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: fa586fcf60f69ad8b8237e0df0a96e1141cea78b
source_lines: 32
dep_graph_callers: 40
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 763
usage_completion_tokens: 531
---

# review: base.is_defined_recursive

## Purpose

This module determines whether a given key path exists and is defined within a data hash structure. It recursively traverses nested hash keys to resolve a path and returns a boolean indicating whether the final key is both present and defined.

## Interface

**Arguments:**
- `$data_key_str` (string): the dot-separated key path to resolve
- `$data_ref` (optional): a reference to a hash; defaults to `*data{HASH}`

**Return:** `TRUE` if the key path resolves to a defined value, `FALSE` if the key is absent or undefined.

## Role & dependencies

This module serves as a utility for safe key access in the AMOS7 codebase. It depends on `base.parser.data_hkey_tree` for parsing key strings into a traversal tree. With 40 modules statically calling it, it is a widely-used accessor pattern.

## Observations

The module has three return paths with different semantics:
1. `defined $next_ref->{$last_key}` — checks both existence and definedness
2. `exists $next_ref->{$last_key}` — checks only existence (returns TRUE even for `undef` values)
3. `FALSE` — key not present

This creates ambiguity: the same function returns `TRUE` for both "defined value" and "exists but undefined" cases. The `exists` check appears redundant given the `defined` check above it.

The use of `*data{HASH}` as a default suggests a global package variable, which couples the module to a specific runtime context.

## Confidence

Unclear whether the `exists` branch is intentionally a fallback for edge cases or an oversight. The comment "only exists [1]" suggests it may be a deliberate alternative behavior, but the documentation doesn't clarify this distinction.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.is_defined_recursive'
No issues found.
```

#,,.,,..,,.,,,,.,,,,.,.,,,,,.,,.,,,..,,..,...,..,,...,...,..,,..,,...,.,.,,,.,
#KJDMR3EPE5F6G4ARHSAOGVEV6P4W7WAXQTICQZKMAHUU5ONX6ZUBJNBFWY5THX4DPTZYYZOHCDILK
#\\\|IIFHZDAOKXFLSZXKOEK3KVSSMYGSEL6IM5VJBTBAOUVDYHCYOII \ / AMOS7 \ YOURUM ::
#\[7]V5EHQ7JLCJ7DZKFZZEQIBWU67Z4GJGYAM2FF24KDMV2HOPDI4SCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
