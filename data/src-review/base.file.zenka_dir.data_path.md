---
module: base.file.zenka_dir.data_path
generated_at: 2026-09-09T10:08:31
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 3ddbaf0fb1f217e0fac6a38e757f4de9e84c3ffe
source_lines: 24
dep_graph_callers: 31
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 704
usage_completion_tokens: 564
---

# review: base.file.zenka_dir.data_path

## Purpose
This module returns the data directory path for the current zenka (project) by selecting a base directory (`/etc/protocol-7/` or `/var/protocol-7/`) and appending the zenka name subdirectory.

## Interface
- **Argument**: `$global_config` (optional, defaults to `FALSE`) — when true, selects the `etc_P7` base directory; otherwise selects `var_P7`.
- **Return**: A string path combining the base directory and zenka name (e.g., `/var/protocol-7/<zenka_name>`).

## Role & dependencies
Called by 31 modules (static literal calls). It depends on two other modules: `<system.path.zenka-dirs>` (provides directory hierarchy) and `<system.zenka.name>` (provides the zenka identifier). It serves as a lookup utility for data path resolution.

## Observations
- The module is a thin wrapper with minimal logic — primarily a path construction utility.
- The `shift` usage makes the `$global_config` parameter positional rather than named, which reduces clarity.
- The deterministic check reports a "missing signature footer" error, yet the source contains a valid AMOS7 signature footer. This may indicate a false positive or a stricter format requirement (e.g., specific comment delimiters or line count).
- The use of `join qw| / |` is correct but could be simplified with `File::Spec` for portability.
- No error handling is present — if either `<system.path.zenka-dirs>` or `<system.zenka.name>` returns undef, the result would be malformed.

## Confidence
Unclear whether the signature footer validation failure is a false positive or a format mismatch (e.g., expected different delimiters or a minimum line count). The validator's error contradicts the visible source.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.file.zenka_dir.data_path':

ERRORS:
  ✗ missing signature footer
```

#,,.,,.,.,,.,,,,.,,.,,.,,,.,,,,,,,..,,,..,,,.,..,,...,...,..,,,,.,.,.,,,.,.,.,
#U32WGOZWB5RPZDWEQHJQJV6EOVHIVJLWTFMZK4RTIFTUIJ6MAA7EHKNPBB4YDS7NR3GFQBJYILS6Q
#\\\|JQAVYNMC7W7XUTTUKMWELGYDJKB6LWDPVP6O6KUEYVVC5DRJCBA \ / AMOS7 \ YOURUM ::
#\[7]SX7OAQFUDSCAOQUIICB7UCC2QFMZZ4WNUHTZH3ECRAKW7RDJ4WDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
