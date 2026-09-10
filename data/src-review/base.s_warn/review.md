---
module: base.s_warn
generated_at: 2026-09-09T09:59:05
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 6fe28f3d69e08de824dc2cbc743a7907c2ba44d7
source_lines: 44
dep_graph_callers: 262
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 904
usage_completion_tokens: 702
---

# review: base.s_warn

## Purpose
This module wraps `warn` with a `sprintf`-style parameterized message format. It validates that all arguments are defined, adjusts the caller level for nested `eval` contexts, and catches `sprintf` errors by re-wrapping them.

## Interface
- **Input**: `@ARG` — an array where the first element is the format template string and subsequent elements are parameters.
- **Return**: `TRUE` on success.

## Role & dependencies
Called by 262 modules (static literal calls). It depends on `<[base.s_warn]>` for self-recursion in error reporting and `<[base.format_error]>` for formatting error messages. It also leverages `use warnings FATAL => qw| all |` to catch all warnings during `sprintf` execution.

## Observations
- The `sprintf` template adjustment logic is fragile. The regex substitution `s|<\{C(\d+)}>$| my $c_l = $1; sprintf '<{C%d}>', $c_l + 2 |e` is an unusual in-place substitution that both matches and rewrites the template. This couples the module tightly to its own internal formatting syntax.
- The `@ARG < 2` check is slightly ambiguous — it allows a single-element call (template only), which may be intentional.
- The `eval` block with `warnings FATAL` is a defensive pattern but may mask other runtime issues.
- The `base.s_warn` self-reference in the error path creates a circular dependency chain that could be problematic if `base.format_error` itself calls `base.s_warn`.

## Confidence
Unclear whether the caller-level adjustment (`$c_l + 2`) is always correct across all calling contexts, especially when `base.s_warn` is called from within another `eval` or from modules that already adjust their caller level. The exact semantics of the `<{Cn}>` marker propagation are not fully documented in the source.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.s_warn'
No issues found.
```

#,,,,,.,.,.,,,,.,,,..,,,.,...,.,.,,,,,,..,...,..,,...,...,.,,,.,,,,,,,,,,,...,
#ZTHYJATSQYQTMRP64FYNWHX7CKLA5E4WXOG44Z4LPR3WWK7YXHC2JGKLU5JH5THT2COQB3WWAUSF6
#\\\|OYPXBKTLZ3TT272KU2EN5O7ORK4DO5GYVTA46GI7EGNAW7SZAM2 \ / AMOS7 \ YOURUM ::
#\[7]6LKXHJWCPP5SYZF3WCEZNLYC4YGHLRLA4GH2V5WQZ6HSHS4N76DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
