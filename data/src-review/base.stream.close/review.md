---
module: base.stream.close
generated_at: 2026-09-09T10:16:51
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 073573297d70828d447f2d6e6412c5750a057add
source_lines: 63
dep_graph_callers: 18
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1125
usage_completion_tokens: 611
---

# review: base.stream.close

## Purpose
This module closes an open stream by emitting a "close" frame if the session is still alive, and cleans up producer-side state regardless of whether the close frame is emitted. It also nudges an idle-shutdown watcher to ensure timely processing.

## Interface
- **Argument**: `<handle>` — a HASH reference containing `sid`, `cmd_id`, and `type` keys.
- **Return**: `1` on a clean close (close frame emitted), `0` if gated (session already gone/cancelled).

## Role & dependencies
This module is called by 18 other modules (per the dep-graph). It depends on:
- `base.stream.gate` — checks session liveness
- `base.stream.record_emission` — logs the emission
- `watcher.io.transfer` — idle-shutdown watcher (used conditionally)
- `bytes::length` and `utf8::downgrade` — buffer handling utilities

## Observations
- **Missing signature footer** — validation failed due to absent AMOS7 signature block at EOF.
- **`truefalse.guarded_return` warning** at line 11: the `return 0 if not defined $h or ref $h ne qw| HASH |` pattern is flagged as a guarded return.
- **Coupling to `watcher.io.transfer`**: The watcher is started conditionally in two branches (gated and success), but the watcher object may be undefined, requiring `defined` checks.
- **State mutation**: Directly mutates `$data{'session'}{$sid}{'streams'}{$cmd_id}` — assumes global `$data` scope.
- **Buffer handling**: Uses `utf8::downgrade` before appending to the output buffer, but the buffer's existence is assumed without prior validation.

## Confidence
Unclear whether `watcher.io.transfer` is guaranteed to be defined in all execution paths, or whether the global `$data` scope is reliably available across all callers.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.stream.close':

ERRORS:
  ✗ missing signature footer

WARNINGS:
  ⚠ truefalse.guarded_return : 1 occurrence [ first at line 11 ]
```

#,,,,,,,.,...,,,,,..,,,..,.,,,..,,..,,,,.,,.,,..,,...,..,,...,.,.,.,,,,..,...,
#3AQMSRJQE3DM5JA3SPGNEULZ3JL7NOMKYPLXJCMOWBUS6VSJSVXVPMASXWP6MVTOF3WQ7TXD4TEE6
#\\\|UEFC5N53ZI5JO27SSCBLITFZ4YYX6CK7NDDKODZ2H723LCCGLKD \ / AMOS7 \ YOURUM ::
#\[7]LPYFDVP6HVXYANPLH33GKKL4FYSFFFGRQ52ZLQAPUMLXP7FDOACQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
