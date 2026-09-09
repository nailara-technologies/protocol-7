---
module: base.eval.comp_regex
generated_at: 2026-09-09T10:17:46
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: bfc224487ba33c2535edca1a363d2f547647b808
source_lines: 73
dep_graph_callers: 17
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1234
usage_completion_tokens: 559
---

# review: base.eval.comp_regex

## Purpose
This module compiles a regex pattern string into a Perl `Regexp` object using `Safe::reval` for sandboxed evaluation. It escapes single quotes in the pattern to prevent delimiter leakage and returns either the compiled regex or an error reference.

## Interface
- **Arguments**: `$regex_str` (the regex pattern string), `$error_sref` (optional scalar ref to store errors)
- **Returns**: On success, the compiled `Regexp` object; on failure, `undef` (or `(undef, $error_sref)` in list context).

## Role & dependencies
This module is a utility for safely compiling regex patterns within a restricted namespace. It depends on `Safe` (for sandboxed eval) and `base.s_warn` / `base.str.eval_error` / `base.logs` (for error handling). It is called by 17 other modules (per the dep-graph).

## Observations
- **Fragility**: The single-quote escaping (`s|'|\\'|g`) is a fragile workaround. It assumes the pattern never contains a literal single quote that should be preserved, which is a common regex use case.
- **Coupling**: The module tightly couples error reporting to the `error_sref` parameter, making it awkward to use without an error sink.
- **Style**: The AMOS7 signature comment at the bottom is non-standard and adds noise.
- **Validation failure**: The module fails the `validate_module` check due to a missing `descr` metadata field.
- **Devmod output**: The `$devmod_output_to_console` flag is dead code with no external control mechanism.

## Confidence
Unclear whether the `Safe` module's `reval` method is the intended sandboxing mechanism or if this should use a more explicit restriction (e.g., `Safe->new` with `permit` calls). The `permit_only(qw| :base_core :base_orig |)` call is present but its effect on `reval` is unclear.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.eval.comp_regex':

ERRORS:
  ✗ missing or invalid metadata field 'descr'
```

#,,,,,...,.,,,.,,,...,,.,,.,,,,,.,.,,,...,..,,..,,...,...,.,,,.,.,,,,,...,.,,,
#5IOEA6QSPJWS4AO5OHCUMIKU76L7P5Z3B6IRTVUCSEZKXCQLCO762AJ535JFH2FMSGM5AHFVGJPYU
#\\\|DCDOOHZJDYAF6VBJFAZJERXTWZCGDBFZDRZDQQFV657S4BBYXQV \ / AMOS7 \ YOURUM ::
#\[7]PU7CK2NVQ4O4JUT3VT6R6M6OOCOOOBA4QFQ2LQODE7ZJHRJXO6DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
