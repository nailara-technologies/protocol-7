---
module: v7-zenki.teardown
generated_at: 2026-09-09T23:18:24
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 255034cf4741fd3432b28131a9f23975a4717706
source_lines: 151
dep_graph_callers: 7
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 2288
usage_completion_tokens: 780
---

# review: v7-zenki.teardown

## Purpose

This module shuts down v7 zenka processes, optionally with a reason message. It terminates child processes, waits for them, and handles orphaned processes before performing a silent cleanup and exiting.

## Interface

**Arguments:** `$reason` (string, optional), `$c_level` (caller level, optional).  
**Return:** None — the module calls `exit($exit_code)` at the end. The exit code is `1` if a reason is provided, otherwise `$CHILD_ERROR`.

## Role & dependencies

It is a terminal shutdown utility called by 7 other modules (per the dep-graph). It heavily relies on `<v7-zenki.child>` for process tracking, `<v7-zenki.sub-process.get_children>` for child discovery, and `<v7-zenki.zenka.instance>` for instance metadata. It also uses `<base.waitpid>`, `<base.logs>`, `<base.time>`, and `<system.kill>` for process control and logging.

## Observations

- **Fragility:** The module assumes `<v7-zenki.child>` is fully populated and accessible; any race condition or stale data could cause missed terminations.
- **Coupling:** It tightly couples to internal v7-zenki state (`<v7-zenki.child>`, `<v7-zenki.sub-process.orphan_pids>`) and system-level calls (`<system.kill>`, `<system.kill_timeout>`), making it brittle to refactoring.
- **Style:** Uses AMOS7-specific syntax (`<...>`, `//`, `qw|...|`) that is non-idiomatic Perl and may hinder portability or readability for external contributors.
- **Potential issues:** The `kill(9, keys %children_left)` call in the abort path passes a list to `kill`, which in Perl may behave unexpectedly depending on context. The `exit(1)` on abort may not be appropriate if the caller expects a different exit code.
- **Check output notes:** The `format.log_singular` warning at line 111 indicates inconsistent pluralization in log messages (`sub-processes` vs `sub-process`). The "module not found in subroutine whitelist" warning suggests `<v7-zenki.tmp-paths.global.clean-up>` may not be in the static analysis whitelist.

## Confidence

Unclear whether `<system.kill_timeout>` is a scalar or a subroutine call — the `//= ` syntax suggests assignment from a variable, but the notation is non-standard. Also unclear if `exit(1)` on abort is the intended behavior or if it should propagate a different code.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'v7-zenki.teardown'

WARNINGS:
  ⚠ format.log_singular : 2 occurrences [ first at line 111 ]
  ⚠ module not found in subroutine whitelist
```

#,,..,,.,,,,,,.,,,,,,,,..,,,,,,.,,,..,.,,,,,.,..,,...,...,..,,,.,,..,,,..,...,
#BHLJNJIMYTVXD562PAZXE4PNQLJBL7VZU6ZXAFJPBBYAXXL7ZWVWQVZWRBWAZC3OHSZXE2TJWX2X4
#\\\|3MFNXM265VRERQGLFD7ICNL5Q7L67JXRIIQQIVMF4IIMZILAKLN \ / AMOS7 \ YOURUM ::
#\[7]OIYOBL2BL5K5WOAH4OSCZA4KZXQGQMUXA6Y4F5DGBV3VXI4MI2BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
