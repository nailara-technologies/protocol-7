## [:< ##

# name  = task: model-sweep cool-down auto-resume -- gpu (mirror existing) + cpu (new, best-effort)
# descr = auto-resume a sweep paused with paused_reason=yield-timeout once
#         the backend has genuinely physically cooled back toward idle
#         baseline, instead of requiring a human to notice and issue
#         model-sweep-resume <backend> :force:

## why now

surfaced live 2026-09-17: `coding.model_sweep.handler.poll_sweep`'s yield
gate (see [[reference-model-sweep-yield-300s-cap-not-stream-aware]]) uses
a flat 300s wall-clock cap with zero awareness of whether the real task
activity it's waiting on is actually healthy -- a legitimately long but
actively-streaming task (confirmed live: self-test/switch probe chunks
climbing 996->2402->2867->3330, genuinely alive) tripped the cap anyway
and paused the gpu sweep, needing a manual `:force:` resume mid-session.

the fix direction, proposed by the user and grounded in an EXISTING,
already-shipped, already-live-tested precedent:
`data/tasks/completed/task-zenka-cold-queue-gpu-cooldown-trigger.md`
(task zenka, 2026-07-21/22) built exactly this shape already for a
different purpose (deferring summary-of-summary background work) --
GPU temperature cooling back to a measured idle baseline is a
physically-grounded, self-smoothing idle signal that a queue-depth
check structurally cannot be (thermal mass integrates recent activity;
a queue can go from busy to empty in zero time with no such smoothing).
that task's own writeup makes the case in detail, read it first.

## scope -- two halves, different confidence levels

### half 1: gpu cool-down auto-resume -- mirror existing infra, no new subscription

the coding zenka ALREADY subscribes to the same feed the cold-queue
task used (`X-11.gpu_metric`) for its own timeout-stretch feedback
loop -- `coding.handler.gpu_temp_update` maintains
`<coding.stats.gpu.temp.load_1s>` / `<coding.stats.gpu.temp.load_5s>`
already, live, right now. this half needs NO new subscription, unlike
the original task-zenka version which had to build one from scratch --
just a new consumer of data that already exists in this same zenka.

add a small watcher (timer, ~15-30s interval, mirroring
`task.handler.cold-queue-sweep`'s own sweep-timer shape) that:
1. only runs at all when at least one backend's model-sweep state is
   `paused` with `paused_reason eq 'yield-timeout'`
   (`<coding.model_sweep_state>->{$backend}`)
2. for the gpu case: checks `<coding.stats.gpu.temp.load_5s>` against
   a new `<coding.cfg.gpu_cold_temp_c> //= 57` (reuse the exact,
   already-empirically-tuned value from the landed task -- same
   hardware, same host, no reason to re-derive it)
3. once cool [ sustained, not a single sample -- mirror the existing
   task's own "not a single noisy sample" requirement, use the same
   5s-average field it already does ], call
   `<[coding.model_sweep.cmd.model-sweep-resume]>` (or route through
   `cube.coding.model-sweep-resume` the same way other internal
   callers do, check which is correct for an in-zenka call) with
   `:force:` for that backend, logging clearly that this was an
   automatic cool-down resume, not a manual one -- so it's
   distinguishable in logs from a human-issued `:force:`

this half is directly testable live on this host (WSL2, confirmed the
`X-11.gpu_metric` feed is real and already flowing).

### half 2: cpu cool-down auto-resume -- new infrastructure, best-effort, UNTESTABLE on this host

**confirmed 2026-09-17: this exact host (WSL2) has ZERO cpu temperature
sensors exposed** -- `sensors` reports "No sensors found!",
`/sys/class/thermal/thermal_zone*` doesn't exist,
`/sys/class/hwmon/*` is empty. This is expected: WSL2's VM layer
doesn't pass real hardware thermal sensors through to the guest. **the
cpu half of this task cannot be live-verified on this deployment at
all** -- only the "gracefully absent, falls back correctly" path can
be tested here. the "actually triggers on real cool-down" path needs a
bare-metal or better-virtualized host to confirm, whenever one is
available.

build it anyway, defensively, exactly as generically as the gpu half:
1. a one-time (or cached, re-probed occasionally) availability check:
   try `/sys/class/thermal/thermal_zone*/type` for a zone whose type
   looks like a real cpu package sensor (commonly `x86_pkg_temp` or
   `coretemp`, varies by kernel/hardware -- don't hardcode one exact
   string, check a few known patterns), reading the paired `.../temp`
   file (millidegrees C, divide by 1000). if nothing matches, cpu temp
   is simply unavailable -- record that once, don't re-probe every
   tick.
2. if unavailable: the cpu backend's yield-timeout pause gets NO
   automatic cool-down resume -- stays exactly as it is today, manual
   `:force:` required. this must be silent/expected, not a warning
   spammed on every sweep tick -- log the unavailability ONCE, not
   repeatedly.
3. if available: same shape as the gpu half -- a new
   `<coding.cfg.cpu_cold_temp_c>` config value (no existing tuned
   number to reuse here, needs a real default AND a note that it will
   likely need live retuning on whatever host actually has cpu temp,
   the same way the gpu number needed retuning from an initial guess
   of 45 to a measured 57), sustained-not-single-sample check, same
   auto-`:force:`-resume call.

**hard requirement**: half 2's absence-detection path must be exercised
live on THIS host as part of verification (confirm it correctly detects
"no cpu temp available" and does nothing destructive/noisy), even
though the presence path cannot be. don't claim half 2 is "done and
verified" without being explicit that only the absence path was
actually exercised.

## explicitly out of scope

- the existing flat 300s yield-cap itself
  (`coding.model_sweep.handler.poll_sweep` lines ~294-372) -- untouched,
  stays as the escalation-to-pause mechanism. this task only adds an
  automatic way OUT of that paused state, not a change to when it's
  entered.
- `coding.helper.backend_idle` (the queue-depth/lock-based idle check
  used for the initial yield decision, before the 300s cap) -- untouched,
  out of scope. this task is specifically about auto-resuming a PAUSED
  sweep, not changing the yield gate itself.
- the task zenka's own `task.handler.cold-queue-sweep` -- a separate
  zenka, separate config namespace, separate feed subscription. this
  task builds coding's own independent consumer of data coding already
  has (gpu) or new data coding doesn't yet read at all (cpu); it does
  not touch or coordinate with the task zenka's existing feature.
- reworking `check_resource_fit`, `calculate_safe_context`,
  `get_children`, `pid_alive`, `gone_child`, or anything else touched
  earlier the same session -- all separately committed and working,
  don't re-investigate.

## verification

- gpu half: live-testable. trigger a real yield-timeout pause (or wait
  for one to occur naturally during a long real task), confirm the new
  watcher correctly auto-resumes once gpu temp genuinely drops below
  threshold, sustained -- not on a single noisy low sample.
- cpu half: only the absence-detection path is testable here. confirm
  it correctly identifies no cpu temp is available, logs that once (not
  per-tick), and the cpu sweep's yield-timeout pause continues to
  require manual `:force:` exactly as it does today -- no regression to
  the existing, working manual-resume path.
- `bin/format-code -c` on every touched/new file. leave the tree
  uncommitted, report back with what changed and how each half was
  actually verified (be explicit about the half-2 testing limitation
  in the report, don't imply more was confirmed than was).

#,,..,.,,,,.,,,..,..,,,.,,.,.,.,.,,,.,...,.,,,.,.,...,...,.,,,..,,.,,,...,..,,
#ITOUSXAUDRVV5NPGIJWOGFDFZNXTSOEQS26KIZKKOTKNAVXJRUN5MN2VRMU3VE5ZATT37BGLMMMMM
#\\\|ZPXHW2CHCMP7OVQXXTE5EKUTSJY4JWIVHLRD6KTVHYOBD2WTS7B \ / AMOS7 \ YOURUM ::
#\[7]DA7IIWMH5XS5WMRQNXFHZZK46NE7MG2N6E3EOUFD3SEQ7RG4VIBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
