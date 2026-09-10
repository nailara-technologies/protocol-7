---
module: base.handler.command
generated_at: 2026-09-09T23:03:55
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 67783fb685bfee95aa1fc8d42fd0b476efeda8e0
source_lines: 1099
dep_graph_callers: 8
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 4412
usage_completion_tokens: 645
---

# review: base.handler.command

## Purpose

This module handles Protocol-7 (AMOS7) command syntax parsing and dispatches commands to registered handlers. It manages input buffers, validates command IDs, processes multi-line commands, and handles incomplete SIZE/STRM/CHRSIZE replies by tracking remaining bytes/characters.

## Interface

Takes a single `$event` object (with `w` accessor for the watcher). Returns `0` on complete invalid commands, `1` on incomplete commands (re-triggering), or `2` on undefined states. No explicit parameters beyond the event object.

## Role & dependencies

Fits as a protocol-specific command dispatcher in the `base.handler` namespace. Notable callees include `<[base.logs]>`, `<[base.session.user]>`, `<[base.session.calc_cmd_stats]>`, `<[base.buffer.add_line]>`, and `<[base.timer.ondemand_timeout]>`. It also uses `<regex.base>` for command ID validation.

## Observations

- **Regex-heavy parsing**: The entire flow relies on regex capture groups (`${^CAPTURE}`), making it brittle to protocol changes. The truncated source (14000/10999 lines) suggests significant logic is missing from the view.
- **Custom accessor syntax**: `$input->$*` and `$session->{'buffer'}->{'input'}` suggest a non-standard object model that increases coupling.
- **Stateful session tracking**: The module maintains per-session state (`ignore_bytes`, `ignore_chars`, `read-mode`, `bytes-to-read`) which creates hidden dependencies on session lifecycle.
- **Style warnings**: `format.log_singular` (2 occurrences) and `truefalse.bool_assign` (1 occurrence) indicate style violations that could affect readability and maintainability.
- **Magic numbers**: Hardcoded values like `63 * 1024` for buffer size and `0 + ${^CAPTURE}[2]` arithmetic are scattered throughout.

## Confidence

Unclear on the exact semantics of `$input->$*` and the custom `<[module.func]>` call syntax — these are non-standard Perl constructs that make static analysis difficult. The truncated source means I cannot assess the full command routing logic or error handling completeness.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.handler.command'

WARNINGS:
  ⚠ format.log_singular : 2 occurrences [ first at line 35 ]
  ⚠ truefalse.bool_assign : 1 occurrence [ first at line 192 ]
```

#,,,,,...,..,,.,.,,,.,.,,,,..,,,.,..,,..,,,..,..,,...,...,.,.,.,,,..,,...,.,.,
#ZFNUV6IZMPZ55IGDK5QDU4OPPKICH66KDYCW7454BE7ILJHCRGIYQV4DLEODEEI2KRLM4I5CLMAK2
#\\\|HEBLVZIGBQTZZNT4SGYVLJHBFC6BIJ4EVKMSRY5FWUBAEH4IZC6 \ / AMOS7 \ YOURUM ::
#\[7]MD23BMGWQCEIW2B7RIJTP37EQ3JVP4H763HYRXPYHQGFLNSCTACA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
