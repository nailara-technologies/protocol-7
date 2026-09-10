---
module: mpv.send_command
generated_at: 2026-09-09T22:35:20
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 73800e5d2e5649e35ada2a4c3cd0351ade9a88d8
source_lines: 55
dep_graph_callers: 46
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1153
usage_completion_tokens: 586
---

# review: mpv.send_command

## Purpose
This module sends JSON IPC commands to an mpv player instance. It generates a unique request ID, constructs a JSON command string, and either writes it directly to the socket or buffers it if the player isn't ready yet. Replies are matched back to commands by request ID rather than arrival order.

## Interface
Takes `@ARG` (JSON command arguments). Returns nothing explicitly (void). If the player is not ready, it returns early after buffering.

## Role & dependencies
Called by 46 modules (static literal calls). Depends on:
- `base.log` / `base.s_write` for logging and socket writes
- `mpv.request_id_seq` for request ID generation
- `mpv.json.command` for JSON serialization
- `mpv.reply_ids` / `mpv.command.reply` / `mpv.pending_reply` for reply bookkeeping
- `mpv.pending_commands` for buffering when the socket isn't open

## Observations
- The reply-matching logic (lines 20–31) is fragile: it pops from `mpv.reply_ids` and `mpv.command.reply` stacks, assuming they're non-empty. If a reply is dropped or reordered, the FIFO matching could desync.
- The buffering path (`mpv.pending_commands`) is a plain array push — simple but lacks priority or dependency tracking that was previously used via jobqueue.
- `format.log_singular` warnings appear twice (line 6), suggesting inconsistent pluralization in logging messages.
- The module is not in the subroutine whitelist, which may indicate it's not formally registered for static analysis.
- The `delete <mpv.success_reply_str>` is a side-effect that clears a global variable — coupling to caller state.

## Confidence
Unclear whether `mpv.reply_ids` and `mpv.command.reply` are guaranteed to be populated when a reply arrives, or if the `or` condition could ever be false when a reply is actually available.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'mpv.send_command'

WARNINGS:
  ⚠ format.log_singular : 2 occurrences [ first at line 6 ]
  ⚠ module not found in subroutine whitelist
```

#,,,,,,..,,,,,...,,,.,.,,,...,,,.,.,,,,,,,,,.,..,,...,...,,,,,,,.,,..,,.,,.,.,
#HAPYO73EJ6KOTLYU6XQCJ4QJAWSIS6RDJZPPGNTDIDIE2RNRQJNIHVRLBGXDZXV5E5PGG2F6EMUC6
#\\\|GJEPWVY37VXBDUC54XKYW7ABDR6OPSYVFS5W4N4VL6J7FCTPGM4 \ / AMOS7 \ YOURUM ::
#\[7]33TYTDODYVJ4SW632L7NPI7FBGFXU6PV4NRFC5RZVO2U7KCMBCDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
