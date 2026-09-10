---
module: v7-zenki.zenka.get_id
generated_at: 2026-09-09T22:47:21
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 20b5d8636190d52bef98007472917fea803c67c9
source_lines: 28
dep_graph_callers: 12
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 809
usage_completion_tokens: 661
---

# review: v7-zenki.zenka.get_id

## Purpose
This module retrieves a zenka id by searching through a zenka setup data structure for a matching name. It strips optional subname suffixes (e.g., `[subname]`) from the input and performs an exact match lookup.

## Interface
- **Input:** A single string argument (zenka name, optionally suffixed with `[subname]`)
- **Return:** The zenka id (string) if found; `undef` if not found
- **Side effect:** Logs a warning via `<base.log>` when no match is found

## Role & dependencies
The module depends on `<v7-zenki.zenka.setup>` as a data source (likely a hash reference) and `<base.log>` for error reporting. It is called by 12 other modules via static literal calls. The `die` statement on line 13 acts as a hard failure for empty/undefined input.

## Observations
- **Fragility:** The `die` on line 13 is a hard failure rather than returning `undef`, which may cause caller-side errors instead of graceful handling.
- **Coupling:** The module tightly couples to `<v7-zenki.zenka.setup>` and `<base.log>`, making it difficult to test or mock in isolation.
- **Style:** The regex substitution on line 8 mutates the input variable in-place; a non-capturing group or `pos`-based approach might be clearer.
- **Check output warnings:** The module is not in the subroutine whitelist and has a `format.log_singular` occurrence at line 19, suggesting potential style or convention violations.
- **Data signature:** The trailing signature block (lines 20–23) is a Protocol-7 artifact for integrity verification.

## Confidence
Unclear what `<v7-zenki.zenka.setup>` and `<base.log>` actually resolve to (module names? hash references?). The check output notes "module not found in subroutine whitelist" — unclear whether this is a warning or a blocker. The `format.log_singular` warning at line 19 is noted but its meaning is unclear from the source alone.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'v7-zenki.zenka.get_id'

WARNINGS:
  ⚠ format.log_singular : 1 occurrence [ first at line 19 ]
  ⚠ module not found in subroutine whitelist
```

#,,,,,,.,,.,,,.,.,...,.,.,..,,...,,,,,.,.,.,.,..,,...,...,.,,,,,.,,.,,,.,,.,,,
#4E7ASEBJIJ7CQWSTAMANUAAJJIJDYRBK5J7BG4NKGOCGR2KK2CYNDH3VOWWDKXZI63MQAWSZJKKX4
#\\\|6ZXCKK3FIMC6CPNW622RMCSBZM5IMMJVGJCDJOXIZOY67VIT3OE \ / AMOS7 \ YOURUM ::
#\[7]CWKAQKMF4L3HHZHUZVB3CU2USJEPHSR2PA7BOJ2WBN43LTVNKSCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
