---
module: base.handler.sig_chld.shutdown
generated_at: 2026-09-09T23:40:33
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: f00fe486d2d57c799a45a6599d559ea1362b78de
source_lines: 77
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1320
usage_completion_tokens: 641
---

# review: base.handler.sig_chld.shutdown

## Purpose

This module handles SIGCHLD signals by waiting for child process termination, logging their exit status, and optionally triggering a shutdown based on configured PID filters. It distinguishes between expected and unexpected child exits, and supports an ignore list to suppress logging of known children.

## Interface

No explicit arguments or return value. It is invoked as a signal handler (implied by the `sig_chld` naming convention). The module relies on global state (`%died_pid`, `$do_shutdown`) and external configuration via `<sig.chld.ignore.pid>` and `<sig.chld.shutdown.pid>` hash references.

## Role & dependencies

This module is a leaf handler in the AMOS7 signal handling chain. It depends on:
- `<[base.waitpid]>` — for reaping children
- `<[base.logs]>` / `<[base.log]>` — for logging at various levels
- `<[base.exit]>` — for termination
- `<zenka.shutdown>` — to detect graceful shutdown signals
- `<system.zenka.name>` — to identify the running process

It is called by 6 other modules (per the dep-graph), indicating it is a central component of the process lifecycle.

## Observations

- **Missing metadata**: Validation failed due to a missing `descr` field — this breaks module registry compliance.
- **Format singular warning** at line 68 suggests a log message may use plural form incorrectly.
- **Coupling risk**: The module assumes `<sig.chld.ignore.pid>` and `<sig.chld.shutdown.pid>` are already defined hash references; if not, `exists` checks may behave unexpectedly.
- **Silent skip**: Ignored PIDs are deleted from the ignore list without re-logging, which could mask configuration drift.
- **Hard-coded signal logic**: Signal 9 (SIGKILL) and 11 (SIGSEGV) are treated specially; this may be intentional but lacks documentation.

## Confidence

Unclear whether `<[base.waitpid]>` with `-1` flag is the correct AMOS7 equivalent of `WNOHANG` — the comment suggests it, but the actual behavior is not verifiable from the source alone.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.handler.sig_chld.shutdown':

ERRORS:
  ✗ missing or invalid metadata field 'descr'

WARNINGS:
  ⚠ format.log_singular : 1 occurrence [ first at line 68 ]
  ⚠ module not found in subroutine whitelist
```

#,,..,.,,,,.,,...,...,,.,,..,,.,.,.,,,,..,.,,,..,,...,...,...,.,,,...,..,,..,,
#IYYLAWPFAJML22BYL7FDOMMY6P2E3MOYX72PYFSHDPJKKNMS6GOSVBSRJ56ZWINB4GLG4HW44SKE2
#\\\|6UXJ7QOU6GS4BFYHY7R73DHEY52NYHOUW2P6OQHPUQZFBJZZUPU \ / AMOS7 \ YOURUM ::
#\[7]5IINQSQTUH24HDUJP3BCUOMSSTPHN3VPUBHVDYKR5BUIO7LKFGCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
