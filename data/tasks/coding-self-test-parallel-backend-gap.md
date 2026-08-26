## [:< ##

# name  = task: coding self-test not safe for two backends ready together
# descr = coding.self_test.run's single global in-flight guard means
#         whichever backend's readiness event loses the race never gets
#         self-tested at all -- silently, no retry, no reschedule.

## context

found 2026-08-26 immediately after the CPU spawn crash-loop fixes landed
(LD_LIBRARY_PATH gpu-only gate, RAM-aware context clamp, model_path
dependency wiring). those fixes made GPU and CPU able to come online
close together for the first time -- before today, only GPU ever spawned
at startup, so this gap was never reachable.

live log, both backends becoming ready roughly together:

```
:. coding  : [monitor_startup] backend=gpu is ready
:. coding  : [self_test] starting : model M7XXVGY:AH6BYCA
:. coding  : [monitor_startup] backend=cpu is ready
:. coding  : [monitor_startup] async self-test did not start : self-test already in progress
:. coding  : [self_test] prompt 1 : model M7XXVGY:AH6BYCA : PASS [ literal ttft=7.12s ]
```

gpu's self-test grabbed `<coding.self_test_probe_in_flight>` first; cpu's
own attempt, seconds later, found it already set and gave up entirely.

## what already exists (verified, not assumed)

- `coding.self_test.run` (`src/coding.self_test.run:58-63`): a single,
  NOT per-backend, idempotency guard --
  `return {...} if <coding.self_test_probe_in_flight>;` -- its own
  comment explains why the guard exists (avoid racing the probe state
  machine), but it was written when only one backend could ever be
  spawning at a time.
- `coding.handler.monitor_inference_startup` (`:171-316`) already handles
  the "didn't start" case gracefully -- checks
  `$run_started->{'mode'} ne 'deferred'`, logs it, and calls
  `$resume_queue->()` immediately so the task queue is never left paused
  forever. **nothing hangs or crashes** -- this is a silent coverage gap,
  not an active bug.
- the skipped backend's server still comes fully online and starts
  accepting real tasks -- just never validated by the calibration-prompt
  self-test (numeric check, cat/mouse structural check, reasoning
  sanity). a subtly broken backend config (wrong seed handling, wrong
  chat template, etc.) on whichever backend loses the race would go
  undetected.

## scope

pick one of two shapes (not both):

1. **smallest fix: per-backend retry on drop.** in
   `coding.handler.monitor_inference_startup`, when
   `run_started->{'mode'} ne 'deferred'` specifically because of
   `'self-test already in progress'` (not other failure reasons), queue
   a short-delay retry for THAT backend instead of just resuming the
   queue and giving up. needs care: don't retry forever if the OTHER
   backend's self-test is itself stuck/hung -- cap retries, and confirm
   `coding.self_test_probe_in_flight` genuinely clears once the first
   self-test's on_done fires (`coding.self_test.handler.poll_probe:526`)
   so the retry has something to succeed against.

2. **bigger fix: make the probe state machine genuinely per-backend.**
   `<coding.self_test_probe_in_flight>` becomes a per-backend flag/hash
   (mirrors `coding.state.backend`'s existing gpu/cpu keying elsewhere in
   this same file set), letting both backends' self-tests run
   concurrently instead of serializing. more invasive -- touches the
   probe state machine (`coding.self_test.handler.poll_probe`,
   `coding.self_test.async_probe`) which isn't audited for whether it
   already assumes single-flight elsewhere (e.g. shared scratch state
   between prompts). do NOT assume it's safe without checking.

option 1 is lower-risk and directly closes the observed gap; option 2 is
more correct long-term but needs its own investigation pass first.

## validation

- reproduce the race deliberately (restart coding with both backends
  enabled and roughly balanced startup times) and confirm BOTH backends
  end up with a real, logged self-test pass/fail -- not just one.
- standalone test harness in the style of
  `bin/test-scripts/test-coding-cpu-spawn-path.pl` : stub
  `coding.self_test.run` as a call-recorder, simulate the "already in
  progress" reply for the second backend, assert a retry is scheduled
  (option 1) or that both calls proceed independently (option 2).

not urgent -- filed same day as the CPU spawn fixes that made it
reachable, not a regression in previously-working behavior.

#,,.,,,,,,,,,,.,,,..,,.,,,...,,.,,.,.,.,.,,,.,.,.,...,...,..,,.,.,.,.,,..,,,,,
#UOWRSCUMSQ6Z7K7VIJTKENWIPXAM4MIX42P53C7J6UMRO4C3SQVO5IKS6ZK6W73FLF33JOJI32MUU
#\\\|FNRLNRILF4JRQJ3VVJLDBM4DJ2ANY52CJ5T4B45ODHA7ZBFKKXR \ / AMOS7 \ YOURUM ::
#\[7]YHMG63PBIM4AA6ZWUKSTHSAQFZPJAO6REDC7O64226KMA42OU4BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
