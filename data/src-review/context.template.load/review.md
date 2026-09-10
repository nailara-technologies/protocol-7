---
module: context.template.load
generated_at: 2026-09-09T23:22:24
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 0779439ebd0a7968863f41165ff2c759cc8ea434
source_lines: 75
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1205
usage_completion_tokens: 525
---

# review: context.template.load

## Purpose
This module loads named context templates from YAML files, with mtime-based cache invalidation to ensure edits are reflected immediately without requiring full cache clearing.

## Interface
Takes a single string argument `$name` (the template filename). Returns a hash reference containing the parsed template (with `name`, `sections`, and `budget` fields) on success, or `undef` on failure.

## Role & dependencies
Serves as a template loader for the context system. Notable callees include `<system.root_path>`, `<context.cfg.template_dir>`, `<[base.logs]>`, `<[format.yaml.load_file]>`, `<context.cfg.default_budget>`, and `<context.templates>` (a global cache keyed by mtime).

## Observations
- **Fragility**: The mtime cache relies on `File::stat::stat` (OO form), which the comment notes "silently returns undef" — if `$st` is undef, `$mtime` becomes `0`, potentially causing false cache hits.
- **Coupling**: Tightly coupled to `<context.templates>` global hash and `<context.cfg.default_budget>`.
- **Style**: The comment block is extensive and well-documented (explains a known bug from 2026-09-09), but the code itself is minimal.
- **Validation**: The deterministic checks report no violations and validation passed.
- **Error handling**: Returns `undef` on missing file, parse error, or invalid structure — no exception mechanism.

## Confidence
Unclear whether `<context.templates>` is truly a global hash or a module-scoped variable — the syntax `<context.templates>` suggests a dynamic lookup, but the exact binding mechanism isn't visible here. Also unclear if the mtime comparison handles timezone/UTC differences across systems.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'context.template.load'
No issues found.
```

#,,,.,,,,,.,.,,.,,...,.,.,.,.,,,.,,,,,,.,,,,,,..,,...,...,,,,,.,,,..,,.,,,...,
#2MXZU5LMPEIF5QJE6SS7AYU7RI6KIQWBPB7P6PMARE7E3XBULXQVRKW2GBHVVLFKWVYZGMS5ISP36
#\\\|CBOYQ2LNOZ6PQAB5T36MESB276PBX2GV4ZOZSKRVYTNGCP5UBKQ \ / AMOS7 \ YOURUM ::
#\[7]DM22HLW5AIXMX5GAG7BHLDOEKGJHB3OXX2GWVCYRSGYBBIEJESCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
