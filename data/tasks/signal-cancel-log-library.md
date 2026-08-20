## [:< ##

# name  = task: signal cancellation log pattern library
# descr = progressive regex pattern library that cancels known log
#         signal, exposing the anomaly surface as a canvas of absence.
#         the library IS the negative of the world — its complement
#         is the unknown. forensics and coding zenki read the canvas
#         rather than hunting through noise.

## the core principle

every log line belongs to one of two categories:
- **known**: matches a pattern in the cancellation library
- **unknown**: matches nothing — candidate anomaly

the library grows by adding patterns. each pattern added
silences one more class of known signal. as the library
matures, the surface of matched content expands until what
remains on the canvas is structurally improbable — things
the system has never seen before.

the canvas is not assembled by the observer. it assembles itself.

## architecture

### pattern library — `data/signal-cancel/patterns/`

patterns stored as YAML files, one file per category:

```yaml
# data/signal-cancel/patterns/cube-routing.yaml
category: cube-routing
description: cube zenka route create/destroy and session events
patterns:
  - name: route-create
    regex: 'creating route \[\d+\] for session \[\d+\]'
    entropy: low
  - name: session-connect
    regex: 'session \[\d+\] connected from .+'
    entropy: low
  - name: route-timeout
    regex: 'route \[\d+\] timed out after \d+s'
    entropy: low
```

categories (initial set):
```
cube-routing       route/session lifecycle (low entropy baseline)
v7-heartbeat       heartbeat send/receive/timeout (very low entropy)
zenka-lifecycle    start/stop/restart/reload events
module-load        module loading and compilation noise
timer-events       IO::Async timer fire/cancel
ipc-handshake      authentication and session negotiation
coding-inference   model load/inference progress messages
network-io         TCP/unix socket read/write/close events
```

### matcher module — `signal.cancel.*`

```
signal.cancel.match          apply full library to one line → match/no-match
signal.cancel.filter         apply library to stream → emit only unmatched
signal.cancel.categorize     apply library → emit with category label
signal.cancel.load           load pattern library from data/signal-cancel/
signal.cancel.stats          matched count / unmatched count / by-category breakdown
```

### anomaly surface — output modes

```
raw anomaly:     unmatched lines only, original format
annotated:       matched lines dimmed / unmatched lines highlighted
canvas:          only unmatched, with surrounding context lines (n=3)
stats-overlay:   matched% per category + unmatched surface count
```

## baseline calibration mode

a clean system run with no anomalies produces a baseline corpus.
the baseline feeder auto-extracts pattern candidates:

```
1. run system for N seconds in known-good state
2. collect all log lines → baseline corpus
3. cluster by edit distance + structural similarity
4. each cluster → candidate pattern (human review confirms)
5. confirmed candidates → added to appropriate category file
6. library updated → next run: these lines silenced
```

the baseline calibration is not a one-time step — it is a recurring
wave. each wave the library matures and the anomaly surface sharpens.

## integration: coding zenka tool

add `analyze_log` tool to coding zenka:

```
input:   path to log file OR pipe from p7c command output
options:
  --baseline-sample   record this run as baseline (no anomaly output)
  --categories        which pattern files to load (default: all)
  --context=N         lines of context around each anomaly (default: 3)
  --stats             show per-category match statistics
  --canvas            visual canvas mode (anomalies highlighted)
output:  anomaly surface with context
```

example coding zenka invocation during debugging:
```
p7c coding.call-tool analyze_log '{
  "path": "/dev/shm/.7/STDOUT/NIW7OAQ",
  "context": 5,
  "canvas": true
}'
```

## integration: p7c pipeline

```bash
# pipe live v7 console through the cancellation filter
p7c v7.console | p7c signal.filter

# analyze a captured log with stats
p7c signal.analyze --stats --context=3 /tmp/session.log

# baseline calibration pass
p7c signal.baseline --record 30s

# show what the current library covers
p7c signal.stats
```

## visual canvas representation

when rendered in the nshell or a UI frame:

```
known (silenced):   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
known (silenced):   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
known (silenced):   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
ANOMALY:            route [4471] created without session context
known (silenced):   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
known (silenced):   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
ANOMALY:            unknown module 'base.foo.bar' requested
```

the anomalies surface on their own. the observer reads rather than hunts.

## pattern promotion workflow

when an anomaly is investigated and understood, it becomes a pattern:

```
1. anomaly surfaces on canvas
2. forensics zenka / human identifies root cause
3. root cause is known → pattern candidate
4. pattern written + added to appropriate category file
5. library updated → this class of event silenced in future runs
6. next canvas: one fewer false positive
```

the library accumulates forensic understanding permanently.
each investigation that produces a pattern is knowledge compressed
into silence — available instantly on all future runs.

## relation to harmonic silence template

this is the concrete implementation of active cancellation as described
in `data/md/design/HARMONIC-SILENCE.md`:

```
theoretical:  waveform cancellation → sensing event horizon
practical:    regex library → known-pattern surface → anomaly canvas

the library IS the negative of the world.
its complement IS the unknown.
the canvas presents what the system has never seen before.
```

the forensics/coding zenki shift from hunting to reading.
the first time a fresh session starts with the library loaded:
the canvas is already calibrated. no warmup. anomalies surface
from the first line.

## implementation order

```
phase 1:  pattern library YAML format + 3 initial category files
          (cube-routing, v7-heartbeat, zenka-lifecycle)
          signal.cancel.load + signal.cancel.match

phase 2:  signal.cancel.filter (stream mode)
          p7c signal.filter as pipeline primitive
          signal.cancel.stats

phase 3:  baseline calibration mode
          signal.baseline.record + signal.baseline.extract_candidates

phase 4:  coding zenka analyze_log tool
          canvas visual mode
          pattern promotion workflow (add-pattern command)

phase 5:  visual canvas in nshell frame
          per-category color coding
          anomaly highlight with context lines
```

## dispatch prompt

implement phase 1 and 2 of the signal cancellation log library:

1. create `data/signal-cancel/patterns/` directory with three initial
   YAML pattern files: `cube-routing.yaml`, `v7-heartbeat.yaml`,
   `zenka-lifecycle.yaml` — each with 5-10 real patterns extracted from
   the actual protocol-7 log format (check `/dev/shm/.7/STDOUT/NIW7OAQ`
   for live examples if available, otherwise use common log patterns from
   the codebase)

2. implement `src/signal.cancel.load` — loads all YAML files from
   `data/signal-cancel/patterns/`, compiles each pattern's regex,
   stores in `$data{signal}{cancel}{library}` keyed by category

3. implement `src/signal.cancel.match` — takes one log line,
   applies all compiled patterns, returns `{ matched => 1/0, category =>
   'name', pattern => 'name' }` or undef if no match

4. implement `src/signal.cancel.cmd.filter` — reads from STDIN or
   file path arg, applies match per line, emits only unmatched lines
   (the anomaly surface)

5. implement `src/signal.cancel.cmd.stats` — returns per-category
   match counts + total matched/unmatched since last reset

6. add `signal` to a standalone start config so it can run on-demand,
   or implement as a library loaded by coding zenka

verify phase 1+2 with: `p7c signal.filter < /dev/shm/.7/STDOUT/NIW7OAQ`
should return only lines that don't match any known pattern.

#,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,

#,,,,,,,.,,,,,.,,,,,.,,,.,.,.,..,,...,,,.,,,,,..,,...,...,..,,.,.,,,,,.,,,.,,,
#4F4JXN2DARFM36QYXPZ6Y2WLG6RHZMNOAUFEAKFAWVJX2U4W4P3NSN7KS3H3HWKIUYKVRCE2CG372
#\\\|JBVRLX7PGXDVFUJJXEEXKYQ3A7D3NCYI64356AG4DM5KQIR3XIN \ / AMOS7 \ YOURUM ::
#\[7]BBBBW7XKERQXPHEUPC3OLOBMMZPL3ILNW7OBK5SL5HOLMC4XMKCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
