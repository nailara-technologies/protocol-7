---
module: base.prng.chars-anum
generated_at: 2026-09-09T10:12:00
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 1e689add0a27f777cb2979fa4d31a121815f7e08
source_lines: 19
dep_graph_callers: 22
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 652
usage_completion_tokens: 565
---

# review: base.prng.chars-anum

## Purpose
This module generates a random string of a specified length using the Fortuna PRNG. It validates the input length argument and delegates string generation to `base.prng.fortuna`.

## Interface
- **Input:** A single integer argument `$length` (required, must be a positive integer ≥ 1).
- **Output:** Returns a string of the specified length drawn from a 62-character alphabet (digits, lowercase, uppercase).

## Role & dependencies
This module is a thin wrapper around `base.prng.fortuna`, calling its `string_from` method. It is called statically by 22 other modules (per the dep-graph). The seed string is hardcoded, making it a deterministic PRNG seeded with a fixed constant.

## Observations
- **Validation:** Input validation is minimal — only checks that `$length` is a positive integer via regex and comparison. No type coercion or range bounds beyond `> 0`.
- **Determinism:** The seed string is static, meaning every invocation with the same `$length` produces the same output. This is likely intentional for reproducibility but limits cryptographic use.
- **Metadata compliance:** The `validate_module` check reports two failures: missing `descr` metadata field and a missing signature footer. The footer appears to be present but may not match the expected format or checksums.
- **Coupling:** Tight coupling to `base.prng.fortuna` — any changes there propagate directly here.
- **Style:** The signature footer is embedded as a comment block with checksums, but the validation tool does not recognize it as valid.

## Confidence
Unclear whether the signature footer is intentionally malformed (perhaps a test artifact) or if the validation tool's expectations differ from the module's actual format. The `descr` field is also absent — unclear if this is a known exception or an oversight.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.prng.chars-anum':

ERRORS:
  ✗ missing or invalid metadata field 'descr'
  ✗ missing signature footer
```

#,,,.,...,,,,,...,.,.,..,,,.,,,,,,.,.,,,,,,,,,..,,...,...,,,.,,..,.,.,,.,,.,,,
#FFVYMV4ZSTTJBDYACVM6VPS62SK2JEUD7TU3RXRYMS2X2U4UV5VPC3CHETNHQVLYSVFQ7HLSDVLXW
#\\\|FSPM2EJ5J6WVEMVIH5FIUFRK2I25C5TA6Y2AEG3UBVJTTS7QWEZ \ / AMOS7 \ YOURUM ::
#\[7]4VCMC77LDVEXNV6O44NP72DT42HGYTMRK4MF652LTIU22QVTHOCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
