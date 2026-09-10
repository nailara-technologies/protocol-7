---
module: base.chk-sum.bmw.224.B32
generated_at: 2026-09-09T10:12:59
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: d95a93f0ccafe9a565badf04d41d6561e6723d29
source_lines: 32
dep_graph_callers: 21
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 845
usage_completion_tokens: 602
---

# review: base.chk-sum.bmw.224.B32

## Purpose
This module computes a 224-bit BMW cryptographic checksum of input data and encodes the result in Base32 (B32) format. It accepts data via positional arguments and returns a B32-encoded hash string.

## Interface
- **Input**: `@ARG` — accepts a scalar reference, array reference, or bare string/array of strings.
- **Output**: B32-encoded 224-bit BMW hash string, or `undef` on error.
- **Errors**: Warns if no arguments provided or input is undefined; returns `undef` for unsupported reference types.

## Role & dependencies
Fits into the AMOS7 checksum family (`base.chk-sum.*`). Notable dependencies:
- `Digest::BMW::bmw_224` — the core hash computation.
- `encode_b32r` — B32 encoding utility (likely from the same codebase).
- `<[base.s_warn]>` — a custom warning helper used for type errors.

## Observations
- **Fragility**: The `ref $ARG[0]` check for strings is fragile — `ref` on a bare string returns `undef`, not an empty string, so the condition `not length ref $ARG[0]` may not behave as intended for scalar strings.
- **Coupling**: Tightly coupled to `Digest::BMW` and `encode_b32r`; swapping hash algorithms requires code changes.
- **Style**: The signature footer is present in the source but the validation reports a "missing signature footer" failure — this appears to be a false positive or a format mismatch in the validator.
- **Edge case**: The `elsif ( not length ref $ARG[0] )` branch may misclassify `undef` or other falsy refs.

## Confidence
Unclear why the validation reports a missing signature footer when the footer is visibly present in the source. Unclear whether `encode_b32r` is a standard AMOS7 utility or an external dependency.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.chk-sum.bmw.224.B32':

ERRORS:
  ✗ missing signature footer
```

#,,,.,,,.,..,,,,.,..,,..,,...,,,,,,..,..,,,,,,..,,...,...,.,,,...,.,.,,..,...,
#YXQLIDOVUQVLV3PO52EVEEBAN5L25XXZAM6JIQKA6SIU3IEMS4HEJ6UNUG3KDCPXHCDLBSRH32XES
#\\\|YHVF4XOYVAVJI25OOKNYE6AOAJ6DT3CUX4O52EL2EZSOVV3QJX6 \ / AMOS7 \ YOURUM ::
#\[7]JLOEVFRF3M3AUJERZORM6YK4Q74GZYPJWA3ZUGHS7OM6FJ2RFWAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
