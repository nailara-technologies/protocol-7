---
module: base.disable_command
generated_at: 2026-09-09T22:45:26
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: ab7020d87ce4f1055e4c11ff3473f50002d1d6ec
source_lines: 45
dep_graph_callers: 12
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 859
usage_completion_tokens: 589
---

# review: base.disable_command

## Purpose

This module permanently disables or removes specific commands from the zenka memory system. It takes a list of command names and removes them from internal data structures, returning a count of how many commands were successfully unloaded.

## Interface

**Arguments:** `@ARG` — a list of command names to disable. Returns `undef` if the list is empty.

**Return value:** Integer count of commands actually removed from the codebase.

## Role & dependencies

This module is a utility called by 12 other modules (per the dep-graph). It relies on `$data{'disabled_commands'}` for persistence tracking and performs deletions across three locations: `%code`, `<base.cmd>`, and `<base.commands>`. Notable callees include `base.reverse-sort`, `base.logs`, and `base.cnt_s`.

## Observations

- **Fragility:** The module assumes `$data{'disabled_commands'}` exists and is an array reference. If this is not properly initialized elsewhere, the `push` operation may fail.
- **Coupling:** It directly mutates `%code`, `<base.cmd>`, and `<base.commands>` — three separate data structures. This tight coupling means changes to any of these could break the module.
- **Style:** The `##` comments are AMOS7-specific metadata markers. The `BNQHIT4EGN4XL4ZLA7IW4RCYYP5XVXFV6XMYDWDWXDEBQ4AQ5RSBDS53XFWWAPDUXJIBUWPPR23DA` signature line appears to be a data signature for integrity verification.
- **Logic:** The `@requested == 0` guard prevents silent no-op behavior, which is good. The `already_disabled` map prevents duplicate entries.

## Confidence

Unclear whether `<base.cmd>` and `<base.commands>` are the same underlying hash or distinct structures — the module deletes from both, suggesting they may be separate. Also unclear if `$data` is always accessible in the calling context or if it requires a specific initialization path.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.disable_command'
No issues found.
```

#,,,.,..,,,..,,.,,,..,,.,,.,.,,.,,,.,,..,,...,..,,...,...,.,.,,.,,,,.,.,.,,.,,
#73XWP3YYEPJNYL3TJZ2KA4CS7HUL7RVXVLVT6XS4JMYHME5PGGB7BISQM632P4ESMVIZULIHCA5OE
#\\\|FN4G6PSY66ZTGRUJWNRLW4K475PPTA4CWAJFNLNJ7CR46EIAAYA \ / AMOS7 \ YOURUM ::
#\[7]5TV6PTOWLJCFJF72Y6377LCNSIVRULFYXZTXHMMUYSKP2UQ6GEBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
