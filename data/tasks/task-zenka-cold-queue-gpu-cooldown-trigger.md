## [:< ##

# name  = task: task zenka — GPU cool-down threshold as the cold-queue trigger
# descr = task zenka should defer summary-of-summary / background follow-on
#         work until the GPU has genuinely cooled back toward baseline,
#         using the same live temperature feed the coding zenka already
#         subscribes to for its timeout-stretch feedback loop — actual
#         physical idle evidence, not a guessed debounce timer

## context

session: 2026-07-21. the motivation stands on its own, independent of any
one anecdote: the system already treats idle time as meaningful in several
places — on-demand zenki idle-timeouts (`base.zenki.set_ondemand_timeout`),
the coding zenka's own live GPU-temperature feed (already driving a
timeout-stretch feedback loop), and the "deferred background analysis"
pattern already established in `INTENT-CLASSIFICATION-AND-SELF-IMPROVEMENT.md`
(accumulate, defer to genuine idle time, let statistical weight build before
acting). an idle queue that actually deserves the name — a real, physically-
grounded trigger rather than a guessed timer — was always a reasonable thing
to want for the coding/task zenka pairing, on those merits alone.

the temperature signal is a better fit than it first appears, too: thermal
mass gives it *free* smoothing that a queue-depth signal structurally can't
have. a task queue can be empty one instant and refill the next with zero
lag — depth alone only ever means "empty right now," and any smoothing over
that has to be bolted on separately (which is what a debounce timer actually
is: an artificial attempt to fake the buffering temperature gets for
nothing). GPU temp physically cannot spike or drop instantaneously — it
integrates recent activity by its nature, so "sustained cool, not a single
sample" falls out of the physics of the signal itself rather than needing to
be engineered on top of it. this is the concrete reason direct temperature
coupling gives better idle-awareness than watching a stacked queue would.

concretely, `task.cmd.summary-tree-notify` (the coding zenka's fire-and-forget
notification to the task zenka after a completed reply) turns out to be a
pure accumulator today: an idempotent upsert into
`<task.summary_tree.entries>->{$chk}` with `integrated => FALSE`, persisted,
nothing more. a repo-wide check found **`integrated` is never read
anywhere** — there is no summary-of-summary consumer in the codebase yet.
so what this task actually builds is the **missing deferred consumer** (the
"process" third of accumulate → defer → process), with the GPU cool-down
gate built into it from the start — `integrated => FALSE` is already the
accumulation hook, ready to be read by whatever this adds.

## requirement

**the actual trigger: GPU cool-down, not a guessed timer.** the coding
zenka already subscribes to a live GPU temperature feed (`X-11.gpu_metric
temp`, consumed in `coding.handler.gpu_temp_update`, which maintains
`coding.stats.gpu.temp.load_1s`/`load_5s` plus a 20-sample sparkline —
already used to drive the timeout-stretch feedback loop against
`coding.cfg.gpu_target_temp_c`). that same metric is directly queryable
system-wide (confirmed live this session: `X-11.gpu_metric temp` returned
1s/5s/15s/30s readings), not something coding-internal.

the task zenka should subscribe to this same feed independently — no
coordination with coding needed, matching the earlier decision to keep
this a single-zenka change — and treat "GPU has cooled back toward
baseline, sustained over the existing 5s/15s/30s averaging windows (not
a single noisy sample)" as the actual **cold-queue trigger**: only once
that condition holds does it proceed into summary-of-summary and other
background follow-on work. this is a direct physical proxy for "no heavy
active work is currently happening," which is a stronger, self-correcting
signal than tracking time-since-last-`summary-tree-notify` (which can
only ever guess "probably quiet by now" from a fixed debounce window).

note on terminology: "immediate" (hot) vs. "deferrable/background" (**cold-
queue**) task work already exists as an effective distinction in how the
system is used today (an interactive `ask-reply` needs its answer now;
summary-of-summary and self-improvement analysis do not) — it just isn't
named or enforced as a formal task-type anywhere. this requirement doesn't
introduce a new category, it gives the already-informal cold-queue class
of work an actual trigger grounded in real hardware state, named for
exactly what it measures.

fallback note: on a node without a GPU (or where the metric is
unavailable), the notify-timing debounce (track time since last
`summary-tree-notify` per `source=coding`/`focus`/`origin`) remains a
reasonable secondary signal — worth keeping as a fallback path, not
discarding entirely just because the GPU signal is the better primary
trigger where available.

## manual override

alongside the automatic physical trigger, a manual command to force
cold-queue processing regardless of measured temperature — full user/zenka
control despite the physical-value alignment being the smart default:

```
task.trigger-cold-queue [delay_seconds]
  e.g. task.trigger-cold-queue 247   -> fires in 247s regardless of GPU temp
       task.trigger-cold-queue       -> fires immediately
```

confirmed: `task.*`, not `coding.*` — the task zenka overriding its own
gate, consistent with the cold-queue consumption logic living there.

this is not a new pattern to invent — it's a second application of the
"deferred background analysis" shape already established in
`data/md/design/INTENT-CLASSIFICATION-AND-SELF-IMPROVEMENT.md`
("## deferred background analysis" section): accumulate records, defer
processing to genuine idle time, let statistical/temporal weight
accumulate before acting. that document's version is idle-triggered
analysis over session feedback records; this is the same idle-debounce
principle applied to the task zenka's own summary-tree follow-on work.

## related gaps found the same session, worth keeping in view (separately scoped)

- `coding.learning.record_outcome` (persists to
  `/var/protocol-7/coding/learning/outcomes.json`) has zero call sites
  anywhere in the codebase; the command-surface version,
  `coding.learning.track_success`, is entirely placeholder (every
  function returns hardcoded/fake data, nothing is actually persisted or
  analyzed). neither schema has a `model_id` field — only `service`
  (routing destination, e.g. `gpu`), which doesn't distinguish between
  different models loaded onto the same backend slot over time.
- `mcp__protocol-7__p7_task_complete` only accepts `task_id` + a free-text
  `result` string — no verdict/success field, no way for an external
  reviewing model (Claude/Kimi) to formally assert a task's output was
  actually correct or actually wrong, independent of what the task itself
  self-reported. concretely demonstrated same session: a model declared
  "migration completed successfully" with an incorrect fix (`split`
  semantics misunderstanding); nothing existed to record that verdict
  anywhere structured.
- these three (idle-debounce, model-aware outcomes schema, explicit
  external verdict marking) are pieces of the same underlying need — the
  system currently has no real notion of "idle," no per-model outcome
  history, and no structured ground-truth feedback loop — but are
  independent, separately-scoped changes, not one feature.
- **ambient-weather-adjusted cold threshold** (raised 2026-07-21, during
  dispatch planning for this same task): heatwave conditions can shift a
  GPU's genuine idle baseline upward, so a fixed absolute
  `<task.cfg.gpu_cold_temp_c>` could misfire cold under sustained ambient
  heat. `weather.temp` (`modules/weather.parent.cmd.temp`) exists but is
  pull-only — the `weather.*` zenka has no STRM/subscribe mechanism
  (confirmed: only a periodic internal cache-refresh timer,
  `weather.parent.handler.update_current_timer`, and query commands).
  building an adaptive variant (`ambient_baseline + delta` instead of a
  fixed number) needs a `weather.cmd.subscribe-temp`-style feed mirroring
  what `X-11.gpu_metric` already does, which roughly doubles this task's
  surface area. deliberately kept out of this dispatch — clean separate
  step, not phase 3 of this one.

## implementation plan (2026-07-21, Opus planning pass)

grounded in the actual codebase, not just the requirement above. read the
correction note earlier in this file first — it changes where the gate
lands, not what it does.

### temperature semantics — do not reuse `gpu_target_temp_c`

`coding.cfg.gpu_target_temp_c` (default 80) is a **ceiling** — "don't
exceed this," driving an asymmetric stretch that ramps timeouts up when
temp is *above* it. cold-queue needs the opposite pole: temp is **low**,
near idle baseline (e.g. 40–50°C depending on GPU/ambient — device- and
environment-dependent). these are different in kind, not just different
numbers. introduce a separate task-local `<task.cfg.gpu_cold_temp_c>`
(see open question 3 for absolute-vs-adaptive-delta).

### confirmed mechanics from the codebase

- **subscription pattern** (`modules/coding.init_code` ~lines 569–597):
  deferred via `push <system.callbacks.initialized>->@*, sub {...}`, then
  `<[base.zenki.resolve_primary_sid]>->('X-11', sub { ... route-send
  "$sid.gpu_metric" with call_args { args => 'temp subscribe' }, reply
  handler => ... })`.
- **STRM consumer pattern** (`coding.handler.gpu_temp_update`): guards on
  `$reply->{cmd} eq 'STRM'` + `args eq 'open'`, extracts `$cmd_id`, then
  `<[strm.local.register]>->($cmd_id, { watcher => sub {...} })` which
  splits the buffer on newlines.
- **feed payload shape** (`modules/X-11.handler.read_gpu_metric` ~lines
  84–98): the STRM feed emits **only** `"<load_1s> <avg_5s>\n"` per line
  (or just `"<load_1s>\n"` before a 5s avg exists). **15s/30s averages are
  NOT pushed over the STRM** — they exist in `X-11.gpu_top.metric` but are
  reachable only via query mode: `X-11.gpu_metric temp <ivl>` or bare
  `X-11.gpu_metric temp` for all intervals. "seconds" here are sample
  counts, not strict wall-clock.
- **FALSE reply path** (`gpu_temp_update` lines 9–16): when X-11 is
  unavailable, the reply arrives as `cmd eq 'FALSE'` — the exact hook for
  the GPU-less fallback.
- **timer API** (`<[event.add_timer]>`, base module `base.event.add_timer`):
  one-shot = `{ after => N, handler => 'mod.name' }`, no `interval` key;
  repeating = add `interval => N`. returns an `Event` timer object
  supporting `->cancel` / `->is_active`. `task.post_init` already
  registers one such timer — a natural sibling site for the sweep timer.
- **config**: the task zenka currently loads only `shared-params`
  (`cfg/zenki/task/start` line 4), no `task.cfg.*` accessors
  yet. new values get added as `<task.cfg.*>` defaults in `task.init_code`
  (mirroring `<coding.cfg.gpu_target_temp_c> //= 80` in
  `gpu_temp_update`).

### phase 1 — deferred consumer + manual override + notify-timing debounce
(no GPU dependency — ships the missing "process" half, works on every node)

1. **sweep timer + consumer skeleton.** in `task.post_init`, register a
   repeating timer (interval ~15–30s) whose handler is a new module
   `modules/task.handler.cold-queue-sweep`: collects entries in
   `<task.summary_tree.entries>` where `integrated` is FALSE, consults the
   gate (phase 1: notify-timing debounce only), and when cold, processes
   the accrued batch. **the content of "processing" — summary-of-summary
   vs. reusing `task.cmd.summarize` → `coding.summarize-context` — is
   explicitly out of scope for this plan** (see open question 1). phase 1
   stops at a skeleton that logs, marks `integrated => TRUE`, and persists
   via `task.persist.summary_tree.save`.
2. **notify-timing debounce state.** in `task.cmd.summary-tree-notify`,
   record a last-notify timestamp per `source`/`focus`/`origin` (fields
   already parsed there) into a new `<task.cold_queue.last_notify>` map.
   phase-1 gate = "no `summary-tree-notify` seen within the last
   `<task.cfg.cold_debounce_secs>` for the relevant key." this is the real
   fallback path, not an afterthought — first-class in phase 1, with its
   own config value.
3. **manual override command** `modules/task.cmd.trigger-cold-queue`:
   parses optional `[delay_seconds]`; sets a force flag
   (`<task.cold_queue.force_until>`) checked *before* any gate logic,
   bypassing both debounce and (phase 2) the GPU check; with a delay,
   registers a one-shot `<[event.add_timer]>` that flips the flag, storing
   the timer in `<task.cold_queue.force_timer>` so a later call can
   `->cancel` a pending one; with no delay, forces immediately. **must
   also add `trigger-cold-queue` to `access.cmd.usr.cube`** in
   `cfg/zenki/task/start` or the command is unreachable.

### phase 2 — layer the GPU-temp gate (event-driven, the automatic trigger)

4. **subscribe to the feed** in `task.init_code`/`post_init`, mirroring
   `coding.init_code` 569–597 exactly (same `resolve_primary_sid` /
   route-send / reply-handler shape).
5. **new consumer** `modules/task.handler.gpu_temp_update` — mirror
   `coding.handler.gpu_temp_update` **minus the timeout-stretch feedback
   loop** (task zenka has no such loop to feed). keep: FALSE-reply guard,
   STRM/open guard, `cmd_id` extraction, `strm.local.register` watcher
   parsing `($temp_1s, $avg_5s) = split / +/`, and a
   `<task.stats.gpu.temp.{load_1s,load_5s,sparkline_buf,updated_at}>`
   buffer (reuse the 20-sample idea). on the FALSE branch, set
   `<task.cold_queue.gpu_available> = FALSE` so the sweep falls back to
   phase-1 debounce — this is where the two paths join.
6. **gate condition**: "cold" = `load_5s` at/below
   `<task.cfg.gpu_cold_temp_c>` for the last N consecutive samples in the
   local buffer (default — event-driven, zero extra traffic; see open
   question 2 for the heavier true-15s/30s query-mode alternative).

precedence in the sweep handler: **force flag** (manual override) →
**GPU gate** if `gpu_available` → **notify-timing debounce** otherwise.

### new/changed files

- **new**: `modules/task.handler.cold-queue-sweep`,
  `modules/task.cmd.trigger-cold-queue`,
  `modules/task.handler.gpu_temp_update`
- **changed**: `modules/task.init_code` (config defaults + subscription
  callback), `modules/task.post_init` (sweep timer),
  `modules/task.cmd.summary-tree-notify` (record last-notify timestamps),
  `cfg/zenki/task/start` (add `trigger-cold-queue` to
  `access.cmd.usr.cube`)

### open questions / risks — need a human decision before implementation

1. **what is the follow-on work?** no summary-of-summary consumer exists
   anywhere; confirm whether the intended processing is (a) genuinely
   unbuilt / out of scope beyond the sweep skeleton this plan delivers,
   or (b) meant to reuse `task.cmd.summarize` → `coding.summarize-context`
   over the accrued entries. this plan scopes to the gate +
   accumulation-sweep skeleton, not the inference content of processing.
2. **which windows.** the STRM subscription only carries 1s + 5s.
   "sustained over 5s/15s/30s" as originally worded requires either (a)
   deriving longer windows from a local sample buffer (event-driven, zero
   extra traffic — the default above) or (b) periodically polling
   `"$sid.gpu_metric temp <ivl>"` query mode for true 15s/30s (heavier,
   adds request traffic + a poll timer). pick one.
3. **threshold definition.** absolute Celsius is simple but
   GPU/ambient-dependent; a delta-above-observed-running-minimum ("within
   X°C of the lowest seen") is more portable but needs a warm-up period
   before it's meaningful. decide absolute vs. adaptive-delta, and the
   default value.
   resolved (2026-07-21, live-tested): absolute, `<task.cfg.gpu_cold_temp_c>
   //= 57`. initial 45 default proved unreachable — live idle-floor
   observation (nothing running) sat at 59-61°C, with genuine inference
   load pushing toward 70+. 57 gives real separation from load without
   chasing a floor this hardware/ambient combo doesn't reach — see the
   deferred ambient-weather-adjusted threshold gap above for the longer-
   term fix once summer heat is no longer a factor.
4. **sweep interval vs. debounce window** — keep the sweep tick short
   enough that the debounce window is the actual controlling latency, not
   tick granularity.
5. **invocation-token check** — the callable module is
   `base.event.add_timer` but invoked as `<[event.add_timer]>` (confirmed
   working in both `task.post_init` and `coding.init_code`) — keep that
   exact token, don't "correct" it to `<[base.event.add_timer]>`.

## status: planned, not started

design pass complete (context, requirement, and now a concrete phased
implementation plan grounded in the actual `task`/`coding`/`X-11` module
code). no urgency — ready to be picked up whenever this becomes active
work. the task zenka change described here is the smallest, most
self-contained of the three related gaps in the section above and could
reasonably be picked up on its own without waiting for the other two.

#,,.,,,.,,.,.,.,.,.,,,.,.,..,,.,,,,,,,,,,,,..,..,,...,...,,,,,..,,,,.,,.,,.,.,

#,,,.,..,,.,,,,,.,,,.,,,.,,..,.,.,,,,,...,,..,..,,...,...,.,,,,..,.,.,.,.,,..,
#KM5LJQDXEMLMIFJKMEQGSWCYITXPCHSF3ZYRD4XYLVXEFGDLKUVN2XPD67ILI5D7Y4K3NNB4N7G6S
#\\\|QPLOC2KBR4EV7PV2SBKHPKEME64Q6QYWPR3572TSRJAIEOSKXCR \ / AMOS7 \ YOURUM ::
#\[7]CNYVIWITI7HOC4ACYXSAMVMZSVNZJW5RVZI5Y7FEXTMY4CWUGEBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
