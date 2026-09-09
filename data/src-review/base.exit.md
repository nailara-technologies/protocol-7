---
module: base.exit
generated_at: 2026-09-09T10:02:42
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: a55f7c722577ec99629b4d133997590992def5a6
source_lines: 61
dep_graph_callers: 102
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1033
usage_completion_tokens: 607
---

# review: base.exit

## Purpose
This module terminates a zenka process, supporting both a Protocol-7 reply-handler mode (when called with a hash argument containing `cmd`) and a regular procedural mode (shifting arguments from `@ARG`). It logs an exit message, resets terminal I/O, and invokes `CORE::exit()`.

## Interface
**Protocol-7 mode:** Accepts a hash reference with keys `cmd`, `return-code`, `log-message`, `log-lvl`, and `call_args`. Returns via `CORE::exit()` with the specified exit code.
**Procedural mode:** Shifts numeric exit code, optional message, and optional log level from `@ARG`. Defaults to exit code 0 with log level 2.

## Role & dependencies
This is a terminal module (102 callers in the dep-graph). It depends on `base.log` (invoked at line 54) and `main::ReadMode` (eval'd at line 56). It also uses a `$colors` hash for terminal reset output.

## Observations
- **Missing signature footer:** The `validate_module` check reports a FAILED validation due to a missing signature footer, despite the footer appearing at the bottom of the source. This is a discrepancy worth noting.
- **`format.log_singular` warning:** Line 46 uses `sprintf` with a singular log message format, flagged as a style warning.
- **Terminal reset coupling:** The module directly manipulates `STDOUT`/`STDERR` and calls `main::ReadMode`, creating tight coupling to the main package's I/O state.
- **`CORE::exit()` call:** Using `CORE::exit()` bypasses any custom exit handling in the caller, which may be intentional but reduces composability.

## Confidence
Unclear whether the "missing signature footer" validation failure is a false positive given the footer is visibly present in the source. The `format.log_singular` warning's severity is also unclear from context.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.exit':

ERRORS:
  ✗ missing signature footer

WARNINGS:
  ⚠ format.log_singular : 1 occurrence [ first at line 46 ]
```

#,,..,,..,,..,..,,.,.,,.,,.,.,,,,,.,,,,..,,,.,..,,...,...,.,.,..,,,,.,,,.,,,,,
#G7X4LFMGNLS25LCZSYWF5UJSV4PJ27DIWWSVGZLLFIMGD6OCYXOCDUBKETD3DTHDIALV4X4SLZ44O
#\\\|IGGEJV5HAYXEY56SE5DSJJQZ6R2TMLM3L4IYGXCBL2DZGNWYQOD \ / AMOS7 \ YOURUM ::
#\[7]VUYNP6XUM6GVO6TJXIDKH6HEKASJ2R3634VVPMF6GMZC56SGIYCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
