---
module: base.vax-int.decode
generated_at: 2026-09-09T10:09:58
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 3df67669f1c0c92e42fdab572c11c975a6289aa3
source_lines: 40
dep_graph_callers: 26
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 939
usage_completion_tokens: 752
---

# review: base.vax-int.decode

## Purpose
This module decodes a VAX base32-encoded job ID back to its original 32-bit numeric value. It handles edge cases like non-encoded numeric strings, all-'A' zero values, and padding restoration for short encoded IDs.

## Interface
Takes a single string argument (the base32-encoded job ID). Returns the decoded 32-bit integer, or the original input unchanged if it's already numeric, too long, or not valid base32 characters.

## Role & dependencies
Called by 26 other modules via static literal calls. It depends on a custom `base32.decode` subroutine (not a standard Perl module), which is flagged as "module not found in subroutine whitelist." The module also uses `eval` around `unpack` for error handling.

## Observations
- The "missing signature footer" validation warning appears to be a false positive — the AMOS7 signature footer IS present at the end of the file.
- The `eval { unpack qw| V |, $decoded_bytes }` is fragile: it silently returns `undef` on any unpack failure, masking potential encoding errors.
- The padding logic assumes decoded bytes are always a multiple of 4; if `base32.decode` returns a different length, the `"\0"` padding may produce incorrect results.
- The `truefalse.guarded_return` warning flags the early `return $id` statements, which is a valid AMOS7 style concern.
- The `base32.decode` dependency is a coupling risk — if that subroutine changes behavior, this module breaks without warning.

## Confidence
Unclear whether `base32.decode` is a custom subroutine or a missing module import. The validation warnings seem inconsistent with the actual source content.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.vax-int.decode':

ERRORS:
  ✗ missing signature footer

WARNINGS:
  ⚠ truefalse.guarded_return : 1 occurrence [ first at line 14 ]
  ⚠ module not found in subroutine whitelist
```

#,,,.,.,.,..,,,..,,..,.,.,,..,.,,,,,,,,.,,...,..,,...,...,.,.,.,.,..,,,..,,..,
#AK4JBLKYAMM4KYAZZ6DVVVYZWPJ4VP54H3WBNLNM7DEEYH7SM5D6HX2ZWEVQZLKBI5YOXVN2J3ALE
#\\\|HQ3JR44XGHPFJRTS77HJTQ6JHATLJTBHHQJKDZV4LYLB7BX3WCD \ / AMOS7 \ YOURUM ::
#\[7]6UFB7WJQD6QB4S3ZKU33IJDJYU23VYRFP3EFGESU5DWFQT3P2EDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
