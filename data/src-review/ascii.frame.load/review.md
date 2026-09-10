---
module: ascii.frame.load
generated_at: 2026-09-09T22:44:39
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: aa691023339bc9e17013c8b6f71c025118a6a65e
source_lines: 145
dep_graph_callers: 12
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1783
usage_completion_tokens: 617
---

# review: ascii.frame.load

## Purpose
Loads a named ASCII frame definition from a YAML file, parses its mockup(s) into descriptors, applies border/margin styling, validates each mode, and caches the result for reuse.

## Interface
Takes a single argument: `$name` (frame identifier). Returns a frame entry hashref (with `name`, `title`, `descr`, `border_style`, `modes`, `slots`, and either `descriptor` or `descriptors`) on success, or `undef` on failure.

## Role & dependencies
Serves as the entry point for frame resolution. It depends on:
- `<[base.logs]>` — logging
- `<[format.yaml.load_file]>` — YAML parsing
- `<[ascii.frame.cache]>` — global cache (wiped by `ascii.frame.init_code`)
- `<[ascii.frame.parse]>` — mockup parsing
- `<[ascii.frame.validate]>` — descriptor validation

## Observations
- **Cache fragility**: The cache is wiped by `ascii.frame.init_code` on reload, meaning edited YAML is re-parsed — a deliberate but fragile coupling between modules.
- **`truefalse.bool_assign` warning** (line 37): `$is_single_mode = 1` uses a bare integer instead of a boolean literal. The deterministic check flags this as 2 occurrences, suggesting a style violation in the AMOS7 codebase.
- **Error handling**: Parse failures silently log and skip modes rather than failing fast. This may hide configuration issues.
- **Style**: The module uses Perl 5.10+ features (`//`, `//=`) and a custom logging macro `<[base.logs]>`. The docstring comment style (`##`/`#,,.,,.`) is non-standard.
- **Coupling**: The module tightly couples frame loading to logging, caching, and validation — a single failure point in the chain.

## Confidence
Unclear whether the `truefalse.bool_assign` warning is a style preference or a semantic concern in this codebase. Also unclear if the cache-wipe-on-reload behavior is intentional or a side effect of `ascii.frame.init_code`.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'ascii.frame.load'

WARNINGS:
  ⚠ truefalse.bool_assign : 2 occurrences [ first at line 37 ]
```

#,,,.,,,,,.,.,,..,,.,,..,,...,.,,,.,,,..,,...,..,,...,..,,..,,.,.,.,.,,.,,.,.,
#P2D5ESHMCQ3BBAZNMJIBVFCKXIO52XIYYZPANE6EKK6VXGXZRII7QUVSAXEU5AC7AJA7AYOMQ5JQM
#\\\|2ETI6SO7JQHEC3MZOREHY7QEDVFFCK64NBPU5NRWKNM2ZJHYUKW \ / AMOS7 \ YOURUM ::
#\[7]65IJTEOMQ4M4S5MFDK6MTVZ6LAE7DMHTVVCAANQVRP74LJQG6YBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
