---
module: base.dump_data
generated_at: 2026-09-09T23:51:59
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: f254036319cd203a153cdf600caed59331accac2
source_lines: 134
dep_graph_callers: 5
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1910
usage_completion_tokens: 654
---

# review: base.dump_data

## Purpose
This module serializes Perl data structures into a human-readable dump format. It recursively traverses HASH, ARRAY, SCALAR, CODE, and GLOB references, applying optional filtering and reference encoding.

## Interface
Takes up to 7 positional arguments via `$ARG[0]`–`$ARG[6]`. Key parameters include `$ARG[2]` (filter string), `$ARG[3]` (data reference), `$ARG[5]`/`$ARG[6]` (key substitution), and flags for `reverse_sort` and `encode_perl_refs`. Returns a formatted string (or warns if called without arguments).

## Role & dependencies
Serves as a core utility for introspection/debugging. Notable callee: `<[base.parser.harmonized_reference]>` for decoding reference addresses. It also calls itself recursively for nested structures.

## Observations
- **Dead code**: The final `else` branch (lines 90–93) is unreachable when `$ARG[0]` is defined, and the comment notes the underlying subroutine no longer exists.
- **Hardcoded limits**: Arrays are truncated at 42 elements; strings are capped at 68 characters.
- **Fragile regex**: `$ARGkey =~ m|[\. \'#]|` uses a bare `|` which may not behave as intended in all Perl contexts.
- **Tied value handling**: Tied scalars/arrays/hashes are reported but their values are never dereferenced.
- **Missing metadata**: Validation failed due to missing `descr` field.
- **Style**: The module uses AMOS7's `<module.subroutine>` dispatch syntax and comment-based metadata, which is non-standard Perl.

## Confidence
Unclear whether the `warn` in the dead branch is intentional (e.g., for backward compatibility) or a leftover. The exact semantics of `$ARG[4]` (namespace prefixing) are also unclear from context alone.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.dump_data':

ERRORS:
  ✗ missing or invalid metadata field 'descr'
```

#,,..,..,,,.,,,,.,,.,,.,,,,,.,..,,.,,,..,,.,,,..,,...,...,...,.,,,.,.,..,,,,.,
#QMLP6TPEEBXGUNZR2SVN52TLSCZGMXRRWFH67ZR6ETK45EMRLR2H3CMDHKETREDSNL2VR6U2DE2TU
#\\\|ALAQ26DSVJ2YG5ISVSDPLTQMRGPXN2YK5IAZSICHZXJCS6AGP3W \ / AMOS7 \ YOURUM ::
#\[7]WFY3KBSEZV22RDO62K6AIFECKMAPMDMZ2PRHYR5AMTNLMMK7OWCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
