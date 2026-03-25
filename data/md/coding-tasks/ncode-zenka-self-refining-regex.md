## [:< ##

# ncode zenka — self-refining regex transformation engine
# descr = dynamic regex lists that learn from LLM passes, reducing future LLM calls

---

## vision

a zenka like `bin/ncode` that maintains **dynamic regex lists** for code
transformation. each regex has applicability conditions, confidence levels,
and coverage metrics. after each LLM-assisted transformation, the successful
pattern is assessed for regex capture — building a growing library of
transformations that can replace expensive LLM calls.

---

## core loop

```
input code
    │
    ├─ 1. regex pre-pass: apply known patterns [ fast, no LLM ]
    │      each regex checks its own applicability condition
    │      partial matches reduce remaining work for LLM
    │
    ├─ 2. LLM pass: handle remaining transformations [ expensive ]
    │      model receives only what regexes couldn't handle
    │      context includes what regexes already did [ for coherence ]
    │
    ├─ 3. diff extraction: compare LLM output to input
    │      identify new patterns that could become regexes
    │      assess: is this pattern generalizable?
    │
    ├─ 4. regex expansion: add new patterns to dynamic lists
    │      even partial coverage is valuable
    │      mark confidence level and trigger conditions
    │
    └─ 5. iterate: next refinement wave starts with expanded regexes
         coverage grows with each cycle
         LLM calls decrease over time for similar work
```

---

## architecture

### ncode zenka

```
ncode
  ├── ncode.init_code           — load regex lists from yaml, init state
  ├── ncode.regex.load          — parse regex definitions with conditions
  ├── ncode.regex.apply         — run applicable regexes on input
  ├── ncode.regex.assess        — check if a transformation can become regex
  ├── ncode.regex.expand        — add new pattern to dynamic list
  ├── ncode.regex.save          — persist updated lists to yaml
  ├── ncode.transform.wave      — single refinement wave [ regex + optional LLM ]
  ├── ncode.transform.pipeline  — multi-wave pipeline to target compliance
  ├── ncode.cmd.transform       — command interface for other zenki
  └── ncode.cmd.tool_list       — self-describing tool call interface for models
```

### regex definition format

```yaml
---
patterns:
  - name: comment-lowercase
    descr: convert uppercase comment starts to lowercase
    pattern: '^\s*##\s+([A-Z])'
    replace: '## \L$1'
    applicability:
      file_type: module
      confidence: 0.95
      coverage: partial    ## only catches first word
    origin: manual
    stats:
      applied: 342
      false_positive: 0

  - name: quote-to-qw
    descr: convert single-quoted scalars to qw| | style
    pattern: "= '([a-z_]+)'"
    replace: "= qw| $1 |"
    applicability:
      context: scalar_assignment
      exclude: multi_word
      confidence: 0.85
    origin: llm-extracted
    source_task: AKXEYFQ
    stats:
      applied: 127
      false_positive: 3

  - name: regex-pipe-delimiter
    descr: flag m|| patterns containing alternation pipes
    pattern: 'm\|[^|]*\([^)]*\|[^)]*\)[^|]*\|'
    replace: null    ## flag only, no auto-replace
    applicability:
      action: flag_for_review
      confidence: 0.70
    origin: llm-extracted
    note: suggest m{} when pattern contains pipes
```

### applicability conditions

each regex carries conditions that determine when it fires:

```yaml
applicability:
  file_type: module | script | config | yaml
  namespace: context.* | httpd.* | *
  context: scalar_assignment | comment | regex_pattern | log_call
  exclude: multi_word | inside_string | signature_block
  confidence: 0.0-1.0      ## below threshold → flag, don't auto-apply
  coverage: full | partial  ## partial = handles some but not all cases
  requires: []              ## other patterns that must have run first
```

---

## model interface — self-describing tool calls

models interact with ncode via tool-call-style commands that expand
into verbose descriptions during use and compact upon success:

### tool call format

```
ncode.transform {
    input:    <file or code block>,
    target:   'p7-style',
    waves:    3,
    llm_budget: 2000     ## max tokens for LLM calls this run
}
```

### tool expansion during execution [ verbose ]

```
## ncode.transform executing ##
wave 1:
  regex pre-pass: 12 patterns applicable, 8 applied
  coverage: 67% of style issues resolved by regex
  remaining: 4 issues need LLM assessment
  dispatching to coding.ask-reply [ budget: 800 tokens ]
  ...
  LLM result: 4 fixes applied
  regex expansion: 2 new patterns extracted [ confidence 0.80, 0.65 ]

wave 2:
  regex pre-pass: 14 patterns applicable, 14 applied
  coverage: 100% — no LLM call needed

## ncode.transform complete: 2 waves, 1 LLM call (saved 1) ##
```

### tool compaction in log [ terse ]

```
ncode.transform: p7-style 2 waves 14 patterns 1 LLM-call [ 800 tokens ]
  +2 patterns extracted [ comment-lowercase-mid, arg-style-convention ]
```

### self-explaining tool list

models can query available transformations:

```
ncode.tool_list → returns:
  - transform: apply refinement waves to code
  - regex.list: show current patterns with stats
  - regex.test: test a pattern against sample input
  - regex.suggest: ask model to propose new patterns from diff
  - coverage.report: show which style rules have regex coverage
```

---

## integration with review pipeline

ncode step groups plug into `context.review.iterate` as pipeline elements:

```
review page N:
  step 1: ncode.transform [ regex pre-pass ] — free, no LLM
  step 2: model review [ only uncovered areas ] — LLM call
  step 3: ncode.regex.assess [ extract patterns from review ] — free
  step 4: compliance check [ attribute group ] — may trigger more steps
```

each review cycle expands ncode's regex library. after reviewing 50 modules,
many common patterns are handled by regex alone. the LLM only gets called
for genuinely novel issues.

### coverage tracking per attribute

```yaml
style_coverage:
  comment-case: 0.95      ## nearly fully handled by regex
  qw-scalar: 0.85         ## most cases covered
  regex-delimiter: 0.70   ## needs context awareness, partial regex
  bracket-annotation: 0.90
  arg-style: 0.60         ## many variants, growing
  signature-handling: 1.0  ## fully handled by regex
```

when coverage crosses threshold [ e.g., 0.95 ], that attribute's LLM step
becomes optional — only triggered if regex flags uncertainty.

---

## self-refinement properties

### each iteration improves the next

- LLM fixes become regex patterns → next run needs fewer LLM calls
- false positives tracked → confidence adjusts automatically
- coverage metrics guide which attributes still need LLM attention
- regex lists version-controlled → refinements are auditable

### partial coverage is valuable

a regex that catches 40% of cases saves 40% of tokens on every future run.
even "flag only" patterns (no auto-replace) help by directing model attention
to specific lines rather than whole-file scanning.

### making LLM calls obsolete

the ultimate goal: for each transformation type, regex coverage grows
until the LLM call for that step is no longer needed. the step remains
in the pipeline [ for new patterns ] but fires rarely, and when it does,
it may extract another regex that handles the new case going forward.

```
cycle 1:  0% regex, 100% LLM  [ learning ]
cycle 5:  60% regex, 40% LLM  [ partial coverage ]
cycle 20: 95% regex, 5% LLM   [ near-autonomous ]
cycle N:  99% regex, 1% LLM   [ maintenance only ]
```

---

## phasing

### phase 1 — foundation
- `ncode.init_code` — load regex lists, init config
- `ncode.regex.load` — parse yaml definitions
- `ncode.regex.apply` — run patterns on input
- `ncode.regex.save` — persist to yaml
- initial pattern set from existing style conventions

### phase 2 — LLM integration
- `ncode.transform.wave` — single regex + LLM cycle
- `ncode.regex.assess` — extract patterns from LLM diffs
- `ncode.regex.expand` — add with confidence tracking
- `ncode.cmd.transform` — command interface

### phase 3 — pipeline integration
- wire into `context.review.iterate` as step group elements
- coverage tracking per attribute group
- optional LLM steps based on coverage thresholds

### phase 4 — model interface
- `ncode.cmd.tool_list` — self-describing capabilities
- verbose expansion during execution, compact logging
- models can suggest and test new patterns directly

#,,..,,,,,,.,,,.,,.,.,,.,,.,,,,,,,.,.,,,.,...,..,,...,...,...,,..,...,,.,,.,,,
#GZ2ZGRE5OAEVABIER7KOAJDV3ELEOPTIE3E55P2KJOYSVSEBCE2H4I3FL3IT7DOT7RDTNIEC4XTOW
#\\\|IKSDQOEVSXSBMF3365XUG5PTUGBVPIJHRIOUKHNGXDVYOOCI37C \ / AMOS7 \ YOURUM ::
#\[7]IN5IE2N4PVDWTOU24DSKFHJDXX7BLT5UGBY3DTISTCYA2XSEK4DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
