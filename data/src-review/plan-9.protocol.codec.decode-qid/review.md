---
module: plan-9.protocol.codec.decode-qid
generated_at: 2026-09-09T23:00:10
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 6f1bdb97829293fb797c274cb072660e873e9a3a
source_lines: 12
dep_graph_callers: 9
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 651
usage_completion_tokens: 557
---

# review: plan-9.protocol.codec.decode-qid

## Purpose
This module decodes a QID (Question ID) structure from Protocol-7 (AMOS7) encoded data. It unpacks a binary blob into its constituent fields (type, version, and path) and returns them as a tuple.

## Interface
**Input:** `$data` — a binary string containing the QID encoding.
**Output:** A list `( $type, $version, $path )` where `$path` is reconstructed from the lower 32 bits of `$phi` and the upper 32 bits of `$plo`.

## Role & dependencies
The module is called statically by 9 other modules (per the dep-graph). It serves as a low-level codec utility within the `plan-9.protocol.codec` namespace. No external modules are imported — it relies solely on Perl's built-in `unpack`.

## Observations
- **Fragility:** The `unpack` format string `'C V VV'` assumes a fixed 13-byte layout. Any deviation in the wire format will silently produce garbage.
- **Metadata:** The `descr` field is missing (validation failure), which reduces discoverability and tooling support.
- **Whitelist:** The module is not in the subroutine whitelist, suggesting it may not be officially recognized or tested by the build system.
- **Style:** The data signature comment block is present but the module lacks a proper `use strict` / `use warnings` header, which is unusual for a production module.
- **Coupling:** The module has no dependencies, making it easy to replace or refactor, but also means it has no contract with callers beyond the unpack assumption.

## Confidence
Unclear whether the `'C V VV'` format is the canonical AMOS7 QID encoding or if it was derived from a specific wire protocol version. The lack of a `descr` field and whitelist entry suggests this module may be in early development or not yet fully integrated into the project's tooling.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'plan-9.protocol.codec.decode-qid':

ERRORS:
  ✗ missing or invalid metadata field 'descr'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,..,,,.,,,.,,..,.,.,,..,...,.,.,..,,.,.,.,.,..,,...,...,,..,,.,,.,,,..,,.,,,
#7HCWPHJ56PAJD7PQY4IRCWB4P2AYVHKSMFFQG3PC5CBE5LJDQ45OIWFPV3Y54OQ5QQKP2WRJUNQMA
#\\\|NUCZRXBBTX7BVVLVXEREYVDIFAL6ZRY4MZQ3ALMK3DSCA456OBV \ / AMOS7 \ YOURUM ::
#\[7]R4DPWT3GZ7A4WEW3R2SN5SYEQZTWVBTDMGZ25AC5BEL3MP7Y4CDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
