---
name: topic-coding-cpu-spawn-day-2026-08-26
description: CPU inference-server spawning made to work for the first time 2026-08-26 -- what's committed and working, what's deliberately deferred, and the two open task files to read before touching self-test or timeout tuning again
metadata:
  type: project
---

2026-08-26: CPU-backend inference spawning was made to actually work for
the first time (previously GPU-only, CPU was an unimplemented
placeholder). This surfaced a chain of real bugs, all fixed and
committed same day (commits `24f45740f`, `782c8c2b6`, `d7e975efb`,
`35c6bfb1a` on branch `base`):

- `coding.spawn_inference_server`'s LD_LIBRARY_PATH override (GPU/CUDA
  rebuild-out dir, carries its own incompatible libggml.so) was applied
  unconditionally, segfaulting the CPU binary on every launch. Gated to
  `backend eq 'gpu'` only.
- `coding.helper.calculate_safe_context`'s CPU branch did zero RAM math,
  just returning a GPU-tuned config default. Added a RAM-aware clamp via
  `/proc/meminfo`, mirroring the GPU VRAM clamp.
- `coding.init_dependencies` (where the model_path dependency objects
  were meant to be created) is NEVER actually invoked anywhere -- dead
  code. Moved the object-creation into `coding.init_code`, which
  genuinely runs at startup.
- `coding.spawn_inference_server`'s GPU-only "foreign llama process" OOM
  safety check treated the running CPU backend's own healthy process as
  an intruder, permanently blocking every GPU respawn (crash-restart,
  seed-retry-restart) for as long as CPU stayed alive. Now excludes
  CPU's own tracked pid + forked children, same as GPU's own pid already
  was.
- `coding.self_test.run`'s single global in-flight guard silently
  dropped whichever backend lost the readiness race (no retry) --
  replaced with a variable watcher wake (mirrors
  `jobqueue.event.register_job_queues`'s precedent) + safety-net
  timeout, verified live end to end.
- `coding.resolve.object.model_path` used `<[base.log]>` (no sprintf)
  with a real substitution arg for a literal `%s` -- fixed to
  `<[base.logs]>`.

**Deliberately NOT done, two open task files, read both before touching
this area again:**

- `data/tasks/coding-self-test-true-parallelization.md` -- the
  sequential-wait fix above works, but self-tests still can't run in
  PARALLEL across backends (only sequentially with a responsive wait).
  Since CPU is ~7-8x slower, a fast GPU can sit blocked behind a slow
  CPU self-test for up to ~1700s if CPU wins the race first -- a real
  usability regression. Full audit already done and is trustworthy (no
  unsafe cross-backend shared state found, two follow-up verifications
  resolved clean) -- do NOT re-audit, the file has the complete findings
  and the exact per-backend-watcher design correction needed (see
  [[feedback-event-add-var-per-key-not-per-hash]]). A first implementation
  attempt hit its own dispatch budget cap mid-edit and left ONE file
  (`coding.self_test.run`) in a genuinely broken, inconsistent state
  (check side converted to hash, set side still scalar -- would crash on
  the second self-test) -- caught and reverted before commit, never
  shipped. The task file documents this exact broken pattern so it isn't
  reproduced.
- `data/tasks/coding-backend-aware-timeout-scaling.md` -- the shared
  HTTP/self-test timeout constants (soft 127s, hard ~780s, cycle
  watchdog ~1700s) are tuned purely for GPU and are too tight for CPU
  (confirmed ~9-10.5x slower on same-session back-to-back same-model
  comparison for simple prompts). Rejected fixing via a flat multiplier.
  Direction: measure tokens/second live during a round, use GPU's own
  baseline (available first, GPU finishes before CPU) to dynamically
  rescale CPU's remaining ceiling; `base.curve.*` may already provide
  the interpolation primitives needed. Not started.

**Process note:** two `claude_dispatch`/`kimi_dispatch` continuations
this same day returned incomplete work — one hit an MCP idle-timeout
after 1800s but had actually finished (verify via disk state, not the
reported status); another hit its own $-budget cap mid-edit and left a
literal crash bug in one file (verify via reading the actual diff for
internal consistency across every touch point of a shared data-shape
change, not just "does it compile"). Both patterns already had memory
entries from earlier sessions; this reconfirms them under a case with
real stakes (a live production crash, not just wasted work).

#,,,.,,,,,,.,,..,,,,.,,,.,,,,,..,,,..,...,,.,,..,,...,...,,.,,..,,,,.,..,,,.,,
#LQXETHF7DPRRV2JYB5724NUFGC7GWD72V6URC2D7A7JQZSUKXSWVLWZ7GYXEUGFQX6SL43GJUD2K4
#\\\|VCAD24TMPHMZSFQANGQAN2QWMJ5JO4NIBSL2CKNX5ZPR3M36AGR \ / AMOS7 \ YOURUM ::
#\[7]RIFOUFL7XWTOZ5ZN7K6VW7E2HQUNNKKORDUFNE654DJ7GYWABSCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
