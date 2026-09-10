---
module: base.file.gen_path_linkname
generated_at: 2026-09-09T23:39:25
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 805c1af08be6f6598af6bba955415b853151c647
source_lines: 83
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1330
usage_completion_tokens: 758
---

# review: base.file.gen_path_linkname

## Purpose
This module generates symbolic link paths for creating target path references. It computes a deterministic symlink name by combining a target path with a harmonic iteration counter, then returns the full absolute path (and optionally the name component).

## Interface
**Arguments:** `$temp_file_dir` (target directory), `$link_target_path` (symlink target), `$file_iteration_counter` (collision counter), `$existing_symlink` (skip existing check), `$target_must_exist` (validate target).
**Returns:** In scalar context, the absolute symlink path. In list context, returns `($symlink_abs, $tmp_path_symlink_name)`.

## Role & dependencies
Fits into AMOS7's path/link generation infrastructure. Notable callees: `<[chk-sum.bmw.L13-str]>` (checksum computation), `<[base.s_warn]>` (warning output), `<[base.number-cache.true_upwards]>` (harmonic counter), `<[chk-sum.bmw.template_L13]>` (template checksum), `AMOS7::Assert::Truth::is_true` (truth assertion). The module is not in the subroutine whitelist (warning noted in validation).

## Observations
- **Fragile `wantarray` placement:** The `wantarray` check appears *after* the `++$file_iteration_counter` line. If `wantarray` is false, the counter still increments before returning, causing the next call to skip the `RECALC_FILENAME` label and produce a different result than expected.
- **`goto RECALC_FILENAME` logic:** The `goto` is triggered by the counter increment, but the counter is incremented *before* the condition is evaluated, creating a subtle off-by-one behavior on the first call.
- **Protocol-7 coupling:** Heavy reliance on AMOS7-specific functions (`<[chk-sum.bmw...]>`, `state` variables, `goto` with label) makes portability difficult.
- **Validation passed:** Deterministic check reports no violations, suggesting the code is syntactically and conventionally compliant.

## Confidence
Unclear whether the `wantarray` placement is intentional (perhaps to always increment the counter regardless of context) or a bug. The interaction between `++$file_iteration_counter` and the `goto` label is non-obvious and could produce inconsistent results across different call contexts.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.file.gen_path_linkname'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,.,,.,,,,,.,,,.,,.,,,,.,,.,,,..,..,,,,,,.,,,..,,...,...,..,,,.,,,.,,,.,,.,.,
#UGJGGUYBFD5VXSR57TMR6SSTUZYWJAX7BMOJ7WHDF5HEOWXZJ6KKDAORLEBBFJOQDZJMOCBNPZTMU
#\\\|V7LZB7SEM66HUCP4PZ75CYVIXU7SNDUX5I4BUJQIOXMZ3EAOJTL \ / AMOS7 \ YOURUM ::
#\[7]BZ7QPTP3ZQX6ZSVOQ3IK6XY26VSH7NE3RIFJ6NKWJKNMDO534EDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
