---
module: format.yaml.load_keyword_path
generated_at: 2026-09-09T23:45:31
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 093340ada9a0394e73fffe890a8864706e70c55f
source_lines: 23
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 685
usage_completion_tokens: 520
---

# review: format.yaml.load_keyword_path

## Purpose

This module loads a YAML file using keyword-based path resolution. It accepts a keyword path string, resolves it to an actual filesystem path, and returns the parsed YAML data or `undef` on error.

## Interface

- **Argument:** `$path` — a keyword path string (passed via `shift`)
- **Return:** Parsed YAML data (hashref/arrayref) or `undef` on error

## Role & dependencies

The module sits between the caller and the YAML loader. It depends on two internal Protocol-7 modules:
- `<[base.path.resolve_keywords]>` — resolves keyword paths to actual paths
- `<[format.yaml.load_file]>` — performs the actual YAML file loading

It is called statically by 6 other modules (per the dep-graph).

## Observations

- **Convention violation:** Line 5 exceeds the 78-character limit (81 chars). The description wraps awkwardly across the line break.
- **Error handling is minimal:** The `return unless defined $path` check is the only guard. If `resolve_keywords` or `load_file` throws an exception, it will propagate uncaught.
- **Tight coupling to internal modules:** The module relies on two other Protocol-7 modules that are not documented here. If either changes signature, this module breaks.
- **No validation of the resolved path:** After resolution, there is no check that the path is a valid file or that it exists before attempting to load.

## Confidence

Unclear whether `<[base.path.resolve_keywords]>` and `<[format.yaml.load_file]>` are internal Protocol-7 modules or external dependencies. The deterministic check reports "Validation PASSED," but the convention violation on line 5 suggests the linter may not be fully enforcing all rules.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
## convention violations [ 1 files scanned, 1 issues ] ##

[src/format.yaml.load_keyword_path]
  L5     line_too_long     81>78  # descr = load YAML file using keyword paths [protocol-7] or [workspac
```

### validate_module

```
Validation PASSED for 'format.yaml.load_keyword_path'
No issues found.
```

#,,..,.,.,.,.,,,.,,,.,,,.,,..,,,,,,.,,,,,,,..,..,,...,...,.,.,,,.,.,.,,,,,.,.,
#UGCXNET7F4AR3X7RGICNMZF4NG3QSDPPBMGCET6FUXMCPVWXBKMRVCUZUOV2X2N7ANGWPK2Q35OSK
#\\\|77G47DKE4QKZGCZJDL4UZSQ2LVEGJOA4LPL3VVPTPE7JVT666O5 \ / AMOS7 \ YOURUM ::
#\[7]OUBDTVH25BB6A73G4JM4EKDCIDGTE6XC2ND5EJCC76MNG3NYLQBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
