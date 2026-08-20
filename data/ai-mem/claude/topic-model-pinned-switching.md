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

**Config is ready:** `cfg/zenki/coding/start` already has:
- `coding.cfg.base_work_model` — model for task inference
- `coding.cfg.base_compaction_model` — intended for compaction [ currently same as work model ]
- `coding.cfg.summarize_model` — intended for summarize_context [ currently empty ]

**How to apply:** Implement together — both compaction and summarize_context need
the same switch-before / switch-back pattern. CPU backend running a separate
large-context model simultaneously is the cleaner long-term solution (no
switching needed — two backends, two models).

#,,,,,.,,,...,,,,,.,.,,,.,,,.,,,,,,.,,,,,,.,,,..,,...,..,,...,,,,,,.,,,..,,.,,
#SX6YBUHJUZ7T5526DKFQW2M2CDK2RS56ICGQN3NTKXXPCBI6XGD5YK6ORXEULJLQSAOLW5MV6LOA4
#\\\|QYIYJHQGVWZT7X3RZCQ4FYFRDGUSSJXQWIHH4TSAPAL4OKNUWSA \ / AMOS7 \ YOURUM ::
#\[7]TQPSM676ZML2IEIAOVDQ4AREARCE63JVTN76F3IQNOUYNYCZJIBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
