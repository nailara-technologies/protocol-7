---
module: ncode.util.run_cmd
generated_at: 2026-09-09T22:59:57
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 07f1054dcf08cabf3fd44c927f2f92d923693a7a
source_lines: 36
dep_graph_callers: 9
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 754
usage_completion_tokens: 572
---

# review: ncode.util.run_cmd

## Purpose
This module runs a subprocess via `IPC::Open3`, capturing both stdout and stderr, and returns their combined output as a single string. It serves as a simple subprocess runner for the `ncode` codebase.

## Interface
- **Arguments**: `@cmd` (array of command arguments, passed via `@ARG`)
- **Returns**: A string containing the combined stdout and stderr output of the command, or an error message string if spawning fails.

## Role & dependencies
The module is called by 9 other modules (per the dependency graph), indicating it's a utility used across the codebase. It depends on `IPC::Open3` for process spawning and `Symbol::gensym` for creating anonymous filehandles.

## Observations
- **Fragility**: The use of `@ARG` as the argument source is unconventional and may reduce clarity for callers.
- **Blocking behavior**: `readline()` blocks until the child process exits, meaning this is a synchronous call — callers must wait for completion.
- **Error handling**: On failure, it returns a formatted error string rather than a defined/undef distinction, which may complicate caller logic.
- **Style**: The AMOS7 data signature at the bottom is a hash-based checksum (base64-encoded), consistent with Protocol-7 conventions.
- **Coupling**: The module tightly couples to `IPC::Open3` semantics; any changes to that module's API would require updates here.

## Confidence
Unclear whether `@ARG` is a module-level variable or a parameter — the signature `my @cmd = @ARG` suggests it's a global or package variable, which is unusual for a utility function. Also unclear if the module is meant to be imported or called directly.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'ncode.util.run_cmd'
No issues found.
```

#,,.,,.,,,,,,,,..,,.,,,.,,,,.,,,,,.,.,..,,,..,..,,...,...,,.,,,..,,.,,...,.,,,
#QONCXCYLFT22TYG73L46WBXBVW5BXY6TGJUSCKYAPBB256XTN7SKPA4YR2KX5HEWYVWM55YETBAOW
#\\\|FUS5SEIAOB7WMEUZYO66AMP5OAKX5NVQ3AHYFSQVNTMEVJZV7FY \ / AMOS7 \ YOURUM ::
#\[7]RWDASVY7ECCDN4RFQQYLUNJVIDEQPI6L63VYX6OKJGYAR6F346DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
