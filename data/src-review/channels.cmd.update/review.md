---
module: channels.cmd.update
generated_at: 2026-09-09T23:12:04
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: a03aa5796f30ea5c3eabe3d8a30a01e49b97897b
source_lines: 113
dep_graph_callers: 7
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1549
usage_completion_tokens: 726
---

# review: channels.cmd.update

## Purpose
This module handles channel data updates from applications. It validates incoming channel paths, parses YAML data, stores it in the channel data store, updates metadata (subscription count, status, timestamp), invalidates checksums, and notifies blocking clients of the change.

## Interface
**Arguments:** `<channel-path> <yaml_data>` (space-separated, parsed via `split`)
**Returns:** `{ mode => 'true', data => 'BASE32_ENCODED_TIMESTAMP' }` on success; `{ mode => 'false', data => 'error message' }` on failure.

## Role & dependencies
Fits into the `channels.cmd` command dispatch layer. Notable callees:
- `<[base.logs]>` — logging
- `<[channels.util.yaml_decode]>` — YAML parsing
- `<[base.ntime.b32]>` — timestamp generation
- `<channels.data>`, `<channels.subscriptions>`, `<channels.all_channels>`, `<channels.checksums>` — global data stores
- `<channels.handler.data_change>` — client notification

## Observations
- **Fragility:** The module relies on global data stores (`<channels.data>`, `<channels.checksums>`, etc.) without any locking or concurrency control. Concurrent updates could corrupt state.
- **Coupling:** Deeply coupled to the `channels` namespace; changes to data store semantics would require modifications here.
- **Style:** Uses Protocol-7's `<[module]>` syntax for calls, which is concise but obscures the call graph. The `modedata.bare_keys` warning (2 occurrences) suggests keys are written without explicit quoting in some contexts.
- **Potential issue:** `delete <channels.checksums>` removes the entire checksum hash rather than selectively invalidating, which may be overly aggressive if only one channel changes.
- **Edge case:** The YAML parser is assumed to always return a reference; if it returns `undef` or a scalar, the error handling catches it, but the error message could be more specific.

## Confidence
Unclear whether `<[base.ntime.b32]>` is a function call or a variable assignment (the syntax `<[base.ntime.b32]>;` is ambiguous without seeing the callee definition). Also unclear if the `modedata.bare_keys` warning indicates a style violation or a potential runtime issue with bare key access.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'channels.cmd.update'

WARNINGS:
  ⚠ modedata.bare_keys : 2 occurrences [ first at line 6 ]
  ⚠ module not found in subroutine whitelist
```

#,,,,,,.,,...,,..,,,,,,.,,,.,,,,.,..,,,,.,.,,,..,,...,...,..,,,,.,,.,,.,.,...,
#QHGFM6MHFUBITVP3LTRY6BK4HOH2S7E6SVF2S23OE6NID3NI7FSU2M6NO3A573PVQTLVCJGDWLOJU
#\\\|76RLLQQFOAW7ENXGWWLUP22FWXCS7TE26GONCGP6CPTBTH2LS76 \ / AMOS7 \ YOURUM ::
#\[7]5KF5Z7E2KU3KSDLWQNEUVJIKQVRK2I4RCPSKGZNZPVGJGXIDZUAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
