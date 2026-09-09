## [:< ##

# name  = task: catalog retrieval phase 2
# descr = confirm the two free retrieval fixes on a fresh held-out set
#         before paying for any generated-summary or descr-rewrite pass

## context

follow-on from `data/tasks/coding-module-catalog-embedding.md`, which built
a descr-anchored module-catalog embedding domain, failed both of its
pre-registered gates, installed nothing, and then -- in three free
diagnostics -- found that most of the failure was implementation and
density, not corpus quality.

three proposals were on the table for what to do next. this task takes one
of them, defers one, and recommends cutting one. the reasoning is below,
and it is driven by measurement rather than plausibility.

## the measured state

all numbers paired, 250 eligible commits, from the prior task's results:

| configuration | gate A top-10 | gate B J |
|---|---|---|
| as originally gated [ all vocab, descr-only corpus ] | 23.9% | 0.156 |
| + module-name candidate filter [ **free** ] | 32.8% | 0.524 |
| + source-mined density, `--source-tokens 60` [ **free** ] | 37.2% | 0.656 |
| pre-registered thresholds | 40% | 0.30 |

two free changes take gate B from decisive failure to comfortable pass and
close most of gate A's gap. neither required inference, a new corpus
source, or a single rewritten descr line.

## verdict on the three proposals

### 1. generated per-subroutine summaries -- DEFER, and re-baseline first

the premise is **partly confirmed**: 33% of retrieval misses share zero
words between the query and the target module's descr, so there is a real
lexical-coverage gap that more text attacks. and density does help --
measured, +4.4 points at top-10 for 5.7x the tokens.

but the proposal's implied baseline is wrong. **a generated summary would
have to beat the free source-mining baseline, not the descr-only one.**
source mining already captures most of the available density benefit at
zero inference cost and zero maintenance. the real question is not "do
richer summaries beat one terse line" [ yes, slightly ] but "does a
generated summary beat crudely-mined identifier and comment text by enough
to justify 18-55 GPU-hours plus a permanent refresh obligation". that
question is unanswered and is the one worth pre-registering.

cost, concretely: 4439 modules with descr, on the local 9B Q4_K_M. the LoRA
task recorded 240 MB free of 12288 MB on the RTX 3060 while the coding
zenka's own server runs, so a generation pass contends with the zenka's
working capability rather than running alongside it. prioritization data
already exists and is free -- `data/md/documentation/module-dependency-
graph.asc` reverse edges give caller counts directly, so a top-500-by-
callers pass is ~2-6 GPU-hours rather than 18-55.

**one honest caveat on the density result**: arm E's gain may be partly
mechanical rather than semantic. mined identifier tokens include the names
of modules a module *calls*, so some of arm E's lift could be rediscovering
the dep-graph rather than describing behaviour. a generated-summary gate
must control for this -- otherwise it will credit summaries for a
structural signal that `codebase-depgraph` already provides.

### 2. usage examples attached to each entry -- CUT

**this has already been tested in this project and it failed.** the
idiom-gate task's arm A3 *was* the "show the model real, curated examples"
intervention -- few-shot demonstrations drawn from a 403-example corpus. it
produced 40% fabricated module references, and its one apparent gain was a
quoting switch that masked a real-usage *decrease* [ 3/9 → 2/9 ]. it is
recorded there as the fourth null in that thread, and explicitly as
something that "would have been reported as a success by raw-rubric reading
alone".

curation does not address this. A3's examples were already real and already
drawn from the codebase. the failure was not example quality -- it was that
showing specimens produces imitation of surface form plus recombination
into names that do not exist. and as correctly noted, my "labelled names,
never specimens" mitigation cannot apply here, because a usage example is
definitionally a specimen.

**the constructive alternative: keep the example index, invert its use.**
examples belong on the *verification* side, which is the only side that has
ever worked here. concretely -- when the model emits a call to module X,
check the emitted call shape against the real call sites of X and
repair-or-flag mismatches. that is `coding.idiom.*` extended with
per-module arity and call-shape knowledge, it is deterministic, it is
resolve-verified by construction, and it is the same mechanism class that
produced the only non-confounded win in the entire three-task thread. an
example corpus is genuinely useful for that; it is a liability in a prompt.

### 3. improving the `# descr =` text in place -- WORTH DOING, but not as a retrieval play

the durability argument is sound and I agree with it: a corrected descr is
versioned with the code, reviewed like code, visible to humans, and never
needs a refresh cycle. that is strictly better than a parallel generated
layer *for the text it can hold*.

the constraint is what it can hold. measured:

| module class | n | median descr | p90 | over 55ch | cap |
|---|---|---|---|---|---|
| `*.cmd.*` / `*.console.*` | 1157 | 42 ch | 52 ch | 2% | **hard 55** |
| all others | 3282 | 52 ch | 66 ch | 42% | none enforced |

the 55-char limit is real for command modules -- enforced both by
`coding.tools.handler.module_convention_check` [ `max_descr` default 55 ]
and by `.git/hooks/pre-commit`, which rejects staged command modules with
over-length `descr`/`param` lines. it is a **display** constraint, since
`base.cmd.commands` formats these into a terminal command list.

so for command modules -- the ones a command catalog most needs -- median
42 chars against a 55-char cap leaves roughly **two words** of headroom.
that cannot close a lexical-coverage gap. for non-cmd modules the cap is
absent, but a descr grown to summary length simply *is* the summary
proposal with a different storage location, and it would then start
tripping the human-facing convention the header exists to serve.

**therefore: prioritize descr improvement on documentation grounds, not
retrieval grounds.** it raises accuracy where a descr is vague or wrong,
which plausibly helps the 67% of misses that already have lexical overlap
and fail on ranking. that is worth having. it is not the lever that moves
the gate, and it should not be sold as one.

**the accuracy hazard is the real risk and it is correctly identified**: a
fluent-but-wrong descr is worse than a terse-but-right one, and it is worse
now than before, because this text feeds a retrieval corpus. any automated
rewrite pass must be gated on verification against the module body, must
respect the 55-char cap and the lowercase / `[ ]`-annotation conventions,
and must land as reviewable diffs rather than bulk-applied edits.

## what to do first -- and why it is not a build

**do not build a generation pipeline or a rewrite pass yet.** the immediate
blocker is methodological, not technical: **four design choices have now
been made against the same 400-commit evaluation set** [ tokenizer variant,
candidate filter, corpus arm D/DG, density arm E ]. that set is soft in
exactly the way the idiom-gate task's reused held-out prompt trio was, and
every number in the table above is now hypothesis-generating rather than
confirmatory.

## pre-registration [ fix before running ]

### the fresh held-out set

commits **older** than the 400 already used, or `coding.submit` task text
harvested going forward -- never the 400 already burned. n ≥ 250 eligible.
built and frozen **before** any model is trained against it.

### gate A2 -- does the free configuration hold up

- configuration: module-name candidate filter + `--source-tokens 60`,
  clean tokenization.
- **threshold: ≥40% top-10 on the fresh set.** unchanged from the original
  gate. if the 37.2% was partly fitted to the burned set, this is where it
  shows.

### gate B2 -- does discrimination hold up

- **threshold: J ≥ 0.30** on the fresh set, unchanged.
- **the negatives must be harvested, not authored.** the prior run's J
  figures used 18 conversational sentences I wrote myself knowing what was
  being measured; the positives were technical commit prose. that confound
  is documented in the prior task and must not be inherited. draw negatives
  from real off-topic text -- other projects' commit messages, general
  documentation, unrelated chat.

### gate C -- does generation beat free mining [ only if A2/B2 pass ]

the gate that actually decides the summary proposal:

- hand-write or generate rich summaries for **30 modules drawn from the
  zero-overlap miss set**, written **from module source only, without
  looking at the query** -- the circularity hazard here is fatal if
  ignored, since knowing the query makes any summary look predictive.
- three paired arms on those 30 targets: descr-only / source-mined /
  summary.
- **threshold: summaries must beat source-mining by ≥10 points on paired
  per-module retrieval.** below that, the generation pipeline is not worth
  18-55 GPU-hours plus a permanent refresh obligation, and source mining
  ships instead.
- control for the mechanical-lift confound: report retrieval with mined
  *callee-name* tokens excluded, so summaries are not credited for
  rediscovering the dep-graph.

### gate D -- descr rewrite accuracy [ if that pass is attempted ]

- sample ≥50 rewritten descr lines and check each against the module body.
- **threshold: zero inaccuracies.** this is a correctness gate, not a
  quality score -- the same discipline as the idiom gate's "auto-class
  flags on known-good code : 0". a wrong descr is a defect, and unlike a
  bad retrieval result it is durable and human-facing.

## on the iteration primitive

if gate C passes and a walk over thousands of modules is actually
warranted, the walk itself should be a small reusable primitive rather than
another bespoke script -- prioritized worklist, checkpointed progress,
resumable after interruption, idempotent per item. this project has now
needed that shape at least three times [ the LoRA and idiom-gate tasks both
improvised `PROGRESS.md`-style resume safety after hitting step limits, and
the idiom-gate's own closing recommendation -- run at `scan` for a week and
harvest -- is the same long-running prioritized-iteration shape ].

the prioritization input already exists and is free: caller counts from
`module-dependency-graph.asc` reverse edges.

**but do not build it speculatively.** nothing above justifies a walk yet,
and a framework built before its first real consumer would be designed
against guesses. the note is here so that whoever does earn the walk builds
it reusably rather than inline.

## scope

1. build and freeze the fresh held-out set.
2. run gates A2 and B2 against it, thresholds above.
3. only if both pass: gate C, to decide generated summaries vs free source
   mining.
4. descr improvement proceeds independently on documentation grounds, with
   gate D as its correctness bar. it is not blocked on any of the above and
   does not block them.
5. usage-example injection: not pursued. an example index for
   *verification* is a separate proposal if wanted.

## results

### progress 2026-09-09 : gates A2/B2 run on the fresh set -- FAIL, nothing installed

gates C and D were **not run**: they belong to the generated-summary and
descr-rewrite proposals, which are deferred. they remain pending.

#### the fresh held-out set, built and frozen before any evaluation

- **positives**: 400 `src/`-touching commits, **strictly older** than the
  400 already burned [ `allS[400:]` of 1613 total ], filtered to those
  touching a module that still exists. frozen to `heldout2.json`.
- **negatives**: 150 real commit messages harvested from
  `/data/source/ik_llama.cpp` -- a genuinely unrelated codebase, but the
  **same register** as the positives [ technical commit prose ]. this is
  the fix for the confound recorded in the prior task, where the negatives
  were conversational sentences I wrote myself.

#### gate A2 -- FAIL, and the in-sample number did not survive

| arm | in-sample [ burned set ] | **fresh held-out** | threshold |
|---|---|---|---|
| D  descr only | 32.8% | **13.1%** | 40% |
| E  descr+source | 37.2% | **13.3%** | 40% |

a 2.8x collapse. the caution was justified: **the in-sample figures were
not measuring generalizable retrieval quality.**

#### gate B2 -- arm E FAILS, and the earlier arm E "win" inverts

| arm | in-sample J [ authored negatives ] | **fresh J [ harvested negatives ]** | threshold |
|---|---|---|---|
| D  descr only | 0.524 | **0.349** PASS | 0.30 |
| E  descr+source | 0.656 | **0.108** FAIL | 0.30 |

**this is the most important result of the run.** in the prior task I
predicted richer text would make each module absorb more arbitrary english
and hurt discrimination; the in-sample measurement appeared to falsify
that, and I recorded the falsification. **against real negatives the
original prediction is correct after all.** arm E's source-mined
vocabulary is full of generic programming words -- cache, buffer, thread,
server, token -- which is exactly what makes it confusable with another
systems codebase's commit prose. relevant and irrelevant medians are now
inverted [ 0.6191 vs 0.6235 ].

**the sign of the conclusion was determined by the quality of the negative
set, not by the model.** authored conversational negatives were an easy
test that made a worse configuration look better. that is a reusable
lesson: harvest negatives, and match their register to the positives.

#### what the collapse is NOT -- one hypothesis raised and falsified

the fresh set's queries average 8 words against the burned set's 62, so
query length was the obvious explanation. it is wrong:

```
CONTROL 1 -- burned set, queries truncated:
  first   8 words   112/265 = 42.3%      first  30 words  103/265 = 38.9%
  first  20 words   110/265 = 41.5%      full  200 words   97/265 = 36.6%

CONTROL 2 -- fresh set, split by length:
  <=10 words   25/213 = 11.7%     >10 words   8/36 = 22.2%
```

**shorter queries score *better* on the burned set** [ 42.3% at 8 words vs
36.6% full ] -- consistent with the unnormalized-sum hazard, where extra
tokens dilute the query vector. and at matched length the gap is unchanged:
8-word burned queries score 42.3%, 8-word fresh queries 11.7%. **length
does not explain it.**

nor is it gradual drift: within the fresh set the hit-rate is flat across
recency bands [ 11.3% / 14.5% / 11.3% / 16.1% ], so this is a step change
between two commit populations, not decay with age.

#### what the collapse IS -- unexplained, and stated as such

the leading hypothesis is temporal leakage: recent commits and the current
descr text co-evolved, so a recent commit message and the module's
present-day descr share vocabulary in a way an older commit's does not.

**this was probed and the probe was inconclusive.** the check -- whether a
commit also wrote the `# descr =` line of a module it touched -- returned
0/116 and 0/83 for the two eras, which is implausible on its face [ the
burned era demonstrably created new modules with descr lines ] and
indicates the probe itself is broken, not that leakage is absent. a null
from a broken instrument is not evidence.

so the gap is **recorded as unexplained**. anyone continuing should fix
that probe first, because the answer determines whether commit messages are
a usable evaluation query source at all.

### verdict

**not installed.** gate A2 fails by a wide margin on both arms, gate B2
fails on the arm that looked best in-sample. no `.vec` was added to
`data/embeddings/`, `coding.tools.handler.embedding_search` is unchanged,
and the domain remains uncreated.

the two "free fixes" from the prior task come out differently now:

- **module-name candidate filtering** is still sound -- it is a real
  ranking improvement and it is not implicated in the collapse.
- **source-mined density is now a negative result**, not a free win. it
  buys ~nothing on out-of-sample retrieval [ 13.1% → 13.3% ] and it
  measurably damages discrimination against realistic negatives.
  `--source-tokens` stays in the assembler as the instrument that measured
  this, defaulted to 0 = off.

### what this means for the deferred proposals

the generated-summary proposal was already going to have to beat free
source-mining. **source-mining now has a negative result attached**, which
removes the cheap baseline but does not promote generated summaries --
because the mechanism that hurt arm E [ more generic vocabulary per module
→ worse discrimination ] would apply to a generated summary too, and
plausibly more so, since fluent prose contains *more* common english than
mined identifiers do. gate C should therefore measure gate-B-style
discrimination against harvested negatives, not only retrieval. that is a
change to the phase-2 pre-registration and it is recorded here rather than
applied silently.

the descr-improvement proposal is untouched by all of this: its
justification was documentation quality, and that still stands on its own.

### recommended next step

the honest reading is that **commit-message-driven evaluation is now the
bottleneck, not the corpus**. two of three explanations for the collapse
have been eliminated and the third could not be measured with a working
instrument. before any further corpus work:

1. fix the leakage probe and determine whether recent commits are
   contaminated. if they are, every number in both task files that used the
   burned set is inflated, including the original 23.9%.
2. replace commit messages with the query distribution that actually
   matters -- harvested `task_summary` strings from real `coding.submit`
   traffic, paired with the modules those tasks touched. this was the prior
   task's closing recommendation and it is now the blocking item rather
   than a nice-to-have.

### progress 2026-09-09 [ second pass ] : both next steps closed out

#### 1 -- the leakage probe : instrument bug found, leakage CONFIRMED

the probe returned 0/116 and 0/83, which was recorded as "a null from a
broken instrument, not evidence". the bug:

```
$ git config --get color.ui
always

python capture of a diff line:
  '\x1b[38;5;34m+\x1b[m\x1b[38;5;34m# descr = load and cache the idiom ...'
```

this repo sets **`color.ui = always`**, so git emits ANSI escapes even when
stdout is a pipe. every added diff line reaches a captured buffer as
`ESC[...m+ESC[m...`, and the probe's `^\+#\s*descr` anchor can never match
a `+` that is not at the start of the line. a systematic zero, exactly as
the implausibility suggested.

**anyone scripting `git` on this host must pass `-c color.ui=false`.** this
is a general trap, not specific to this probe -- and worth checking against
any other tooling here that parses git diff output.

re-run with `git -c color.ui=false`:

| era | n | commits that WROTE a descr line of a module they touched | msg ↔ current-descr overlap |
|---|---|---|---|
| burned [ recent ] | 141 | **61 = 43%** | median 2, mean 2.87, 23% zero |
| fresh [ older ] | 103 | 21 = 20% | median 0, mean **0.26**, **78% zero** |

**leakage is real and large.** in the recent era nearly half of all commits
authored the very descr line they are then being asked to retrieve, and
message-to-descr lexical overlap is 11x higher by mean.

controlling for era removes any doubt -- within the fresh set alone, split
by whether the commit wrote a descr line:

```
contaminated [ commit wrote a descr line ]   10/ 44 = 22.7%
CLEAN        [ did not ]                     10/106 =  9.4%
```

a 2.4x difference **inside the same time period**, so this is contamination
rather than age or style drift. it also explains the 42.3% vs 11.7% gap at
matched query length that the earlier length control could not account for.

#### consequence : every prior number is inflated

| figure | as reported | status |
|---|---|---|
| original gate A [ prior task ] | 23.9% | inflated -- burned set, 43% contaminated |
| + candidate filter | 32.8% | inflated, same reason |
| + source-mined density | 37.2% | inflated, same reason |
| fresh held-out | 13.1 / 13.3% | mildly inflated -- 20% contaminated |
| **clean subset** | **9.4%** | **the trustworthy estimate** |

**the honest performance of a descr-anchored module-catalog domain on
commit-message queries is roughly 9%, not 24% and not 37%.** the gate
thresholds were never close to being met. this retroactively strengthens
the original decision not to install, and it retires the burned 400-commit
set permanently -- it should not be used again by anyone.

#### 2 -- harvesting instrumentation : built, off by default

the recurring conclusion across both tasks is that commit messages are the
wrong query source. the right one -- real task text paired with what the
task actually touched -- **exists nowhere**, and would keep not existing
for as long as "revisit when there is real data" stayed the plan. so the
recorder now exists and can accumulate from here.

new modules:

- **`coding.catalog.track_write`** -- resolves the current task by scanning
  `<coding.task.queue>` for `in_progress` [ the same idiom
  `coding.tools.handler.record_observation` already uses, since a tool
  handler is not handed the task id ], and accumulates written module names
  in memory under `<coding.catalog.touched>{$task_id}`. writes to paths
  that are not real `src/` modules are ignored.
- **`coding.catalog.corpus.record`** -- on completion, flushes one JSONL
  line to `data/catalog-corpus/YYYY-MM.jsonl`:
  `{ ts, task_id, task_summary, modules, n }`.

integration, mirroring the idiom gate's own three-call-site pattern:

- `coding.tools.handler.{write_new_file,edit_file,replace_in_file}` -- one
  guarded call each, placed beside the existing `coding.idiom.check_write`
  hook.
- `coding.task.queue_complete` -- flush, placed before the task record can
  be pruned.
- `cfg/zenki/coding/zenka.v7` -- `coding.cfg.catalog_harvest` and
  `coding.cfg.catalog_corpus_dir`, **shipped commented out**.
- `cfg/zenki/coding/subroutines.load-early` -- regenerated with
  `bin/dev/gen-sub-whitelist coding` [ 1258 subs ] rather than hand-edited.
  note the generator strips the file's AMOS7 footer, as `bin/dev/dep-graph`
  does to the `.asc`; it is restored at the next signed commit, and the
  tool prints the signing command itself.

three deliberate design decisions worth recording:

1. **`task_summary` is bounded to 200 characters** -- the *same* bound
   `coding.prompt.assemble` already applies when building its template
   vars. that exact string is what an auto-inject provider would query
   with, so harvesting more would measure a query shape that never occurs
   *and* would turn a code corpus into a transcript archive.
2. **`data/catalog-corpus/` is gitignored.** `data/idioms/corpus/` is
   committed because it stores only a *checksum* of its prompt; this
   corpus stores real task text, which can carry user content and does not
   belong in a tracked file.
3. **the corpus directory is deliberately NOT pre-created.** the idiom-gate
   task hit exactly this: a `taeki`-owned directory that the
   `protocol-7`-user zenka could not append to, which failed silently.
   letting the zenka's own `base.file.make_path` create it on first use
   gives correct ownership by construction.

verification possible without running the zenka:

- both modules parse -- `bin/format-code` reformatted them in place and
  exited 0, which requires translating P7 syntax to perl first.
- the two riskiest pure-perl paths were exercised directly: whitespace
  collapse plus the 200-char bound, and the pretty-JSON newline collapse
  that keeps the one-object-per-line contract [ 0 newlines remaining ].
- **not verified live**: no task has run with `catalog_harvest` enabled, so
  the in-progress task resolution and the append path are unproven against
  a real queue. that is the first thing to check when it is switched on,
  and it is the same class of integration bug the idiom gate found only by
  running live.

#### what was not done

the optional third item -- inverting the 93 `data/src-review/*.md` "Purpose"
sections into candidate queries -- was **not attempted**. with the leakage
result in hand it would be a third proxy query distribution measured at
n=93, when the actual finding is that proxy query distributions are the
problem. the harvester now collects the real distribution; that is the
comparison worth making, and it should be made against real data rather
than a third stand-in.

### status

**nothing installed, nothing enabled.** no `.vec` in `data/embeddings/`,
`embedding_search` unchanged, `coding.cfg.catalog_harvest` commented out =
current coding-zenka behavior is byte-identical. the harvester is inert
until someone deliberately turns it on.

#,,.,,.,,,.,.,.,.,..,,,.,,,,,,.,.,,.,,,..,..,,..,,...,...,...,...,,,,,.,.,,.,,
#FG754FGXFMYIALHLBMALXML6THGRYR23YG4RO5DEYXLB4B6GHLCIAB2MRYC2IOHDQDPV3LT7YYT2M
#\\\|CAWBSKFDV2ZJ3EW43BC2PS4SVFNOBMXP2VIRZJ576OK3YCBFYIU \ / AMOS7 \ YOURUM ::
#\[7]NIKXDUZ2HKLTABTFVAQWNEPUJ2S4DCTF6YTCUCAZVGBOWRYDCSAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
