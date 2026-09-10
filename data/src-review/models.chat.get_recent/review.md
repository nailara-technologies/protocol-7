---
module: models.chat.get_recent
generated_at: 2026-09-09T23:48:04
generator: llm
status: llm-generated, NOT hand-verified -- generated draft, not documentation fact
model: Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M.gguf
model_amos_id: OFSQC4I:QDBKEXY
model_endpoint: http://127.0.0.1:8000/v1/chat/completions [ ik_llama.cpp llama-server, local ]
prompt_version: src-review-v1
source_sha1: 054dc0b7bd96bf256a517fa1d9e90874bed7b1b7
source_lines: 27
dep_graph_callers: 6
dep_graph_caveat: static literal calls only; conditional/dynamic dispatch invisible to the graph
usage_prompt_tokens: 678
usage_completion_tokens: 561
---

# review: models.chat.get_recent

## Purpose
This module retrieves the last N chat messages from a data model, defaulting to 20 messages when no count is specified. It serves as a simple accessor for recent chat history.

## Interface
- **Parameter:** `$count` — number of messages to retrieve (default: 20)
- **Return:** Array reference of chat entries, or empty array if no messages exist

## Role & dependencies
The module is a leaf in the dependency graph with 6 callers. It depends on `<models.chat.messages>`, a data model that provides access to the full chat message store. The module is a thin accessor — it delegates all data retrieval to the underlying model.

## Observations
- The `0;` at the end is a no-op since the function already returns; this is a common Perl idiom but adds noise.
- The module relies entirely on `<models.chat.messages>` being defined — if that model changes or is removed, this module breaks silently (returns `[]`).
- The `shift // 20` pattern is concise but may be less clear to readers unfamiliar with Perl's `//` operator.
- The module is called by 6 other modules, suggesting it's a frequently used utility.
- No convention violations or validation failures were detected.

## Confidence
Unclear whether `<models.chat.messages>` is a data model or a subroutine call — the syntax `<...>->@*` suggests a data model accessor, but the exact semantics of AMOS7's `<...>` notation aren't fully evident from this snippet alone.

---

## deterministic check outputs [ verbatim ground truth ]

### module_convention_check

```
<!-- no violations found in 1 files [ max_line=78 max_descr=55 ] -->
```

### validate_module

```
Validation PASSED for 'models.chat.get_recent'

WARNINGS:
  ⚠ module not found in subroutine whitelist
```

#,,,,,..,,.,.,.,,,,.,,.,,,.,,,.,,,,,,,..,,.,.,..,,...,..,,...,..,,..,,.,.,.,.,
#FQQFD2WEVWTQ7H3RSXLFT6V5WR2SEIITL7BKAUWPZYCKM62OGP7YV6TAR4MMDIY3PYGDVMP77CX2A
#\\\|W7VQZBN5TMCQ4DNV43XST2HFZIEYEDLWIP3HGPQ6W75UDN3GKJ5 \ / AMOS7 \ YOURUM ::
#\[7]AD5DABPZK66TZE7AHMTKZLWGB7HGUTDXMK4FDKP27KTFIB54PSCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
