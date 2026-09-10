---
module: base.X-11.wait_for_window
generated_at: 2026-09-09T23:38:47
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 43d5cea2e2cdd64b56d05a95299f78506823b3df
source_lines: 65
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1212
usage_completion_tokens: 602
---

# review: base.X-11.wait_for_window

## Purpose
This module waits for an X-11 window to become visible by sending a `wait_visible` command to a cube socket and polling for a reply. It returns the X window ID on success or `undef` on failure.

## Interface
- **Arguments:** `$name` (required window name), `$user` (default 'cube'), `$cmd_path` (optional command path prefix)
- **Returns:** X window ID on success, `undef` on failure

## Role & dependencies
This module is called by 6 other modules (per the dep-graph). It depends on:
- `<x11.window_timeout>` and `<x11.id>` configuration values
- `<system.zenka.name>` and `<system.zenka.subname>` for auto-naming
- `<base.log>` for logging
- `<base.gen_id>` for generating command IDs
- `<base.net.send_to_socket>` for socket communication
- `$data{'user'}{$user}{'session'}` for session state

## Observations
- **Missing metadata:** The module lacks a `descr` field, flagged as an error by the validator.
- **Format warnings:** Five occurrences of `format.log_singular` suggest inconsistent pluralization in log messages.
- **Fragile socket handling:** The `while` loop relies on `$reply_string` being defined and non-empty; if the socket closes unexpectedly, the `die` message is generic (`<<<!>>> cube handle exception <<<!>>>`).
- **Tight coupling:** The module assumes `$data{'session'}{$local_sid}{'handle'}` exists and is a valid filehandle, with no defensive checks.
- **Regex dependency:** The success path requires `<x11.id>` to match the captured window ID from the reply string, creating a potential mismatch if the ID changes between the command and reply.

## Confidence
Unclear whether the `format.log_singular` warnings indicate a real problem or just a style preference. Also unclear if the module whitelist exclusion is intentional or a configuration oversight.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.X-11.wait_for_window':

ERRORS:
  ✗ missing or invalid metadata field 'descr'

WARNINGS:
  ⚠ format.log_singular : 5 occurrences [ first at line 19 ]
  ⚠ module not found in subroutine whitelist
```

#,,..,...,,,,,..,,,,,,.,,,,.,,,..,..,,,.,,,,.,..,,...,...,,..,..,,,,.,...,..,,
#PT3LB6MHI6IA3S54WQBUF2KGMWWYZVO4IIKACITHVY62IM5PEXBL4NXEHYC46PEDF4IPHPF4FNTYW
#\\\|5BNXHI6EERX2XXX3M5H2CHBNIPBFCDNWBPGQQGOYNFTEZ7ZC7SN \ / AMOS7 \ YOURUM ::
#\[7]2F3H5UX6JY43BEPIIXDXG3CF7ZR3YYSBUEV2S2PIREYNY6VZNICY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
