---
module: v7-zenki.instance_ids
generated_at: 2026-09-09T10:11:33
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: c8af1226025498d19a9629179cfeb1c2bb619cdf
source_lines: 36
dep_graph_callers: 23
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 815
usage_completion_tokens: 473
---

# review: v7-zenki.instance_ids

## Purpose
This module returns a sanitized list of zenka instance IDs by iterating over a zenka instance hash, filtering out entries that lack a valid name or status, and removing invalid entries from the source hash.

## Interface
**Input:** None (relies on global `<v7-zenki.zenka.instance>` hash reference).  
**Output:** Returns `@instances` — a list of valid instance IDs.

## Role & dependencies
The module depends on `<v7-zenki.zenka.instance>` (a zenka instance hash) and `<regex.base.iid>` for ID validation. It is called by 23 other modules (per the dep-graph). It also uses `<[base.logs]>` for warning logging.

## Observations
- **Validation FAILED** due to a missing signature footer — the module lacks the required AMOS7 signature block at the end.
- The module mutates the zenka instance hash by deleting invalid entries (`delete <v7-zenki.zenka.instance>->{$instance_id}`), which may have side effects on callers expecting a read-only view.
- The `warn` call references `$ARG` which is not defined in scope — this appears to be a bug or placeholder.
- The module is not in the subroutine whitelist, which may indicate it was not formally registered in the AMOS7 toolchain.

## Confidence
Unclear whether `$ARG` is a typo for `$instance_id` or an intentional reference to a global variable not shown in this excerpt.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation FAILED for 'v7-zenki.instance_ids':

ERRORS:
  ✗ missing signature footer

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,,.,,.,,,,.,...,,,.,,,.,.,,,.,.,,,.,,,,,,..,..,,...,...,..,,..,,,,.,..,,..,,
#6WMJ5CEZ73AVRJIQZK7BSEPJN7QBH3XEDVEGWO73SKLRZRJDBSOYGUUALUH5OES2VTC7BIEPQ4RUG
#\\\|TKEMTCPLDJWQRCLGKMNFSIVKMYEWT7IVMQTWGA6WDYYKRTU6HO7 \ / AMOS7 \ YOURUM ::
#\[7]PDAHWK4DPDLTEFTPBA66LZYTUOWOKBW7SS34GFBDAFLYURYFXYCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
