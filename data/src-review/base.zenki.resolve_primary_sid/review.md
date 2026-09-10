---
module: base.zenki.resolve_primary_sid
generated_at: 2026-09-09T10:10:22
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: d3f4f6297286451f5e327d69e35c7696912a14b7
source_lines: 93
dep_graph_callers: 26
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1528
usage_completion_tokens: 807
---

# review: base.zenki.resolve_primary_sid

## Purpose

This module asynchronously resolves the primary zenka instance SID for a given user and subname group. It first checks a local cache, then queries local v7-zenki instance data if available, and finally falls back to a network `list` command against the zenka cube.

## Interface

**Arguments:** `$user_name`, `$callback`, `$caller_subname` (defaults to `<system.zenka.subname>`).

**Return:** None — results are delivered via the `$callback` function with a single SID argument.

## Role & dependencies

Called by 26 modules via static literal dispatch. Key dependencies include:
- `<zenki.resolve_cache>` / `<zenki.resolve_cache_ttl>` — caching layer
- `<base.time>` — for TTL comparison
- `<base.logs>` — logging at level 2
- `<base.mod.exists>` / `<base.code.call_expected>` — module discovery and RPC
- `<v7-zenki.zenka.instance>` — local instance metadata
- `<protocol-7.route-send>` — network dispatch
- `<base.zenki.resolve_primary_sid.pick>` — selection logic

## Observations

- **Validation FAILED** due to missing signature footer — a clear style violation.
- The module assumes `<v7-zenki.zenka.instance>` is a hashref keyed by instance ID; undefined entries are skipped.
- Status filtering (`online|extbin`) gates which instances are eligible.
- The `cube_sid` is used instead of `root_sid` to avoid double-prefixing in `protocol-7.route-send`.
- The cache key is a two-level hash keyed by `$user_name` and `$caller_subname`.
- The network fallback uses a `list` command with `subnames $user_name` as the argument.

## Confidence

Unclear on the exact semantics of `<base.zenki.resolve_primary_sid.pick>` — whether it returns a single SID or a list. Also unclear whether `<protocol-7.network.parent_route>` is invoked automatically by `<protocol-7.route-send>` or if the comment about prepending is misleading.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.zenki.resolve_primary_sid':

ERRORS:
  ✗ missing signature footer
```

#,,,,,...,..,,.,,,.,,,,,.,,,,,..,,,..,.,.,,,.,..,,...,..,,.,.,,..,,,.,.,.,.,,,
#JBQBEQCO32OLJW7GP2PFJJAYIBNNFFRARXLX6IN24S4RJZTDNKMVZ4HAGQJ6AU4WXS2CLAI4UHPGS
#\\\|DNLJY7LAIJZQTYC6I34FKATX7E3DP4UI4O773QHNGS4YYNGVR5L \ / AMOS7 \ YOURUM ::
#\[7]EEVRDD2LUNQDZLVAYVRSAZWZQJR75DKE6L5AWOTKPNABBBMWMOAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
