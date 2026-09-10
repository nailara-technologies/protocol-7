---
module: window.profile.calculate
generated_at: 2026-09-09T23:07:53
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 67174336989b5cbd4674e06dce532902085f9c7b
source_lines: 140
dep_graph_callers: 8
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 2321
usage_completion_tokens: 515
---

# review: window.profile.calculate

## Purpose
This module calculates window geometry (x, y, width, height) from a named proportional profile. It supports built-in profiles (fullscreen, bottom-strip, etc.), saved user positions, and config-driven profiles, returning a hashref with the computed geometry.

## Interface
**Arguments:** `$args` (hashref) with keys: `profile` (string), `screen_w`, `screen_h`, `screen_x`, `screen_y`, `caller` (string). Defaults are provided for all parameters.

**Return:** Hashref with keys `x`, `y`, `width`, `height`, `profile`.

## Role & dependencies
Called by 8 modules via static literal dispatch. Depends on `<system.zenka.name>`, `<[window.profile.load]>`, and `<[base.logs]>`. The `cfgaccess.hashref` pattern appears 5 times (first at line 57), indicating hash-based config access.

## Observations
- **Validation failure:** 5 `cfgaccess.hashref` occurrences and missing whitelist entry suggest the module uses hashref access patterns that the static analyzer flags as non-deterministic.
- **Fragility:** The `saved` profile branch has commented-out fallback logic (`// sprintf(...)`), suggesting incomplete error handling.
- **Coupling:** Tightly coupled to `zenka_name` config structure via `$data{$zenka_name}{'window'}`.
- **Style:** Uses `<[...]>` syntax for inter-module calls, consistent with AMOS7 conventions. The `##` comment delimiters appear to be a codebase-specific convention.

## Confidence
Unclear whether the `cfgaccess.hashref` violations are intentional (dynamic config access) or indicate a style violation. The commented-out fallback logic in the `saved` branch is unclear whether it's a bug or intentional placeholder.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'window.profile.calculate':

ERRORS:
  ✗ cfgaccess.hashref : 5 occurrences [ first at line 57 ]

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,.,,...,.,.,.,.,.,.,,.,,,.,,..,,,,,,,,,,.,.,..,,...,...,,.,,.,.,...,.,,,..,,
#DDQNIFM2S42HIE4LE36UMHHEKDPT6OW5LRXG4LBWGBOENXCGWVKQ2EFIYO3EOPAVOX52GIJVRE6CW
#\\\|IZ33IJ2UJWKGOR2N3H66NX6L6WEHQDCAG7HKBUJY3KREW66BY7X \ / AMOS7 \ YOURUM ::
#\[7]E4WTTW6QJM56W7QBUPJDFC4W3ZG54HOCFRX453CTCU75B526GOBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
