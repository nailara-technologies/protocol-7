---
module: httpd.send_error_page
generated_at: 2026-09-09T10:19:11
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: f4cb1bacfa860d8949220f79fe35ed0846abbbf0
source_lines: 37
dep_graph_callers: 17
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 848
usage_completion_tokens: 576
---

# review: httpd.send_error_page

## Purpose

This module generates HTML error response pages for HTTP requests. It takes a session ID and an error code, validates the code against a protocol table, and returns formatted HTML with the error message.

## Interface

**Arguments:**
- `$ARG[0]` — session ID (required)
- `$ARG[1]` — error code (required)
- `$ARG[2]` — optional additional reason string

**Return:** HTML string formatted as a complete HTML document, or `undef` if insufficient arguments are provided.

## Role & dependencies

This module is called by 17 other modules (per the dep-graph). It depends on:
- `<protocol.http.status_codes>` — a hash mapping error codes to human-readable descriptions
- `<base.logs>` — for logging undefined error codes
- `<httpd.send_raw_html>` — for returning the final HTML response

## Observations

- **Fragility:** The module assumes `<protocol.http.status_codes>` is always defined and populated. If that table is missing or stale, it silently falls back to code 500 with a log warning.
- **Coupling:** The module is tightly coupled to the protocol's status code table, making it difficult to extend without modifying the protocol definition.
- **Style:** The use of `<[...]>` syntax for protocol lookups and function calls is consistent with AMOS7 conventions, but the signature footer is malformed — the check reports "missing signature footer" despite visible footer content, suggesting a parsing issue.
- **Safety:** The module checks argument count but does not validate that `$id` is actually a valid session identifier before use.

## Confidence

Unclear whether the "missing signature footer" warning is a false positive (the footer is visibly present in the source) or indicates a specific AMOS7 format requirement not met. The check output contradicts the visible source, so I cannot determine the exact expectation.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'httpd.send_error_page':

ERRORS:
  ✗ missing or invalid metadata field 'descr'
  ✗ missing signature footer

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,,,,...,,,.,,.,,,..,..,,,..,.,.,,,.,,.,,...,..,,...,...,.,,,,.,,.,,,.,.,,.,,
#4MOSLDXS4IHSMNPAT5L67ID6M4RLIY7WEWD3WSXSJNWVBQOYV7MBTWUCCD7ILLFFZDTE2DVXNEO44
#\\\|4M3CXRYV727OPR5OPNQLHNOGSOZZP7TNNZHZN3D5QYYDQ5NE27V \ / AMOS7 \ YOURUM ::
#\[7]S2GMAS6JOTOVAMFC37HKTDDK3FGNQEZBGGHVZDU42MKAGV2SGSDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
