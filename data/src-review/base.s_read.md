---
module: base.s_read
generated_at: 2026-09-09T10:06:55
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 3a309f98693c567e7806d45bf87d8ac3035f7bc6
source_lines: 44
dep_graph_callers: 47
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 923
usage_completion_tokens: 931
---

# review: base.s_read

## Purpose

This module provides a UTF-8 safe, non-blocking `sysread` wrapper for sockets and pipes. It reads up to a specified length from a filehandle into a caller-provided buffer, handling EAGAIN/EWOULDBLOCK for non-blocking I/O, and downgrades the UTF-8 flag on the returned data to prevent double-encoding when the data is later sent via sockets.

## Interface

- **Arguments**: `$read_fh` (filehandle), `$buffer_ref` (SCALAR reference), `$read_len` (integer)
- **Returns**: Number of bytes read on success, `0` on would-block, `-1` on error, `undef` if arguments are invalid

## Role & dependencies

Called by 47 modules via static literal calls. It depends on `sysread` (Perl core), `utf8::` functions, and `$OS_ERROR` hash for error classification. It is the primary I/O read primitive for socket/pipe operations in the codebase, with `base.s_read.file_io` serving as a separate path for file handles.

## Observations

The `utf8::downgrade($r_buff, 0)` call is the most notable design choice — it strips the UTF-8 flag from the buffer after reading. The comment explains this prevents double-encoding when data is later sent via sockets, suggesting the protocol layer expects raw bytes. The `length($r_buff)` adjustment after downgrade is unusual; `length()` returns byte count regardless of the UTF-8 flag, so this appears to be a defensive measure against a specific edge case in the decoding pipeline.

The `warn` statements use a custom format string `<{C1}>` which is not standard Perl — this is a Protocol-7 convention. The module is tightly coupled to the `$OS_ERROR` hash, making it fragile if error codes change.

## Confidence

Unclear why `utf8::downgrade` is necessary on read — typically one would preserve UTF-8 semantics. The "adjust for decoding" comment is vague and doesn't explain what the `length()` call actually adjusts for, since `length()` returns byte count regardless of the UTF-8 flag state.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.s_read'

WARNINGS:
  ⚠ truefalse.guarded_return : 1 occurrence [ first at line 22 ]
```

#,,.,,,.,,,,.,.,.,.,,,...,...,,.,,,,,,.,,,,,,,..,,...,...,..,,..,,.,.,.,.,,,,,
#C4K4ZZ7T5L3B2DJR74MVYX6I6BPOZC2KQXOYTTY3ZCGBSNH6J52JZEI6HRVK4AWTTCW5PHPJNG6TW
#\\\|QR2OT7CH7XPVVKH7F5GPCT7TNBHRLBJH3PLFDPYFV4NLF7JAR6O \ / AMOS7 \ YOURUM ::
#\[7]OW2G64GGBX6YZ67D53KI3EKNMHKK3QFEJIS7NQMWI3RL7W6XKYBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
