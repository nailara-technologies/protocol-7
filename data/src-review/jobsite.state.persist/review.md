---
module: jobsite.state.persist
generated_at: 2026-09-09T10:23:27
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: a3ce930e59da4e5aafd17fa1991a2ae594b6d92c
source_lines: 40
dep_graph_callers: 15
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 846
usage_completion_tokens: 627
---

# review: jobsite.state.persist

## Purpose
This module persists the jobsite scan state to disk by serializing a state hash (cycle, last_scan, pending_count, sync_last_ntime) to `scan-state.yaml` and ensuring an `index.yaml` exists.

## Interface
No explicit arguments or return value are defined in the source. The module appears to be invoked as a statement (e.g., `<[jobsite.state.persist]>;`) and returns a boolean (`TRUE`/`FALSE`) based on serialization and write success.

## Role & dependencies
It is called by 15 other modules (per the dep-graph). It depends on:
- `jobsite.cycle`, `jobsite.last_scan`, `jobsite.pending_count`, `jobsite.sync.last_server_ntime` (AMOS7 template lookups)
- `YAML::XS` for serialization
- `base.logs` for error logging
- `file.zenka_dir.write` for file I/O
- `jobsite.index.rebuild` for index maintenance

## Observations
- **Fragility**: The module has no explicit arguments, making it impossible to override state fields or target alternate paths. The state is hardcoded.
- **Coupling**: It tightly couples to `YAML::XS` and `file.zenka_dir.write`. If either fails, the entire operation aborts with a log message but no retry logic.
- **Style**: The AMOS7 template syntax (`<jobsite.cycle>`, `<[file.zenka_dir.write]>`) is consistent with Protocol-7 conventions. The docstring comment is minimal.
- **Potential issue**: The `index.yaml` rebuild is unconditional on missing file — it always calls `jobsite.index.rebuild` when the file is absent, but the rebuild's side effects are not documented here.
- **Warning**: The module is not in the subroutine whitelist, which may indicate it is not yet fully integrated into the static analysis toolchain.

## Confidence
Unclear whether the module is intended to be called as a statement or with arguments. The lack of an explicit interface makes its contract ambiguous.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'jobsite.state.persist'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,,,,,..,..,,,.,,,.,,,,,,.,,,,,.,..,,.,.,.,,,..,,...,...,.,,,..,,,,,,,,.,.,.,
#XJAI2TRNCC4HAZRWXPGV37DQJNO3HZAHKBQLANEHQ42H4RFSSIO4QAQ7WYWZOAOWO54X4HSCTUPLE
#\\\|2QE5Z352H6HHKMALQOY6XVHKCEXCHMBXESIRWQHVKBKSHCZKQ3D \ / AMOS7 \ YOURUM ::
#\[7]3O5MM6P25GFHLHXGRPQJRSAWLBBNKAMTQ5MS7NPOPK2SKMCNV2DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
