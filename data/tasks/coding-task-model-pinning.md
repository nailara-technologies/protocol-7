## [:< ##

# name  = task: coding zenka task-level model pinning — completed
# descr = enforce a task's ":model:CHECKSUM:" marker against what's
#         actually loaded, auto-switching when needed, verified by
#         direct process inspection, not by label alone.

## context

session: 2026-06-21. raised as the first of two remaining open items
from `coding-model-self-test-cycle.md`'s tier 1 work. investigated,
found genuinely half-built (label parsed, never enforced), then fully
implemented and live-verified.

## status: DONE, live-verified via direct process inspection

```
coding.ask-reply :model:DVEAZIA:GPAKBLA: what is the capital of germany?
  -> switched from whatever was loaded to DVEAZIA:GPAKBLA, task deferred
     correctly during the switch, resumed once ready, answered "Berlin"
  -> confirmed via `cat /proc/<pid>/cmdline`: the ACTUAL running process
     loads OmniCoder-9B-Claude-Opus-High-Reasoning-Distill.Q8_0.gguf,
     DVEAZIA's real model file - not a label, the literal running binary
```

this is the bar that matters: earlier attempts LOOKED correct (label
said the right checksum, self-test reported "2/2 passed") while the
actual running process was a completely different, wrong model. nothing
in this feature was trusted as done until verified by `/proc/<pid>/cmdline`
inspection, not by any internal status field.

## what was actually broken (three layered bugs, all fixed)

### 1. upstream extraction never worked via the normal submission path

`coding.intake.parse_command_string`'s generic `:template-name:` prefix
stripper (`^:([\w-]+):\s*`) matched `:model:` too, consuming it as if
"model" were a template name and promoting it to `type`, BEFORE
`coding.prompt.assemble`'s own specific `:model:CHECKSUM:CHECKSUM:`
regex ever got a chance to see the intact marker. fixed with a negative
lookahead: `^:(?!model:)([\w-]+):\s*`. this is why the feature was
"parsed but inert" - the parsing existed in `prompt.assemble`, but the
generic intake stripper upstream destroyed the marker first, every time,
via the normal `coding.ask-reply` path (the only caller that worked,
`jobsite.util.build_prompt`, must have been injecting the marker through
a different path that bypassed this generic stripper).

### 2. enforcement was entirely missing (the half-built state)

`coding.prompt.assemble` echoed the requested checksum into
`backend_info.model` unconditionally, but nothing ever compared it
against what was actually loaded, and nothing fired `switch-model`.
fixed by adding enforcement in `coding.task.execute`, right after
`prompt.assemble` resolves `backend_info` and before building the
request: if `$assembled->{'parsed'}{'model'}` is defined (an explicit
pin, distinct from `backend_info.model` which is also populated for
auto-selected models), check it against current state via the new
`coding.task.ensure_model_pinned` helper.

new pieces:
- `coding.callback.object_model_checksum_loaded` - dependency callback,
  live self-computing check (no manual flag): true when the object's
  checksum+backend matches `coding.inference_servers.<backend>.model`
  AND status is `ready`.
- `coding.task.ensure_model_pinned` - get-or-creates a per-checksum
  dependency object (lazy, cached, reused across future pins of the
  same checksum), fires `switch-model` once (guarded against redundant
  firing via `coding.model_switch_in_flight`), returns the dependency
  id or undef if already correct.
- `coding.task.execute` - on mismatch, mutates the job's `object_id` to
  the returned dependency id and calls `jobqueue.move_job($job_id,
  'depending')` - re-entering the SAME dependency-wait mechanism every
  other job already uses, no new jobqueue capability needed (confirmed
  precedent: `coding.callback.http_error` already does exactly this
  job_id/bucket mutation for a different reason).
- registered the `model_checksum_loaded` type once in `coding.init_code`,
  alongside the existing `memory_gpu`/`self_test_pending` registrations.

### 3. the await_resources twin-handover watchdog (the deep one)

even with (1) and (2) fixed, switching to a pinned model kept silently
landing on the WRONG (boot-default) model while reporting a CORRECT-
looking label. root cause: `coding.handler.await_resources` exists to
handle a one-time `:twin:` handover scenario at boot (wait for a
sibling instance's GPU server to vacate the port before spawning this
instance's own). it has no way to distinguish "the twin I'm replacing
exited" from "switch-model just killed my own server mid-switch" - it
reacted to ANY gpu-server loss by respawning via
`coding.async_spawn_inference_servers`, which uses
`coding.spawn_params.gpu_model_id` (the BOOT-TIME default), completely
unaware a switch was in progress.

three compounding issues, all fixed:
- a flag-based guard (`coding.switch_model_active`, set in
  `coding.cmd.switch-model`, cleared on every exit path of
  `coding.handler.switch_model_reply`) was added first, but proved
  insufficient ALONE: `await_resources` polls on a 3s interval, which
  can be SLOWER than an entire switch+respawn cycle, so the flag could
  already be cleared by the time it next checked.
- `coding.handler.switch_model_reply` itself had a real regression:
  it updated `<inference.model.amos_id>`/per-backend model_id fields
  AFTER `spawn_smart` succeeded, not before - widening the exact window
  during which anything reading that config (including await_resources)
  would see the stale OLD model. fixed by moving the update to fire
  BEFORE each spawn attempt.
- the actual root fix: `coding.handler.await_resources`'s watchdog
  purpose is permanently fulfilled the FIRST time this instance's own
  GPU server becomes ready - it should retire itself then, not poll
  indefinitely. added cancellation in
  `coding.handler.monitor_inference_startup`'s readiness branch.
  but this alone still wasn't enough: `coding.init_code`'s `$gpu_busy`
  port-probe-and-arm logic ran on EVERY `coding.reload` (reinit, not
  just first boot), re-arming a FRESH await_resources timer every
  single reload, since the port is always legitimately busy with the
  instance's own already-running server. fixed by gating the entire
  probe+arm block on `not $already_initialized` - matching the
  existing sibling `elsif` branch's own gating, which already had this
  right.

## why this took so many passes

each fix was individually correct and each one was live-verified to
do exactly what it claimed - the genuinely hard part was that several
INDEPENDENT, layered bugs all happened to produce the SAME superficial
symptom ("label says the right thing, behavior looks plausible") while
the actual process was wrong underneath. the discipline that actually
caught it: refusing to trust `inference-status`'s label or a passing
self-test as proof, and instead checking `/proc/<pid>/cmdline` directly
against the real gguf file path, every time, until it genuinely matched.

## still open, deliberately out of scope for this task

per the user: automatic batch-grouping of multiplexed tasks by pinned
model (to avoid switch overhead when several queued tasks want the same
non-default model) is a latency optimization, not required for
functional correctness, and explicitly deferred. configurable self-test
suites (from the earlier tier 1 follow-ons) also remains open.

#,,,.,,.,,,,.,..,,..,,,,,,,..,...,.,,,..,,..,,..,,...,...,..,,,,,,..,,.,,,,,.,
#IOM7JTZTZTPRBQTDTCPGMRJEFTNXX5MUQ3HUBVW7HROTWHBN3MNCBPWK2BQPKVSDGRZWQGDC46LBI
#\\\|ENNLZTPATJX7ZHR2IMHYNXSUXCFYHUETCCFMIQZ4O6SPBW34KAV \ / AMOS7 \ YOURUM ::
#\[7]6YYIEWCB55SHNDOUKYQDRL3VUQPC4DM4JZRE4T37HRLLAGDDSGDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
