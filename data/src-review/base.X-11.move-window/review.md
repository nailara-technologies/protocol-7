---
module: base.X-11.move-window
generated_at: 2026-09-09T23:08:31
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: a250dc943efc8aaabd8dcedbf412cbe2080adf6b
source_lines: 56
dep_graph_callers: 7
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1094
usage_completion_tokens: 566
---

# review: base.X-11.move-window

## Purpose
This module handles X-11 window move commands by receiving window geometry parameters, generating a command ID, sending the request to a Cube socket, and awaiting a TRUE/FALSE reply. It was updated to include width/height in the geometry request to fix WSLg/Weston placement issues for managed ticker windows.

## Interface
**Arguments:** `$id` (window id, numeric), `$x`, `$y`, `$width`, `$height`, `$user` (default 'cube'), `$cmd_path` (default '').
**Returns:** `TRUE` on success, `FALSE` on failure (with error logged).

## Role & dependencies
Fits into the AMOS7 command routing layer as a handler for `X-11.move-window`. Notable callees: `base.log` (logging), `base.gen_id` (command ID generation), `base.net.send_to_socket` (Cube IPC). It depends on `$data` being pre-populated with user/session information.

## Observations
- **Missing metadata:** The `descr` field is absent, causing validation failure.
- **Format singular warnings:** `format.log_singular` appears twice (line 18 and likely elsewhere), suggesting inconsistent pluralization in log messages.
- **Fragile socket handling:** The `while` loop assumes the Cube socket will eventually return a matching reply; no timeout or max-iteration guard exists, risking indefinite hangs.
- **Tight coupling:** Direct access to `$data{'user'}{$user}{'session'}` without validation could fail if session data is missing.
- **Style:** The long comment block at the end (data signature) is unusual and may be a fingerprint or checksum.

## Confidence
Unclear whether the `format.log_singular` warnings are actual bugs or just style nitpicks. Unclear if the data signature comment serves a runtime purpose or is purely decorative.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.X-11.move-window':

ERRORS:
  ✗ missing or invalid metadata field 'descr'

WARNINGS:
  ⚠ format.log_singular : 2 occurrences [ first at line 18 ]
  ⚠ module not found in subroutine whitelist
```

#,,.,,.,.,...,,,.,,,,,,,,,,,.,,,.,...,..,,...,..,,...,...,,..,...,.,.,,,,,,,,,
#HWKEPY7VIMKTSZBHSK44M3SWD4SAHXCM52CHPWNQQSL5RGBUK2Y2EHBCFM573J5FBIH7QEKKQX5VY
#\\\|53K7WMR7WIMRZWHZ3LZIGCATLXY7YF5G6ADDB2IYJB52SSBZAVX \ / AMOS7 \ YOURUM ::
#\[7]UF44TOLUXRZ2PHJO7JVGVSXXLN56S46BT3PDBSZP77BMNBY4RCDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
