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

1. **smallest fix: per-backend retry on drop [ CHOSEN, 2026-08-26 ].** in
   `coding.handler.monitor_inference_startup`, when
   `run_started->{'mode'} ne 'deferred'` specifically because of
   `'self-test already in progress'` (not other failure reasons), queue
   a short-delay retry for THAT backend instead of just resuming the
   queue and giving up. needs care: don't retry forever if the OTHER
   backend's self-test is itself stuck/hung -- cap retries, and confirm
   `coding.self_test_probe_in_flight` genuinely clears once the first
   self-test's on_done fires (`coding.self_test.handler.poll_probe:526`)
   so the retry has something to succeed against.
   `<coding.self_test_probe_in_flight>` itself stays a single global flag
   -- self-tests are still meant to run one at a time, this fix is only
   about making sure every backend eventually GETS a turn instead of
   being silently dropped.

   **design constraint (per user, 2026-08-26):** today only two backends
   exist (`gpu`/`cpu`), but per the already-filed "future: generalized
   multi-slot / multi-model support" note in
   `coding-cpu-and-hybrid-offload-path.md`, that's expected to grow to N
   slots eventually. all NEW retry-tracking state this fix introduces
   (pending-retry flag, retry count, backoff timer per backend) MUST be
   keyed generically by the backend/slot identifier string [ a hash,
   e.g. `<coding.self_test_retry_pending>->{$backend}` ] -- never as two
   separate named variables, an assumed-fixed-size array, or anything
   else that hardcodes "exactly two backends". costs nothing today, and
   means this fix doesn't need rework when multi-slot support lands.

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

#,,.,,.,.,,,,,,.,,..,,,..,.,.,,..,..,,.,.,.,,,.,.,...,...,,,,,...,,,.,,,.,...,
#VJ4TJUNBDJXRW635RU3HTPC2OFSFS7MZMOPLL33H3Y7ODH4K4PYITC4G3CZHEAWAUYY7JOKYKSHKG
#\\\|GE7BBOFXC3HNEISQQZJR6ZGUWQLK2HRJSPAONPTSIFPTKITTEK2 \ / AMOS7 \ YOURUM ::
#\[7]B2CE42RHSA52GMGPEUCVK422E5Z4IKIB3CXZOCFN454NKXTK72BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
