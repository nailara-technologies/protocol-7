---
module: base.s_write
generated_at: 2026-09-09T10:16:37
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 3a925dee9a8bdc54b69bf58a9cb18f7e37a97ed1
source_lines: 48
dep_graph_callers: 18
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1003
usage_completion_tokens: 606
---

# review: base.s_write

## Purpose
Provides a UTF-8 safe, non-blocking `syswrite` wrapper for sockets and pipes. It encodes UTF-8 strings in-place, computes byte length, and returns write results with specific error codes (0 for EAGAIN/EWOULDBLOCK, -1 for other errors).

## Interface
- **Arguments**: `$write_fh` (filehandle), `$write_string_ref` (scalar reference to string), `$write_len` (optional byte count), `$str_offset` (optional offset, defaults to 0)
- **Returns**: Number of bytes written, `0` on EAGAIN/EWOULDBLOCK, `-1` on error, `undef` on missing parameters

## Role & dependencies
Called by 18 other modules (static literal calls). Uses `syswrite`, `utf8::encode`, `utf8::downgrade`, `bytes::length`, and `$OS_ERROR` hash. Intended to replace `base.s_write.file_io` for socket/pipe writes.

## Observations
- **Missing signature footer** — validation failed; the footer line is truncated/corrupted in the source.
- **Line too long** (line 5, 80 > 78) — violates convention.
- **`truefalse.guarded_return` warning** at line 36 — the `return undef` pattern may not be recognized as a proper guard.
- **Fragile**: `$ARG` array access assumes caller passes arguments in a specific order; no type checking on `$write_fh`.
- **Coupling**: Depends on `$OS_ERROR` hash which may be module-specific or global state.
- **Style**: The `elsif` chain for undefined checks could be simplified; the `utf8` block has redundant `if` nesting.

## Confidence
Unclear whether `$OS_ERROR{EAGAIN}` and `$OS_ERROR{EWOULDBLOCK}` are defined in the calling context or require a specific import. The `truefalse.guarded_return` warning suggests the return pattern may conflict with Protocol-7's expected guard semantics.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
## convention violations [ 1 files scanned, 1 issues ] ##

[src/base.s_write]
  L5     line_too_long     80>78  # note = use base.s_write.file_io for file handle writes [ IO::AIO wit
```

### validate_module

```
Validation FAILED for 'base.s_write':

ERRORS:
  ✗ missing signature footer

WARNINGS:
  ⚠ truefalse.guarded_return : 1 occurrence [ first at line 36 ]
```

#,,,,,.,,,.,.,.,.,,..,,..,.,.,.,.,.,,,,..,,.,,..,,...,...,.,,,.,.,,,,,.,.,,,,,
#WLHGZBFAXUVMIUDLLEKSDXBKVNNT4NWFPBURW6FF26UJQCSZARX37KWDFDOP2CT2GU27PKCW3D2AA
#\\\|DJZZNI7VIDE7VH7NGGNNUVD6GCUS4DCTRHIJA2ZWNUTFOO7FON3 \ / AMOS7 \ YOURUM ::
#\[7]2RT75MDTQLOZTXAISGUS2FC3RSSSOGTJIHUUD3TFMKNIV5XLHQCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
