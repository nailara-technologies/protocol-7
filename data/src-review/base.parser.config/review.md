---
module: base.parser.config
generated_at: 2026-09-09T23:38:28
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 2e3c743455b7a8007d867f59b0cb30626c7741cd
source_lines: 215
dep_graph_callers: 9
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 2917
usage_completion_tokens: 810
---

# review: base.parser.config

## Purpose
This module parses zenka configuration lines, expands template variables, resolves command references, and returns an array of Perl code strings for initialization.

## Interface
Accepts a reference to an array of config lines (and an optional variable prefix). Returns an array of Perl code strings (`@init_code`) representing the parsed configuration.

## Role & dependencies
Called by 9 modules (dep-graph). Heavily relies on dynamic dispatch: `<base.log>`, `<base.logs>`, `<base.config_parser>`, `<base.access.special-user-map>`, `<system.zenka.verbosity.console>`, `<system.descr.config>`, and `<base.str.os_err>`. These dynamic calls are not captured in the static dependency graph.

## Observations
- **Style**: `format.log_singular` warning at line 7 indicates a singular form issue in a log message.
- **Fragility**: The `cmd` variable is used in `join( qw| = |, $conf_hash, "'$_value'" )` but never explicitly defined — it appears to be a bareword that may not behave as intended.
- **Unclear**: `LAST_PAREN_MATCH` is referenced in the substitution loop but its definition is not visible in this module.
- **Coupling**: The module tightly couples to `<system>` and `<base>` dynamic dispatch, making it difficult to test in isolation.
- **Silent overwrites**: Duplicate keys are logged but silently overwritten, which may hide configuration errors.
- **Template expansion**: Relies on `<base.access.special-user-map>` for template resolution; failures silently preserve the original template.

## Confidence
Unclear whether `LAST_PAREN_MATCH` is defined elsewhere or if it's a Perl regex special variable. The `cmd` variable's scope and intended behavior is also unclear from this module alone.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.parser.config'

WARNINGS:
  ⚠ format.log_singular : 1 occurrence [ first at line 7 ]
```

#,,..,..,,,..,,..,..,,.,.,,..,,,,,,,.,..,,.,,,..,,...,...,...,,.,,.,,,,,,,.,,,
#NLBAYUITKGP3GYIILEWNWOILYV2W7R6QD35U6KZRR24KFT5TNIKOPS74CIZCBKGTA7JH4CQZFWI4E
#\\\|46H5L5V7OYNKP65HEI24MTSK4EKQ5BGOBMZUHWJPSGBGPP4LTSQ \ / AMOS7 \ YOURUM ::
#\[7]6E3HCITZ5UWNAQYLWAEPXNEB5CQRWHP4VCOJLUEWYYMO4WC7PWDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
