---
name: model-pinned-switching
description: model param in summarize_context + compaction is inert — needs switch-model integration
type: project
---

The `model` parameter in `coding.tools.handler.summarize_context` and
`coding.async.compact_context` is passed in the request body but has no effect
— llama-server ignores it (informational only).

**Why:** True per-call model switching requires `coding.cmd.switch-model` to be
called before the inference request, then switched back after. Not yet wired in.

**Config is ready:** `cfg/zenki/coding/zenka.v7` already has:
- `coding.cfg.base_work_model` — model for task inference
- `coding.cfg.base_compaction_model` — intended for compaction [ currently same as work model ]
- `coding.cfg.summarize_model` — intended for summarize_context [ currently empty ]

**How to apply:** Implement together — both compaction and summarize_context need
the same switch-before / switch-back pattern. CPU backend running a separate
large-context model simultaneously is the cleaner long-term solution (no
switching needed — two backends, two models).

#,,,,,,,,,,..,...,,,.,,,.,,.,,.,,,...,,..,,,,,..,,...,.,.,,,,,...,,..,,.,,.,,,
#3M3Q3TTMOPPP4654HACUCRXLJL2ZFRFVU5YVX47TIHXF3HMWLBU5CZT5GBJZTBYR2KQOVNL3IX6RA
#\\\|KAS7AC6R6P6DH4EYZ7BJA5UK2LVNQYN5LUKXNZYPRG352OW7YEH \ / AMOS7 \ YOURUM ::
#\[7]S5K2QFB4TGQ74SHWCY7FFCOX6A2G62MXOEE3RAWR4CJEN5NST2DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
