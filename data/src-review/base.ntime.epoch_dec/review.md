---
module: base.ntime.epoch_dec
generated_at: 2026-09-09T23:10:56
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 72f60eccc102a390549f97ba0f31a1c253f309ca
source_lines: 71
dep_graph_callers: 7
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1187
usage_completion_tokens: 629
---

# review: base.ntime.epoch_dec

## Purpose

This module computes and returns numerical network epoch values for a V7 network. It provides access to the current epoch, previous epochs, and future epochs, with optional count parameters for batch retrieval.

## Interface

- **Arguments**: `$req_param` (string: `prev`, `current`, or `next`), `$e_count_param` (positive integer ≤ 512)
- **Returns**: A scalar epoch value (float or unsigned int) or an array of epoch values when a count is specified. Returns `undef` on invalid parameters.

## Role & dependencies

The module depends on `<[base.ntime]>` for the current epoch time. It is called statically by 7 other modules. It uses `state` variables to cache epoch constants (`$epoch_days_per_year`, `$epoch_divisor`, `$epochs_total`), suggesting it is designed for repeated calls without re-computation overhead.

## Observations

1. **Critical bug**: The `$current_epoch` variable is computed once at the top but then mutated in the `prev` and `next` branches. Subsequent calls will return incorrect values because the state is not reset. The `state` variables are cached, but `$current_epoch` is a local variable that gets modified and never restored.

2. **Inconsistent regex delimiters**: The first regex uses `,` as the delimiter (`m,^(prev|current|next)$,`), while the second uses `|` (`m|^\d+$|`). This inconsistency is a style issue.

3. **Unusual `sprintf` syntax**: The format strings use `qw| %.13f |` and `qw| %u |` which is non-standard and may be a Protocol-7 convention.

4. **Magic numbers**: `$epoch_days_per_year //= 365 / 13` and `$epochs_total //= 385280` are hardcoded without documentation of their derivation.

## Confidence

Unclear whether the mutation of `$current_epoch` is intentional (e.g., a stateful iterator) or a bug. The module name suggests it should return epoch values without side effects, but the `prev`/`next` branches modify the local variable.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.ntime.epoch_dec'
No issues found.
```

#,,,,,...,,..,,.,,,..,.,.,,,,,,,.,...,,,.,...,..,,...,...,.,.,,..,.,,,...,,.,,
#IC4VJC3SFWZMQ5DX744JMSWSB7D7K6GTKUA5WA5JKJMNPT7REXXCJOVEDGMIROXQ5OURXYGCOWPSW
#\\\|VPYTYV3FGQIN4GPTXQJWSQM7GWOLTP76H4ZUBHB5AODP77ATALJ \ / AMOS7 \ YOURUM ::
#\[7]6FQDFO2UIKSLQUTJOOPCAJOYFWT2WZ6XXI7OVELWBBAI3IA57SDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
