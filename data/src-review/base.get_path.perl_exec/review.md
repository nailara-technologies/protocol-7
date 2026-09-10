---
module: base.get_path.perl_exec
generated_at: 2026-09-09T22:55:56
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 4d20578e17894b960c36956931bb6cea857f13eb
source_lines: 32
dep_graph_callers: 9
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 798
usage_completion_tokens: 483
---

# review: base.get_path.perl_exec

## Purpose
This module retrieves the Perl executable path by querying the `Config` module, with a security guard that warns if the discovered path differs from the expected executable name. It ultimately returns the Perl binary path for use by other modules.

## Interface
- **Returns**: A string containing the Perl executable path (from `$Config{'perlpath'}`), or falls back to `<system.perl_execname>` if acquisition fails.
- **Parameters**: None.

## Role & dependencies
This module is called statically by 9 other modules (per the dep-graph). It depends on the `Config` module and the `<system.perl_execname>` dynamic dispatch. It also calls `<[base.s_warn]>` for security warnings. The `EXECUTABLE_NAME` variable is used in the security comparison.

## Observations
- **Missing metadata**: The `descr` field is absent, causing validation failure.
- **Line length violation**: Line 4 exceeds 78 characters (convention check flagged).
- **Security check**: Compares the discovered Perl path against `<system.perl_execname>` to detect path manipulation attacks.
- **Dynamic dispatch**: Uses `<system.perl_execname>` and `<[base.s_warn]>` — these are not captured in the static dep-graph, making the call graph incomplete.
- **VMS handling**: The `$^O` check for VMS systems suggests platform-specific path formatting is considered.

## Confidence
Unclear whether `<system.perl_execname>` is a dynamic dispatch or a compile-time constant — the syntax `<...>` suggests dynamic dispatch, but the exact mechanism isn't visible in this source.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
## convention violations [ 1 files scanned, 1 issues ] ##

[src/base.get_path.perl_exec]
  L4     line_too_long     79>78  # note = see 'man perlvar' [$EXECUTABLE_NAME] for why this subroutine
```

### validate_module

```
Validation FAILED for 'base.get_path.perl_exec':

ERRORS:
  ✗ missing or invalid metadata field 'descr'
```

#,,..,,..,.,.,.,,,.,,,,,,,..,,,.,,..,,,..,,.,,..,,...,..,,.,,,,..,,,,,,..,,..,
#S7ZHKRNQ5ONBGNYLJAZLVDUQCKCRQ3UEROUMV6YB6NYYMD5TIFX2MQLXZRJWNCFNIHL6UW4EMY4YY
#\\\|JOWSCRVPBDVR36QVGKKG2JWR6KECCMYPIK3CTOCGZMS7PQHAH4N \ / AMOS7 \ YOURUM ::
#\[7]P4AQ36TB5RGZFW5FYZMKNB3H4FE4JZX2E3US6DBIPBVZPLZGCMAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
