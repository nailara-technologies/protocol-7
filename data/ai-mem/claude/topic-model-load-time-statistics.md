---
name: topic-model-load-time-statistics
description: planned per-model load-time stats (fastest/average/longest) to replace fixed switch/cold-start timeouts with adaptive ones
metadata: 
  node_type: memory
  type: project
  originSessionId: 0167cea8-7299-4bd1-b3b4-a507800e7687
---

Idea (user, 2026-06-21): track per-model load-time statistics —
fastest/average/longest (or similar) — persisted per model checksum.
Use much higher timeouts when a model has no stats yet (first load is
unknown territory), then immediately store that first observed load
time as the seed reference value, refining with each subsequent load
for more precision.

**Why**: motivated directly by a live finding while verifying the
result_constraint+tiered-escalation feature
([[coding-zenka-improvement-pipeline]]) — `poll_switch`'s
`coding.cfg.switch_model_max_wait` is a single fixed value (raised
120s->300s this session), but a restore on this system's slow
`/mnt/ext-xfs-data` drive took ~7 minutes once, vs ~15-20s ttft once
actually ready on other loads of the same model in the same session.
No fixed constant can be both safe and tight across that range — WSL
disk I/O for cold model loads is highly variable ("can be slow
sometimes... but usually completes" - user).

**How to apply**: when next touching `coding.cfg.switch_model_max_wait`
/ `coding.cfg.cold_start_data_start_timeout` / any other cold-start
timeout, prefer building this adaptive per-model stats mechanism over
adding another fixed constant. Natural home: alongside
`coding.self_test.archive`'s existing per-model result storage, or the
models zenka's registry. Not yet designed or built — this is a capture
of the idea only.

[[feedback-ondemand-timeout-tiering]]

#,,..,,.,,,,,,,..,,..,.,.,,.,,.,,,.,,,.,.,,,,,..,,...,...,,,.,.,,,,.,,.,,,,,.,
#Y2WYDYENPBLNWZBQ75U6LMKJGXGIJIIK3Z3OMNG6UL5XN37HLUACNDP63F24GFNB7KPXGHC4SLOAE
#\\\|4ZBBX22XMO4AECRRTIJSXBPPENW6BO3AE2SWVDKBI66UASIOUE3 \ / AMOS7 \ YOURUM ::
#\[7]R6CP3SGPIPG7EXPP55JIAO23QQ2MZXEBGKYV35PKAEMR7JFK2AAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
