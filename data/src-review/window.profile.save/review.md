---
module: window.profile.save
generated_at: 2026-09-09T23:01:43
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: f7cd73be0f54235b2f71bee474a27135952a18c5
source_lines: 94
dep_graph_callers: 9
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1239
usage_completion_tokens: 742
---

# review: window.profile.save

## Purpose

This module saves the current window position (x, y, width, height) to a YAML file keyed by a checksum of the caller name. Each caller (e.g., shell/window kind) gets its own position file for persistent state.

## Interface

**Arguments:** `$caller` (string), `$x`, `$y`, `$width`, `$height` (numeric). All must be defined and non-empty/non-negative.

**Returns:** Number of bytes written on success; `undef` on failure.

## Role & dependencies

Called by 9 modules (dep-graph). Notable callees: `YAML::XS::Dump`, `base.s_warn`, `base.logs`, `base.ntime`, `chk-sum.amos`, `file.zenka_dir.write`. The module fits into the window state persistence layer, persisting geometry per caller.

## Observations

- **Clamping:** Negative coordinates default to 0; width/height default to 1. This prevents invalid geometry but may silently mask bugs if callers pass negative values intentionally.
- **Checksum-based keying:** Using `chk-sum.amos` on the caller name ensures unique filenames without collisions.
- **Security:** File is written with `0600` permissions — owner-only access, appropriate for local state.
- **Error handling:** YAML serialization is wrapped in `eval` with a fallback warning; empty output is also caught.
- **Validation:** The deterministic check reports no convention violations and validation passed. The `⚠ module not found in subroutine whitelist` warning is a static analysis artifact, not a runtime concern.
- **Style:** AMOS7 conventions are followed (docstring, signature, signature hash at end).

## Confidence

Unclear whether `base.s_warn` is the intended logging mechanism or if `base.logs` should be used consistently for all warnings. The module appears functionally sound, but the warning-level inconsistency is a minor style question.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'window.profile.save'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,,,,,.,,...,,,,,.,.,.,.,,,.,,,,,.,.,.,,,,..,..,,...,..,,.,.,,..,,..,,,,,,,.,
#EUJSW57VASCSJDGOVYNNWQ7B6HMIQV3G5KTFRFZ6X2AMOMBFU23ZMSHRY4KMEOFU5WLJ46O6D5AUY
#\\\|XQFR4LQLZAEGRYQSFJWXKPPMGBXW4X5Z4TKBS2Z4DDBRO52PS5T \ / AMOS7 \ YOURUM ::
#\[7]XW7MFEYFMRI6F2XNBRPSNU7J4HWAXWWJIW7P5MPX3TH5MH7FIOBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
