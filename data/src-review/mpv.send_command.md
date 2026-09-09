---
module: mpv.send_command
generated_at: 2026-09-09T10:07:15
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 3662e4082a7ce16c7fbc2772e44ac4fc2907ecc8
source_lines: 54
dep_graph_callers: 46
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1157
usage_completion_tokens: 546
---

# review: mpv.send_command

## Purpose
This module sends MPV commands over a JSON socket connection. It assigns a unique request ID, serializes arguments into JSON, and either writes immediately or buffers the command if the player socket isn't yet ready.

## Interface
Takes `@ARG` (command arguments) as input. Returns nothing explicitly (void). The caller is responsible for registering reply bookkeeping via `mpv.reply_ids` or `mpv.command.reply`.

## Role & dependencies
It is a core communication layer in the MPV control stack, called by 46 modules via static literal dispatch. It depends on `base.log`, `mpv.request_id_seq`, `mpv.json.command`, `base.logs`, `mpv.reply_ids`, `mpv.command.reply`, `mpv.pending_reply`, `mpv.socket`, and `base.s_write`. It feeds into `mpv.handler.pipe_output` for reply matching.

## Observations
- **Fragility**: The module assumes `mpv.reply_ids` and `mpv.command.reply` are pre-populated by the caller. If a caller forgets to register, `success_reply_str` is deleted without a reply being stored, silently losing the response.
- **Coupling**: The synchronous reply bookkeeping (`delete <mpv.success_reply_str>`) tightly couples the caller's registration to this module's internal state.
- **Style**: The AMOS7 signature footer is present but the module lacks the required `descr` metadata field and proper signature footer (validation FAILED).
- **Logging**: Uses `"log"` singular twice (line 5 and line 32), likely a typo for `"logs"`.
- **Buffering**: Commands are buffered in a simple array (`mpv.pending_commands`) without priority or dependency tracking, which the comment acknowledges as a simplification over the previous jobqueue approach.

## Confidence
Unclear whether `mpv.pending_commands` is ever drained or if buffered commands are replayed atomically. The comment references `mpv.startup.handler.socket_ready` but the replay mechanism isn't visible here.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'mpv.send_command':

ERRORS:
  ✗ missing or invalid metadata field 'descr'
  ✗ missing signature footer

WARNINGS:
  ⚠ format.log_singular : 2 occurrences [ first at line 5 ]
  ⚠ module not found in subroutine whitelist
```

#,,.,,,..,,..,,..,,..,...,,.,,,..,,.,,...,,..,..,,...,...,,,,,..,,...,.,.,..,,
#X3QRKNX757YOIO2IBY4T5QRAEHWA3UQ5LQ43NQXFTZ7G2QBL544GUOT2DRHYSI4IVEMSCUABBQQDW
#\\\|Q3MHKMDWPWU2A5E4IGLN5QPPFEWNVXF43O3SM5U7NURLY7ECMXN \ / AMOS7 \ YOURUM ::
#\[7]GHXVIB4WWQMU3YFVDORX4CXXWLRIBFZHZFUS26V3EDMUQSA3L6CI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
