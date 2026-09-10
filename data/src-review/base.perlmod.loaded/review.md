---
module: base.perlmod.loaded
generated_at: 2026-09-09T10:05:28
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 942735588d205c3e300888fba75f814e7449a364
source_lines: 23
dep_graph_callers: 55
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 643
usage_completion_tokens: 506
---

# review: base.perlmod.loaded

## Purpose
This module checks whether a given module name has been loaded by looking it up in a global hash reference `<base.perlmod.loaded>`. It returns a boolean indicating module load status.

## Interface
- **Input:** `$module_name` (string, required) — passed via `shift`. Returns `undef` and warns if empty.
- **Output:** `TRUE` if the key exists and is defined in `<base.perlmod.loaded>`, otherwise `FALSE`.

## Role & dependencies
This is a utility module with 55 static literal callers in the dependency graph. It depends on a global hash reference `<base.perlmod.loaded>` which is not defined within this module. Notable: it uses `<base.perlmod.loaded>` as a bareword hash reference, implying a global package-level variable.

## Observations
- **Validation FAILED** due to missing signature footer — the AMOS7 signature block is truncated or absent, which may break tooling that relies on it.
- **Global coupling:** The module relies on `<base.perlmod.loaded>` being defined at the caller's package level. This creates tight coupling and makes testing difficult.
- **Style:** Uses AMOS7-specific syntax (`##` comments, `TRUE`/`FALSE` literals, `<...>` bareword references) consistent with the Protocol-7 style.
- **Fragility:** The bareword hash reference `<base.perlmod.loaded>` could be fragile if the package context changes or if the variable is not properly exported.

## Confidence
Unclear whether `<base.perlmod.loaded>` is a package variable or a global lexical — the source doesn't show its declaration. Also unclear whether the truncated signature footer is a source control issue or an actual omission.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.perlmod.loaded':

ERRORS:
  ✗ missing signature footer
```

#,,,,,,,.,,.,,,.,,..,,...,..,,...,,,.,,,.,.,,,..,,...,..,,...,,..,,,,,,,,,,,,,
#RBJVNUGWPZJ6SBZZIPUVBXLYE64KMCQK6262NXAWZDKISPWSFLNMB2JYRD3RP6V77RK5REDUI4K32
#\\\|XXMYMVSKNJSTC7ZCPP7TPMP3X4SNOVJ3WELZ4Z5UZUK43NCCCWQ \ / AMOS7 \ YOURUM ::
#\[7]LY6PDICFX7DTGD2WUGVQE7GOJ4JHBRJIR6H3QDSHK3AK65ZKIWBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
