---
module: httpd.new_header
generated_at: 2026-09-09T22:37:28
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 3e482ae0ee376a2c1d257e8d25a1ad217a505bd0
source_lines: 24
dep_graph_callers: 24
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 709
usage_completion_tokens: 534
---

# review: httpd.new_header

## Purpose
This module constructs an HTTP/1.1 response header string from a status code and optional parameters. It looks up the status text, inserts a Date header, and appends any additional params in sorted order.

## Interface
- **Arguments**: `$code` (status code integer), `$params` (optional hashref of header name/value pairs)
- **Return**: A complete HTTP/1.1 header string terminated with `\r\n`

## Role & dependencies
Called by 24 modules (static literal calls). Depends on `<protocol.http.status_codes>` for status text lookup and `<base.sort>` for parameter ordering. Uses `time2str(time)` for the Date header.

## Observations
- **Fragility**: Defaults to 500 Internal Server Error when `$code` or `$status_str` is undefined — this silently masks programming errors rather than failing fast.
- **Coupling**: Relies on `<base.sort>` via dynamic dispatch (`<[base.sort]>->($params)`), which is not captured in the dependency graph.
- **Style**: The AMOS7 signature comment and data signature block are present but the module is not in the subroutine whitelist (validation warning).
- **Style**: The `map` block uses a `if defined` guard inside the map body rather than filtering the list beforehand — slightly unusual but functional.
- **Style**: The `// {}` default for params is good defensive programming.

## Confidence
Unclear whether `<base.sort>` is a subroutine or a method call — the syntax `<[base.sort]>->($params)` suggests dynamic dispatch but the exact semantics aren't explicit in the source.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'httpd.new_header'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,.,,,.,,,..,..,,.,.,,,,,.,.,,,,,,.,,.,.,,,.,..,,...,..,,..,,...,,..,,..,,,,,
#MRPHLBGEPUYT2SKWZFHJ5P34BWMO7UAAVP6T44PFE43QUDBAVKH4OCW2SZR4C2PIDIL7L7TIJRLNM
#\\\|I4KWK246RJZW5QLU5ZKA3KNP46MM42EHVRHTJGYLLASGRNL3VUH \ / AMOS7 \ YOURUM ::
#\[7]6K5H435SJNHPCHOX65LMDJ2CAZ6VEXSTZXSOWPJSGAXY5YEKZWCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
