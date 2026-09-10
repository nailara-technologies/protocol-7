---
module: base.file.which
generated_at: 2026-09-09T22:41:14
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: d8334a640090d403fff8a7e2a1101da8893533f8
source_lines: 17
dep_graph_callers: 13
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 598
usage_completion_tokens: 520
---

# review: base.file.which

## Purpose
This module acts as a thin wrapper around Perl's `which` function, providing a consistent interface for locating executable binaries in the system PATH. It validates that a binary name parameter is provided before delegating to the underlying `which` call.

## Interface
- **Input:** `$bin_name` (string, defaults to `''` if not provided)
- **Output:** Returns the path to the executable found by `which`, or `undef` if the parameter is missing/empty.
- **Side effect:** Emits a warning if the parameter is undefined or empty.

## Role & dependencies
This module is called by 13 other modules (per the dep-graph), indicating it serves as a utility dependency across the codebase. It relies on Perl's built-in `which` function and does not introduce external dependencies. The `warn` call suggests it integrates with the module's logging/warning infrastructure.

## Observations
- **Fragility:** The module is extremely thin — essentially a single delegation call. This makes it a poor candidate for refactoring or extension.
- **Style:** The AMOS7 signature header (data signature, encoding markers) is present but the module body is minimal, creating a mismatch between the boilerplate and actual logic.
- **Validation failure:** The deterministic check reports a FAILED validation due to a missing or invalid `descr` metadata field. This is a compliance issue that should be addressed.
- **Error handling:** The warning is emitted but the module returns `undef` — callers must handle this explicitly.

## Confidence
Unclear whether the `which` function is a Perl built-in or an imported function from another module in this codebase. Unclear whether the 13 caller count includes dynamic dispatch or only static literal calls (the dep-graph note clarifies this limitation).

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.file.which':

ERRORS:
  ✗ missing or invalid metadata field 'descr'
```

#,,,,,,.,,.,,,..,,,.,,,,,,,,,,,,.,..,,,..,,.,,..,,...,...,...,,.,,.,,,,,,,,..,
#NQFS6QAZNEHT4W3RPOWEYGS4GEPZJANGT5HO5FUKAHIHWGYR5GQNQCSISJ57D4AENDLIRM2XHK4ZW
#\\\|G6WYNWDVAIDKEDU2F2PU4QCR42FJ75E7NZ3IYY5OS7QEXG5HWXV \ / AMOS7 \ YOURUM ::
#\[7]T6INXTZ6HODT2ZQPPMNCANWUCQNKGJDSKLKQBPCSBFIZNMUQLIBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
