---
name: project-2026-10-29-thermal-aware-local-worker
description: DESIGN 2026-10-29 : local gpu stays in the worker pool, gated by gpu temp [ relative to idle baseline, hysteresis ], memory pressure, idle start, day \ night windows, outdoor temp amplifier -- all ranges configurable, refinements = defaults
metadata:
  type: project
---

design : `data/md/design/THERMAL-AWARE-LOCAL-WORKER.md` [ not built yet ].

- heating here is off 22:00-06:00 [ at 06:00 it comes on full until the
  thermostat regulates ] : night gpu heat is WANTED ; a
  night profile looser than day is intended, not a mistake.
- outdoor temp [ `weather.temp`, NOT the stub `weather.current` ]
  amplifies night offsets only ; hard ceiling + memory marks never move.
- 2026-10-29 host freeze had memory pressure too -> memory is its own gate.
- reuse the cold-queue gate [ task.handler.cold-queue-sweep ] + coding
  stretch curve ; the two gpu_temp_update handlers are near-copies ->
  one shared `thermal.*` module first.
- owner : configurable ranges = the flexibility wanted ; profiles optional.

related : [[project-2026-10-29-session-handover-jobsite-live-updates]]

#,,,,,,,,,,.,,,,.,...,...,,..,.,.,,,,,.,,,,,.,..,,...,...,.,.,,.,,,,,,.,.,,,,,
#7SB35OD7B4PVSYRYR6CG4GG74KYURQBBY4KZ3CJDI6ANXGUYVO44VZFSEWL2ANCBKXWFZYAHTO5VE
#\\\|FPZUJAPZKBJK7YJZTFQNBXNIHT6R3HA4DHP3IL5GWZ4VHV3PTQX \ / AMOS7 \ YOURUM ::
#\[7]F5RRPWRUO3MBM3PZSJGSLEQ2P3IDT3X3ESRP7TAFNBL6UNWTWSAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
