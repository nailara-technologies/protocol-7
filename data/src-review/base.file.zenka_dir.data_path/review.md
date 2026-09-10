---
module: base.file.zenka_dir.data_path
generated_at: 2026-09-09T22:35:55
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: a4c2fbab95c7b15e03b45e718f6e2fcd0f2bb276
source_lines: 24
dep_graph_callers: 31
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 704
usage_completion_tokens: 597
---

# review: base.file.zenka_dir.data_path

## Purpose
This module computes the data directory path for the current zenka instance. It resolves to either `/etc/protocol-7/` or `/var/protocol-7/` as a base, then appends the zenka name subdirectory.

## Interface
- **Argument**: `$global_config` (optional, defaults to `FALSE`)
- **Return**: A string path like `/var/protocol-7/<zenka_name>/`

## Role & dependencies
Called by 31 other modules (static literal calls). It depends on two system modules: `<system.path.zenka-dirs>` for directory resolution and `<system.zenka.name>` for the zenka identifier. It acts as a thin path-builder, delegating all actual filesystem discovery to system modules.

## Observations
- **Fragility**: The module assumes `<system.path.zenka-dirs>` always returns a hash with `etc_P7` and `var_P7` keys. If either is missing, `$base_dir` becomes undefined, and `join` produces a malformed path.
- **Coupling**: It tightly couples zenka data layout to the `etc_P7`/`var_P7` naming convention. A schema change in `<system.path.zenka-dirs>` would break all 31 callers.
- **Style**: The signature `my $global_config = shift // FALSE;` is unconventional for a standalone function (suggests it may have been adapted from a subroutine). The `FALSE` default is a bit unusual; `undef` or a named parameter would be clearer.
- **Deterministic checks** report no violations, confirming the module conforms to AMOS7 conventions (max line 78, max description 55).

## Confidence
Unclear whether `<system.zenka.name>` can return an empty string, which would produce a trailing slash in the result. Also unclear if the 31 callers handle the returned path being `undef` (if `$zenka_dir_href` is missing both keys).

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.file.zenka_dir.data_path'
No issues found.
```

#,,,,,.,.,.,,,..,,...,.,,,.,,,..,,.,,,.,,,,..,..,,...,...,,,,,,.,,...,...,,.,,
#S6VO5PTLXMF5IWXYWYNKSOKGYD6GWOKTM6YTQX35JLW3BEXUT53MAM6AY6SOYGEFA53OGRMKZXCJW
#\\\|HLUV4O7RDHFF2MW535SE4RBQKJPE4656DIECSK3NAZ42UK7PP7R \ / AMOS7 \ YOURUM ::
#\[7]S2TF6GAETBHSB5RIPUPSP7EJLKYNFBROJLOAOAIKZ3CPHQ6UG2BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
