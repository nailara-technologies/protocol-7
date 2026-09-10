---
module: editor.control.multiline.lines
generated_at: 2026-09-09T23:45:10
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: b1f01f7ec4047dd1ea7b273fe8ad5866f268d940
source_lines: 30
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 805
usage_completion_tokens: 609
---

# review: editor.control.multiline.lines

## Purpose

This module splits a text buffer into display lines using `split m|\n|`, with a critical `-1` limit that prevents Perl from silently dropping trailing empty fields. This preserves trailing blank lines in prose, which is semantically meaningful.

## Interface

- **Input**: `$text` (scalar, optional — defaults to empty string)
- **Output**: A list reference containing all split lines, including trailing empty ones

## Role & dependencies

This is a utility module called by `user-edit.form.build_frame` and `editor.ui.ascii_frame.render_form` to determine how many rows a multiline field needs. It's also referenced by `editor.control.list.summary` for consistency in line-counting logic. The module is deliberately excluded from the subroutine whitelist (a noted warning).

## Observations

- The `-1` limit is **load-bearing**, not cosmetic — without it, `"para one\n\n"` would lose its trailing blank line on round-trip. This is the module's entire raison d'être.
- The module is a thin wrapper around Perl's `split`, making it fragile to any changes in Perl's `split` behavior.
- The extensive comment block documents the design rationale well, which is good for maintainability.
- The module is not in the subroutine whitelist — unclear whether this is intentional or an oversight.

## Confidence

I'm confident about the `-1` limit's significance (well-documented in the source). I'm less certain about the whitelist warning — it may be a known limitation or a genuine issue. The module's role as a "single source of truth" for line splitting is clear from the comments.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'editor.control.multiline.lines'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,.,,,.,,..,,,..,...,..,,,.,,,,.,,,,,...,.,,,..,,...,...,...,...,.,.,..,,,,,,
#J5E2FQ4OJGQ2PYJEZ7JAT7HONUNWL3NRNAO4F42JNQLPNZH3JZIEX53IL4IXMRUZOH2Z7FS2NZ5NY
#\\\|QXNCFTHLGIJ53BNWN4NK6UGS5N5T4WFSK4D3FEPVL3ZGFKCXVUE \ / AMOS7 \ YOURUM ::
#\[7]425CMRL5SYDTRVXNCCOURM7C3TK432OTUMBQIHLI47IYHMXZB2DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
