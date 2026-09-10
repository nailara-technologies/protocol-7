---
module: powershell.exec
generated_at: 2026-09-09T23:48:28
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: fa5631cb8ea6b597827deaa1e457ba980c09eba1
source_lines: 64
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1085
usage_completion_tokens: 773
---

# review: powershell.exec

## Purpose
This module executes a fixed PowerShell script via `powershell.exe -Command` and returns the stdout text (with CRLF normalized to LF) or `undef` on failure.

## Interface
- **Argument:** `$ps_script` — a string containing the PowerShell command (array-form, no shell expansion).
- **Return:** stdout text as a string, or `undef` if the script is empty/undefined, PowerShell is unavailable, or the process exits with a non-zero code.

## Role & dependencies
Called by 6 other modules (static literal calls only). It relies on `IPC::Open3` for process spawning, `IO::Handle` for I/O, and two framework zenka calls: `<[base.perlmod.autoload]>` and `<[base.str.eval_error]>`. The `open3` import is described as a "side effect" of other framework code paths.

## Observations
- **Fragility:** The module depends on `powershell.exe` being available at runtime; if the zenka `<powershell.cfg.exe_path>` returns empty, the module silently returns `undef` with a warning.
- **Coupling:** The `open3` import is deferred via a side-effect mechanism, which may not trigger in all code paths (the comment explicitly notes this risk).
- **Style:** Uses AMOS7's zenka syntax (`<...>`) for framework calls, which is non-standard Perl.
- **Potential issue:** The `eval { open3(...) }` only catches exceptions during spawn; if `open3` succeeds but the child process fails, the error is only surfaced via `$CHILD_ERROR` after `waitpid`.
- **Validation warning:** The module is not found in the subroutine whitelist, which may indicate it's not formally registered in the framework.

## Confidence
Unclear whether `<[base.perlmod.autoload]>` is a true runtime import or a compile-time macro. The dep-graph reports 6 callers but notes "conditional/dynamic dispatch is NOT captured," so the actual call count may be higher.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'powershell.exec'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,,,,,,.,...,,,,,,,,,,,,,..,,,..,..,,,..,.,.,..,,...,...,..,,,..,,..,,,,,.,.,
#JLF6PF2LHNTISQBRVAUJ2FP6UA5GRUGUIJWIFOGCQRZ7FUMDXMBFQOJG2BWGLAJTOJ2F5R4SCLDZO
#\\\|EIY3ATILGSNGMMZBJER5O4R2SPJA2LDWKUL5SYPNGUKOUNZ4OSJ \ / AMOS7 \ YOURUM ::
#\[7]VGJ3X6DYKJW7N3TJLQUS6XJBVGCBU67BMTWBYRUFAWPCF2EZSSCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
