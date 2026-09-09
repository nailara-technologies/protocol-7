---
module: base.file.zenka_dir.write
generated_at: 2026-09-09T10:04:37
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 2c3aa1b2ec67dca6be80612c8973743ba4e41767
source_lines: 221
dep_graph_callers: 73
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 2781
usage_completion_tokens: 917
---

# review: base.file.zenka_dir.write

## Purpose
This module writes files to Protocol-7 zenka directories (`/var/protocol-7/zenka/..` or `/etc/protocol-7/..`), supporting atomic overwrite via temp-file+rename and non-atomic append modes. It resolves zenka-specific paths, validates input, and enforces ownership via `chown`.

## Interface
- **Arguments**: `$filepath_rel` (relative path), `$content_sref` (scalar ref to data), `$open_mode_str` (default `qw| > |`), `$file_mode` (default `0600`), `$encoding_str` (default `qw| :raw |`).
- **Returns**: Number of characters written on success; `undef` on failure.

## Role & Dependencies
Called by 73 modules via static literal dispatch. Leverages AMOS7 system calls (`<system.amos-zenka-user>`, `<system.zenka-user.current>`, `<system.path.zenka-dirs>`, `<system.zenka-group.current>`, `<system.zenka.name>`) and base utilities (`<[base.s_warn]>`, `<[base.str.os_err]>`). Uses `File::Path` (`catfile`, `catdir`) and `File::stat::stat` for filesystem operations.

## Observations
- **Logic bug**: `index( $filepath_rel, qw| / |, 0 ) == 0` is always true for any non-empty path starting with `/`, making the validation condition effectively `not length $filepath_rel or TRUE or ...` — the `/` check is dead code. Should be `!= 0` or `== -1`.
- **Atomicity**: Overwrite mode uses temp-file+rename for atomicity; non-overwrite modes (e.g., append) use direct `open` without atomic guarantees.
- **Coupling**: Heavily coupled to AMOS7 system macros and zenka-specific path resolution logic.
- **Style**: Uses AMOS7's `<[...]>` macro syntax for warnings and system calls, which is opaque to non-AMOS7 readers.

## Confidence
Uncertain about the exact semantics of `<system.amos-zenka-user>` and `<system.zenka-group.current>` — whether they return defined values on failure or always return a value. The `index` bug is certain; the rest is inferred from AMOS7 conventions.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.file.zenka_dir.write'
No issues found.
```

#,,.,,...,...,,..,,..,..,,,,,,.,.,.,.,.,,,,..,..,,...,...,,,.,,,.,,..,...,.,.,
#G3OH4EV5HRSBTXRANGWNTQA3AFWD47DBFMM4DDYNGN5WK2VDZOUG7FUCX5KBFCVGEJRCI2KJ3RRJA
#\\\|C52BIMVKTJ2NI7SMX2SFYAAUSZLFNBL7TKPI22G4XYBWCBLERAQ \ / AMOS7 \ YOURUM ::
#\[7]WHBXPIXTVZWWQPLO3GCCTEQTJWY2Q3FAII4RGSMZISOY2AX7RIAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
