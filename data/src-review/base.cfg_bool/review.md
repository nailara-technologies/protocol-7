---
module: base.cfg_bool
generated_at: 2026-09-09T22:32:37
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 1c83bc5a5a9c5fdea91a79e6680f64eb763af82a
source_lines: 27
dep_graph_callers: 98
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 736
usage_completion_tokens: 534
---

# review: base.cfg_bool

## Purpose

This module interprets boolean configuration options, returning `TRUE`, `FALSE`, or `undef` depending on the input value. It accepts a single string argument and normalizes common truthy/falsy representations into canonical Perl boolean values.

## Interface

**Argument:** `$option_value` (string or undef) — the configuration option value to interpret.

**Return value:**
- `TRUE` — if the value matches truthy patterns (`y`, `yes`, `1`, `5`, `true`)
- `FALSE` — if the value matches falsy patterns (`''`, `n`, `no`, `0`, `false`, or undef)
- `undef` — if the value is not recognized, after emitting a warning

## Role & dependencies

The module serves as a utility for parsing boolean config flags throughout the codebase (98 modules call it statically). It depends on `base.s_warn` for reporting unrecognized options. The deterministic checks confirm no convention violations and that module validation passes.

## Observations

The regex-based approach is straightforward but has a subtle fragility: the truthy pattern `^(y(es)?|1|5|true)$` treats `5` as truthy, which may be an intentional design choice or an oversight. The falsy pattern `^(0|\-1|no?|false)$` includes `-1` as falsy, which is unusual for a boolean parser. The module uses `shift` to consume the argument, making it a subroutine-style interface rather than a function with explicit parameters. The warning call uses `base.s_warn` with a format string and the original value, which is appropriate for debugging but adds a dependency on another module.

## Confidence

Unclear whether `5` being treated as truthy is intentional (perhaps for legacy config compatibility) or a bug. The `-1` falsy classification is also non-standard and warrants clarification.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.cfg_bool'
No issues found.
```

#,,,.,..,,.,,,.,.,.,,,,,.,,,,,,,,,.,,,.,,,,..,..,,...,...,.,.,,..,,..,,,,,,,,,
#STUSKPB7HXO7T3C4JIQKHJFI6BYHZYIA42BKPYJ4ATC2HDYNYVVPP3K6GX7CCL34S3GDB43XO5OCS
#\\\|UB7TRSLXFLVP4PBXOYLMRU6TLFVEIKGVOQYG3SXCEJPPPSIP2WQ \ / AMOS7 \ YOURUM ::
#\[7]TWYXWXWT42XINKNOIGEBSWPWOPHAUJCFW7OPUL534G2FPYKIYODA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
