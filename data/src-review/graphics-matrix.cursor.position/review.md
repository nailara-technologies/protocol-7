---
module: graphics-matrix.cursor.position
generated_at: 2026-09-09T22:49:26
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 21e72f9ed8d5d2d6981081cdc283f8cfe01dc21b
source_lines: 21
dep_graph_callers: 11
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 654
usage_completion_tokens: 506
---

# review: graphics-matrix.cursor.position

## Purpose
This module returns the current cursor position and state from the graphics-matrix cursor system. It extracts five fields (selX, selY, selZ, zoom, radius) from a global cursor object and returns them as a shallow copy hash.

## Interface
**Input:** None — reads from a global `$cursor` variable.
**Output:** A shallow copy hash containing: `selX`, `selY`, `selZ`, `zoom`, `radius`.

## Role & dependencies
This is a thin accessor module that depends on `graphics-matrix.cursor` (imported via `my $cursor = <graphics-matrix.cursor>;`). It is called by 11 other modules (per the dep-graph), suggesting it serves as a read-only data source for cursor state across the codebase.

## Observations
- **Shallow copy design** is intentional (documented in comment), preventing callers from mutating the internal cursor state.
- **Global dependency** on `$cursor` creates coupling to the `graphics-matrix.cursor` module; changes there could break this module silently.
- **No subroutine whitelist entry** — flagged as a warning in validation. This may indicate it's not meant to be called dynamically or is an oversight.
- **Data signature** at the bottom (AMOS7 format) suggests this module is part of a larger data serialization framework.
- **No error handling** — if `$cursor` is undefined or missing keys, the module will return `undef` values without warning.

## Confidence
Unclear whether the lack of a subroutine whitelist entry is intentional (module is purely data-returning) or an oversight. Also unclear if the global `$cursor` is guaranteed to be initialized before this module is called.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'graphics-matrix.cursor.position'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,..,,,,,,,,,..,,...,.,.,,.,,,.,,.,,,,..,..,,..,,...,...,..,,.,.,,..,,,,,..,,
#KOPVZTVED2LWX7LZEWNQ2YLIWPQCETVYRW32HG7PWXCCTBLTT3NW64ZPQWXYQ2P7QT7SXFWYHMIDQ
#\\\|IUSJQPCB4NBW46WJ334VACYMXMCKXL7KJHHKGJDLCJJTKXU7FQU \ / AMOS7 \ YOURUM ::
#\[7]LAU67KBEKLRK7YU3SQ2KYG6NYRLE4M7UZDR3A6SS2ADPLROBJKCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
