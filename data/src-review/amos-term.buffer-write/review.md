---
module: amos-term.buffer-write
generated_at: 2026-09-09T23:34:37
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 7eeac5a79d6dac78470f081d7c0195ebddaec283
source_lines: 61
dep_graph_callers: 5
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1141
usage_completion_tokens: 544
---

# review: amos-term.buffer-write

## Purpose
This module writes a single voxel (character + color) to a 3D shared-memory buffer and notifies registered attachments of the change. It serves as the primary write interface for the term buffer system.

## Interface
**Arguments:** `$window_id`, `$x`, `$y`, `$z`, `$char`, `$color_idx` (defaults to 4), `$client_type`.  
**Returns:** `undef` on failure (invalid window, out-of-bounds, missing shm_ptr), `TRUE` on success.

## Role & dependencies
Fits into the term rendering pipeline as a low-level buffer writer. Notable callees: `<amos-term.windows.by_id>` for window lookup, `<amos-term.buffer-attachments>` for notification dispatch. Uses shared memory (`$$shm_ptr`) for zero-copy writes.

## Observations
- **Fragility:** The `substr` write assumes the buffer is at least 2 bytes wide; no explicit check. The `ord($char) // 0` fallback silently converts non-ASCII to 0.
- **Coupling:** Tight coupling to `buffer-attachments` via dynamic dispatch (`<[base.load_code]>`), making it harder to reason about handler lifecycles.
- **Style:** The `qw| ... |` syntax in the hash construction is non-standard Perl (likely a Protocol-7 macro). The `// next` idiom in the foreach loop is unconventional.
- **Warning:** The module is not in the subroutine whitelist, which may indicate it's not yet fully integrated into the module registry.

## Confidence
Unclear whether the `// next` pattern in the attachment loop is intentional Protocol-7 syntax or a typo. Unclear if `client_type` is validated or merely passed through.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'amos-term.buffer-write'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,.,,,.,,..,,,,.,.,.,...,..,,,..,,,,,...,,..,..,,...,...,...,...,,,.,.,.,,,.,
#SHQCHAVK6PQVDA5MSPYOAKYGGJ42XR54OTE4BXBBE6BIP43XTF7PGNABVJM65UCBQFROZWCDZ7LH4
#\\\|ZARE3PYEJ3YX2XY4C7NNLFZBZ7KTABJIVT3KQSMXULBQPDOYMJG \ / AMOS7 \ YOURUM ::
#\[7]LOCHQZYJW5GCYHPKI7IRBGYKDDISQ36NHCK3M6SOMHW64O3IT4DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
