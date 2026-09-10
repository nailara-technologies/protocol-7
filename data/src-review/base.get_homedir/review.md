---
module: base.get_homedir
generated_at: 2026-09-09T23:40:04
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: f2710d12f8aa0288b96ab32840d1f3698d1d490c
source_lines: 52
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 990
usage_completion_tokens: 597
---

# review: base.get_homedir

## Purpose

This module resolves a user's home directory path, supporting multiple resolution strategies: environment variables (`HOME`, `LOGDIR`), environment user variables (`USER`, `LOGNAME`), the current process's UID, or a provided username. It returns the resolved home directory string or an empty string on failure.

## Interface

- **Arguments**: Optional `$user` parameter (string or empty).
- **Return**: A string representing the resolved home directory path, or empty string on failure.

## Role & dependencies

This module is called by 6 other modules (static literal calls). It depends on:
- `base.logs` — for logging at severity levels 0, 2
- Perl's `unix.pm` — for `getpwuid` and `getpwnam`
- `%ENV` — for `HOME`, `LOGDIR`, `USER`, `LOGNAME`

## Observations

- **Validation failure**: The deterministic check reports a missing or invalid `descr` metadata field — this is a compliance issue for AMOS7 modules.
- **Fragility**: The module assumes `getpwuid` and `getpwnam` always return arrays with at least 8 elements. If either fails silently or returns fewer elements, `$pwnam[7]` could be undefined, causing `$homedir` to be empty without a clear error path.
- **Coupling**: The module tightly couples to `base.logs` and the `%ENV` namespace, making it harder to test in isolation.
- **Style**: The `qw| :env-homedir: |` comparison is unusual — it compares a scalar against a list, which works but is non-idiomatic.
- **Edge case**: When `@pwnam == 0`, the module logs but still returns `$homedir` (empty), which may confuse callers expecting a failure signal.

## Confidence

Unclear whether the module is intended to be called with a username that may not exist on the system. The behavior in that case (returning empty string) is not explicitly documented. Also unclear whether the module should raise an exception or return a special value on failure.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.get_homedir':

ERRORS:
  ✗ missing or invalid metadata field 'descr'
```

#,,.,,,..,,..,,..,.,.,,.,,,,,,.,,,,.,,,..,,,,,..,,...,...,,..,.,,,,,,,,..,...,
#DDAXJUNSYUDYWYKFM4OKNOFAI354UDLQOJRM3FJ2RJ2INO6N4I5NLKRDTR63K5CEZJSKAENIQDUXK
#\\\|3AM57GQ4EUVYSCW5KPI7JN2CU2YCHMGPMDE3QDV4ZCQH7J2O6WA \ / AMOS7 \ YOURUM ::
#\[7]G5LH42TCZVQZF7X3YACQMNWYEFOH2QK4TSWBVWUSJMOP2LR5IOAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
