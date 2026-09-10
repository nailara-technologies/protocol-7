---
module: format.yaml.load_str
generated_at: 2026-09-09T10:14:41
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 1c4c8b3cb8c18a9e12fe65d7da30982fe6e06cea
source_lines: 82
dep_graph_callers: 20
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1273
usage_completion_tokens: 549
---

# review: format.yaml.load_str

## Purpose
This module parses YAML from a string, attempting `YAML::XS` first and falling back to pure `YAML` on strict parsing failures. It also logs parse errors to a buffer and returns `undef` with an error summary if parsing fails or yields no data.

## Interface
Takes a single string argument (defaults to `undef` if omitted). Returns a single value or a two-element tuple `(data, error)` depending on `wantarray`. On success, returns the parsed YAML data; on failure, returns `undef` plus an error summary string.

## Role & dependencies
It is a utility module with 20 static literal callers. It depends on `format.yaml.pre_init` to load a parser, `base.logs` for error reporting, `base.str.eval_error` for extracting eval errors, `base.perlmod.autoload` for lazy loading, and `base.buffer.add_line` for error buffering. It also conditionally uses `YAML::XS` and `YAML::Load`.

## Observations
The module relies on module-level variables (`<format.yaml.load_str_fn>`, `<format.yaml.backend>`, `<format.yaml.load_str_fallback>`) that are not defined in this file, indicating it expects a prior initialization step. The `wantarray` pattern is used consistently for return values. Error buffering is capped at 42KB (`<buffer.yaml-errors.max_size> //= 42 * 1024`). The deterministic checks report no convention violations and validation passed. The fallback mechanism is lazy-loaded via `autoloading`, which may introduce subtle timing dependencies.

## Confidence
Unclear whether `<format.yaml.load_str_fn>` is guaranteed to be set before any caller invokes this module. Unclear if `YAML::XS` is always available on the target deployment environment.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'format.yaml.load_str'
No issues found.
```

#,,,.,,,,,...,.,.,,,.,,.,,,,,,,,,,..,,,.,,...,..,,...,...,,.,,..,,...,.,.,.,.,
#4A6FJ2WEMPODJMBSHO6TUF4MJ7OXAAOHKMOFAEU7R2OQIQK3JZDSNWP76DGMH4HLD5M6DSXCJT7Q2
#\\\|TVZWCKNUM4S6BECRGBD2MYWIZCRCF63R5XDP2EBY42JJJUY7DGA \ / AMOS7 \ YOURUM ::
#\[7]RVO7W4UCRLA7EVXIAUHIPH4KPOPZI6MGLXZSW7PGOBLQCHWCXCCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
