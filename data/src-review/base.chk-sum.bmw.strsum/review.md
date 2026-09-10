---
module: base.chk-sum.bmw.strsum
generated_at: 2026-09-09T23:51:16
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 640eb2dfcf2594d1205f2c42c9bc12647bbc7a16
source_lines: 32
dep_graph_callers: 5
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 800
usage_completion_tokens: 581
---

# review: base.chk-sum.bmw.strsum

## Purpose
This module computes a BMW (Blum-Micali-Wagner) cryptographic checksum of an input string, optionally at a specified bit size (224, 256, 384, or 512). It returns the digest encoded in Base32 reversed format.

## Interface
- **Arguments**: `$input_string_sref` (required, a scalar reference to a string), `$bits` (optional, one of 224/256/384/512)
- **Returns**: A Base32-reversed encoded digest string, or `undef` if input is invalid

## Role & dependencies
This module is a leaf in the checksum computation chain, called by 5 other modules (per the dep-graph). It depends on:
- `<[chk-sum.bmw.ctx]>` — creates a BMW hash context
- `<[base.s_warn]>` — emits warning messages
- `encode_b32r` — Base32 reverse encoding utility

## Observations
- **Fragility**: The module assumes `$input_string_sref` is always a scalar reference; the fallback `\$ARG[0]` is a defensive but potentially confusing pattern.
- **Coupling**: Hard-coded bit sizes (224, 256, 384, 512) limit flexibility.
- **Style**: AMOS7 syntax (`<[...]>->`, `<>`) is consistent with the codebase but may reduce readability for non-AMOS7 readers.
- **Validation failure**: The module lacks a `descr` metadata field and is not in the subroutine whitelist, which may cause downstream tooling issues.

## Confidence
Unclear whether `encode_b32r` is a standard AMOS7 utility or a custom function defined elsewhere. Also unclear if the fallback `\$ARG[0]` is intentional or a workaround for a calling convention issue.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.chk-sum.bmw.strsum':

ERRORS:
  ✗ missing or invalid metadata field 'descr'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,,,,,..,,..,,..,..,,,,.,.,.,...,,.,,...,.,.,..,,...,...,...,,..,,.,,..,,,,.,
#VKQJEVHHVI4TYELUI2YBKACITLSFP3YG2GMVCYYVYU5EKJOGBHXX4K6RLNP27YHVCX65PBJBRJOEQ
#\\\|GS7TAZ72MQP4UQO3N4DOIY4KN7HKD7PNAKW7SZCDXDISUEKGXLK \ / AMOS7 \ YOURUM ::
#\[7]ZNNZNM2L2AZ4ZTXGLZOIPCXTFDYAQZMJJHQQ4XK7OLU6HJBHX6CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
