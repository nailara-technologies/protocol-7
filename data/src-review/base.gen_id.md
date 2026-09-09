---
module: base.gen_id
generated_at: 2026-09-09T10:03:21
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: cbd9e788e4a297eae0ab1d0be94c7da411ae43e0
source_lines: 69
dep_graph_callers: 90
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1211
usage_completion_tokens: 530
---

# review: base.gen_id

## Purpose

Generates unique identifier strings by sampling from a configurable character pool, avoiding collisions in a provided hash reference. Optionally enforces a "numerical truth" assertion on the generated ID.

## Interface

- **Arguments**: hashref (collision store), integer (max IDs), string (character range), optional flags
- **Returns**: integer/ID string, or `undef` on failure

## Role & dependencies

Called by 90 modules (static literal calls). Depends on `base.prng.fortuna` for random sampling. Uses `AMOS7::Assert::Truth::is_true` for the harmony check. The module is a utility for ID generation with collision avoidance.

## Observations

- **Metadata violation**: The `descr` field is missing from the module header, which the validation check flags as an error.
- **Signature footer missing**: The validation check reports a missing signature footer, though the source appears to contain one — unclear if the check is parsing it correctly or if the footer is malformed.
- **Fragile collision handling**: The `goto abort` label jumps past the collision-warn block, potentially skipping the "element count exceeded" warning when giving up.
- **Hardcoded limits**: `$max_retries` capped at 4096; the "truth assertion" is disabled after half the retries — these are opaque policy decisions.
- **Style**: The `##` comments are Protocol-7 specific; the `#4A4RZ...` signature line appears to be a checksum or hash for integrity verification.

## Confidence

Unclear whether the signature footer is truly missing or if the validation tool is misparsing the multi-line footer. The `goto abort` behavior is also unclear — it skips the collision warning but the `warn` before it still fires.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.gen_id':

ERRORS:
  ✗ missing or invalid metadata field 'descr'
  ✗ missing signature footer
```

#,,..,.,.,..,,.,,,,,,,,.,,.,,,,..,,,,,.,,,...,..,,...,...,.,,,,,.,,.,,.,.,,,.,
#WJ3GBKHGFBLWUFBCVTE3QF4OKL7R2K3LQ35QDU24M4SH2Q72VDRZBHFL2YEKUN736FQBR6VKXW2CG
#\\\|3LV5EZNPJO6EYNJONBBAGP4YX4AKHY6B6O6MDHA7GTKBZRUEVB5 \ / AMOS7 \ YOURUM ::
#\[7]4YPAHTRESM4OV5ZYFSB3E4BEPBLPEQ2MACD6327DAA347DTE3QCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
