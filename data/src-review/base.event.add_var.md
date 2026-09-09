---
module: base.event.add_var
generated_at: 2026-09-09T10:18:02
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 49a53bcfe53e244295c6fc115d167084d316cbca
source_lines: 46
dep_graph_callers: 17
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 939
usage_completion_tokens: 650
---

# review: base.event.add_var

## Purpose

This module registers a variable access watcher by installing a callback that fires whenever a specified variable is accessed. It wraps the user-provided handler for code reloading support and configures the watcher with optional parameters like polling, reentrancy, and priority.

## Interface

**Arguments:** A hash reference containing:
- `handler` — required callback reference
- `var` — required variable reference
- `poll` — default `qw| w |`
- `reentrant` — default `TRUE`
- `repeat` — default `TRUE`
- `prio` — default `2`
- `async` — default `FALSE`
- `desc` — default `$params->{'var'}`
- `data` — optional data payload

**Return:** `undef` on failure (missing/invalid params, unknown callback), otherwise returns the result of `Event->var()`.

## Role & dependencies

This module is a thin wrapper around `Event->var()`, delegating the actual watcher registration. It depends on `base.perlmod.autoload` and `base.perlmod.loaded` for lazy module loading, and on a global `$code` hash (not shown) for callback indirection. It is called by 17 other modules via static literal calls.

## Observations

- **Missing signature footer:** The deterministic check reports a validation failure due to a missing AMOS7 signature footer. This is a compliance issue.
- **Global `$code` hash:** The module relies on an external `$code` hash for callback lookup and wrapping. This creates coupling to an undefined global state.
- **Callback wrapping:** The `'cb' => sub { $code{$callback}->(@ARG) }` wrapper enables code reloading but introduces an extra indirection layer that could obscure failure points.
- **Error handling:** Uses `warn` for most failures but delegates to `<[base.s_warn]>` for the unknown callback case — inconsistent logging approach.
- **Early availability:** The autoload check ensures `Event` is available before calling it, which is a reasonable pattern.

## Confidence

Unclear whether `$code` is a module-level or package-level hash, and whether the `Event` module's `var` method signature is stable across versions.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.event.add_var':

ERRORS:
  ✗ missing signature footer
```

#,,.,,..,,.,,,,,,,.,,,,.,,,.,,,..,,.,,,.,,..,,..,,...,...,..,,.,,,,,.,...,..,,
#NGHLHOMG4DGU6GU65NFQWRJRKQIVW3SMHI2G5RANBV6YUJZFFR6UW6JP3ED4QVT3GSUFJRNGPC2US
#\\\|CMYOS6PKFRCLNAWTLRHC5ZOZ6QQWTGS64UHHQHXID2UI35FMJUP \ / AMOS7 \ YOURUM ::
#\[7]GUAD73TWD3JGAUYSSA4G4XREWFOXJEHRTZXLP7RHURWRDUYWTCBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
