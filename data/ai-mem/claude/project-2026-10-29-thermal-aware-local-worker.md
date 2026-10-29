---
name: project-2026-10-29-thermal-aware-local-worker
description: DESIGN 2026-10-29 : local gpu stays in the worker pool, gated by gpu temp [ relative to idle baseline, hysteresis ], memory pressure, idle start, day \ night windows, outdoor temp amplifier -- all ranges configurable, refinements = defaults
metadata:
  type: project
---

design : `data/md/design/THERMAL-AWARE-LOCAL-WORKER.md` [ not built yet ].

- heating here switches off after 22:00 : night gpu heat is WANTED ; a
  night profile looser than day is intended, not a mistake.
- outdoor temp [ `weather.temp`, NOT the stub `weather.current` ]
  amplifies night offsets only ; hard ceiling + memory marks never move.
- 2026-10-29 host freeze had memory pressure too -> memory is its own gate.
- reuse the cold-queue gate [ task.handler.cold-queue-sweep ] + coding
  stretch curve ; the two gpu_temp_update handlers are near-copies ->
  one shared `thermal.*` module first.
- owner : configurable ranges = the flexibility wanted ; profiles optional.

related : [[project-2026-10-29-session-handover-jobsite-live-updates]]

#,,,,,...,,,.,..,,.,.,,..,...,...,,.,,,..,,,.,..,,...,...,,,,,..,,..,,,,,,,..,
#ISLY6NE7FZATMAAWNIL35DAYISPK4U36FLHANPQCK7ILLBIF2TDQTADLS5257A2FN2NQSEK57ISUY
#\\\|GSCLQNZBUAX45KVB6Z3L4TS26L6E5DZMRBSWGSX5Q4BQDZZMTO6 \ / AMOS7 \ YOURUM ::
#\[7]EB5XBI43BHZ7SBVTCYBJ24T3TZH6ALET6OEGBGFU7CHZN5FNNKDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
