---
module: base.file.zenka_dir.load
generated_at: 2026-09-09T22:34:48
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: a7da94bf9ecbdb4e93cc53fe6a7e305227c26b50
source_lines: 73
dep_graph_callers: 47
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1202
usage_completion_tokens: 612
---

# review: base.file.zenka_dir.load

## Purpose
This module loads file content from a zenka directory structure under `/var/protocol-7/zenka/` or `/etc/..`, returning a scalar reference to the file contents. It handles path resolution based on global config flags and zenka subdirectory prefixes.

## Interface
- **Arguments**: `$filepath_rel` (relative path, default `''`), `$encoding_str` (encoding string, default `qw| :raw |`)
- **Return**: A scalar reference to file content on success, `undef` on failure
- **Side effects**: Emits warnings via `<[base.s_warn]>` on permission or path errors

## Role & dependencies
Fits into the file I/O layer of the Protocol-7 codebase. Notable callees include `<system.path.zenka-dirs>`, `<system.zenka.name>`, `<[file.slurp]>`, and `<[base.s_warn]>`. It is called by 47 modules via static literal calls.

## Observations
- **Fragility**: The regex substitution `$filepath_rel =~ s|^cfg-dir:||` both checks and modifies the path in one operation — this is a fragile idiom that could silently alter `$filepath_rel` unexpectedly.
- **Coupling**: Strong dependency on `<system.path.zenka-dirs>` and `<system.zenka.name>`; these external calls are not documented as parameters.
- **Style**: The comment block at the end (signature block) is non-functional and adds noise. The `qw| :raw |` default encoding is unusual — typically `:raw` is a flag, not a string.
- **Safety**: The `-d` and `-r` checks on `$zenka_write_dir` are good, but the `-e` check on `$file_abs_path` only catches missing files, not permission-denied on the file itself.

## Confidence
Unclear whether `<system.path.zenka-dirs>` and `<system.zenka.name>` are guaranteed to exist at runtime, or if they could fail silently. The `catfile` function is assumed to exist but not shown in the source.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'base.file.zenka_dir.load'
No issues found.
```

#,,.,,.,.,.,.,.,,,..,,..,,.,,,.,.,,.,,,..,...,..,,...,...,,..,,.,,,.,,,..,,..,
#24EVPQS5WLLT5G5IIK63QTFAWWWURNDOKHDGMJ5AL5CBC3CT5PNR7BYNOXP2BW62BM73URE4Q4ATA
#\\\|WB5CNC7IA5ZGXT32AJKPZ4JL7ZEYJCLV4ORR2ZQL6MBBGIZ32B4 \ / AMOS7 \ YOURUM ::
#\[7]IUONGRZWCLQELTUX4OGFHENPN4IT5GDPLHDVLSRTVBZKR56RH2DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
