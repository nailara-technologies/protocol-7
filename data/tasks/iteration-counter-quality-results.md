## [:< ##

# name  = results: signature-footer iteration counter vs code quality
# descr = does amos-iterations-remaining correlate with code quality?
#         tested on real files with blind scoring + controlled distortion
#         injection. verdict: REJECTED-ON-CHECK.
# date  = 2026-08-04
# task  = data/tasks/iteration-counter-code-quality-correlation.md

## verdict

**REJECTED-ON-CHECK.** The footer's harmonization iteration counter does
not correlate with code quality on real files, by three independent blind
measurements plus a controlled within-file distortion test. It is a chaotic
function of the exact signed bytes [ including the signing key ], not of
anything semantic. Do not use it as a review-priority signal.

## mechanism recap [ what the counter actually is ]

`source.create_harmonic_footer` starts `$iterations_left` at `07777777`
and decrements once per candidate footer until every truth assertion
passes [ first header line, footer BMW checksum, both signature parts,
complete-file ELF checksum, individual footer lines ]. The stored
`amos-iterations-remaining` is the leftover count, so:

    iterations_taken = 0o7777777 - amos-iterations-remaining + 1

The per-iteration checks are checksum predicates over bytes that include
the counter itself, so the loop is a deterministic-but-chaotic search:
each candidate is effectively a fresh dice roll. Nothing in the loop
inspects code semantics.

## part 1 — extraction [ all 5055 modules/ files ]

- standalone python decoder [ `iter-quality/extract_iterations.py` ],
  cross-verified against the real `amos7.decode_octal_bit_header` logic
  and against `bin/dev/iter-rank` [ exact match ].
- all 5055 files decoded, 0 undecodable, 0 inverted-mode [ all-zero ]
  instances in the corpus.
- distribution of iterations-taken: min 0, p10 2066, median 14144,
  p90 48118, p99 93594, max 178667 [ of 2097151 possible ], 4756
  distinct values. plausibly geometric-ish, no clustering.
- data: `iter-quality/iterations.tsv` [ taken, remaining, endline, path ].

## part 2 — blind quality scoring

two independent blind scorers plus one deterministic metric set. in all
cases the scorer never saw the iteration count: footers were stripped
from scoring copies [ `iter-counter-study/scratch/` ] or the scorer was
instructed to treat the footer as opaque and the count never appeared in
any prompt.

1. **local 9B scorer** [ same Qwen model the coding zenka uses, via
   direct inference calls, fixed rubric: style 0-4 / comments 0-3 /
   structure 0-3 ]. stratified sample: 240 files, 40 per stratum across
   6 log-spaced iteration-count strata [ seed 13 ]. 240/240 scored.
   rubric grounded in `data/yaml/code-style/CONVENTIONS.yaml`.
   scripts/data: `iter-counter-study/{score_batch.py,sample.tsv,scores.tsv}`.
2. **kimi k2.7 scorer** [ independent model, 5-criterion rubric, batches
   of 12 ]. stratified sample: 240 files, 30 per octile [ seed 13 ].
   168/240 scored before the run was stopped [ see "scoring dataset
   decision" below ]. data: `iter-quality/scores/`.
3. **scripted style metrics** [ deterministic, full corpus n=5055 ]:
   header presence, 78-col violations, comment lowercase fraction,
   `( word )` annotations, `s///`-form regexes, interpolated log format
   strings, unguarded data reads → composite 0-10.
   `iter-quality/{style_metrics.py,metrics.tsv}`.

### scoring dataset decision [ stated explicitly per review ]

the k2.7 second pass was abandoned at 168/240 [ batches 00-13 of 20 ].
rationale: at n=168 the replication is already adequately powered for
the effect sizes of interest [ |rho| >= 0.22 detectable at 80% power ],
all three measurements agree, and part 4 is the decisive test anyway.
the remaining 6 batch prompts are unused; `iter-quality/batches/`
documents exactly which files went unscored.

## part 3 — correlation results [ spearman primary, pearson secondary ]

| measurement                          | n    | spearman rho | p      |
|--------------------------------------|------|--------------|--------|
| 9B total score vs iterations-taken   | 240  | +0.057       | 0.380  |
| 9B style subscale                    | 240  | +0.142       | 0.028  |
| 9B comments subscale                 | 240  | -0.014       | 0.826  |
| 9B structure subscale                | 240  | +0.121       | 0.062  |
| k2.7 total score [ replication ]     | 168  | +0.033       | 0.676  |
| scripted composite [ full corpus ]   | 5055 | +0.008       | 0.574  |
| iterations-taken vs file size [confound] | 5055 | -0.002   | 0.865  |

t-stat for the headline number: 0.88 [ matches the orchestrator's
independent recomputation: rho=0.057, n=240, t=0.88, not significant ].

- the only nominal p < 0.05 [ 9B style subscale, +0.142 ] does not
  survive multiple-comparison correction [ 4 tests on the same data,
  bonferroni alpha 0.0125 ] and is not replicated by k2.7 or the
  scripted metric. treated as noise.
- decile means of the 9B score across the iteration range show no trend:
  7.42 8.38 7.79 7.88 7.96 8.75 7.92 8.00 8.17 8.46 [ lowest-to-highest
  decile of iterations-taken ].
- scorer-agreement check was not meaningful: the two samples are
  near-disjoint [ 4 overlapping files ]. noted as a limitation.
- 9B scorer caveat: coarse scale [ score 7 given 106/240 times ].
  attenuates any real correlation toward zero, but the k2.7 scorer
  [ finer 5-25 scale ] and the deterministic metric both show the same
  null, so attenuation is not the explanation.

## part 4 — controlled distortion-injection test [ decisive ]

two base files, re-signed on scratch copies with the temp key
[ `bin/Protocol-7 sourcecode test-sign-and-verify`, one console
invocation per series so all variants share one key ]. variants:
realistic typo-class bugs + a comment-only control per series.

series v [ base `modules/ncode.init_code`, 10 distortions ]:

    v00 reference                    22673  [ +0 ]
    v01 wrong-threshold  0.70→0.07   17165  [ -5508 ]
    v02 typo-data-key    patern_dir  16133  [ -6540 ]
    v03 inverted-match   !~ → =~      4310  [ -18363 ]
    v04 eq/ne swap                     346  [ -22327 ]
    v05 if/unless inversion          46356  [ +23683 ]
    v06 dropped // 0 default          4690  [ -17983 ]
    v07 wrong literal    5 → 50      19121  [ -3552 ]
    v08 deleted statement            13796  [ -8877 ]
    v09 duplicated line               5456  [ -17217 ]
    v10 comment-only [ control ]     31344  [ +8671 ]

series w [ base `modules/coding.cmd.complete-analysis`, 4 distortions ]:

    w00 reference                    19772  [ +0 ]
    w01 max_resumes 5→6               7210  [ -12562 ]
    w02 wrong variable               45122  [ +25350 ]
    w03 dropped negation             30309  [ +10537 ]
    w04 comment-only [ control ]      3749  [ -16023 ]

reading:

- real bugs moved the count in BOTH directions [ 9 down / 3 up across
  12 bug distortions ] with swings up to ±25k — no consistent direction.
- comment-only controls [ zero semantic change ] moved it just as much:
  +8671 and -16023. the counter cannot distinguish a bug from a comment
  edit — it tracks bytes, not meaning.
- bonus finding: the count is also key/session-dependent. identical body
  re-signed under different signing keys gives unrelated counts
  [ ncode.init_code: 4637 in the corpus vs 22673 under the temp key;
  w00 across invocations: 19444, 26471, 81601, 19772 — the console
  regenerates `test-proto7-sourcecode` per invocation ]. absolute
  iteration counts are not even stable properties of a file's content.
- variants: `iter-counter-study/sign-scratch/` [ v00-v10, w00-w04 ].

## prior art [ consistent ]

short-word level test [ ledger: `topic-harmonic-correlation-ledger.md`,
REJECTED-ON-CHECK ]: LOVES=5 vs FRICTION=163 motivating anecdote failed
controlled comparison [ FRIKTION→7, LOVSE converged faster than LOVES ].
this file-level result closes the question for real files, which the
ledger entry explicitly left open.

## caveats / limitations

- quality scorers are LLMs [ 9B local, k2.7 ]; both are blind and
  independent of each other and of the counter, but LLM judgment of
  "quality" is itself noisy. the deterministic scripted metric
  [ n=5055, full corpus ] is the noise-free backstop and shows the
  strongest null of all.
- 9B scores are coarse-grained; see attenuation note above.
- the two LLM samples were drawn independently [ different seeds/
  stratifications ], so inter-scorer agreement could not be measured.
- single-codebase result; says nothing about other signing loops.

## conclusion

the hypothesis **does not hold** — tier: REJECTED-ON-CHECK [ third
independent rejection after the two word-level tests ]. the iteration
counter is a checksum-search artifact: chaotic in exact file bytes,
session/key-dependent, and insensitive to every dimension of code
quality tested. `bin/dev/iter-rank` remains useful for inspecting the
footer field, but must not be read as a quality ranking.

## reproduction

    # part 1
    python3 data/tasks/iter-quality/extract_iterations.py modules
    # part 2 [ 9B scorer, needs local inference on :8000 ]
    python3 data/tasks/iter-counter-study/score_batch.py
    # part 3
    python3 data/tasks/iter-quality/analyze.py
    # part 4 [ one invocation per series — key regenerates per run ]
    bin/Protocol-7 sourcecode test-sign-and-verify "<space-separated paths>"

#,,..,...,,,.,,,,,.,.,,..,.,.,...,,,,,...,..,,.,.,...,...,..,,.,.,,..,,,,,,..,
#6N5YEOZ4GUY3JJTQTDXUSNIV4L7UVRBJQET7PXBI4NTAZRQZNAINBTN33LIVU4MT5YWW4PQIOQZGA
#\\\|QOS4IS6JHFZYAHX7DRRML3RQOQHAOW7VITNAYAB2AV6JC6JF4GW \ / AMOS7 \ YOURUM ::
#\[7]MKBHUZVAG4FRTWKGF6UUVDB553V7TJFGMHVWOVEGBRPREPE6RUBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
