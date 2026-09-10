---
module: users.record.path
generated_at: 2026-09-09T23:30:46
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 0eb322e6f35173529e3e6d7a0aefd35cdf23f1b3
source_lines: 39
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 870
usage_completion_tokens: 615
---

# review: users.record.path

## Purpose
This module generates a keyword path for a record document within a user namespace. It serves as the single source of truth for record layout on disk, ensuring readers and writers use a consistent path format without needing to hunt for call sites.

## Interface
- **Arguments**: `$username` (required), `$document` (optional, defaults to `"details"`)
- **Returns**: A formatted path string like `[USERS_HOST]/<user>/<document>.yaml`, or `undef` if `$username` is undefined or empty.

## Role & dependencies
This is a foundational utility module with 6 static literal callers. It feeds into `format.yaml.load_keyword_path` and `base.path.resolve_keywords`. No external modules are imported — it's a self-contained path formatter.

## Observations
- **Fragility**: The `[USERS_HOST]` prefix is hardcoded in `sprintf`. If this needs to be configurable (e.g., per-environment), the module becomes brittle.
- **No validation**: `$document` is accepted as-is with no length or character validation.
- **Style**: The module uses `qw|` quoting and `//=` (Perl 5.10+), which is fine but worth noting for portability.
- **Warning**: The module is not found in the subroutine whitelist, suggesting it may be dynamically dispatched or omitted from static analysis.
- **Design**: The directory-as-session model (record = directory, not file) is well-documented in the header comments.

## Confidence
Unclear whether `[USERS_HOST]` is a defined constant elsewhere or a placeholder that should be parameterized. The module's behavior depends on this being correctly defined at runtime.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'users.record.path'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,,,,,,.,.,.,.,,,..,,..,,...,,,,,.,.,.,.,...,..,,...,...,,,,,,.,,..,,,,.,.,,,
#TVK6HTWNEO2SIVKLNWV2K57TDVIFR2K6CN62HZB75BPVK4FBGVTWLMXI555IFGBC6D4XDR43NMQ4Q
#\\\|C63J6WQGXRVUYZKJGTC2SR5OV6CUSRTB3TUYY2CM457WLQBLXCM \ / AMOS7 \ YOURUM ::
#\[7]32RMMCPXGILZMPYZMICK5XBTTPEQINKXX5TBXMPBZMOYCOYDG4BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
