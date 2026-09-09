---
module: base.event.add_timer
generated_at: 2026-09-09T09:59:21
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: b633277500177a9ff795749951eaada4ebd47263
source_lines: 81
dep_graph_callers: 242
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1199
usage_completion_tokens: 749
---

# review: base.event.add_timer

## Purpose
This module installs a timer watcher by creating an `Event->timer` object. It accepts a hash of parameters to configure the timer's behavior (handler, interval, priority, etc.) and returns a timer reference or `undef` on failure.

## Interface
**Input:** A hash reference with optional keys: `handler` (string name), `cb` (code reference), `interval`, `reentrant`, `prio`, `async`, `desc`, `time`, `hard`, `data`.
**Return:** A timer object reference on success, `undef` on failure.

## Role & dependencies
This module is a thin wrapper around `Event->timer`. It fits into the event system as a timer-creation utility. Notable callees include `Event->timer` and template helpers like `<[base.s_warn]>` and `<[base.str.eval_error]>`. The `@ARG` variable used in the wrapper subroutines is not defined within this scope, suggesting it may be a global or context-dependent variable.

## Observations
- **Fragility:** The `$code{$cb_name}` global hash is used to store callbacks, creating coupling to an external registry. If the hash is cleared or modified elsewhere, timers may break.
- **Unclear variable:** `@ARG` is used in the wrapper subs but never defined in this scope — its origin is unclear.
- **Validation check discrepancy:** The deterministic check reports "missing signature footer," yet the source clearly contains a signature footer (the AOGRZWAVWK... line). This may indicate a false positive or a specific format requirement not met.
- **Error handling:** The `eval` around `Event->timer` is good, but the error message uses a template placeholder `<[base.str.eval_error]>` whose output is unclear.
- **Redundancy check:** The `handler` vs `cb` redundancy warning is helpful but returns `undef` on conflict, which may be overly strict.

## Confidence
Unclear where `@ARG` is defined — it appears to be a global or context variable not visible in this module. The signature footer validation failure is contradictory to the visible source.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.event.add_timer':

ERRORS:
  ✗ missing signature footer
```

#,,.,,,,,,,..,...,...,.,.,,.,,..,,,.,,..,,,,.,..,,...,...,,..,,,.,...,...,,,.,
#U7BZWWAZBC4DK7AIVPKP5J6W3Z4A57BJ4DI3ZHMWHB75N65XEG34YAP3NEK4FJNHXK7DIENLRL6NY
#\\\|C6YRXZEVETLA4J756YYNUN45B2K5KUFTWC5YENDGEIDUF6TCIDX \ / AMOS7 \ YOURUM ::
#\[7]56P5MJ2KPQDYCHQHSWNBQLSYQCC6UEO3N4SB5A6ZLIK5332CZ2AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
