---
module: base.perlmod.autoload
generated_at: 2026-09-09T09:59:54
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 8476dbefef421a3cda0aa51650a3cc471f445bd1
source_lines: 107
dep_graph_callers: 167
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1527
usage_completion_tokens: 650
---

# review: base.perlmod.autoload

## Purpose
This module provides dynamic module loading via `Module::Load::autoload`, with a fallback mechanism to manually construct the autoload subroutine if the module isn't available. It registers loaded modules and handles installation failures with optional auto-install retry logic.

## Interface
Takes `$module_name` and `@export` as arguments. Returns `TRUE` on successful load, `FALSE` on failure (with optional silent suppression).

## Role & dependencies
Serves as a central autoload dispatcher for the Protocol-7 codebase (167 callers). Notable callees include `<[base.perlmod.loaded]>`, `<[base.logs]>`, `<[base.perlmod.register_loaded_module]>`, `<[base.perlmod.install]>`, and `<[base.s_warn]>`. It also depends on `Module::Load` with a runtime fallback.

## Observations
- **Missing signature footer** — validation FAILED; the module lacks the required AMOS7 signature footer, which may break tooling or inter-module verification.
- **Format warning** — `format.log_singular` used at line 65 suggests a potential pluralization/formatting inconsistency.
- **Double warning suppression** — the `$SIG{__WARN__}` handler for `List::MoreUtils` prototype mismatches is defined twice (lines 34–37 and 78–81), which is redundant.
- **Silent failure path** — when `delete <base.perlmod.silent_error>` is true, errors are swallowed without logging, which may hide real issues.
- **Unclear error handling** — the condition `if ( $reason !~ m|^\S+ locate | )` appears to check for a specific error pattern, but the intent of the `## -1 ? ##` comment is unclear.

## Confidence
Unclear whether the double warning suppression is intentional or a copy-paste artifact. Also unclear whether `delete <base.perlmod.silent_error>` is meant to be a one-time flag or a persistent state.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.perlmod.autoload':

ERRORS:
  ✗ missing signature footer

WARNINGS:
  ⚠ format.log_singular : 1 occurrence [ first at line 65 ]
```

#,,.,,,..,,.,,..,,,..,,,.,,..,..,,.,.,...,...,..,,...,...,...,,,.,,,,,.,,,.,,,
#2STUP346G4UHS76AFZHJSO3I73I6YP7K26W2ACDTC4ZYOZND4BHTYMSBMYHLBDZLHJ7FCTDFCINAM
#\\\|KGFMHSSFMVPRULYSEN4RUJBGVZTYTNWQQRPYZZTA3QEOSJALCH3 \ / AMOS7 \ YOURUM ::
#\[7]E4BGIAJMMVN5PGRCMIEOXLIMTFKGWSLX5ZYYISP47UFNAGOWQADA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
