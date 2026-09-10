---
module: crypt.C25519.get_keyname
generated_at: 2026-09-09T23:12:38
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 2bf99d9c79ad32e550755be14925522bae4ce463
source_lines: 52
dep_graph_callers: 7
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1054
usage_completion_tokens: 748
---

# review: crypt.C25519.get_keyname

## Purpose
This subroutine extracts a key name from a key filename by stripping the directory path and matching the filename against a set of regex patterns. It returns the matched key name or `undef` if no pattern matches.

## Interface
- **Input**: A filename string (shifted from the caller; defaults to empty string).
- **Output**: A key name string on match, or `undef` if no match is found.
- **Side effects**: May emit a warning if the filename doesn't match any known type and the `quiet` flag is unset.

## Role & dependencies
Called by 7 modules (per the dependency graph). It relies on:
- `crypt.C25519.regex.key_file` — a hash of regex patterns keyed by type.
- `crypt.C25519.get_keyname.cache` — a memoization hash to avoid repeated lookups.
- `<[base.s_warn]>->` — a warning helper.
- `crypt.C25519.get_keyname.quiet` — a flag to suppress redundant warnings.

## Observations
- **Memoization** is used to avoid re-deriving classifications on repeated calls, which is important since callers like `keyfiles()` and `chksum()` rescan all files.
- **`shift`** is used, making this a subroutine rather than a method — consistent with AMOS7 conventions.
- **`LAST_PAREN_MATCH`** is used to capture the parenthesized group from the regex; this is a Perl idiom but may be less readable than explicit capture groups.
- The **`quiet` flag** is a reasonable design to avoid redundant warnings when callers already handle unrecognized files.
- The regex `|:.virtual\.:(.+)$|` handles virtual keys; the fallback iterates over `crypt.C25519.regex.key_file` keys.
- The deterministic checks report no violations, confirming compliance with AMOS7 style and validation rules.

## Confidence
Unclear on the exact structure of `crypt.C25519.regex.key_file` — whether it's a static hash or dynamically populated. Also unclear whether `LAST_PAREN_MATCH` is a global variable or a subroutine call (the syntax `$LAST_PAREN_MATCH` suggests a global, but the regex context is ambiguous).

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'crypt.C25519.get_keyname'
No issues found.
```

#,,,.,,,.,..,,.,,,,..,..,,.,.,...,,..,.,,,...,..,,...,...,,..,,,,,..,,..,,.,.,
#5JQE2CA2WPYFSOZCLMLBSRCRQRQWNPIKLBKEGTPHOQ3BIIAGJOM6M4MO5F3I4SHDHMXXEKPAAYP74
#\\\|EZSCG3WWO2RKSTFJ7DYENP6L76WMVN6NYZLIFQDLWWHWZOTZ6QT \ / AMOS7 \ YOURUM ::
#\[7]O7Y3JF3KPNMF3E766KR2Q6PC7PZY2NSY56PQKUU5MQLACIJK6MAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
