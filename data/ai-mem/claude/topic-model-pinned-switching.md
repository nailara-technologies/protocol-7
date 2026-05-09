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

**Config is ready:** `configuration/zenki/coding/start` already has:
- `coding.cfg.base_work_model` — model for task inference
- `coding.cfg.base_compaction_model` — intended for compaction [ currently same as work model ]
- `coding.cfg.summarize_model` — intended for summarize_context [ currently empty ]

**How to apply:** Implement together — both compaction and summarize_context need
the same switch-before / switch-back pattern. CPU backend running a separate
large-context model simultaneously is the cleaner long-term solution (no
switching needed — two backends, two models).

#,,,.,.,,,,,.,,..,,..,,..,.,,,,..,,.,,.,,,,.,,..,,...,...,.,.,,.,,,,,,.,,,,,.,
#JUNEKGWZRPK7RI63BRRST3DEHCING4IFJ7WH3U5ZZNLVYSSUQBHDQ6SQRJP6X3RBQHMGY7JTO5AQK
#\\\|M7OFPKT4R5ZOIZTMLW2X3MZU4AT7RIKYAFGPBAQEAQSY2PNZKGC \ / AMOS7 \ YOURUM ::
#\[7]BUARDIE5356SPS2CMI4JY5TDO223SKXUZ4YKYDJAK4K2GLKWXICI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
