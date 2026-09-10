---
module: base.reverse-sort
generated_at: 2026-09-09T22:34:11
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 1425b0ed7f36a4b4f56250d2e7ec0a7cc6b0cbae
source_lines: 16
dep_graph_callers: 50
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 596
usage_completion_tokens: 517
---

# review: base.reverse-sort

## Purpose

This module sorts a list of strings by length in descending order (longest first). It filters out undefined values before sorting and returns an empty list when no parameters are provided.

## Interface

**Arguments:** Accepts a list of strings via `@params` from `base.context.list`.

**Return value:** A list of strings sorted by length, longest first. Returns `()` if no parameters are provided.

## Role & dependencies

This module is called by 50 other modules (per the dep-graph). It depends on `base.context.list` for parameter retrieval. The sorting logic uses Perl's built-in `sort` with a custom comparator (`length $b <=> length $a`) and `grep {defined}` for filtering.

## Observations

- The `grep {defined}` filter is a reasonable defensive measure against `undef` values in the input list.
- The `reverse sort` combined with the length comparator achieves the "longest first" ordering.
- The data signature at the bottom appears to be a checksum or integrity marker (AMOS7 convention).
- No convention violations were found in the deterministic check.
- The module has moderate coupling to `base.context.list` — if that module's interface changes, this module would break.
- The `reverse sort` is somewhat redundant with the comparator logic (one could use `length $b <=> length $a` alone with a negative comparator), but the current approach is clear and correct.

## Confidence

Unclear whether `base.context.list` is a module or a subroutine call — the syntax `<[base.context.list]>` suggests a module import, but the exact mechanism isn't fully documented in the source. Also unclear whether the data signature is verified at runtime or is purely a comment.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.reverse-sort'
No issues found.
```

#,,..,...,...,,,,,.,,,.,,,...,.,,,..,,,,.,.,.,..,,...,...,.,.,,,,,...,,.,,.,.,
#A4YCRQYAO4PPJH25OWZONMZOJQGZKDTNXVXCPKAEWDJMFW7HSTQNIXVDWMCBV5Y2LJ7TKMLEFS6XC
#\\\|EJ2XM5UAZDWTAC77SBPBPIBURU7QJMJCVBZ3AJA5M4MAOVGKBLH \ / AMOS7 \ YOURUM ::
#\[7]UNIBRLSPFU6JORG7FNHRZYS32767GQRNLLDHNMWSK55MZT5ZHQCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
