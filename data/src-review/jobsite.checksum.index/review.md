---
module: jobsite.checksum.index
generated_at: 2026-09-09T23:06:21
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 08e773268e24cbf95f1e125423c6279575b28816
source_lines: 197
dep_graph_callers: 8
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 2644
usage_completion_tokens: 662
---

# review: jobsite.checksum.index

## Purpose

This module implements a filesystem-based checksum store for jobsite deduplication and company blacklisting. It stores unique identifiers (checksums) for job titles, URLs, and companies in epoch-based directory structures, enabling efficient duplicate detection without database dependencies.

## Interface

**Actions:** `check` (default), `add`, `blacklist_company`, `stats`, `prune`, `load`, `persist`.

**check:** Accepts a job hash reference; returns `{ is_blocked => bool, hits => [array] }`.

**add:** Accepts a job hash reference; returns TRUE if job is not in 'new' status, otherwise TRUE (gate prevents self-block).

**blacklist_company:** Accepts a company string; returns TRUE on success.

**stats:** Returns `{ companies, titles, urls }` counts.

**prune:** Accepts optional epoch retention count; returns number of removed epoch dirs.

## Role & dependencies

Fits as a dedup/blacklist backend for jobsite processing. Notable callees: `<[chk-sum.amos]>` (company checksum), `<[chk-sum.bmw.str-b32.L13]>` (title/URL checksum), `<[file.zenka_dir.write]>` (epoch-aware file writes), `<[base.ntime.epoch_timestamp]>` (epoch directory naming).

## Observations

- **Fragility:** The `add` action returns TRUE even when the job is 'new', relying on external callers to gate self-blocks — a fragile contract.
- **Coupling:** Tightly couples to filesystem layout (`checksum-store/` hierarchy) and epoch-based directory naming (`V7[A-Z2-7]{5}`).
- **Style:** Line-too-long violations (83>78, 81>78 chars) indicate readability issues.
- **Potential issue:** The `check` action iterates all epoch dirs for URL dedup — O(n) per check, which may degrade under high volume.
- **Migration:** Handles legacy YAML blacklist migration with a flag file, but assumes `YAML::XS` availability.

## Confidence

Unclear whether the `add` action's TRUE return on 'new' status is intentional or a bug — the comment suggests it's a deliberate gate, but the return value is misleading. Also unclear if `<system.amos-zenka-user>` is reliably available in all environments.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
## convention violations [ 1 files scanned, 2 issues ] ##

[src/jobsite.checksum.index]
  L5     line_too_long     83>78  # note  = file existence = record; no load/persist cycle; epoch dirs f
  L4     line_too_long     81>78  # descr = filesystem directory-based checksum store for jobsite dedup
```

### validate_module

```
Validation PASSED for 'jobsite.checksum.index'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,.,,...,.,.,,,.,..,,,,.,.,.,..,,.,.,,,,,..,,..,,...,.,,,..,,...,..,,,..,..,,
#SACGHZSRD6XCGZC6NDUTQJOZN4VI6UA73QWPVPHWB3NQFU2HIV7RMSUMHK3UXLALUTI2MUG6BZDBC
#\\\|PSUXHN2FHOQFUKNFT3XYT2RHG3F2MBCKX757JNI7YUV4XDH4EY7 \ / AMOS7 \ YOURUM ::
#\[7]G7HE4SANJ4PQK27L5G35MO4RLBQQG7VBL6VLL7ZCHDWBGULF5GDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
