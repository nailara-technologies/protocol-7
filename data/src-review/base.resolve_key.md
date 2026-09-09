---
module: base.resolve_key
generated_at: 2026-09-09T10:18:58
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: c7583c047c9c9061b669bd1c92da164fbe6e883b
source_lines: 47
dep_graph_callers: 17
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 889
usage_completion_tokens: 765
---

# review: base.resolve_key

## Purpose
This module resolves a dotted hash key string (e.g., "a.b.c") into a nested hash reference, returning metadata about the resolved value's type and data. It traverses a hierarchical hash structure by splitting the key string and descending into nested hashes.

## Interface
- **Arguments**: `$key_str` (string key to resolve), `$hash_ref` (hash reference to traverse)
- **Return**: A reference to a hash containing `r-type`, `r-data`, `key-href`, and `last-key` on success; `undef` on failure.

## Role & dependencies
Called by 17 modules via static literal dispatch. It depends on `<[base.parser.data_hkey_tree]>` for key splitting — a dynamic call not captured in the dependency graph. The module sits in the `base` namespace, suggesting it's a foundational utility.

## Observations
- **Logic bug**: The `elsif (scalar @dtree == 0)` branch can never execute inside the `while` loop because `shift @dtree` empties the array on each iteration. The final return should be outside the loop.
- **Validation failure**: Missing signature footer (62D2YONMNLYMO5HHHPQUUZLXFGGCTKBGPZTS5CIMSJS7ASLDIQL3N6VS5MWC4KE26BBEF5L34XVXO) — a required AMOS7 artifact.
- **Redundant check**: `ref $hash_ref ne qw| HASH |` is checked twice (once before the loop, once inside).
- **Dynamic coupling**: The `<[base.parser.data_hkey_tree]>` call is not in the static dep-graph, making the module's true dependencies opaque to static analysis.
- **Style**: Uses AMOS7-specific syntax (`<[...]`, `qw|...|`, `##` comments) consistent with the codebase.

## Confidence
Uncertain about whether `<[base.parser.data_hkey_tree]>` is a subroutine call or a template directive — the AMOS7 syntax is non-standard Perl. Also unclear if the missing signature footer is a hard requirement or a soft linting rule.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.resolve_key':

ERRORS:
  ✗ missing signature footer
```

#,,,,,,,.,...,,.,,,,.,,.,,,..,.,.,...,.,,,..,,..,,...,...,,.,,..,,...,..,,,.,,
#BU7D7FKBLHFSMT5ZEDCJUCQX22FAFFIJ4HKPRIHFSVTIEC6F5FYAZXQFKN5PQJUKK6BUFJRV4L6EA
#\\\|4QXPVT3RMZAVOFVODBMGHEWUFWRR7AP2FYBALQ2DOSRL666TT6H \ / AMOS7 \ YOURUM ::
#\[7]EWVCY4IZEKLQWZ3AQ274G4E6IQSMVJEW5COY5YFNR6IOPYU5ACBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
