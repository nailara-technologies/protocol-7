---
module: window.profile.load
generated_at: 2026-09-09T22:54:36
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 5afa621b85d4d4c536df5f780875f9a6c8218174
source_lines: 81
dep_graph_callers: 10
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1150
usage_completion_tokens: 602
---

# review: window.profile.load

## Purpose
This module loads a saved window position from a zenka-local YAML file, keyed by a caller checksum. It parses the YAML, validates that required coordinate fields exist, and returns a hash with x, y, width, and height values.

## Interface
**Arguments:** A single required string argument (`$caller`) identifying the caller whose position is being loaded.
**Return value:** A hash reference containing `x`, `y`, `width`, and `height` on success; `undef` on failure (file not found, parse error, or missing fields).

## Role & dependencies
This module is a companion to `window.profile.save` (same per-caller path logic). It depends on `YAML::XS` for parsing and several base modules: `base.perlmod.load`, `base.s_warn`, `base.logs`, `base.file.zenka_dir.load`, and `base.str.eval_error`. The checksum-based file naming (`window/position.{chksum}.yaml`) provides caller isolation.

## Observations
- **Fragility:** The module relies on `YAML::XS` being available at runtime; if the module isn't installed, the `Load` call will fail silently (eval catches it but returns `undef`).
- **Coupling:** The `chk-sum.amos` module is called for checksum generation — if that module changes behavior, the file naming scheme breaks.
- **Style:** The `format.log_singular` warning (3 occurrences) suggests inconsistent pluralization in log messages.
- **Safety:** The eval block wraps the YAML parse, preventing crashes on malformed YAML, but the error message is generic.
- **Whitelist warning:** The module isn't in the subroutine whitelist, which may indicate it's not yet fully integrated into the AMOS7 toolchain.

## Confidence
Unclear whether the `chk-sum.amos` module is deterministic across all callers, and whether the `format.log_singular` warnings are intentional or indicate a style inconsistency that should be resolved.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'window.profile.load'

WARNINGS:
  ⚠ format.log_singular : 3 occurrences [ first at line 24 ]
  ⚠ module not found in subroutine whitelist
```

#,,..,,.,,..,,,,.,..,,,,.,.,,,,..,...,,..,,,.,..,,...,...,.,,,.,.,.,,,,,.,.,.,
#PZ43FAXEHVIA7YTKCPIPJACFKSWIDY6NZPJL54XPXKCZGVVPFSKWU64BSP3JQ6AHCAC4L45WQJYCG
#\\\|IAK45HIS4UGYRBCHYFC5K2NU5KO4GTBDF23OMLLZFMLRY3BF6RR \ / AMOS7 \ YOURUM ::
#\[7]BY2RJNY53KZV6KJBG52DS4EFFZAWCLGQ4GJF33C4I27YN2MYXSBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
