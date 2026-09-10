---
module: mod-test.callback.reload-test.is_registered
generated_at: 2026-09-09T23:28:51
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: c95f1cf020b7268a85f262153a1c496b07c38cca
source_lines: 38
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 855
usage_completion_tokens: 627
---

# review: mod-test.callback.reload-test.is_registered

## Purpose
This module checks whether a given module file is registered in a type-specific registry directory. It returns a truthy value (5) if the module exists as a symlink in the registry, or 0 if not registered.

## Interface
- **Arguments**: `$register_type` (string, default ''), `$module_file` (string, default '')
- **Return**: `undef` on error, `5` if registered, `0` if not registered

## Role & dependencies
This is a utility module used by 6 other modules (per the dependency graph). It relies on several AMOS7 infrastructure macros:
- `<mod-test.path.mod-reg-dir>` — registry path lookup
- `<[base.s_warn]>` / `<[base.logs]>` — logging utilities
- `<[file.gen_path_linkname]>` — path generation for symlinks

## Observations
- **Fragility**: The module assumes `$register_type` is a valid key in a hash reference. If the key is missing, it logs a warning but returns `undef` — this could silently break callers expecting a numeric return.
- **Coupling**: Heavy reliance on AMOS7 macros (`<mod-test.path.mod-reg-dir>`, `<[file.gen_path_linkname]>`) makes it tightly coupled to the AMOS7 framework.
- **Style**: The module uses AMOS7-specific syntax (e.g., `my $register_type = shift // ''`) which is non-idiomatic Perl. The docstring at the bottom is a data signature, not human-readable documentation.
- **Validation failures**: The module lacks a `descr` metadata field and is not in the subroutine whitelist, which may cause downstream tooling issues.
- **Edge case**: The `-l` test checks for symlinks specifically — if a module is registered as a regular file, it returns 0 (false), which may be intentional but is worth noting.

## Confidence
Unclear whether returning `5` (truthy) instead of `1` is intentional (AMOS7 convention?) or a bug. Also unclear if `undef` on missing registry type is the desired behavior or should be a more explicit error.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'mod-test.callback.reload-test.is_registered':

ERRORS:
  ✗ missing or invalid metadata field 'descr'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,,,,..,,,,.,.,.,...,..,,.,,,...,.,.,,.,,,.,,..,,...,..,,,..,...,,,,,,..,...,
#FZSNURK7CAHHVBXJBEAS7FSPNP24IZ2A2M7DONRFVJMCPYNNDEW2RNKTKIFQXN4FPIAPON6U3NM6E
#\\\|3UUMLFJKK7R2OOXPTJJCQEZCABVV6W6XLU52RYIKLPYN2H6J4B4 \ / AMOS7 \ YOURUM ::
#\[7]GLU7J7PF66T6EWNJ25Y6K7TME3KYFDCJMRJ46HKNNRV354FGIEDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
