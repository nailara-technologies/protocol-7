---
module: index.rank
generated_at: 2026-09-09T23:46:34
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 883ea98340c9bffc86c706b1e9e8ad4eea34ed0e
source_lines: 108
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 1722
usage_completion_tokens: 570
---

# review: index.rank

## Purpose
This module assigns numerical addresses to sequences by frequency rank and constructs a ring trie structure. It processes sequences across multiple window sizes ("rings"), sorting them by frequency and lexicographically, then building trie nodes that encode child relationships via packed child ranks.

## Interface
No explicit arguments or return value. It reads from external data structures (`<index.freq>`, `<index.level>`, `<index.terminal>`) and writes results to `<index.addr>`, `<index.packed_rank>`, and `<index.trie>`. Returns `0` at the end.

## Role & dependencies
Called statically by 6 other modules. It depends on `<index.freq>`, `<index.level>`, `<index.terminal>`, and `<index.addr>` as pre-populated data sources. It produces a trie structure that likely serves as a lookup index for downstream modules.

## Observations
- **Fragility**: The module assumes `<index.freq>`, `<index.level>`, and `<index.terminal>` are already populated by prior modules. No validation of these inputs is performed.
- **Coupling**: The `format.log_singular` warning (2 occurrences) suggests inconsistent logging style — the module mixes singular/plural forms in log messages.
- **Style**: The use of `<index.xxx>` as a data access pattern is opaque to readers unfamiliar with the AMOS7 convention.
- **Potential issue**: The `next if $win == 0` guards appear redundant since `keys <index.level>->%*` likely excludes 0, but this is unclear without seeing how `<index.level>` is populated.

## Confidence
Unclear whether `<index.level>` is guaranteed to be sorted or whether the `sort { $a <=> $b }` on keys is necessary (the outer loop already sorts). Also unclear if `<index.terminal>` is a hash or a different data structure — the `// {}` default on `<index.freq>` suggests hash, but `<index.terminal>` lacks a default.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'index.rank'

WARNINGS:
  ⚠ format.log_singular : 2 occurrences [ first at line 7 ]
  ⚠ module not found in subroutine whitelist
```

#,,..,,,.,,.,,...,,,,,.,,,.,,,,..,,,,,,,,,,..,..,,...,..,,...,.,,,,.,,,,.,,.,,
#NXPKPNFH6QPIEXE3QICN632V6TCMEEFCCNK35SQSTOUWKSK5NP63MIOF5CKZF4QNUQ3ZSOVH5YKHY
#\\\|VQ4SQB4MHPZXSR75OFFB5O4TJJ6S6IESXBEHZVDEO4EWIREPR6U \ / AMOS7 \ YOURUM ::
#\[7]N6XWATZRSV6XKZ5WCOVS2YZLB4KGJWQI6E46FLSSYAQXKPPHGWBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
