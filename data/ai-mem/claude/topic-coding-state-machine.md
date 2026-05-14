---
name: coding state machine namespace
description: reactive coding.state design replacing polling timers with variable watchers
type: project
originSessionId: b0b8f206-7222-40ca-8773-87ffa6d21352
---
Replace `coding.async.backend_busy` polling (0.7s retry timer) with proper reactive
state under `<coding.state>` namespace, using `<[event.add_var]>` (Event.pm variable watchers).

**Why:** Polling timers are blind — they fire repeatedly regardless of whether
state changed. Watchers fire exactly once on change, deterministic, no wasted ticks.

**Namespace:**
```
coding.state.backend.gpu.lock    → task_id holding lock | undef
coding.state.backend.gpu.queue   → [ waiting task_ids ]
coding.state.task.<id>.status    → pending|streaming|waiting|complete|failed
```

**Lifecycle:** pre_init bootstrap → init_code restore from zenka_dir → end_code
persist snapshot. Same pattern as valued tree. Watchers are ephemeral (not
persisted), re-registered when tasks resume after restart.

**Only timers remaining:** inference_timeout, task_stale_cleanup, buffer save/drop.

**Task file:** `data/md/coding-tasks/coding-state-machine-namespace.md`
**Template:** `data/yaml/context-templates/timer-to-watcher.yaml`

**How to apply:** When implementing, verify `event.var_watcher` call signature
in base.event.* before writing the watcher registration code.

#,,..,,..,.,,,,,.,,,.,..,,...,.,,,,,,,,..,,,,,..,,...,...,...,..,,.,.,,,,,...,
#WRHTNT5Q6XMKAWG6JILKIIGKHJUU2DMRYSPXY2PSAEF5IRUJFTR6O3BFBJ43UWGNLI7ER3RRL6E6A
#\\\|DTQWU2PP22BR2KB6CHDFYBTCPYWAT3CKBBP3YAAQBA2SUDDIJXG \ / AMOS7 \ YOURUM ::
#\[7]ZXHQ327GYJ7F6LTAUVAFFDRYLEZCAPNZ6CLJDSGMIOVCCK6ZUODQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
