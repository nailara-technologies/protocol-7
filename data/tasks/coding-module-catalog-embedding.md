## [:< ##

# name  = task: module-catalog embedding domain
# descr = a bilingual name-to-description embedding domain over src/'s own
#         '# descr' headers, so a natural-language query can resolve to
#         module names -- which the existing identifier-only domains
#         structurally cannot do

## context

raised 2026-09-09, from a review of what to build next on the existing
fasttext base [ `data/embeddings/*.vec`, `bin/dev/depgraph-corpus`,
`coding.tools.handler.embedding_search` ]. the review's headline finding
is a structural blocker that reorders every proposed follow-on:

**the shipping `embedding_search` tool cannot answer a natural-language
query against `codebase-depgraph`.** verified directly:

```
data/embeddings/codebase-depgraph.vec   header: "3092 300"
vocab: base.logs base.log base.event.add_timer base.file.slurp ...
in-vocab check for plain english:
  read no · write no · file no · list no · search no · config no
  error no · network no · module no · timer no · socket no
```

the tool loads `.vec` [ text word-vectors ] and looks each query token up
exactly, with a lowercase fallback and nothing else
[ `coding.tools.handler.embedding_search:104-110` ]. it never loads the
`.bin`, so **there is no subword composition at query time** -- fasttext's
`-minn 3 -maxn 6` shaped training but is unreachable from a `.vec`-only
query path. an out-of-vocab token is silently skipped; an all-OOV query
returns `no query token found in domain vocab`.

so `codebase-depgraph` answers only "what is near this module name", for a
module name the caller already holds. it cannot answer "what is relevant to
what the user just said". and no further domain built on the
`depgraph-corpus` edge-list pattern fixes this, because that pattern
produces identifier-only vocabularies by construction.

**the fix is already proven in-project, in the other direction.** the
security domains are id-anchored-plus-prose:

```
data/training/cisa.txt :
  CVE-2002-0367 CVE-2002-0367 CVE-2002-0367 microsoft windows privilege
  escalation vulnerability smss.exe debugging subsystem in microsoft ...

bin/dev/cisa-kev-corpus:20  "first ~10 description tokens, id repeated 3x
                             for weighting"
```

`cisa.vec` contains `buffer`, `overflow`, `remote`, `execution`,
`authentication` as first-class vocab -- one vector space holding both the
identifier and the english that describes it. same repetition-as-weight
trick as `depgraph-corpus`, already written and working here.

## confirmed mechanism

- the corpus already exists and is hand-written. per CLAUDE.md's module
  format, `# name` + `# descr` is the convention for every module, and it
  is largely kept:

```
src/ files                     5470
carrying a '# descr' header    4433   [ 81.0% ]
  of which src/*.cmd.*         1066 / 1069   [ 99.7% ]
```

- `coding.tools.handler.embedding_search` needs **no code change** to pick
  up a new domain: it globs `data/embeddings/*.vec` and validates the
  domain name against `^[\w-]+$`. dropping `module-catalog.vec` in makes it
  queryable [ documented at `:13-15` as the intended extension path ].
- `fasttext` 0.9.2 is on PATH [ debian package, `.deps/profiles.yaml`
  profile `embeddings` ] -- no source build needed, unlike the phase-1
  dep-graph run.
- what this buys that nothing today does: `commands <keyword>` is literal
  substring matching over name and descr [ `base.cmd.commands:33-36`,
  `$cmd !~ m|\Q$keyword\E|i` ] and `list_modules` is namespace-prefix
  listing. neither has semantic recall.

## hazards [ read before running anything ]

1. **the query vector is an unnormalized sum over in-vocab tokens**
   [ `embedding_search:104-110` ]. a conversational query contributes
   vectors for `how` / `do` / `to` / `a` alongside `timer`. cisa gets away
   with this because its queries are dense technical finding-names, not
   sentences. **decision, pre-registered below: strip stopwords at corpus
   build time** so they never enter vocab -- the tool's existing OOV-skip
   then drops them from queries for free, with no change to shared query
   code that the cisa/cwe/mitre domains also depend on.

2. **query tokens are split on whitespace only, with no punctuation
   stripping** [ `split ' ', $query` ]. `timer?` and `timer.` will not
   match the vocab entry `timer`. this is a real ceiling on
   natural-language queries and is **measured, not assumed**, in gate B's
   companion check below. do not "fix" it by editing the shared tokenizer
   without measuring the effect on the three existing security domains.

3. **fasttext's default `-minCount 5` would delete most of the english.**
   with ~4400 lines of ~10 descr tokens, many useful words occur under
   five times. `-minCount 1` is required, which is also why hazard 1's
   stopword strip has to happen in the corpus rather than being left to
   frequency pruning.

4. **`-bucket` default 2000000 produced a 2.3 GB `.bin` for the dep-graph
   domain** [ `DEPGRAPH-EMBEDDING-PHASE1-RESULTS.md` ]. `.bin` is
   gitignored, but use `-bucket 200000` as that doc itself recommends.
   the committed `.vec` is unaffected either way.

5. **a rubric hit that does not resolve is not a hit.** the idiom-gate task
   established this: A3's apparent win was 40% fabricated references. any
   consumer of this domain must resolve returned names against the live
   registry before presenting them. that discipline belongs in the
   consumer, but the gates below already report resolvability so the
   domain is not credited for vocabulary it invented.

## pre-registration [ fixed 2026-09-09, before any corpus was built ]

### decisions

- **stopwords**: stripped from descr tokens at corpus build time using a
  fixed list in the assembler. never enter vocab.
- **fasttext params**: `skipgram -epoch 100 -dim 300 -minn 3 -maxn 6
  -wordNgrams 2 -minCount 1 -bucket 200000`. first four match the
  dep-graph phase-1 run for comparability; the last two per hazards 3-4.
- **two arms, declared in advance**:
  - **arm D [ PRIMARY ]** -- descr-anchored lines only. the minimal thing
    that answers the question.
  - **arm DG [ secondary, exploratory ]** -- arm D plus the dep-graph
    adjacency lines and `cfg/zenki/cube/access.zenki` co-occurrence lines,
    in one corpus. tests whether english-to-name bridging and name-to-name
    clustering can share a vector space.
  arm D is the one the go/no-go is read from. DG is reported either way and
  is not allowed to rescue a failed D.

### gate A -- retrieval hit-rate against ground truth

N recent `src/`-touching commits. query = the commit message subject+body.
ground truth = `git log --name-only` for that commit, mapped to module
names. **do the top-K neighbors include a module the commit actually
touched?**

- **threshold: ≥40% of commits land ≥1 truly-touched module in top-10.**
  below that, this domain is not carrying an auto-injection design and the
  follow-on provider work stops.
- denominator: commits touching ≥1 `src/` file that has a `# descr` header
  [ i.e. is vocab-eligible ]. the all-`src/` number is reported alongside
  so the exclusion is visible.
- **limitation, stated up front**: the gate's queries are commit messages
  -- terse, post-hoc, written by someone who already knew the answer. a
  real auto-inject query is imperative and pre-hoc. this gate measures
  commit-message-shaped queries; transfer to task text is an assumption,
  not a measurement.

### gate B -- false-injection calibration

cosine always returns something. run relevant queries [ gate A's ] and
irrelevant ones [ general-knowledge and other-domain text whose correct
answer is "nothing here" ], compare top-1 cosine.

- **threshold: at the best floor, TPR - FPR ≥ 0.30** [ Youden's J ].
  below that there is no usable similarity floor, and any auto-injection
  built on this domain would inject confident-looking noise into every
  prompt.
- this is the check that can end the design in an hour, and it is the
  direct analogue of the idiom-gate's false-positive calibration over
  known-good `src/`.

## scope

1. `bin/dev/module-catalog-corpus` -- corpus assembler, same shape as
   `bin/dev/depgraph-corpus` / `bin/dev/cisa-kev-corpus`.
2. run both arms, train both.
3. gates A and B against the pre-registered thresholds.
4. if the gates clear: keep `data/embeddings/module-catalog.vec` as a
   committed domain and spot-check it the way
   `DEPGRAPH-EMBEDDING-PHASE1-RESULTS.md` did -- real natural-language-ish
   queries, sane neighbors, honestly reported.
5. no config gating: a read-only `.vec` file adds no runtime behavior and
   nothing switches on it. it is inert until something queries it by name.
   [ contrast the idiom gate and control vector, which changed live output
   and therefore shipped off-by-default. ]
6. results section below, including anything that did not work.

## results

### progress 2026-09-09 : both pre-registered gates FAIL -- STOP

built, ran, and stopped at the gate. **the domain was not installed** --
no `.vec` was added to `data/embeddings/`, so nothing in the running system
changed. what follows is the negative result and the two things it did
establish.

#### what was built

- `bin/dev/module-catalog-corpus` -- scans all 5470 `src/` files, extracts
  `# descr` [ including wrapped continuation lines ], strips stopwords,
  emits `<name> x3 + namespace segments + descr tokens`. `--with-graph`
  adds the dep-graph adjacency and `access.zenki` grant lines [ arm DG ].
- `data/embeddings/gate_check.py` -- both gates, replicating
  `embedding_search`'s query semantics exactly by default, with
  `--clean-tok` to price the tokenizer ceiling.

```
:: scanned 5470 files, 4439 with descr, 1031 without [ 81.2% ]
arm D  :  4439 lines            -> vocab 11905, dim 300
arm DG : 16055 lines [ 4439 descr + 11537 graph + 79 access ]
                                -> vocab 13078, dim 300
```

training as pre-registered: `skipgram -epoch 100 -dim 300 -minn 3 -maxn 6
-wordNgrams 2 -minCount 1 -bucket 200000`.

#### gate A -- FAIL [ 23.9% vs 40% threshold ]

400 recent `src/`-touching commits, query = commit message, ground truth =
modules that commit touched, top-10.

| arm | tokenizer | eligible | hits | hit-rate | median rank | verdict |
|---|---|---|---|---|---|---|
| **D [ primary ]** | tool-exact | 251/400 | 42 | **16.7%** | 4.0 | FAIL |
| **D [ primary ]** | clean-tok | 251/400 | 60 | **23.9%** | 2.0 | FAIL |
| DG [ secondary ] | tool-exact | 322/400 | 7 | 2.2% | 6.0 | FAIL |
| DG [ secondary ] | clean-tok | 322/400 | 24 | 7.5% | 5.0 | FAIL |

the primary arm reaches 23.9% against a pre-registered 40%. not close
enough to argue about, and the threshold does not move after the fact.

#### harness validation [ two challenges to the gate A number, both checked ]

the 23.9% was challenged on two independent grounds during review. both
were tested rather than argued, and neither moves it:

1. **"non-`src/` filenames from `--name-only` are being appended to the
   query text, polluting it."** does not occur. `git log --name-only --
   src/` applies the pathspec to the *file list*, not just to commit
   selection: commit `12271bf2c` touches 84 files, and the harness sees
   exactly the 16 `src/` module paths, with the message parsed as clean
   prose. verified by direct comparison against `git show --stat`.
   residual: 3 commit *bodies* out of 400 contain a line beginning `src/`,
   which would slightly inflate the ground-truth set — i.e. make the gate
   *easier*, so it cannot be masking a pass.

2. **"bulk commits inflate the hit-rate"** -- a real concern: one commit in
   the window touches 5293 modules [ p50=3, p95=51, p99=428 ], and a
   ground-truth set that large makes a top-10 hit nearly free. measured by
   capping the ground-truth set size:

```
   no cap          eligible 251   hits 60   rate 23.9%
   <=50 modules    eligible 230   hits 55   rate 23.9%
   <=20 modules    eligible 216   hits 54   rate 25.0%
   <=10 modules    eligible 184   hits 39   rate 21.2%
```

   flat across every cap. the result is not a bulk-commit artifact.

#### gate B -- FAIL [ J 0.156 vs 0.30 ], and the mechanism matters more than the number

| arm | tokenizer | relevant med top-1 | irrelevant med top-1 | best floor | TPR | FPR | J |
|---|---|---|---|---|---|---|---|
| D | tool-exact | 0.7504 | **0.7557** | 0.6591 | 96.8% | 83.3% | 0.134 |
| D | clean-tok | 0.7538 | **0.7557** | 0.7290 | 76.8% | 61.1% | 0.156 |

**irrelevant queries score as high as relevant ones** -- the medians are
inverted. the cause is specific and worth recording, because it
generalizes past this domain:

```
[1 tok] who won the world cup in 1998 and what was the score
          -> scores 0.832, re-score 0.795, score-candidate 0.731
[1 tok] recommend a good beginner acoustic guitar under 300 dollars
          -> recommendation 0.940, recommendation_engine 0.925
[1 tok] summarize the plot of the great gatsby in three sentences
          -> note.summarize 0.938, summarize-done 0.928
[4 tok] how do tides work and why are there two per day
          -> artwork 0.729, work.aggregate_todos 0.700
```

one incidental english word survives the OOV filter, and fasttext's
subword training puts its morphological variants at 0.83-0.94 cosine. so
**a high cosine means "some word in your sentence resembled some word in
the corpus", not "this query is about this codebase"**. a similarity floor
cannot separate those, because the quantity it thresholds is not measuring
relevance in the first place. that invalidates the cosine-floor design
sketched for the follow-on auto-inject provider, not just this domain's
score.

the tool's own refusal path is the only thing that worked as intended:
2 of 18 irrelevant queries had no in-vocab token at all and returned
nothing.

#### secondary arm : mixing graph edges into the descr corpus is actively harmful

pre-registered as exploratory, and it produced the clearest number in the
run. both arms scored on **arm D's identical eligible set** [ n=251, so the
differing denominators above are not the cause ]:

```
arm D   top-10 hit-rate   60/251 = 23.9%
arm DG  top-10 hit-rate   21/251 =  8.4%
```

**a 2.8x degradation.** the 11537 identifier-only adjacency lines swamp the
4439 descr lines; module vectors end up dominated by call-graph
co-occurrence and the english words are pushed to the periphery.

this **contradicts the recommendation in the review that produced this
task**, which argued for absorbing the dep-graph lines into one corpus so
the provider could do english→name→neighbors in a single space. that was
wrong, and it was wrong for a reason worth keeping: the two corpora are not
just different vocabularies, they are different *densities*, and the denser
one wins. keep `codebase-depgraph` as its own domain. any two-hop query
should be two queries against two domains.

#### the tokenizer ceiling, measured rather than assumed [ hazard 2 ]

whitespace-only splitting costs a real, quantified amount: gate A 16.7% →
23.9% when punctuation is stripped [ +7.2 points, ~43% relative ], and
"no in-vocab token" drops from 6 commits to 2. so hazard 2 is a genuine
ceiling — but fixing it would not have saved this run, since the ceiling
is well below the threshold either way. **not fixed here**: the tokenizer
is shared with the cisa/cwe/mitre domains and changing it to rescue a
failed gate would be exactly backwards.

#### post-hoc, clearly labelled : coverage discriminates where cosine does not

**this was not pre-registered and did not influence the verdict.** having
established that cosine cannot gate relevance, the obvious question is
whether anything cheap can:

| signal | relevant median | irrelevant median | best floor | TPR | FPR | J |
|---|---|---|---|---|---|---|
| top-1 cosine | 0.754 | 0.756 | 0.729 | 76.8% | 61.1% | **0.156** |
| in-vocab token count | 5.00 | 2.00 | ≥3 | 82% | 28% | 0.547 |
| **in-vocab token fraction** | 0.53 | 0.20 | ≥0.38 | 86% | 11% | **0.744** |

*what fraction of the query is codebase vocabulary* separates cleanly where
similarity does not. that is a hypothesis for a future gate, not a result,
and it carries a confound worth naming precisely so nobody builds on it
unexamined:

- **the two classes differ in register and authorship, not only in
  subject.** the positives are commit messages -- dense technical prose,
  median 5 in-vocab tokens. the negatives are 18 conversational sentences
  **written by the same author who knew what the gate measured**. so the
  separation may be measuring *technical prose vs conversational prose*
  rather than *about this codebase vs not*.
- n is small on the negative side, and none of it has been tested against
  real task text.

anyone reusing this needs their own negatives, ideally harvested rather
than written.

#### descriptive : what the domain actually does well [ exploratory, not a gate ]

the failure is not uniform. on **short, dense, technical phrases** -- the
query shape `cisa.txt` was built for -- the bridging works:

```
blank the mouse cursor        -> blank-cursor 0.936 · X-11-pointer.cmd.blank-cursor 0.842
drop root privileges          -> privilege 0.847 · root.drop_privs 0.830
parse yaml config file        -> format.yaml.load_file 0.743
nearest neighbor embedding search -> embedding_search 0.919
restart an unresponsive zenka -> restart_own-zenka 0.912 · self_restart 0.856
```

**this must not be used to explain away the gate.** the pre-registration
named the query-distribution mismatch as a limitation *in advance*
precisely so that a failure could not later be attributed to it, and the
idiom-gate task's A3 result is the standing warning about reading a
selected set of good-looking outputs as a win. the honest statement is:
**the pre-registered gate failed**, and a descriptive probe suggests the
domain may work on a query shape the gate did not test. that is a new
hypothesis needing its own pre-registered gate against real
`task_summary` text, not a partial pass.

#### what is NOT true, despite the failure

the headline finding that motivated this task stands independently and was
re-confirmed in passing: `codebase-depgraph`'s vocabulary is pure
identifiers, and a natural-language query against it returns nothing. arm
D's vocab **does** contain english [ 11905 tokens vs depgraph's 3092 ], and
the short-phrase probes above only work at all because of that. the
diagnosis was right; the proposed remedy did not clear its bar.

### state

- **nothing installed, nothing gated, no runtime behavior changed.** no
  `.vec` added to `data/embeddings/`; the trained models stayed in a
  scratchpad and are not in the repo. `embedding_search` is untouched and
  still serves exactly `cisa`, `cwe`, `mitre`, `codebase-depgraph`.
- working tree adds three files only: `bin/dev/module-catalog-corpus`,
  `data/embeddings/gate_check.py`, this task file. no AMOS7 signature
  stubs, per convention -- a human signs separately.
- both are worth keeping regardless of the verdict: the assembler is the
  reproducible corpus step, and `gate_check.py` is the reusable
  calibration harness for **any** future domain. rerun with
  `python3 data/embeddings/gate_check.py --vec <path> [ --clean-tok ]`.

### follow-up 2026-09-09 : is terse descr text the bottleneck ?

a follow-on proposal was raised: generate **richer per-subroutine
summaries** by inference [ prioritized by caller count, refreshable ] to
replace the one-line descr as corpus text, on the hypothesis that ~10
tokens per module is simply too little signal. before scoping that, three
free diagnostics were run against the existing arm D model.

#### finding 1 -- 63% of the ranked vocabulary is not a module name

`embedding_search` scores **every** vocab token, and arm D's vocab is 11905
tokens of which only 4452 are module names. english words from the descr
text compete for result slots with the modules they describe -- visible in
the earlier spot-checks, where `blank-cursor 0.936` and `privilege 0.847`
outrank the actual modules `X-11-pointer.cmd.blank-cursor` and
`root.drop_privs`.

restricting candidates to module names, same model, same queries:

```
all vocab [ as gated ]   top-10   60/250 = 24.0%     top-20  85/250 = 34.0%
module-names only        top-10   82/250 = 32.8%     top-20 100/250 = 40.0%
```

**+8.8 points at top-10, for free, with no corpus change and no inference.**
this is the largest single lever found so far and it is an implementation
detail, not a data problem. it still does **not** clear the pre-registered
40% at top-10 [ 32.8% ], and the top-20 figure landing exactly on 40.0% is
not a pass -- the gate was pre-registered at top-10 and the K does not move
after the fact.

not shipped: a result-class filter belongs in `embedding_search` as an
additive optional parameter, but there is no installed domain that needs it
yet. recorded here rather than changing a shared tool for a consumer that
does not exist.

#### finding 2 -- the coverage gap is real, and is one third of the misses

for each eligible commit, the shared-word count between the query and the
corpus line of the module it actually touched:

| group | shared words median | mean | **zero overlap** | target descr size |
|---|---|---|---|---|
| hits [ n=82 ] | 4 | 5.16 | **0%** | 10 tok |
| misses [ n=168 ] | 1 | 1.79 | **33%** | 9 tok |

target descr size is the same in both groups, so this is not "missed
modules have shorter descrs" -- it is **the descr vocabulary not covering
the words the query uses**. one third of misses share literally no word
with the target's descr. that is a genuine mechanism a richer summary would
attack, and it is direct support for the proposal's premise.

the other two thirds already have lexical overlap and still miss. that is a
*ranking* failure, and more text does not obviously fix it -- it may dilute
a module's vector toward generic language.

#### finding 4 -- arm E : density tested for free, and the absorbency fear was WRONG

rather than pay for generated summaries to test whether density helps, the
assembler gained `--source-tokens N`, which mines up to N extra vocabulary
tokens from each module's own body [ comment prose + words inside
identifiers ]. zero inference, fully automatic, and it produces the
dynamic range finding 3 lacked: **median 57 tokens per line vs arm D's
10** [ 5.7x ]. this is a crude lower bound on summary *quality* and a
reasonable proxy for summary *density*.

paired against arm D on the same 250 commits, both module-filtered:

| arm | tokens/line | gate A top-10 | top-20 | gate B best J | irrelevant median |
|---|---|---|---|---|---|
| D  descr only | 10 | 32.8% | 40.0% | 0.524 | 0.6880 |
| **E  descr+source** | **57** | **37.2%** | **44.0%** | **0.656** | **0.5622** |

two results, and the second one **falsifies my own prediction in finding 3**:

1. **density helps gate A, modestly**: +4.4 points at top-10 for 5.7x the
   text. real, cheap, but not transformative.
2. **density helps gate B rather than hurting it.** I predicted richer text
   would make each module absorb more arbitrary english and worsen
   discrimination. the opposite happened: J rose 0.524 → 0.656 and the
   *irrelevant* median fell 0.688 → 0.562 while the relevant median fell
   far less. the mechanism is the reverse of the one I assumed -- with more
   tokens per module, any single incidental english word contributes
   proportionally *less* to that module's vector, so a one-word match no
   longer produces a near-1.0 cosine. dilution is protective here, not
   harmful.

#### where the two free fixes leave the gates

| configuration | gate A top-10 | gate B J |
|---|---|---|
| as originally gated [ all vocab, descr only ] | 23.9% | 0.156 |
| + module-name candidate filter [ free ] | 32.8% | **0.524** |
| + source-mined density [ free ] | **37.2%** | **0.656** |
| pre-registered threshold | 40% | 0.30 |

**gate B goes from decisive failure to comfortable pass on the free fixes
alone.** gate A closes most of its gap but still misses at top-10.

**this does not retroactively convert the run into a pass, and must not be
read that way.** the original verdict stands for the configuration that was
gated: as-shipped query path, descr-only corpus. what these numbers say is
narrower and more useful -- *the failure was substantially an
implementation and density problem, and both fixes are free*.

they also come with a methodological debt that has to be paid before any
go-decision: **four design choices have now been made against the same
400-commit set.** that set is soft in exactly the way the idiom-gate task
warned about when it retired its first held-out prompt trio. these numbers
are hypothesis-generating now, not confirmatory.

#### finding 3 -- the absorbency risk is untested, because the data has no range

richer text should also make each module match *more* arbitrary english,
which is exactly the mechanism that failed gate B. the natural experiment
is inconclusive: descr lines are capped at 24 tokens by the assembler and
run median 10 / p90 13 / max 29, so there is no dynamic range to detect the
effect.

```
returned-module descr size, irrelevant queries : median 10  mean 10.2
returned-module descr size, relevant queries   : median 10  mean 12.0
baseline, all modules                          : median 10  mean 10.2
```

the slight bias toward larger lines on relevant queries [ 12.0 vs 10.2 ]
hints that size does confer retrievability, which cuts both ways. **this
must be an explicit pre-registered gate in any follow-up, not an
assumption.**

### recommended next step

do **not** retune this domain to chase the threshold -- that is the
rubric-gaming the two prior tasks were caught by. the two findings that
should carry forward:

1. **a cosine floor is not a relevance gate.** any auto-inject design must
   drop it. coverage [ in-vocab token fraction ] is the candidate to
   pre-register instead.
2. **the descr corpus must not be diluted with identifier-only lines.**

if this is revisited, the cheapest honest next gate is the one this run
could not do: harvest real `task_summary` strings from actual
`coding.submit` traffic, pair them with the modules those tasks ended up
touching, and re-run gate A against *that* distribution. that is a week of
passive collection costing nothing, and it tests the exact query shape the
auto-inject provider would see -- the same "run it at `scan` for a week and
re-read the corpus" move the idiom-gate task ended on.

#,,,,,.,,,.,,,,..,..,,.,.,,,.,,,,,...,...,..,,..,,...,...,.,.,..,,.,,,,.,,,..,
#KVGZ6MEJNTQEVBCJYYBFXKU7TXIKXS7C7LVPZAYNL7JY2OOUL2QP6ZDYO3EL3P75BMR7P5FJ5ECJS
#\\\|PNAWXATIRWCEDM4PFLFAKSX6TC56YYJV5RHN2D2PIGOHAX235VA \ / AMOS7 \ YOURUM ::
#\[7]54CA3PSJ7T7YGPBGLMFI4OEXCB54DQTCULHTOG6WIXHRYPUN3UAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
