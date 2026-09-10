---
module: httpd.update_download_count
generated_at: 2026-09-09T23:46:19
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 426694cb06efc84799bbaef288dcd9a3383a859a
source_lines: 78
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1191
usage_completion_tokens: 536
---

# review: httpd.update_download_count

## Purpose

This module tracks file download statistics, maintaining per-file counts, bytes transferred, and timestamps, along with global totals. It also enforces a 1000-file limit by removing the oldest entries when exceeded.

## Interface

Takes two arguments: `$file_path` (required) and `$bytes` (optional, defaults to file size via `-s`). Returns `TRUE` on success or `FALSE` if the file path is empty or the file does not exist.

## Role & dependencies

It is a utility module called by 6 other modules (static literal calls). It depends on `<httpd.downloads>` data structure, `<[base.ntime]>` for timestamps, `<[base.log]>` for logging, and `<[httpd.base.size.normalize]>` for byte formatting.

## Observations

- **Fragility**: The cleanup logic assumes `last_time` is always set, but the initial file entry sets `'last_time' => 0`, which could cause incorrect sorting if all files have zero timestamps.
- **Coupling**: The module tightly couples to the `<httpd.downloads>` data structure shape; any schema change breaks it.
- **Style**: Uses AMOS7's `<>` data access syntax throughout, which is idiomatic but may be unfamiliar to Perl-only readers.
- **Warning**: `format.log_singular` at line 49 suggests a potential formatting issue in the log message.
- **Whitelist**: The module is not in the subroutine whitelist, which may indicate it's not yet fully integrated into the build system.

## Confidence

Unclear whether the 1000-file limit is a hard constraint or a soft recommendation. Also unclear if the whitelist exclusion is intentional or an oversight.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'httpd.update_download_count'

WARNINGS:
  ⚠ format.log_singular : 1 occurrence [ first at line 49 ]
  ⚠ module not found in subroutine whitelist
```

#,,..,.,,,,,.,.,,,..,,..,,..,,,..,.,.,..,,...,..,,...,...,.,,,,..,,..,..,,,,.,
#VWAZSHM3OUQV5FIM3XKDVQILEIP4N65CDMVNWPIYDGYHYUOQMFLCOSMNPL3ZQUEO3MKN3Q7QZLH4W
#\\\|QP22E7NGC5VJRRY5CGDHRDZIAV2CXOOUVPCH5T3VW3FUXI2BLNL \ / AMOS7 \ YOURUM ::
#\[7]ORQA32WEJAESZ5XKJ7SQWH6U5OCSDRLRRZREH5K4VVKR25CYWIDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
