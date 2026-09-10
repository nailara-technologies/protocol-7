---
module: user-edit.form.build_frame
generated_at: 2026-09-09T22:43:53
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: c5d4955020c7c541f5252b143754fee7f1cce6f1
source_lines: 647
dep_graph_callers: 13
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 3911
usage_completion_tokens: 643
---

# review: user-edit.form.build_frame

## Purpose

This module generates an ASCII frame descriptor for a runtime-derived field set. It builds a mockup text in memory (since no YAML file exists for user-edit forms), parses it via `ascii.frame.parse`, and seeds the result into `ascii.frame.cache` for later retrieval by `render_form`.

## Interface

**Arguments:** `$editor_state` (HASH ref), `$frame_name` (optional), `$title` (optional).

**Return:** `undef` on validation failure (invalid state, missing fields, empty names); otherwise returns a frame descriptor structure.

## Role & Dependencies

Serves as a bridge between runtime schema and the ASCII frame rendering pipeline. Notable callees: `user-edit.form.field_options` (vocabulary), `editor.control.cycler.window_width` (fixed width constant), `editor.control.list.summary` (collapsed list display). It is called by 13 modules via static literal dispatch.

## Observations

- **Tight coupling:** The module hardcodes `42` and `45` as column offsets, tuned against `ascii.frame.render`'s live computation. These are fragile — any change in `render_form`'s column layout breaks the reservation.
- **Double-pass width reservation:** The module computes a static `min_width` per field, then `ascii.frame.render` recomputes from live values. The comment admits this is a "separate, later pass" — the two must stay in sync manually.
- **Magic number density:** 23-char checksum, 42-column start, 45-char reservation — all derived from live output rather than a shared constant.
- **Validation is minimal:** Only checks `HASH` ref, `fields` is an `ARRAY`, and names are defined/non-empty. No schema validation beyond that.
- **Deterministic checks passed:** No convention violations; module validation passed (though it's not in the subroutine whitelist).

## Confidence

Unclear whether the double-pass width computation is intentional or a known limitation. The comment suggests it was "tuned together against live output" — this implies manual calibration rather than a robust design. The module's correctness depends on `ascii.frame.render`'s column layout remaining unchanged.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'user-edit.form.build_frame'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,.,,,..,...,.,.,...,.,,,..,,,.,,,.,,.,.,,..,..,,...,..,,..,,,,,,.,.,,.,,.,,,
#ESLF2LKEXLCS22DH2IPOBEX4TMJ2CFKEZ36JJTXIDK72M7HGBCJXLOSYLNZWUUVX4DY5DV4XFD33U
#\\\|46FNFFOTJPFWXZL5ALGSQ2OHKJM77XU7YLLYFXVBVNEZS6XGI2D \ / AMOS7 \ YOURUM ::
#\[7]PVWTB4WDAHKVCE7FWIUBXK4AKMKU7LU5CPQX73LEX7XZJETWZMCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
