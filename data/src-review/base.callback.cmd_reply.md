---
module: base.callback.cmd_reply
generated_at: 2026-09-09T10:02:05
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 57a1f55777e846abaf549155e81d6665b1f3f095
source_lines: 178
dep_graph_callers: 111
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 2326
usage_completion_tokens: 819
---

# review: base.callback.cmd_reply

## Purpose

This module delivers deferred replies to local command callers in the AMOS7 protocol. It resolves a reply ID against stored metadata, validates the reply payload, and formats output according to the specified reply mode (TRUE/FALSE/WAIT, SIZE, CHRSIZE, DATA, TREE, or TERM).

## Interface

**Arguments:** `$reply_id` (string/numeric ID), `$reply` (hash reference with mode/data fields).

**Return:** Nothing (void). Logs errors via `base.logs`, warns via `base.s_warn`, and writes formatted output to a filehandle stored in the metadata.

## Role & Dependencies

This module is a dispatcher for command reply handling, invoked by 111 callers. It depends on:
- `<base.cmd_reply>` — hash storing command metadata keyed by reply ID
- `<base.logs>` — logging facility
- `<base.s_warn>` — warning output
- `<base.caller>` — caller identification
- `<base32.encode>` — Base32 encoding for DATA/TREE frames
- `<base.reverse-sort>` — sorting TREE nodes by ref_count descending
- `<base.session.shutdown>` — session termination
- `bytes::length` / `utf8::upgrade` / `utf8::downgrade` — character/byte counting

## Observations

1. **Missing signature footer** — validation check reports "missing signature footer," indicating incomplete module metadata.
2. **Fragile mode validation** — the regex `m{^(size|data|tree)$}io` is case-insensitive but the comparison `uc($reply_mode) eq qw| SIZE |` later uses uppercase, creating potential inconsistency if `$reply_mode` contains unexpected casing.
3. **`$output->$*` syntax** — this non-standard Perl syntax (likely a Protocol-7 macro) is opaque and couples the module to an external macro system.
4. **`$code{'chk-sum.amos'}` fallback** — the checksum function lookup is dynamic and could fail silently if neither key exists.
5. **`$ARG->{'id'}` in TREE checksum** — uses `$ARG` (global) instead of `$node` variable, which appears to be a bug.
6. **`$output->$* .=`** — repeated use of this macro suggests tight coupling to a non-standard Perl construct.

## Confidence

Unclear on the exact semantics of `$output->$*` — whether it's a filehandle dereference or a macro expansion. The `$ARG` usage in the TREE checksum loop appears to be a bug but I cannot confirm the intended variable without seeing the caller context.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.callback.cmd_reply':

ERRORS:
  ✗ missing signature footer
```

#,,.,,,..,,..,.,.,,,,,.,,,,,,,..,,...,,,.,.,,,..,,...,..,,...,,.,,,,.,.,,,...,
#GMUYHA6N3QM6MKWA3K3GWJPARS6VUU265IESKYWYJDPAZKL4UR3HRN4LU2LTKIVE35IWGR6LMD3DU
#\\\|VWN46VEO2JCCWJXGUI2BR5F2D2UKXNGHCYQBF2F3HTFXNQFRZJZ \ / AMOS7 \ YOURUM ::
#\[7]RZPFVLHA2MA7RWGAUSQ4Q73FMB3OSH762TSVPZUZFMLCCUPZVSCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
