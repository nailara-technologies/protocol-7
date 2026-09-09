---
module: jobsite.job.load_all
generated_at: 2026-09-09T10:23:07
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: c3bfec83644cb52caecc8a9ed8dc742c35b49b3e
source_lines: 153
dep_graph_callers: 15
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 2334
usage_completion_tokens: 722
---

# review: jobsite.job.load_all

## Purpose
This module scans a jobsite directory structure, loads active job records from YAML files, and populates an in-memory task map. It indexes jobs by ID across multiple status directories (new, assessed, review, apply, applied, interviewed, rejected, skipped) and epoch directories (blocked, deleted), with active statuses taking priority over orphaned terminal-state files.

## Interface
**Arguments:** None — uses global configuration (`<system.path.zenka-dirs>`) and module-level globals (`<jobsite.tasks>`).
**Return value:** A reference to a hash `%jobs` containing loaded job records keyed by job ID.

## Role & dependencies
This is a data-loading utility called by 15 other modules (per the dep-graph). It depends on:
- `<system.path.zenka-dirs>` — path configuration
- `<base.vax-int.decode>` — ID decoding
- `<base.logs>` — logging
- `<base.str.eval_error>` — error string formatting
- `<jobsite.tasks>` — in-memory task state store (used for carry-forward markers)
- `YAML::XS::LoadFile` — YAML parsing
- `catfile` — path construction

## Observations
- **Re-entrant safety:** The module explicitly carries forward `stage`, `queue_gen`, `attempt`, `task_id`, and `repair_task_id` from `<jobsite.tasks>` to prevent re-entrant calls (e.g., from `settle-timer`) from wiping in-flight markers. This is a deliberate design to avoid dispatch race conditions.
- **Priority ordering:** Epoch statuses (blocked/deleted) are scanned first so active statuses can overwrite them on collision — a defensive pattern against orphaned files from incomplete cleanups.
- **Validation failures:** The module lacks a signature footer (deterministic check ERROR) and is not in the subroutine whitelist (WARNING).
- **Error handling:** YAML load failures are logged but the file is skipped — no retry or fallback mechanism.
- **Style:** Uses AMOS7-specific syntax (`<...>` for globals, `qw|...|` for lists, `//` for defaults).

## Confidence
Unclear whether `<jobsite.tasks>` is guaranteed to exist at call time (the `// {}` suggests it may not). Also unclear if `YAML::XS::LoadFile` is always available or if a fallback is needed.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'jobsite.job.load_all':

ERRORS:
  ✗ missing signature footer

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,,,,,.,,,,,,...,.,.,,,,,...,.,.,.,,,..,,,..,..,,...,...,..,,,.,,...,...,,..,
#6ZQJ2X3N6G4PVTCYGCTQYJZUD7UXART33LHSZ5VLMZM3EBXRF4LQ2RYCNPJUR6WEVNABMAXMKNNSK
#\\\|NKUL2GE55MWJM3V65K37FX4JDB4WW5UCCNMSKTRARBWTLRRBFI4 \ / AMOS7 \ YOURUM ::
#\[7]TCXQYCGSTP53QPTH57XOTY63HT4XJOC2I3P2PR6D47Q7VJT3O2DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
