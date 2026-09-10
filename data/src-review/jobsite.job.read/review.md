---
module: jobsite.job.read
generated_at: 2026-09-09T10:15:47
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 7f61e414cb0d5d4124c7a23a297adef06ec461fe
source_lines: 67
dep_graph_callers: 19
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1137
usage_completion_tokens: 677
---

# review: jobsite.job.read

## Purpose
This module reads a single job record from per-file storage, using a status index to locate the record. It handles both active jobs and trash items (compressed xz archives), decoding and normalizing the YAML payload into a hash reference.

## Interface
**Input:** `$job_id` (string, required) — passed via `shift`. Returns `undef` if empty.
**Output:** A hash reference representing the job record, or `undef` on any failure (missing index entry, decode error, load error, or non-hash result).

## Role & dependencies
Serves as a data accessor layer for the jobsite subsystem. Notable callees:
- `jobsite.job.index` — status index lookup
- `base.vax-int.encode` — ID encoding
- `file.zenka_dir.load` — file loading
- `base32.decode` / `IO::Uncompress::UnXz` — trash item decompression
- `YAML::XS::Load` — deserialization
- `base.logs` — error logging

## Observations
- **Fragility:** The `eval` around `YAML::XS::Load` swallows all exceptions, returning `undef` without distinguishing between a missing key and a parse error. The `eval` block also lacks a `die` or `warn` on failure, making debugging harder.
- **Coupling:** Tightly coupled to `base32` and `xz` compression formats; any format change requires code changes.
- **Style:** The AMOS7 signature footer is malformed — it contains extra characters (`\|DDP7ECAQS2M47SDQQJP5DT7FL42NDFBC4B27DM75JBDVQVMZGCW \ /`) and violates the expected format, triggering the "missing signature footer" validation failure.
- **Potential issue:** `utf8::decode` is called without checking `utf8::valid` first on the final result, which could silently corrupt data if the YAML contains invalid sequences.

## Confidence
Unclear whether `YAML::XS::Load` can throw exceptions that aren't caught by `eval` (e.g., file I/O errors if the module wraps file access internally). Also unclear if the `base.logs` call with `%s` placeholders expects string interpolation or a different format.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'jobsite.job.read':

ERRORS:
  ✗ missing signature footer

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,,.,,..,.,,,,.,,...,..,,,..,,,.,,..,.,.,,,,,..,,...,.,.,,.,,..,,,,,,...,,,.,
#CEDCGRFBBUVLIHLJQMHVGKDAUL2IAOUABFBH375PYLRR5LPJBI56MDC656XU3IASD3QP6UWU7WS6U
#\\\|CPJDBXNKLOBV2TDGJLI7YYF5LAW4ICSFEV72CNKIAHB22SHJMY5 \ / AMOS7 \ YOURUM ::
#\[7]3GCU7YN2DNLQCNV63NGH4QYWPNJHKMO6HVESIS2JLLISVBXM4SAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
