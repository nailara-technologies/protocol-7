---
module: plugin.storage.p7ref.parse
generated_at: 2026-09-09T23:16:39
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: c36d91195221add23fccc3d3b84d359cc75863d3
source_lines: 89
dep_graph_callers: 7
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1192
usage_completion_tokens: 614
---

# review: plugin.storage.p7ref.parse

## Purpose
This module parses P7REF reference strings into structured components (type, address, authority, segments, query parameters, and nested references). It leverages a registry for regex patterns and caches results to avoid redundant parsing.

## Interface
**Input:** A hashref `$args` containing a `p7ref` key with the reference string to parse.
**Output:** A hashref with keys `mode` ('true'/'false'), `data` (parsed components or error message), and optionally `cached` (1 if served from cache).

## Role & dependencies
This module is a leaf in the dependency graph (7 modules call it statically). It depends on `<storage.mapping.p7ref>` for its regex patterns and cache registry. It also calls `<[base.ntime]>` to timestamp parsed results. It serves as a utility for downstream modules that need to decompose P7REF strings.

## Observations
- **Fragility:** The module assumes the registry at `<storage.mapping.p7ref>` is always available and properly initialized. If that module fails to load or the regex keys are missing, the script will die at runtime.
- **Coupling:** The regex patterns are externalized to the registry, which is good for maintainability but means the module's behavior is entirely dependent on that external configuration.
- **Style:** The data signature at the bottom (ALBY6TCBJJXPXGJL44QOTUDXADF2IMKA33OLHWUAKAKEJBVV5NKEUC2AMP3V2WW22QHRZRAIDE7NO) is a Protocol-7 signature marker, not executable code.
- **Potential issue:** The `split m|=|, $pair, 2` in query parsing could produce empty values if a key has no value, though the `// 1` default mitigates this.
- **No violations** were found in the module convention check, and validation passed.

## Confidence
Unclear whether the registry is guaranteed to be pre-populated with valid regex patterns at runtime, or if this module is expected to handle missing/invalid patterns gracefully. The error handling only covers the `p7ref` key absence and the `full` regex match failure.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'plugin.storage.p7ref.parse'
No issues found.
```

#,,.,,,,.,.,,,,,.,.,.,,.,,,.,,,.,,,..,,..,..,,..,,...,...,...,,,.,.,,,,.,,.,.,
#FUKJIFS3NJLTCTX4F3FZYW6TDR5TNR4T55YQUGGOH5PPOKF4APT6TJBCSNG353YCL4RHQLVSUWLLS
#\\\|6UJIH32ND72IVWO5SM7NTQVWLRUYBFYQ4YJUGE7QEKDCXTOCCKM \ / AMOS7 \ YOURUM ::
#\[7]NWWWDSTQOLA6ME33KGQ3THKA2EO63WQUZFATIAYOC72G2HL5DUCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
