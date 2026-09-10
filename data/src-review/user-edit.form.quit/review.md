---
module: user-edit.form.quit
generated_at: 2026-09-09T23:07:40
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 79a36b93cdddfc9d354434f66f96ef5945482646
source_lines: 46
dep_graph_callers: 8
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 905
usage_completion_tokens: 581
---

# review: user-edit.form.quit

## Purpose
This module provides a centralized exit path for interactive forms, ensuring terminal state is always restored regardless of how the form is terminated. It clears the screen, optionally clears scrollback, restores terminal settings, and prints an outcome message before exiting.

## Interface
- **Arguments:** `$message` (string, optional), `$class` (string, optional, defaults to `info`)
- **Return value:** `TRUE`

## Role & dependencies
This is a funnel module — all exit paths from the form converge here. It depends on:
- `<user-edit.form.interactive>` — checks if currently in interactive mode
- `<user-edit.term_restore>` — restores terminal I/O settings (idempotent)
- `<user-edit.message>` — prints the outcome message
- `<base.exit>` — fires registered end_code callbacks (including a second term_restore call)

Notable: `term_restore` is called twice — once here, once via `base.exit`'s callback — which is intentional belt-and-braces for SIGTERM paths that bypass this module.

## Observations
- **Design strength:** The double `term_restore` call is a deliberate safety pattern, not a bug.
- **Information leak prevention:** Clearing the screen *before* printing the outcome message preserves the rendered record on screen — a thoughtful UX detail.
- **Scrollback is opt-in:** The `clear_scrollback` config flag keeps the default conservative, avoiding accidental data loss.
- **Whitelist warning:** The module is not in the subroutine whitelist — a potential security or instrumentation gap.
- **Style:** AMOS7 signature comment is present and properly formatted.

## Confidence
Unclear whether the double `term_restore` call could cause issues if the terminal state is already fully restored (though the comment claims idempotency). Also unclear why the module isn't whitelisted given it's called by 8 modules.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'user-edit.form.quit'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,,.,...,,..,..,,...,,,,,..,,.,.,...,,,.,,.,,..,,...,...,...,..,,,,.,...,..,,
#IEJ6FEBUCGE7YMHU4W5LT5JCFOUV3Q76ALGU6UDOVQDL4MPTDCRGHGYGIO4VPPFLJU7MTT6SI3WQI
#\\\|66ZT5VS6S4I56OOBO7XXJNQB27VKAZA7YMXHJXKV7QC4QBT6URU \ / AMOS7 \ YOURUM ::
#\[7]6FPMDVM3K6C2GQBF3PPCLEQKU77UJZPM2JPYZI44AOJUDJN6GUCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
