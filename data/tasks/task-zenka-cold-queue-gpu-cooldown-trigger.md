## [:< ##

# name  = task: task zenka — GPU cool-down threshold as the cold-queue trigger
# descr = task zenka should defer summary-of-summary / background follow-on
#         work until the GPU has genuinely cooled back toward baseline,
#         using the same live temperature feed the coding zenka already
#         subscribes to for its timeout-stretch feedback loop — actual
#         physical idle evidence, not a guessed debounce timer

## context

session: 2026-07-21. surfaced while investigating why summaries after
`kimi_dispatch` (and similar chained follow-ons) run slower than expected.
root cause identified precisely: `coding.handler.deferred_reply` already
fires `task.summary-tree-notify` as fire-and-forget — it explicitly never
delays or risks the reply to the original caller (see the comment at
`modules/coding.handler.deferred_reply` around the notify call). that part
is correct and already live.

the actual problem is on the **receiving** side: the task zenka consumes
that notification and immediately proceeds into its own follow-on work
(summary-of-summary, etc.) with no debounce. "fire-and-forget for the
caller" was mistaken for "cheap for the receiver" — it isn't. if the active
workflow (e.g. `kimi_dispatch`) is about to submit more directly-related
work immediately after, the task zenka is already mid-processing the
previous notification instead of being idle, so the two contend and the
whole chain runs slower than if it had waited a moment to see what else
was coming.

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

## status: not started, deliberately deferred

no urgency — captured for whenever this becomes active work. the task
zenka change described here is the smallest, most self-contained of the
three related gaps and could reasonably be picked up on its own without
waiting for the other two.

#,,.,,,.,,.,.,.,.,.,,,.,.,..,,.,,,,,,,,,,,,..,..,,...,...,,,,,..,,,,.,,.,,.,.,

#,,,.,.,.,..,,,,.,,,,,,,,,,,.,,,.,..,,.,.,..,,..,,...,...,...,,..,...,,,,,,,.,
#3RPSEHATVQTSUBPF3DERLEQQFABD6IX2AANTL332JPBOVSQ46VDRXBWDUGS6YGWVPXOM6C7MLDLWU
#\\\|EF3DEYXN42VUVNJC3SFK7ZABN7V3SNXVQF3LYINNMY63HXMJFJ3 \ / AMOS7 \ YOURUM ::
#\[7]XQEL2P46RM4VEMB5EYBCOOOPGCSXJAOSCFVV4WYG4OH5GGDKU2DY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
