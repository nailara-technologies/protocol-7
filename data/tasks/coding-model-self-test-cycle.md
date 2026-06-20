## [:< ##

# name  = task: coding zenka model self-test cycle
# descr = run a calibration benchmark after each model load to acquire
#         per-model timeout multipliers. expandable to model fallback,
#         consensus ranking, and archived per-attempt results.

## context

the coding zenka already has:
- `coding.cfg.timeout_stats` — statistical adaptive timeout (future task)
- `coding.async_spawn_inference_servers` — model loading infrastructure
- `llm.service.consensus_vote` — multi-model voting
- task zenka — state machine iterator for batch processing

this task adds the self-test cycle that feeds the timeout stats and
enables intelligent model selection and fallback.

design context: `data/md/design/CHECKSUM-NESTED-ADDRESSING-AND-EPOCH-VALIDITY.md`
                (section 3)
relates to: [[topic-coding-state-machine]], [[topic-task-coordination]],
            `data/tasks/coding-model-selection-template.md`

## the self-test cycle

after each model load completes, before the model is marked available
for production tasks:

```
1. send calibration prompt (fixed, short, known-good)
2. record: time-to-first-token (TTFT), total tokens, total time
3. compute: tokens_per_second, estimated timeout multiplier
4. store in coding.cfg.timeout_stats[model_id]
5. if test fails (timeout, error, garbage output): mark model suspect
   → try fallback model
   → if no fallback: log warning, proceed anyway (degraded mode)
6. mark model available for production
```

## calibration prompts

run as a fixed sequence per model load. each prompt must be:
- short (fast to process, low variance)
- deterministic (same answer every time — checkable)
- exercises the model's reasoning path (not pure recall)

```
prompt 1 (arithmetic): "What is 7 × 13? Reply with only the number."
expected: "91"

prompt 2 (predation riddle): "put a cat and a mouse in a room, close
  the door and wait.., who is the remaining animal?"
expected: "cat" (case-insensitive, trimmed — exactly 3 characters)
```

the division-by-13 calibration has a pleasant harmonic property. the
riddle was chosen live (2026-06-20 session) after observing the local
model answer it correctly once, then incorrectly/contradictorily on a
second unconstrained run — it's a good calibration case precisely
because it has exactly one correct short answer but a known failure
mode (verbose self-contradiction) that's easy to detect mechanically:
checking the trimmed answer length/content catches both "wrong content"
and "didn't follow the brevity instruction" in one comparison.

if the model answers anything other than the expected string for either
prompt: suspect, log, proceed with a warning annotation in
`coding.cfg.model_status`, AND trigger the anomaly follow-up below.

## anomaly follow-up

when a calibration answer doesn't match the expected string exactly
(after trim + case-fold): don't just log pass/fail — automatically
re-prompt the same model, same context, asking it to explain its own
reasoning for the answer it just gave. archive the follow-up
explanation alongside the original mismatch.

```
1. self_test.evaluate finds answer != expected
2. immediately send follow-up prompt to the SAME model:
   "explain your reasoning for that answer, step by step"
   (no new context — same conversation/session if the inference
   backend supports continuation, otherwise replay the original
   prompt + answer + the follow-up question together)
3. archive the explanation in
   $data{coding}{self_test}{$epoch}{$model_id}{anomaly}{$prompt_id} =
     { answer => <original mismatched answer>,
       explanation => <follow-up response>,
       expected => <expected string> }
4. mark model suspect (existing behavior, unchanged)
5. do NOT block availability on this — the follow-up is diagnostic,
   not gating; degraded mode proceeds as already specified above
```

this turns every calibration failure into a labeled training/diagnostic
sample instead of a silent pass/fail bit — the explanation is what
distinguishes "model is just unreliable" from "model has a specific,
nameable confusion" (e.g. tonight's case: pattern-matching the riddle
against the wrong genre of lateral-thinking puzzle instead of
recognizing predation).

## timeout multiplier calibration

the self-test TTFT becomes the baseline for this model:

```perl
my $ttft_seconds = $self_test_result->{ttft};
my $baseline_tps = $self_test_result->{tokens_per_second};

# store in stats ring (rolling window of N self-tests per model)
push @{ $data{coding}{cfg}{timeout_stats}{$model_id}{ttft_samples} },
    $ttft_seconds;

# compute p95 multiplier
my $p95_ttft = percentile_95( @ttft_samples );
$data{coding}{cfg}{timeout_stats}{$model_id}{ttft_p95}   = $p95_ttft;
$data{coding}{cfg}{timeout_stats}{$model_id}{baseline_tps} = $baseline_tps;
$data{coding}{cfg}{timeout_stats}{$model_id}{multiplier}  = $p95_ttft * 1.5;
```

this feeds directly into the statistical adaptive timeout described
in `topic-next-steps` — no separate task needed for the data structure.

## model fallback chain

on production task failure (timeout, error):

```
current model fails
  → check fallback_chain config for current model
  → if fallback available: resubmit task to fallback model
  → log: which model failed, which fallback used, failure reason
  → if fallback also fails: escalate (return error to caller)
```

fallback chain configured per-model in zenka config:

```
coding.cfg.model_fallback.DVEAZIA = CSABG4A   # Glitter fails → DeepSeek
coding.cfg.model_fallback.CSABG4A = none       # DeepSeek is the last resort
```

## result archival

each self-test result archived with epoch-scoped key:

```
$data{coding}{self_test}{$epoch}{$model_id}{timestamp} = <ntime>
$data{coding}{self_test}{$epoch}{$model_id}{ttft}      = <seconds>
$data{coding}{self_test}{$epoch}{$model_id}{tps}       = <tokens/sec>
$data{coding}{self_test}{$epoch}{$model_id}{passed}    = TRUE/FALSE
$data{coding}{self_test}{$epoch}{$model_id}{answer}    = <model output>
$data{coding}{self_test}{$epoch}{$model_id}{prompt_id} = <which calibration prompt>
$data{coding}{self_test}{$epoch}{$model_id}{anomaly}{$prompt_id} = {
    answer => <mismatched answer>, explanation => <follow-up response>,
    expected => <expected string> }    # only present on mismatch
```

older epochs can be squashed/archived. current epoch self-tests
always available for timeout calibration.

## consensus ranking (phase 2)

after multiple models have completed their self-tests:

```
send same calibration task to all loaded models simultaneously
collect all responses
run through llm.service.consensus_vote
rank models by: correctness + speed + consistency
store ranking in coding.cfg.model_ranking
use ranking for task routing (prefer top-ranked for quality tasks,
accept lower-ranked for speed tasks)
```

this may share a state-machine iterator with the task zenka batch
processor — the common pattern: send N tasks, collect N results,
aggregate. extract that into a shared `batch.collect.*` module
when the duplication becomes clear.

## modules

```
coding.self_test.run          run calibration prompt sequence, record results
coding.self_test.evaluate     check answer correctness; on mismatch,
                              trigger coding.self_test.follow_up
coding.self_test.follow_up    re-prompt the model to explain its
                              reasoning for a mismatched answer
coding.self_test.archive      store result (+ anomaly explanation if
                              any) in epoch-scoped data tree
coding.self_test.multiplier   compute timeout multiplier from sample set
coding.self_test.cmd.status   show self-test results per model
coding.self_test.cmd.run-now  trigger manual self-test for a model
```

## integration point

in `coding.async_spawn_inference_servers` or
`coding.handler.monitor_inference_startup`, after readiness is confirmed:

```perl
# model is ready — run self-test before marking available
<[coding.self_test.run]>->( $model_id );

# if self-test passes: mark available
$data{coding}{model}{$model_id}{available} = TRUE;

# if self-test fails: log + mark suspect (still available, degraded)
$data{coding}{model}{$model_id}{suspect} = TRUE;
warn "model $model_id failed self-test — degraded mode";
```

## validation

```bash
# trigger model reload + watch for self-test
p7c coding.self_test.status
# → shows all models with last self-test timestamp, TTFT, pass/fail

# manual trigger
p7c coding.self_test.run-now DVEAZIA
# → runs calibration, shows result

# check timeout multiplier was updated
p7c coding.self_test.status
# → multiplier column updated from new TTFT sample
```

## dispatch prompt

implement the coding zenka model self-test cycle.

1. create `modules/coding.self_test.run` — sends the calibration prompt
   sequence (arithmetic "7 × 13", then the cat/mouse riddle) to the
   specified model via the existing HTTP inference API
   (`coding.handler.process-queued-task` pattern), records TTFT +
   total time + answer per prompt, calls coding.self_test.evaluate +
   archive for each

2. create `modules/coding.self_test.evaluate` — checks answer against
   the prompt's expected string (trim + case-fold), returns TRUE/FALSE;
   on FALSE, calls `coding.self_test.follow_up` before returning

3. create `modules/coding.self_test.follow_up` — sends a second prompt
   to the same model asking it to explain its reasoning for the
   mismatched answer; returns the explanation text for archival

4. create `modules/coding.self_test.archive` — stores result (+ anomaly
   explanation if any) in `$data{coding}{self_test}{<epoch>}{<model_id>}`
   tree

5. create `modules/coding.self_test.multiplier` — percentile_95 of
   TTFT samples × 1.5 → stores in `coding.cfg.timeout_stats`

6. create `modules/coding.self_test.cmd.status` — SIZE reply showing
   all models × last self-test timestamp / TTFT / pass/fail / multiplier
   / anomaly count

7. create `modules/coding.self_test.cmd.run-now` — accepts model_id arg,
   triggers immediate self-test sequence, returns result (+ anomaly
   explanations if any)

8. wire into `coding.handler.monitor_inference_startup`: after readiness
   confirmed, call `coding.self_test.run` before marking model available

check existing `coding.handler.process-queued-task` for the HTTP
inference pattern to reuse. check `coding.cfg.timeout_stats` data path
to confirm it's initialized in `coding.init_code` or add it there.

#,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,

#,,,.,,..,,.,,,,.,,..,.,.,,..,,..,,..,,,.,...,..,,...,...,,..,.,,,,..,...,.,.,
#N2376QUR22Z46NOCGCYDLLUWZM5LLT42Z2BEMP4QIQGJF7I6O2LZPZGFI4NEJGGN3PQWKKOLQ3EAY
#\\\|OS7QR4DREHIPXQNWUAOAZTZQIIRAEAIFMF2RVZQVWOK4I4TXSU3 \ / AMOS7 \ YOURUM ::
#\[7]AJOE4TMYBU6GRXFCT5L5SE4V63F4N2QQXCQ3XUOWE5BH4AGCNQCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
