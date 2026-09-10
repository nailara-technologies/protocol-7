---
module: source.cmd.get-code-signed
generated_at: 2026-09-09T23:49:39
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 7e1eb8315be43e37c9a28ef6465b84cda86bbdc5
source_lines: 284
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 3674
usage_completion_tokens: 632
---

# review: source.cmd.get-code-signed

## Purpose
This module validates source code files by checking their signature footers, computing a stable body-only BMW checksum, and re-signing files when the signature or checksum has changed. It supports an "unchanged skip" optimization to avoid re-signing valid files.

## Interface
**Input:** `$call` hash with keys `args` (code name), `skip-valid` (boolean), `verbosity` (0|1|2), `expect-header` (boolean).
**Output:** Hash with `mode` (qw|false| or qw|true| or qw|size|) and `data` (string or body content with checksums).

## Role & dependencies
Called by 6 modules (static literal calls). It orchestrates:
- `<source.valid_src_name>` — name validation
- `<source.extract_sig_body>` — footer extraction
- `<chk-sum.bmw.strsum>` — body checksum computation
- `<source.signature_valid>` — signature verification
- `<source.create_harmonic_footer>` — new signature generation
- `<source.normalize_endline_paths>` — path-based endline repair
- `<crypt.C25519.key_vars>` / `<crypt.C25519.private_key_loaded>` — key access

## Observations
- **Fragility:** The `normalize_endline_paths` mechanism relies on a global array that may not be reliably populated across calls.
- **Coupling:** Heavy dependency on external modules via `<[...]>` syntax; any change in those modules breaks this one.
- **Style:** The `format.log_singular` warning (24 occurrences) indicates inconsistent logging — some paths use `: :` while others use `: :.` or `: :*`.
- **Potential issue:** The `needs_separator_endline` flag is cleared after use, but if `create_harmonic_footer` re-sets it, the module could enter an infinite re-signing loop.
- **TOCTOU protection:** The `body-chksum`/`body-length` return values allow callers to detect disk changes between read and write — a good design.

## Confidence
Unclear whether `source.normalize_endline_paths` is guaranteed to be populated before this module runs, or whether it's a global state that could be stale. Also unclear if `create_harmonic_footer` can re-set `needs_separator_endline` after this module clears it.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'source.cmd.get-code-signed'

WARNINGS:
  ⚠ format.log_singular : 24 occurrences [ first at line 75 ]
  ⚠ module not found in subroutine whitelist
```

#,,,.,,.,,..,,,..,.,,,.,,,,.,,,..,...,..,,,,,,..,,...,...,..,,,..,,.,,,..,,..,
#FPQO4NSRBMWRG24I3NVQJAJKYTWSCKO72XM3SDQ3ISVJWZS5XVWK645KEIJJ52NEVE724N65A46JO
#\\\|6REYWFFNOYUMKLKQMBP7S2QCRDZSHUZLT2476VEHNZPCUWUBBCT \ / AMOS7 \ YOURUM ::
#\[7]ZTLDUH7MNEZCDUDX5KB2F2KVWEQR5WABG4QYJQLNJTX3HKFHEGAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
