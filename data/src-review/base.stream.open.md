---
module: base.stream.open
generated_at: 2026-09-09T10:22:31
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 81200dfcfe773abdac6efc5e310a7b617615feb6
source_lines: 71
dep_graph_callers: 15
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1267
usage_completion_tokens: 871
---

# review: base.stream.open

## Purpose
This module opens a reply stream (STRM or STRM-SIZE type) for a given session, registers producer state, emits an 'open <total>' frame, and returns a handle for subsequent push/close operations.

## Interface
**Arguments:** `{ sid => ..., cmd_id => ..., type => 'STRM'|'STRM-SIZE', total => N|undef, cmd_id_str => '(NNN) '?, upstream => ... }`
**Returns:** A hashref with `sid`, `cmd_id`, `type`, `total`, and `upstream` on success; `undef` on failure (invalid type, invalid total, or missing session).

## Role & dependencies
This module is called by 15 other modules (static literal calls). It depends on:
- `<[base.logs]>` — for error logging
- `<[base.stream.gate]>` — for session lookup
- `<[base.ntime]>` — for timestamping
- `bytes::length` — for frame length calculation
- `<[base.stream.record_emission]>` — for emission recording

## Observations
- **Validation failure:** The module has a signature footer but the validator reports "missing signature footer." The footer format (`#6A6EILBGPXDT...`) may not match the validator's expected format, or the validator may require a different structure.
- **Type coercion:** `$total` is coerced with `0 + $total` — this silently converts non-numeric values to 0, which could mask bugs.
- **Error handling:** Errors are logged but not returned as structured errors; callers must check for `undef` return.
- **Coupling:** The module tightly couples to internal session state (`$session->{'streams'}->{$cmd_id}`), making it hard to test in isolation.
- **Style:** The signature footer is placed at the end of the file, but the validator appears to expect a different format or placement.

## Confidence
Unclear why the validator reports "missing signature footer" when a footer is visibly present. The footer format may not match the validator's expectations, or the validator may have a specific structural requirement (e.g., specific header line, checksum validation, or placement relative to other code).

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.stream.open':

ERRORS:
  ✗ missing signature footer
```

#,,.,,.,,,,,,,..,,,,.,,..,,,.,,,,,,,.,..,,,,.,..,,...,...,.,.,.,.,,..,,,.,...,
#NERDQS5MFOM2GD3FHLRQYPP74NBFUEUBRHVY7OHRYH33TPQEBCS3BTT7MM3CKHLTXCKINWWGTRIWM
#\\\|4QAX5NA6WHREORWGEYLLDWVRKDBBRTCOJBC6VEEWYI2RPEOWNYQ \ / AMOS7 \ YOURUM ::
#\[7]NLQCTUZ6BW2GU7HUFYELSONM7GLI6OXDNWIMRA2L7OI34BZP4CBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
