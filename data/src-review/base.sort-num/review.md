---
module: base.sort-num
generated_at: 2026-09-09T23:11:42
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: b7b42233f070b7b18733c36e2007511e35d9143d
source_lines: 15
dep_graph_callers: 7
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 603
usage_completion_tokens: 588
---

# review: base.sort-num

## Purpose
This module takes a list of parameters from `base.context.list`, filters them to numeric values only, and returns them sorted in ascending numerical order.

## Interface
**Arguments:** `@ARG` — passed through `base.context.list`. Returns an empty list if no parameters are provided.

**Return value:** A sorted list of numeric strings (integers and decimals) extracted from the input.

## Role & dependencies
Called by 7 other modules via static literal calls. It depends on `base.context.list` for its input data. The module serves as a utility for numeric sorting within the Protocol-7 codebase.

## Observations
- **Metadata violation:** The `validate_module` check reports a missing or invalid `descr` field — a required metadata field for AMOS7 modules.
- **Regex fragility:** The filter regex `m|^\d+(.\d+)?$|` uses an unescaped dot, which matches any character followed by digits. This would incorrectly accept strings like `"1.2.3"` or `"a12"` as valid numbers. It should be `m|^\d+(\.\d+)?$|` to properly match integers and decimals.
- **Coupling:** The module tightly couples to `base.context.list`, making it less reusable outside that context.
- **Style:** The data signature comment at the bottom is non-standard and may not be recognized by AMOS7 tooling.

## Confidence
Unclear whether the unescaped dot in the regex is intentional (perhaps allowing arbitrary separators) or a bug. The `base.context.list` interface is opaque — unclear what types of values it returns.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.sort-num':

ERRORS:
  ✗ missing or invalid metadata field 'descr'
```

#,,,.,.,.,,.,,.,,,,,,,,,,,...,.,,,...,,,,,.,,,..,,...,...,.,,,,,.,..,,.,,,,,,,
#GGOMU3XNAPJXBRKQUGCTBA2BIVH34LML3BL346BL2UFENBTJAUZX7G7IQHZDZPKANHUWZQBP6PEEG
#\\\|N5PC6T54OETR4UPX65M3K7P5PNQB7UBI575S7TG4AUNVLEN2I2E \ / AMOS7 \ YOURUM ::
#\[7]AFCXYHWBIFAE2AND5CN25GR3NPDDXLIZNYGZQSDLLHURNXFEV2DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
