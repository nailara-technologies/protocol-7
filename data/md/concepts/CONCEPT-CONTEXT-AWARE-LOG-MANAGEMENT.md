# concept: context-aware log management

## current limitations

- heartbeat traffic at verbosity level 2 on the cube console slowly washes away
  all other messages — signal-to-noise degrades rapidly with connected zenki
- child zenka startup produces a burst of buffered messages when p7-log becomes
  accessible (v7.notify_online p7-log reply), visually resembling a runaway loop
  but settling once the initial buffer drains
- log files on disk grow unbounded without compaction; older entries have equal
  visual weight regardless of relevance

## planned direction

### context-aware filtering and compaction

- filter and compact repetitive log patterns (heartbeat traffic, routing noise)
  without discarding them entirely — summarize into counts or rate indicators
- anomaly detection: flag log patterns that deviate from established baseline
  for a given zenka or time window
- automatic highlighting of unexpected or security-relevant events regardless
  of current verbosity level

### dynamic verbosity

- automatically raise log level temporarily around anomalous or security-relevant
  events to capture surrounding context while they are occurring
- automatically reduce verbosity for high-frequency repetitive patterns once
  they are confirmed as expected behavior
- net effect: always-on low-verbosity baseline with automatic zoom-in on
  anything worth attention

### log file lifecycle

- context-aware auto-compaction of older log files on disk
- retain anomalous or flagged entries at full resolution; compact routine entries
- time-windowed aggregation: "200 heartbeat exchanges, no anomalies" rather than
  200 individual lines

## existing foundation

`buffer-erase-level <1..3>` — already implemented: erases all in-memory zenka
buffer entries above the specified level on demand. a manual precursor to the
automatic compaction direction — the mechanism exists, the next step is making
the trigger context-aware rather than operator-driven.

next step: add an age parameter so level and age combine as compaction dimensions:

```
buffer-erase-level <level> <age-seconds>   ## erase entries older than age above level
```

this enables compaction waves — multiple thresholds running simultaneously:

| age threshold | level erased | effect |
|---------------|--------------|--------|
| 30s           | 3+           | debug noise fades quickly |
| 5min          | 2+           | info settles after activity |
| 30min         | 1+           | only errors survive long-term |

the buffer then naturally decays toward signal over time — always reflecting
"what matters now" rather than "everything since startup", without any operator
intervention once the wave thresholds are configured per zenka type.

## non-linear ring buffer

the compaction wave model changes the fundamental character of the ring buffer:
instead of a lossy FIFO that silently drops oldest entries when full, the tail
becomes a compressed summary — you lose resolution, not meaning.

### repetition and group coherence

messages can be grouped and compressed by structural pattern — strip variable
parts, match the template, count occurrences and track variable ranges:

```
## raw (linear ring buffer, 2400 entries eaten):
heartbeat ok [ peer: cube, sid: 0x4a2f ]
heartbeat ok [ peer: cube, sid: 0x4a2f ]
... × 2400

## compacted (non-linear, one summary entry):
heartbeat ok [ peer: cube ] × 2400  [ last 30min, no anomalies ]
```

coherent message groups — sequences that form a logical unit (request →
process → response, connect → authenticate → ready) — are treated as a
single repeatable pattern. repetition of the whole group collapses into
one summary with count, timing statistics, and outlier flagging:

```
request-process-response × 847  [ mean 12ms, 3 outliers > 100ms ]
```

### anomaly surfacing and parameter preservation

any occurrence that breaks the compression pattern — an unexpected member
in a known group, a timing outlier, an error in a sequence that is usually
clean — is automatically surfaced at full resolution and promoted in
visibility, regardless of its log level or age. the compression itself
becomes an anomaly detector: what cannot be compressed is by definition
unusual.

critically, anomalous entries preserve their triggering parameters — the
variable parts that deviated from the established pattern — not just the
observable symptoms and fallout. this is the difference between knowing
something went wrong and being able to understand or reproduce why:

```
request-process-response × 847  [ mean 12ms ]
  !! outlier × 3  [ 340ms, 280ms, 190ms ]
     preserved:  peer=10.0.0.7  payload_size=48302  queue_depth=14
                 peer=10.0.0.7  payload_size=51204  queue_depth=12
                 peer=10.0.0.3  payload_size=47891  queue_depth=11
```

without triggering parameters: "sometimes slow" — a symptom.
with triggering parameters: "large payload + high queue depth, one peer
appears twice" — a reproducible hypothesis. the buffer retains the causal
context, not just the effect.

### result

the buffer retains semantic context of what happened across its full depth
rather than just recent raw entries. for development and debugging: recent
activity at full resolution, older activity as dense summaries, anomalies
always visible. the buffer becomes a meaningful operational history rather
than a sliding window of noise.

## relationship to self-morphing code direction

the same pattern applies here as in code style convergence: a system that
autonomously moves toward a desirable state (clear, informative, low-noise logs)
guided by defined quality dimensions (signal/noise ratio, anomaly salience),
without manual tuning per deployment. context awareness as a first-class property
rather than a configuration parameter.

the compressed, parameter-preserving buffer is also the natural input to the
forensics zenka — one produces structured anomaly records across its full depth,
the other consumes them to find causes across time.

## see also

- data/md/concepts/CONCEPT-SECURITY-AND-FORENSICS-ARCHITECTURE.md
- data/md/documentation/LOGGING-AND-VERBOSITY-REFERENCE.md
- data/md/concepts/CONCEPT-SELF-MORPHING-CODE-STYLE-CONVERGENCE.md

#,,..,.,,,.,,,.,,,,..,,,,,,,,,,.,,..,,,..,...,..,,...,..,,.,.,...,...,,.,,.,.,
#YGZ4WCGKXDXKBYILLNPQNM53CRTPVGWDZ37FQF5JZHKB23B4K7CVVJP6OSGBH57KCCMMRCOUQJXWC
#\\\|K4RTMOZZ6E5GL7YITYCYQ3HTPRNMQJY2OXBHAR2K3KNIREZ6JSK \ / AMOS7 \ YOURUM ::
#\[7]SSJSLZ5IFRUEZZBLSOWZKDGNJKD3NDYVOFCI7VRJPUFWGTJSHKCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
