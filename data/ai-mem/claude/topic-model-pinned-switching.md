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

#,,,.,,,.,.,.,,,,,.,,,..,,,.,,,,.,,.,,.,.,.,.,..,,...,...,..,,.,,,..,,...,...,
#ONTECJHFDMVHF5SAUZVPUFL77MVS66SJHETU3WOXOTPZGZSVKYS3WK6WOGR5SD255KWC2TUMAQHRS
#\\\|Q3XZTSYDXURVQ4YB5EOIDJJ5DTLKBDY6TAXY3RACPDRF7ZCWWTW \ / AMOS7 \ YOURUM ::
#\[7]BLFDSVDHYRPWNIBZTLEOKZSV3V6R3LOIV7CDICMQNPXTWXLHYQBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
