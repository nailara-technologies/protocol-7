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

## decision tree — regex → callback → LLM escalation

each transformation is a **decision tree** where nodes are regexes, callbacks,
or LLM escalation points. the tree grows from its own decisions.

### escalation ladder

```
level 0: regex match → auto-apply [ fastest, no cost ]
level 1: callback → evaluate condition → select from alternatives [ fast ]
level 2: LLM call → decide among options [ expensive, but informed ]
level 3: user prompt → confirm preference [ rare, but definitive ]
```

### example: m|| pipe delimiter fix

```
regex: detect m|...(a|b)...|
  │
  ├─ callback: does pattern body contain alternation pipes?
  │   no  → pass [ no issue ]
  │   yes → callback: which delimiter alternatives are safe?
  │           candidates: m{} m() m[] m!! m##
  │           │
  │           ├─ callback: pattern contains braces?
  │           │   no  → m{} [ auto-select, confidence 0.98 ]
  │           │   yes → callback: pattern contains parens?
  │           │         no  → m() [ auto-select ]
  │           │         yes → escalate to LLM
  │           │               │
  │           │               └─ LLM selects best delimiter
  │           │                  → user confirms? [ optional ]
  │           │                  → record preference as hint
  │           │                  → next time: skip LLM, use hint
  │           │
  │           └─ if regex expansion exceeds readability threshold:
  │               → is next style alternative still smaller?
  │               → is this better left for LLM context awareness?
  │               → meta-decision: regex vs LLM boundary assessment
  │
  └─ apply selected fix → log → update stats
```

### preference recording

user and LLM decisions become **loaded hints** — not hard rules, but
weighted defaults available in similar future cases:

```yaml
preferences:
  - pattern: regex-delimiter-conflict
    hint: prefer m{} even when braces present [ escape inner braces ]
    source: user-confirmed
    confidence: 0.95
    recorded: 2026-03-25
    applied: 0
    overridden: 0

  - pattern: qw-vs-quotes
    hint: qw| | preferred for single scalars in P7
    source: user-corrected
    confidence: 1.0
    recorded: 2026-03-22
    note: kimi flagged as wrong, user corrected — this IS the style
```

### tree growth dynamics

```
session 1: 3 nodes in tree → 5 LLM calls → 2 preferences recorded
session 5: 12 nodes → 2 LLM calls → 1 new preference
session 20: 30 nodes → 0 LLM calls [ all patterns covered ]
session 21: 30 nodes → 1 LLM call [ novel pattern ] → 31 nodes
```

each resolved escalation adds a node. each user preference prunes a branch.
the tree converges toward complete coverage while staying open to novelty.

---

## self-refinement properties

### each iteration improves the next

- LLM fixes become regex patterns → next run needs fewer LLM calls
- false positives tracked → confidence adjusts automatically
- coverage metrics guide which attributes still need LLM attention
- regex lists version-controlled → refinements are auditable
- user preferences become loaded hints, reducing future escalations

### three-layer optimization

```
layer 1: regex handles syntax [ frees LLM reasoning ]
  - style corrections, delimiter fixes, naming conventions
  - basic coding LLMs already have full syntax understanding
  - style enforcement is a delimiter between generations:
    protected and optimizing, freeing reasoning for architecture

layer 2: regex groups replace generic LLM file operations [ high confidence ]
  - open/read/close → <[file.slurp]>->($path)->$*
  - manual socket setup → <[base.net.connect]>
  - parallel similar regex alternatives cover input pattern space
  - complexity handled by coverage breadth, not individual regex depth

layer 3: LLM compacts the regex tree itself [ meta-optimization ]
  - review regex branches for redundant coverage
  - collapse N specific patterns → 1 generalized pattern
  - decrease iteration steps at branch points via reference count
  - keep same functionality with fewer nodes
  - regular optimization target: tree compaction cycle
```

the tree breathes: **expands** through learning new patterns,
**compacts** through LLM-driven generalization. same rhythm as
context compaction — expand where focus is needed, contract
where resolution was reached.

### reference count optimization

when multiple regex alternatives cover overlapping input space:
- that overlap is visible as branch count at decision nodes
- high reference count = redundancy = compaction opportunity
- LLM reviews the group, finds the generalized pattern
- N branches → 1 branch, same coverage, fewer steps
- the compacted tree is itself version-controlled and auditable

```
before compaction:
  regex-A: m|foo_bar| → style fix    [ 40 hits ]
  regex-B: m|foo_baz| → style fix    [ 35 hits ]
  regex-C: m|foo_\w+| → style fix    [ 12 hits ]
  total: 3 branches, 87 hits

after LLM compaction:
  regex-AC: m|foo_\w+| → style fix   [ 87 hits ]
  total: 1 branch, same coverage

  regex-B removed: fully covered by generalized regex-AC
  regex-A removed: fully covered by generalized regex-AC
```

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

### phase 4 — model interface + design-phase advising
- `ncode.cmd.tool_list` — self-describing capabilities
- verbose expansion during execution, compact logging
- models can suggest and test new patterns directly
- **design-phase suggestions**: ncode surfaces prioritized pattern hints
  *before* code generation, preventing issues rather than fixing them
- models learn to use ncode as fast contextualized scan tool with edit
  capabilities on the result stream — always style-aware, token-efficient
  even for large-scale refactorings
- awareness of ncode capabilities makes models bolder at structural changes:
  style compliance is handled, so architectural ambition is freed
- cleaner structure from early ncode passes reduces integration code
  for follow-up design steps — each improvement compounds

#,,.,,.,,,,,,,,.,,,..,,,.,.,.,,,.,..,,.,.,,.,,..,,...,.,.,..,,...,.,.,.,.,...,
#JLSNAD664E6STWRV6LZDXHEELZTVE7IVLAPPRVXMP4E2PPO4JP4HE2HPVUSLDO2OF4CTVCA3CBDQC
#\\\|EH5ZSZ2VYO3VDPRUYNEYYMDIA5YTC4KWQK2I25KOUF7SUPLLJOG \ / AMOS7 \ YOURUM ::
#\[7]VUDJ6UJ4X7TMO7CCRABMVBVPZXYQYKT7NEEKJK2ZTKONCMREB2BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
