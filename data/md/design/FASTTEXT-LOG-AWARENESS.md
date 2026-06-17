## [:< ##

# name  = design: fasttext log awareness arc
# descr = train FastText models on log data and load them into zenki that
#         need deep in-system context. forensics, search, coding zenka each
#         get a log-trained model with timestamps as numerical coordinates.
#         immediately applicable: logs we already have.

## why this arc

log data is the densest signal in the system. every zenka emits it
continuously — command routing, timing, errors, state transitions. today
that signal is used only for human reading. a FastText model trained on log
data transforms it into a dense vector space where:

- similar events cluster numerically
- temporal proximity is preserved through numerical timestamps
- anomalies sit far from known-pattern clusters
- cross-zenka correlations emerge from co-occurrence patterns

the infrastructure being built (signal-cancel-log-library, log-anonymization)
already segments and processes log data. FastText is the next layer: from
structured text → dense numerical awareness.

## timestamp encoding

timestamps must be numbers, not strings, for proximity to carry meaning.
two options depending on precision requirement:

```
ntime (numerical):
  <[base.ntime_BASE32_to_numerical]> → integer, sortable, fast
  use for: sequence ordering, delta calculation, bucket assignment

high-resolution epoch float:
  Time::HiRes::gettimeofday → float with microsecond precision
  use for: correlation windows, event proximity, latency modeling
  format: 1750123456.789012  (14 significant digits)
```

both forms make timestamp proximity implicit — events 200ms apart are
numerically close. sorting by timestamp = sorting by vector proximity on
the time axis. no special time-handling needed in the model: the numbers
carry the semantics.

## zenki that benefit

### forensics zenka

context: full recent log buffers for every active zenka, held in mind.
use: anomaly detection, root cause tracing, incident reconstruction.

```
model: trained on anonymized log stream (all zenki, 30-day window)
load:  at forensics zenka init — one model per log category
query: "find events similar to this error in the last 6 hours"
       → model returns nearest log vectors → reconstruct event sequence
output: ranked timeline of related events, cross-zenka correlation map
```

### search zenka

context: deep in-system search needs more than keyword matching — it needs
to understand what a command, a module, a data path *does* in context.

```
model: trained on combined log + module header corpus
       log entries teach behavioral context; headers teach naming
load:  at search init or on-demand for deep-search mode
query: "find all places where route resolution fails under load"
       → not keyword grep but semantic proximity in log+code space
```

### coding zenka

context: test sequence logs carry precise behavioral traces — `-vvv` output
shows every subroutine call chain; `-vvvv` adds parsed perl code per sub.
too large for any context window, not too large for a FastText index.

```
model: trained on test run logs (-vvv output), per test suite
load:  at coding zenka init when test mode is active
use cases:
  - "did this change break behavior similar to the last regression?"
    → compare current -vvv trace against model of known-good traces
  - "which subroutines are unusual in this run?"
    → outlier vectors from the test-trace model
  - auto-detection of regressions without writing explicit test assertions:
    behavioral distance from known-good model exceeds threshold → flag
```

## model training pipeline

```
phase 1:  log collection
          - read p7-log ring buffer + archived logs
          - apply signal-cancel patterns → strip known noise
          - apply log-anonymization → replace sensitive fragments with tokens
          - convert timestamps to ntime/epoch-float
          output: clean token stream ready for training

phase 2:  FastText model build
          - fasttext skipgram or cbow on the token stream
          - separate models per corpus type:
            log-forensics:   full system log window
            log-test-traces: -vvv test output per suite
            log-commands:    command routing events only
          - model stored at data/fasttext/models/<name>.<epoch>.bin
          - epoch-scoped: models rotate with v7 epoch

phase 3:  zenka integration
          - each zenka that loads a model gets a log.awareness.* module set
          - log.awareness.init:   load model file, set up query interface
          - log.awareness.query:  vector search, return top-N nearest
          - log.awareness.score:  score a line against the loaded model
          - log.awareness.update: online update (fasttext supports this)

phase 4:  automated test support harness
          - build-on-commit hook: after each commit, rebuild test-trace model
          - regression detector: compare current test trace to model
          - threshold config: sensitivity per test suite
          - alert path: p7c coding.regression-alert → task zenka
```

## model build automation

FastText model building is fast (seconds for typical log sizes). automation:

```
trigger:             v7 epoch rotation, or explicit p7c fasttext.rebuild
input source:        log ring buffer snapshot + recent archives
pipeline:            collect → anonymize → tokenize → fasttext train
output:              data/fasttext/models/<corpus>.<epoch>.bin
notification:        p7c fasttext.model-ready <corpus> <path>
zenka reload:        receiving zenki reload model on notification
```

## corpus types and their shapes

```
corpus              source                    token density   update freq
──────────────────  ────────────────────────  ──────────────  ───────────
log-forensics       full ring buffer          high            per epoch
log-test-traces     bin/Protocol-7 -vvv out   very high       per commit
log-commands        routing events only       medium          per epoch
log-errors          error+warn lines only     low             per epoch
module-headers      modules/* name+descr      low             per release
```

## relation to signal-cancel-log-library

signal-cancel creates a "canvas of absence" — known patterns removed,
anomalies surface. FastText creates a "semantic field" — known patterns
form clusters, anomalies are distant outliers.

the two are complementary:
- signal-cancel: rule-based, fast, binary (matched/not)
- FastText:       learned, richer, continuous (distance from cluster)

ideal pipeline: signal-cancel first (remove obvious noise fast), FastText
second (score remaining events in semantic space). signal-cancel reduces
FastText training data to the interesting subset.

## implementation priority

```
1. log collection + tokenization pipeline     — prerequisite for everything
2. fasttext model build script (bin/dev/)     — standalone, no zenka needed
3. log.awareness.* modules                   — generic, reusable by any zenka
4. forensics zenka integration               — highest value, most direct use
5. coding zenka test-trace integration       — regression detection
6. search zenka deep-context mode            — longer horizon
7. automated rebuild + epoch rotation        — production automation
```

relates to:
  data/tasks/signal-cancel-log-library.md    (anomaly surface complement)
  data/tasks/log-anonymization.md            (training data preparation)
  data/tasks/coding-model-self-test-cycle.md (calibration + test harness)
  data/md/design/HARMONIC-SILENCE.md         (canvas of absence concept)

#,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,

#,,,,,..,,.,,,,,.,.,,,...,,.,,...,,,.,,,.,.,.,..,,...,...,.,.,,,,,,,.,,.,,..,,
#246LECQY3ZPNYHX2EJDMOFSDEHGWYOVFKEQPWQ64KYUDOKYTW4IA5TEA4YIW357DICQSU3Y3OACBU
#\\\|RDCHN3JRM4XS77DZMUKWUQI4Q4ICYKWN4U3H3KAJHX5XD5D2LCI \ / AMOS7 \ YOURUM ::
#\[7]GGQA4AOLVBYME3J5CXJXXCM4KPVULQWKIEPBI3Z3RIY72BXQFIDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
