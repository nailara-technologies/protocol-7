---
module: base.protocol-7.command.send.local
generated_at: 2026-09-09T09:59:39
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: e5cdf205dd3abe6adf70bcc483b3fdf64b89c1c0
source_lines: 188
dep_graph_callers: 184
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 2483
usage_completion_tokens: 765
---

# review: base.protocol-7.command.send.local

## Purpose

This module handles local command sending within a Protocol-7 session. It validates incoming commands, resolves routing targets (by session ID or username), and appends formatted command strings to target session buffers. It also logs network traffic based on configurable verbosity levels.

## Interface

**Input:** `$ARG[0]` contains `{'command' => $cmd, 'call_args' => {...}, 'reply' => {...}}`. The command is parsed via a regex capturing the target name.

**Return:** Number of targets processed (`$count`), `-1` if no clients in session, `0` if target unknown, `-2` on protocol mismatch.

## Role & Dependencies

This is a leaf command handler (184 static callers). It depends on:
- `<[base.caller]>` — caller level detection
- `<[base.logs]>` — logging output
- `<[base.gen_id]>` — command ID generation
- `<[base.route.add]>` — route setup
- `<[base.session.calc_cmd_stats]>` — command length statistics
- `<[base.zenki.resolve_routing_sids]>` — multi-instance disambiguation
- `<[base.s_warn]>` — warning output

## Observations

**Validation failures:** The module lacks a `descr` metadata field and a signature footer, causing `validate_module` to fail.

**Regex fragility:** The command parsing regex `s|^([^\.]+)\.((([^\.]+)\.)*\w[\w\d\_\-\.]*(\s.+)?)$|$2|go` is complex and may be brittle with edge cases (trailing dots, special characters).

**Hardcoded assumptions:** The code assumes `$data{'session'}` and `$data{'user'}` exist without prior checks. The session mode check (`$session->{'mode'} ne qw| client |`) suggests a specific enum that may not be documented.

**Dead code:** Multi-line command mode (lines 105–120) is commented out but still present.

**Logging logic:** The nested conditional for log filtering is dense and may be hard to maintain. The `devmod.skip_log_msg` and `devmod.skip_v7_heartbeat` flags suggest runtime toggling of logging behavior.

## Confidence

Unclear whether `$data{'session'}` and `$data{'user'}` are guaranteed to exist at module load time. The exact semantics of `base.route.add`'s return value are not documented in the source.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.protocol-7.command.send.local':

ERRORS:
  ✗ missing or invalid metadata field 'descr'
  ✗ missing signature footer
```

#,,.,,.,.,,,,,,,,,,,,,.,,,,,.,..,,.,,,,..,,.,,..,,...,...,...,,.,,,,,,..,,...,
#P4FGY5NO5ZRGJMAUNW4SPAUAAWCWD2RQTOO454OFJKGDFAUE4POJW6ODANUWSQ53GZI7OFKZUQNE2
#\\\|2VTA4LVNNN7WVCAYOP4KYSQ3IYGWJYO4MYQ2INKXP5K5J6IXOBL \ / AMOS7 \ YOURUM ::
#\[7]WSAJKQYRZW63Z7Q2GCB2GUNFSMH2UNRJBDKTM267HK7VWB3APGDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
