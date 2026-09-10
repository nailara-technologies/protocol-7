---
module: base.handler.write
generated_at: 2026-09-09T23:41:10
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: f17ea814daba3f5be2c80fad25881ae9c65757c9
source_lines: 161
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 2075
usage_completion_tokens: 706
---

# review: base.handler.write

## Purpose
This module writes buffered output data to a client socket handle. It manages session-based writes, handles socket buffer full conditions (EAGAIN), and orchestrates event watchers to retry writes when the kernel socket buffer drains. It also handles session shutdown and buffer exhaustion.

## Interface
**Arguments:** `$ARG[0]` — either a session ID (numeric string) or an `Event::Event::Io` object. Returns `FALSE` on success, `2` on shutdown, or implicitly `0` on failure.

## Role & dependencies
This is a core I/O handler in the AMOS7 stack, called by 6 modules via static dispatch. It depends on:
- `base.session.check_remaining` — session state validation
- `base.ssl.write` / `base.s_write` — actual socket write operations
- `base.stream.advance_drain` — stream drain tracking
- `event.add_io` — creates write-ready watchers
- `event.io_idle_restart` — deferred restart on idle
- `watcher.io.transfer` — transfer watcher management

## Observations
- **UTF-8 safety:** Uses `bytes::length()` consistently, avoiding character-count bugs with multi-byte sequences.
- **EAGAIN handling:** When `syswrite` returns 0, it creates a write-ready watcher via `event.add_io` to retry when the kernel buffer drains. This is a robust backpressure pattern.
- **Burst-write mode:** Allows up to `$session->{'burst-writes'}` consecutive restarts before deferring to an idle watcher, preventing excessive event loop churn.
- **SSL path:** Routes SSL sockets through `base.ssl.write`, suggesting TLS-aware write handling.
- **Watcher lifecycle:** Carefully manages `start`/`stop`/`cancel` on event watchers, with special logic for download handlers vs. var watchers.
- **No convention violations:** Both `module_convention_check` and `validate_module` passed cleanly.

## Confidence
Unclear whether `$session->{'burst-writes'}` is set externally or defaults to a safe value. The `return 2` on shutdown path is non-standard (usually `undef` or `0`), which may confuse callers expecting boolean success.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.handler.write'
No issues found.
```

#,,.,,.,,,,,.,...,.,,,,,.,..,,..,,,..,,..,.,.,..,,...,...,.,.,.,.,.,.,.,.,.,,,
#LDPHIDKURAJI4NDRL2LIY4LDA3IPPMD7K7KDCL4JQ2GKUJUVLKOESRGSLBUKITQGRKZHTWMO26C4K
#\\\|XZNVCIEG3P5C6HQN4TUNX6JQ6P6TAIERD6JFVIIVANBFAGA7TV2 \ / AMOS7 \ YOURUM ::
#\[7]RHQEV42IKDSLGHSCLVMVDN27DJRXXTQ7P6XVFD2ALTNX6JGBDWBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
