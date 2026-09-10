---
module: plugin.storage.p7ref.resolve
generated_at: 2026-09-09T23:16:57
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 5042d971e14d74b34b5f12ef12128b2a36bd0bc0
source_lines: 149
dep_graph_callers: 7
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1779
usage_completion_tokens: 668
---

# review: plugin.storage.p7ref.resolve

## Purpose
This module resolves P7REF identifiers to their actual storage locations by dispatching to type-specific handlers. It validates the P7REF, checks type support, and returns a structured result containing protocol, path, or authority information.

## Interface
**Input:** `@ARG` containing a hashref with `p7ref` key (string). Returns early with `mode => 'false'` if `p7ref` is missing.

**Output:** A hashref with `mode` ('true'/'false') and `data` containing protocol-specific fields (path, authority, segments, etc.).

## Role & dependencies
This module sits in the storage resolution pipeline, called by 7 other modules. It depends on:
- `<storage.mapping.p7ref>` — registry of supported types
- `<plugin.storage.p7ref.parse>` — P7REF parsing
- `<plugin.storage.inference.lookup>` — inference cache lookup
- `<plan-9.default_port>` — default 9P port

It acts as a dispatcher, delegating to type-specific handlers (checksum, 9p, path, inference, segment).

## Observations
- **Fragility:** The `inference` branch has a nested conditional that checks `exists $code{'plugin.storage.inference.lookup'}` — this is a dynamic dispatch pattern that may be fragile if the plugin is loaded via a different mechanism.
- **Coupling:** The module tightly couples to the registry structure (`$registry->{'types'}{$type}`) and assumes `handler` is always a code reference.
- **Style:** The `elsif` chain is long and could benefit from a dispatch table. The `9p` branch has a subtle bug: `$path` is built from `$parsed->{'address'}` but then `$parsed->{'authority'}` is used in the `full` URL without being set earlier.
- **Validation passed** both `module_convention_check` and `validate_module` with no violations.

## Confidence
Unclear whether `$parsed->{'authority'}` is guaranteed to exist for 9P types, or if it's always defaulted to `$default_authority`. The `full` URL construction uses `$parsed->{'authority'}` which may be undefined.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'plugin.storage.p7ref.resolve'
No issues found.
```

#,,,.,,.,,,.,,,,,,,.,,,.,,.,.,.,,,...,,.,,...,..,,...,...,...,..,,.,,,,.,,,..,
#GFVACIUHZTMKZRCPNMXXSMEWECY4FRGG2GYL76QYQ7C7IM7EPGERBMUAZORDDFAR7SSRC5EFBPVD2
#\\\|H6XSXWHMKLPQBGWC23KGYGF3UM6LRVAJION6N7S3VUEYOLTVRLP \ / AMOS7 \ YOURUM ::
#\[7]KPTGTY6NWT36CYWHGACTJU5FJDBDLUSOCBABGWI6E6P2YEDC4MDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
