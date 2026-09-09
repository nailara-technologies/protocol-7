---
module: base.perlmod.load
generated_at: 2026-09-09T10:00:27
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 66769e4c9a9877d44b0e8ec7a4527c769fd3095d
source_lines: 91
dep_graph_callers: 157
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1352
usage_completion_tokens: 965
---

# review: base.perlmod.load

## Purpose

This module provides a dynamic Perl module loader using `Module::Load::load`. It attempts to load a specified module, handles loading errors gracefully, and optionally auto-installs the module if loading fails and auto-install is enabled.

## Interface

**Arguments:** `$module_name` (string), `@export` (list of exported symbols).
**Returns:** `TRUE` on successful load, `FALSE` on failure.

## Role & dependencies

Called by 157 other modules via static literal calls. It depends on `Module::Load` (with a fallback stub if unavailable) and several base modules: `base.perlmod.autoload`, `base.perlmod.auto_install`, `base.perlmod.loaded`, `base.perlmod.register_loaded_module`, `base.perlmod.silent_error`, `base.perlmod.install`, `base.perlmod.unregister_loaded_module`, `base.logs`, `base.format_error`, `base.s_warn`, and `base.log`.

## Observations

- **Fragility:** The fallback stub for `Module::Load::load` is a bare `eval join ' ', qw| use |, @ARG` — this is fragile and may not handle all edge cases correctly.
- **Coupling:** Heavy reliance on the base module registry (`<base.perlmod.loaded>`) creates tight coupling to the module system's internal state.
- **Style:** The module uses a custom logging abstraction (`<base.logs>`, `<base.s_warn>`, `<base.log>`) rather than standard Perl warnings, which may reduce portability.
- **Potential issue:** The auto-install path re-registers the module as loaded even if the second load attempt fails (the `unregister` call happens inside the error branch, but the flow is complex).
- **Warning:** The `format.log_singular` warning at line 57 suggests a potential inconsistency in error message formatting.
- **Complexity:** The error handling branches are somewhat convoluted, particularly the auto-install path which mixes logging, re-attempting the load, and conditional returns.

## Confidence

Unclear on the exact semantics of `@export` — whether it's passed through to `Module::Load::load` or used for additional export handling. Also unclear whether the auto-install mechanism actually performs installation or merely logs an attempt.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.perlmod.load'

WARNINGS:
  ⚠ format.log_singular : 1 occurrence [ first at line 57 ]
```

#,,,.,...,,.,,.,,,,.,,.,,,.,.,..,,...,,,,,,.,,..,,...,...,.,,,,,.,.,.,.,.,.,,,
#OAQG3S4QHIPM5UVYLGSLRTKQTCU2LKEAMHARNF64YWCCOSI3H5B5YDYAGPZNSZ2KZ2BHV6UHCD7VQ
#\\\|VNKLJWBRSKRMUZS3BANHHKKHHRCUQNCTL2BP7HL5WFCMVFVWVHI \ / AMOS7 \ YOURUM ::
#\[7]N6U6YRPVEPYCDLSQQMPTSSDPUDH4QCR546CA3MUXMOHZY4OY2UAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
