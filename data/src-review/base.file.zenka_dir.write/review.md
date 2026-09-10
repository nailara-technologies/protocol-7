---
module: base.file.zenka_dir.write
generated_at: 2026-09-09T22:33:48
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 7f8b79b05fc24470604e0f56a2fc5dca4975df20
source_lines: 221
dep_graph_callers: 73
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 2782
usage_completion_tokens: 876
---

# review: base.file.zenka_dir.write

## Purpose

This module writes files to Protocol-7 zenka directories (`/var/protocol-7/zenka/` or `/etc/`), supporting both overwrite (atomic via temp+rename) and append modes. It handles directory creation, permission enforcement, and ownership validation before writing.

## Interface

| Param | Default | Description |
|-------|---------|-------------|
| `$filepath_rel` | `''` | Relative output path |
| `$content_sref` | — | Scalar ref to content |
| `$open_mode_str` | `qw| > |` | Write mode |
| `$file_mode` | `0600` | File permissions |
| `$encoding_str` | `qw| :raw |` | Encoding |

Returns the number of characters written, or `undef` on failure.

## Role & dependencies

Called by 73 modules. Key dependencies:
- `<system.amos-zenka-user>` / `<system.zenka-user.current>` — user resolution
- `<system.path.zenka-dirs>` — directory lookup
- `<[base.path-set-up.check-zenka-paths]>` — path validation
- `<[file.temp]>` / `<[file.open]>` — file I/O primitives
- `<[base.s_warn]>` / `<[base.str.os_err]>` — warning/error utilities

## Observations

- **Atomic writes**: Overwrite mode uses temp file + `rename()` to avoid the "write-in-progress" window. The temp file is placed on the same filesystem as the target (critical for `rename()` to succeed).
- **GID override**: When a zenka group is configured, the target GID is overridden — this mirrors `check-zenka-paths` behavior.
- **Path validation**: Rejects absolute paths, paths containing `..`, and empty paths.
- **Non-overwrite mode**: Falls back to direct `open()` when mode isn't `>`.
- **Convention check**: No violations found; validation passed.

## Confidence

Unclear whether `<system.zenka-group.current>` is always defined or if it can be `undef` without triggering the override logic. The `catfile`/`catdir` functions are not shown in the source, so their error handling is unknown. The `File::stat::stat` call syntax is non-standard Perl — unclear if this is a custom module or a typo.

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

#,,..,...,...,...,,,.,.,,,...,,.,,,,.,.,.,..,,..,,...,...,..,,.,,,..,,.,.,..,,
#2UUUIUOUHXGHFVP4KJUABCCGG2DA75MRBQQVRQZZK7JZHK3Y632JUPIH47EY3G6G4FFNDZLEUYOW4
#\\\|DTCEDYQCKGNT4XBWPJDOESDGZEH4FCBYBV4YGUKRRFBURKLVN36 \ / AMOS7 \ YOURUM ::
#\[7]6V76FKQPOGVC7DHRADIAAYC5PLLSA6C2KDHE7G4KCNROUEZKJMCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
