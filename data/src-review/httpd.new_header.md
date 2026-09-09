---
module: httpd.new_header
generated_at: 2026-09-09T10:10:58
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: c9c909ac34aa6a9dc9543eebe50c6f1faddfeefc
source_lines: 23
dep_graph_callers: 24
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 705
usage_completion_tokens: 521
---

# review: httpd.new_header

## Purpose
This module constructs an HTTP/1.1 response header string from a status code and a hash of header parameters. It looks up the status text, defaults unknown codes to 500, and serializes the params into header lines.

## Interface
**Arguments:** `$code` (integer status code), `$params` (hashref of header names/values, optional).
**Returns:** A complete HTTP header string including the status line, Date header, and all params as key-value pairs.

## Role & dependencies
It is called by 24 other modules (static literal calls). It depends on `<protocol.http.status_codes>` for status text lookup and `<base.sort>` for parameter ordering. The `time2str` function is used for the Date header.

## Observations
- **Validation failures:** The module lacks a `descr` metadata field and a proper signature footer, causing `validate_module` to fail. This suggests incomplete compliance with AMOS7 module conventions.
- **Fragility:** The `<protocol.http.status_codes>` hash is a dynamic lookup; if that data structure changes or is missing, the module silently falls back to 500.
- **Style:** The `map` block uses a `if defined` guard inside the map body, which is slightly unusual but functional.
- **Coupling:** The module tightly couples to the `time2str` utility and the `base.sort` dispatcher.

## Confidence
Unclear whether `<protocol.http.status_codes>` is a static hash or a dynamic dispatcher — the syntax suggests a hash lookup but the angle brackets could indicate a different mechanism. Also unclear if the 24 callers expect a specific header ordering beyond what `base.sort` provides.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'httpd.new_header':

ERRORS:
  ✗ missing or invalid metadata field 'descr'
  ✗ missing signature footer

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,..,...,,..,,.,,...,,.,,.,,,.,,,,,,,.,.,..,,..,,...,..,,..,,.,,,,,,,.,.,,..,
#4MP4L2FQBF5HBR2TPMNCLS3SEUJYPOEJ7XL4MPWD6JOL7N3PZ6ZZMVDYHGEGXW5JX6AK6G765A5FE
#\\\|W5HO2L7DL6GGOPPBVZQPHTWVCJ4INRRDJRSMMV6OHEDVWUKKFG3 \ / AMOS7 \ YOURUM ::
#\[7]UPBKENB54CGQ4X6CSBKFV7L4VH35BHQPLOVFYV4G772QWXIEFCBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
