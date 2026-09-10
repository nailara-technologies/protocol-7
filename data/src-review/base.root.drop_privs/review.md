---
module: base.root.drop_privs
generated_at: 2026-09-09T23:11:23
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 2031f0558c362b94f0150ea5c745d94c892831a9
source_lines: 278
dep_graph_callers: 7
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 3268
usage_completion_tokens: 1099
---

# review: base.root.drop_privs

## Purpose
This module switches the execution context to a specified Unix user, optionally overriding the primary group and managing secondary group membership. It handles home directory creation, temporary home directories for users like 'nobody', and records the resulting privilege state in the system.

## Interface
**Arguments:** `$user_spec` (user name, optionally with `:group` override), `@ARG` (optional group list), `$noop` flag.
**Returns:** On success, a hash with `uid`, `gid`, `all_gids`, and `home`. On failure, exits via `<[base.exit]>` or returns `-1`.

## Role & dependencies
Called by 7 modules. Heavily depends on `<[base.logs]>`, `<[base.exit]>`, `<[base.check_dependency_dirs]>`, `<[base.tmp_dir]>`, and `<system.zenka-user.current>`. Uses `getpwnam`, `getgrnam`, `getgrent`, `make_path`, `chown`, and `chdir` for system operations.

## Observations
- **Fragile control flow:** Multiple early exits (`<[base.exit]>`) make error paths hard to trace. The `noop` flag is checked inconsistently throughout.
- **`truefalse.bool_assign` warning** at line 105: `$noop` is assigned via a ternary expression rather than a direct boolean assignment, which may confuse downstream logic.
- **`format.log_singular` warning** at line 34: Logging format may not match expected singular/plural patterns.
- **`getgrent` loop** only executes once (no iterator reset), so secondary group auto-detection is a one-shot operation.
- **`make_path`** is called without a trailing slash on `$h_directory`, which may cause `make_path` to fail or behave unexpectedly.
- **`chown`** is called on `$h_directory` even when the directory may not exist (e.g., if `make_path` failed silently).
- **`split( ' ', $GID )`** will produce an empty list if `$GID` is empty, causing `%_gid` to be empty and breaking the `has_all_gids` check.
- **`qw| / |`** is used as a single-element array in some places, which is inconsistent with `qw| /var/tmp/ |` elsewhere.

## Confidence
Unclear whether `<system.zenka-user.current>` is thread-safe or whether the module is intended to be reentrant. The `getgrent` loop behavior is unclear — it may only run once per invocation, which could miss groups if the iterator isn't reset.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.root.drop_privs':

ERRORS:
  ✗ missing or invalid metadata field 'descr'

WARNINGS:
  ⚠ format.log_singular : 4 occurrences [ first at line 34 ]
  ⚠ truefalse.bool_assign : 2 occurrences [ first at line 105 ]
```

#,,..,.,,,,,,,..,,,,.,.,.,...,,,,,,.,,.,,,..,,..,,...,...,,,.,,,,,.,.,...,.,,,
#UI5YDZ4SMUHDXV47B6JRYANUPJZWHWI2X62R52LB5KE5NYOCHJN7FTHZ33NLXWQXDLXIP2S3RZOBW
#\\\|GHFF2J3SFDNQ4R7VXSGGPMWKUSHNAH2DYMIHZ74ZT7SPMAQSP7H \ / AMOS7 \ YOURUM ::
#\[7]IX5BCA5GZGUF6NYAFM52DWZR443A6M6KZLZN5NHRA5YZAOTTZ6BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
