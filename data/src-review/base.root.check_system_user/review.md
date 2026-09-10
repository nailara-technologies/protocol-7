---
module: base.root.check_system_user
generated_at: 2026-09-09T23:42:36
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 606947c234285b4fe2e6d1227db7c0f9947790c0
source_lines: 131
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1931
usage_completion_tokens: 812
---

# review: base.root.check_system_user

## Purpose
This module creates a system user via the `useradd` binary if the user does not exist, or confirms the user already exists. It optionally creates a key directory structure for C25519 cryptography under the user's home directory.

## Interface
Takes two parameters: the username to create, and an optional `'not-home'` flag to skip home directory creation. Returns `TRUE` on success (user created or already exists), `FALSE` if not running as root and user doesn't exist, or `undef` on failure (missing binary, error, or no user parameter).

## Role & dependencies
Part of the `base.root` module family. Notable callees include `base.logs`, `base.caller`, `base.cfg_bool`, `base.get_homedir`, `base.stderr_redir`, `base.stderr_restore`, `file.make_path`, and `base.root.pref-uid`. It also depends on `base.root.init_code` and `base.root.useradd.exit-codes` for initialization.

## Observations
- **Validation FAILED** for missing `descr` metadata field.
- **`format.log_singular` warning** at line 49 (2 occurrences) — log format strings may not match singular/plural expectations.
- The `^` operator is used as a boolean XOR on `$home_setting ^ TRUE`, which is unusual and potentially fragile.
- The `qw| not-home |` comparison at line 22 should likely be `eq 'not-home'` for clarity.
- The `>> 8` bit shift on `system()` return value is non-standard (typically `>> 8` is used for `waitpid` status, not `system`).
- Race condition concern is noted in comments regarding `file.make_path` during pre_init phase.

## Confidence
Unclear about the exact semantics of the `>> 8` shift on `system()` return values — this is non-standard Perl idiom. Also unclear whether the `^` boolean XOR is intentional or a typo for `!`.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.root.check_system_user':

ERRORS:
  ✗ missing or invalid metadata field 'descr'

WARNINGS:
  ⚠ format.log_singular : 2 occurrences [ first at line 49 ]
```

#,,..,.,.,.,.,.,,,,..,...,,..,...,..,,..,,..,,..,,...,...,,,.,...,...,.,,,,,,,
#FZP543KCYBGDDY3IMJRW6H67RR36MHTZ4ADQDDOUQ5CTHPUD7XHKKRC7VDVU2PCGIPNOQ6U6WA324
#\\\|B4K4WPZ6WC624VDDL2NZD6LGJYRQIXKWUU6DQ2QFC5WD5MDXLH3 \ / AMOS7 \ YOURUM ::
#\[7]ABZTL5OPCFNQO2XZKWF4RMWDXRAGYNQ5VQW4XJG2OVVP6XHC2MBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
