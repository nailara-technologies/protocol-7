---
module: crypt.C25519.key_is_virtual
generated_at: 2026-09-09T23:43:32
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 756f5cc3dec34e8eda6d2caeed431628ee96041f
source_lines: 27
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 721
usage_completion_tokens: 568
---

# review: crypt.C25519.key_is_virtual

## Purpose
This module determines whether a given key is a "virtual" key (derived from a seed phrase). It returns a boolean indicating whether the key's virtual keyfile exists on disk.

## Interface
- **Input:** `$name` — the key identifier (string). Defaults to empty string if not provided.
- **Output:** `TRUE` if the key is virtual (virtual keyfile exists), `FALSE` otherwise. Returns `undef` on error.

## Role & dependencies
This is a utility function within the `crypt.C25519` namespace, likely used by higher-level key management code. It depends on two internal functions:
- `crypt.C25519.key_exists` — validates the key name exists
- `crypt.C25519.key_vars` — retrieves key metadata including the virtual keyfile path

## Observations
- **Fragility:** The `-f` test on `$virtual_keyfile` assumes the path is always a regular file. If the keyfile is a symlink or directory, behavior is undefined.
- **Coupling:** Tight coupling to internal `key_vars` structure (`$key_vars_ref->{'key_filename'}->{'virtual'}`) — a schema change here would break callers.
- **Style:** The signature `my $name = shift // '';` is unconventional for a module function (typically `sub` with `@_` is clearer). The long comment block at the end appears to be a data signature / checksum.
- **Safety:** The `warn` calls use `base.s_warn` — unclear if this is a custom wrapper or a typo for `warn`.

## Confidence
Unclear whether `base.s_warn` is a custom logging function or a typo. Also unclear whether the `-f` test is sufficient for all virtual key scenarios (e.g., symlinks, network mounts).

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'crypt.C25519.key_is_virtual'
No issues found.
```

#,,,.,.,,,,,,,,..,.,.,,,.,.,,,.,,,,.,,,..,,,.,..,,...,...,...,,,.,,,,,.,,,.,.,
#2LDQ2LRRIH2SDK4UH2OGCEHSTZPC54TC4ILY5S2G6LLMU53O2MMT42DFZRJCTYTQMR2EV3RK54CGY
#\\\|L7PRU3W3F3UQIE7RCIDQ5BNDQZJPUHCBVR7ZHZ6VIJCCP55WZPK \ / AMOS7 \ YOURUM ::
#\[7]5H6XV6RTVF2S6Q5RYYZNTZHHX4HJ5EQDXSXHXSNCQFM6MW5KVSAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
