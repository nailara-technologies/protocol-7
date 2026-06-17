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

## calibration prompt

the calibration prompt must be:
- short (fast to process, low variance)
- deterministic (same answer every time — checkable)
- exercises the model's reasoning path (not pure recall)

```
prompt: "What is 7 × 13? Reply with only the number."
expected: "91"
```

the division-by-13 calibration has a pleasant harmonic property.
if the model answers anything other than "91": suspect, log, proceed
with a warning annotation in `coding.cfg.model_status`.

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
coding.self_test.run          run calibration prompt, record results
coding.self_test.evaluate     check answer correctness
coding.self_test.archive      store result in epoch-scoped data tree
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

1. create `modules/coding.self_test.run` — sends "7 × 13 = ?" prompt
   to the specified model via the existing HTTP inference API
   (`coding.handler.process-queued-task` pattern), records TTFT +
   total time + answer, calls coding.self_test.evaluate + archive

2. create `modules/coding.self_test.evaluate` — checks answer = "91",
   returns TRUE/FALSE, logs mismatch with actual output if FALSE

3. create `modules/coding.self_test.archive` — stores result in
   `$data{coding}{self_test}{<epoch>}{<model_id>}` tree

4. create `modules/coding.self_test.multiplier` — percentile_95 of
   TTFT samples × 1.5 → stores in `coding.cfg.timeout_stats`

5. create `modules/coding.self_test.cmd.status` — SIZE reply showing
   all models × last self-test timestamp / TTFT / pass/fail / multiplier

6. create `modules/coding.self_test.cmd.run-now` — accepts model_id arg,
   triggers immediate self-test, returns result

7. wire into `coding.handler.monitor_inference_startup`: after readiness
   confirmed, call `coding.self_test.run` before marking model available

check existing `coding.handler.process-queued-task` for the HTTP
inference pattern to reuse. check `coding.cfg.timeout_stats` data path
to confirm it's initialized in `coding.init_code` or add it there.

#,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,

#,,..,,,.,,..,,,.,,.,,.,,,.,.,.,,,,.,,,.,,,.,,..,,...,...,...,.,,,..,,.,.,..,,
#53LRF5AXU3XRNADUB43QK3N24XN2XZKOWO4PLW7AAEIAK7473BBP4UYWQW3JDHLTTDDKRC4DHJYE2
#\\\|6KUQQDMHLVAYO6NFVE3W47I47XLHQK7AKUJRPJK3LBPORB3EVFD \ / AMOS7 \ YOURUM ::
#\[7]NXVXQUFV6PQD3VTI7NFV7EUV4KBHPDDE4FYRZFLCR35WIZRTTUAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
