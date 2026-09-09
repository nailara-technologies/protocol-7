---
module: base.swap_subs
generated_at: 2026-09-09T10:13:29
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: d116e1806671717c97f21da54e76e0bd7366d6fb
source_lines: 214
dep_graph_callers: 21
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 2897
usage_completion_tokens: 651
---

# review: base.swap_subs

## Purpose

This module moves subroutines from one module namespace into another, supporting three overwrite policies: `undefine` (wipe target first), `overwrite` (replace existing), and `if_missing` (skip if target exists). It also updates tracking structures and handles deferred-compile stubs by aliasing them across namespaces.

## Interface

Takes three arguments: `$source_sub_prefix`, `$target_sub_prefix`, and `$overwrite_policy` (default: `qw| undefine |`). Returns `FALSE` if no matching subs are found; otherwise returns `TRUE` (implicit).

## Role & dependencies

It is a lifecycle hook called during code reload, coordinating with `<base.logs>`, `<base.cmd>`, `<base.cli>`, `<base.resolve_key>`, `<base.is_defined_recursive>`, and `<base.subroutines.referenced>`. It maintains a generation counter keyed by namespace prefix to avoid redundant wipes within the same generation.

## Observations

- **Fragility**: The generation guard relies on `<base.loader.namespace_generation>` being populated *before* this module runs. If the loader hasn't tracked a namespace yet, `$current_generation` falls back to `<base.loader.load_seq>`, which could cause false positives/negatives in the wipe check.
- **Coupling**: Heavy coupling to internal loader state (`namespace_generation`, `load_seq`) and multiple global namespaces (`code`, `cmd`, `cli`, `sub_list`, `referenced`).
- **Style**: The "signature footer" (the `#\[7]HWXR...` block) is present but the validator reports a missing signature footer — unclear if the format differs from what the validator expects.
- **Edge case**: The `undefine` policy deletes target subs *before* moving source subs, which could break reachability if a target sub is also a source sub in a different swap.

## Confidence

Unclear whether the signature footer format is correct (validator says missing, but a signature-like block is present). Unclear whether `namespace_generation` is always populated before `swap_subs` runs in all code paths.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'base.swap_subs':

ERRORS:
  ✗ missing signature footer
```

#,,,,,,..,,,.,,..,...,.,,,,,.,...,,,.,..,,,..,..,,...,...,.,.,,..,,,,,.,.,,,,,
#L4UQUPGDXN7NXJP2TEMSGJVI376LNVSW32GTUX3KMKKCGL7EJLMHUY76ADT3GEMXT77N57WZRYCQW
#\\\|GIF3RQU6TMNWV4VA6EEGW2XR42J6EOCEQR7R27RQ6ZRJ7R653NY \ / AMOS7 \ YOURUM ::
#\[7]VDKM7KWWDHM35UZQ4SCYELP4O3VFUHP3DZ77GZZGUVLZ6URL3CBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
