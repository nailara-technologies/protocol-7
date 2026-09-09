---
module: v7-zenki.zenka.change_status
generated_at: 2026-09-09T10:23:52
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: af8d5cc458444d1cc1241b37a7fb577496f528e7
source_lines: 45
dep_graph_callers: 15
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1044
usage_completion_tokens: 664
---

# review: v7-zenki.zenka.change_status

## Purpose
This module wraps the zenka status change handler, validating inputs, checking instance existence, and maintaining online instance counts. It updates a shared online-zenki hash and conditionally triggers prefix length recalculation.

## Interface
Takes two arguments: `$instance_id` and `$new_status`. Returns a warning string on validation failure (undefined instance_id, undefined status, or undefined instance entry). Returns the result of the zenka_status handler on success.

## Role & dependencies
Called by 15 modules via static literal dispatch. Depends on `<v7-zenki.zenka.instance>` (instance registry), `<v7-zenki.online-zenki>` (online counter), `<v7-zenki.handler.zenka_status>` (status handler), and `<v7-zenki.calc_prefix_lengths>` (prefix recalc).

## Observations
- **Validation FAILED** for missing signature footer — the module lacks the required AMOS7 signature block.
- **Not in subroutine whitelist** — may indicate it was added outside standard review process.
- The `map` block iterates `qw| status zenka_name |` but references `$ARG` instead of `$_`, which is a bug — it will always check `$ARG` rather than each element.
- The conditional `defined <v7-zenki.online-zenki>->{$zenka_name}` checks key existence, but the intent appears to be checking whether the count is non-zero (the `--` decrement suggests this).
- The `calc_prefix_lengths` call is gated on a count mismatch, but the condition `scalar keys <v7-zenki.online-zenki>->%*` is evaluated twice — once in the `if` and once in the `if` condition — which is inefficient.
- The module uses dynamic dispatch (`<...>`) extensively, making the dependency graph incomplete (15 static callers don't capture dynamic ones).

## Confidence
Unclear whether the `map` block's `$ARG` reference is intentional or a typo. Unclear if the `defined` check on the online-zenki hash is the intended logic or should be a numeric comparison.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'v7-zenki.zenka.change_status':

ERRORS:
  ✗ missing signature footer

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,,.,.,,,.,.,.,,,...,,..,,,,,...,,..,..,,,,.,..,,...,.,.,.,.,,..,,.,,,..,..,,
#RA3KEL2R6GTQKKEHJLCSGEEP5U6JUGRGG4A3NITRY2YH3GOONMYXYRHFKRWEJZUNPEHSHHSKQAVRG
#\\\|I2EIBI5P4MH25NWOT2ASPS5ZX3TMELOGFJJ4WMKVN2FH77W7JIL \ / AMOS7 \ YOURUM ::
#\[7]5C6M3QSC4PJT7LOLID3JGZV7BKQNZ27EFWOUDCOFRHYNYDSJOCAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
