---
module: base.event.add_io
generated_at: 2026-09-09T10:05:17
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 82c2fe9adaba76da83516e24e4ddf60ccc40c379
source_lines: 53
dep_graph_callers: 62
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1028
usage_completion_tokens: 707
---

# review: base.event.add_io

## Purpose
This module installs an I/O watcher/handler on a filehandle by wrapping `Event->io()`. It validates that a hash reference is passed, resolves a callback (either via a direct code reference or a named handler), and configures polling, timeout, and priority options.

## Interface
**Arguments:** A single hash reference containing:
- `cb` — optional direct code reference
- `handler` — optional named callback key
- `fd` — file descriptor
- `poll` — polling mode (defaults to `rt` or `r`)
- `repeat` — repeat flag (defaults to `1`)
- `async` — async flag (defaults to `0`)
- `desc` — description (defaults to callback name)
- `prio` — priority (defaults to `3`)
- `timeout` — timeout value (defaults to `0`)
- `hard` — hard flag (defaults to `0`)
- `data` — optional data payload
- `timeout_cb` — optional timeout callback

**Returns:** `undef` on validation failure; otherwise the result of `Event->io()`.

## Role & dependencies
This is a thin wrapper around `Event->io()`, providing parameter validation and callback resolution. It is called by 62 modules (per the dep-graph). Notable internal dependencies: `Event` class, `warn` function, and a `%code` hash (used for named callbacks).

## Observations
- **Validation fragility:** The module returns `undef` on multiple failure paths, making error handling at the call site non-trivial.
- **Callback resolution coupling:** The `%code` hash is referenced but never defined in this file — it must be in a parent scope, creating a hidden dependency.
- **Signature footer:** The deterministic check reports "missing signature footer," yet the source clearly contains an AMOS7 signature block at the end. This appears to be a false positive or a format mismatch in the checker.
- **Style:** The `##` comments are used for both documentation and internal notes, which may reduce readability.
- **Default behavior:** `repeat` defaults to `1` (repeating), which may not be desired in all use cases.

## Confidence
Unclear whether the `%code` hash is truly external or if this module is incomplete. The signature footer check failure contradicts the visible source, suggesting either a checker bug or a format expectation I cannot verify.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.event.add_io':

ERRORS:
  ✗ missing signature footer
```

#,,,,,.,,,.,,,,,.,,,.,.,,,...,.,,,.,,,..,,.,.,..,,...,..,,,..,.,,,,,,,.,.,..,,
#NLQLG3L2GCDYLE222ISLFBSLY2NNPHH4YQQADSROLH3I7PA3RFBUG3V7G3H6FHF77FXRUC5ITLV7O
#\\\|IQIZVMKM3O7TTBPNRTU2NMGP2NVROLKHH574SIXO22IHK7MRXYN \ / AMOS7 \ YOURUM ::
#\[7]VZLL7ENEPPMJKICABFXOSA2ESBEYEN2ZOJTLWTBQJJFCMDIACEAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
