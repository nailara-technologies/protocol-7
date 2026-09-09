---
module: base.sprint_t
generated_at: 2026-09-09T10:24:48
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: fb04f2920859ab164c9c268651e6a1d1bf517dd0
source_lines: 67
dep_graph_callers: 14
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1089
usage_completion_tokens: 548
---

# review: base.sprint_t

## Purpose
This module provides a registered template-based `sprintf` wrapper. It validates template names against a registry, resolves template groups (including module-based auto-discovery), and performs argument validation before formatting output.

## Interface
- **Input:** `$template_name` (required string parameter)
- **Output:** Formatted string via `sprintf` or `undef` on failure
- **Side effects:** Warns on missing templates, undefined arguments, or missing template groups

## Role & dependencies
- Called by 14 modules (static literal calls only; dynamic dispatch not captured)
- Depends on `<base.silence.sprint_t>` (silence flag) and `<base.templates.sprintf>` (template registry)
- Uses `caller(0)` for module namespace auto-discovery when no explicit group is provided
- Relies on `@ARG` global for argument passing

## Observations
- **Fragility:** The `@ARG` global coupling is brittle — any caller not using this convention breaks silently.
- **Coupling:** The module assumes `@ARG` is pre-populated by the caller, creating a hidden dependency chain.
- **Style:** The signature footer is present (visible at end of source), contradicting the validation failure — this appears to be a false positive in the check.
- **Edge case:** The `delete <base.silence.sprint_t>` call in the silence branch may have unintended side effects on reload.
- **Readability:** The regex for `$t_group` extraction is opaque and hard to maintain.

## Confidence
Unclear whether the `delete <base.silence.sprint_t>` is intended to clear a cached state or if it's a workaround for a broader design issue. The validation check reports a missing signature footer, but the source clearly contains one — this discrepancy warrants investigation into the check's expectations.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.sprint_t':

ERRORS:
  ✗ missing signature footer
```

#,,,.,,,,,.,.,,.,,.,,,,,.,...,,,.,,,,,..,,...,..,,...,...,.,,,,,.,,,.,,,,,..,,
#2AZRCKUAPUJLXOAPFNI7JK3ORXIFMCSXF4BOAXCOYIHDXX7LRFTLQEILCDYUESR3IG5N3BB36OVFQ
#\\\|743VKKWPMISJIMPSOGCDA4RXFSECCCQRZVSUBFKCRK2Q2337TN5 \ / AMOS7 \ YOURUM ::
#\[7]QVK7YNH46CC3WJD4HONTSWAXZAQ6VXSSG6T6URBYZAVM35PFFYDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
