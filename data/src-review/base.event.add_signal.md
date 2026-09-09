---
module: base.event.add_signal
generated_at: 2026-09-09T10:14:01
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 07aa042e3ab255ee018a9a49eda918206dc72ee0
source_lines: 71
dep_graph_callers: 20
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1082
usage_completion_tokens: 839
---

# review: base.event.add_signal

## Purpose
This module assigns a new signal handler and cancels any existing one for the given signal. It wraps custom callbacks or uses a registered handler from a `$code` hash, then registers the handler via an `Event->signal` constructor.

## Interface
**Arguments:** A hashref with keys `signal` (the signal name) and `handler` (a registered handler name) or `cb` (a custom callback). A second positional argument sets the log level (defaults to 2).
**Returns:** The registered event object, or `undef` on failure.

## Role & dependencies
This module is a caller of `Event->signal` and relies on global state (`<watcher.signal>`). It uses several callable references: `<[base.s_warn]>`, `<[base.logs]>`, `<[base.str.eval_error]>`, and `<watcher.signal>`. It also depends on a `$code` hash for registered handlers.

## Observations
- **Validation failure:** The module lacks a signature footer, causing `validate_module` to fail. This is a structural compliance issue.
- **Non-standard constants:** `FALSE` is used instead of `0` or `false`, which may break portability.
- **Unusual syntax:** `qw| CODE |` is used instead of `qw(CODE)`; while functionally equivalent, it's non-idiomatic.
- **Global state coupling:** `<watcher.signal>` is a global hash, creating tight coupling and potential race conditions in concurrent contexts.
- **Error handling:** The `eval` block catches `EVAL_ERROR` but only checks `length $EVAL_ERROR`, which may not reliably detect all failure modes.
- **Logic gap:** The `elsif ( defined $handler )` branch warns about "nonexistent callback" but doesn't explicitly check `$code{$handler}` existence — it relies on the earlier `exists $code{$handler}` check in the first branch.

## Confidence
Unclear whether `<[base.s_warn]>` and `<[base.logs]>` are truly callable references or if they're meant to be invoked differently. The `qw| CODE |` syntax is also non-standard and may indicate a template or macro expansion that isn't visible here.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.event.add_signal':

ERRORS:
  ✗ missing signature footer
```

#,,.,,.,,,...,.,,,..,,,..,.,.,,,.,..,,...,,..,..,,...,...,.,,,...,,..,,,,,.,.,
#552P37JBKNJLQ7W6OY2PHXV4ZPQ2PZFZGJHPS2VMA7NUAGRETIAHLBTZIAAVWELL2QERII6EU6SUS
#\\\|YP5LXTPABFCNJ7HUMDUTVLZW3SB6WXGBCONYV34PYFNMIKKEVTC \ / AMOS7 \ YOURUM ::
#\[7]MXXMAR6JM7WRFIOOTS2I6JUWWYPTICXEM7U6ZU5ZEX4HD6F6S6AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
