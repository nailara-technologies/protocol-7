# harmonic quality correlation study

## hypothesis

harmonization step count (encoded in amos7 octal header, rightmost value) is
inversely proportional to code quality score as assessed by llm models. if
correct, the signing process encodes a passive quality oracle on every commit.

## the signing step count signal

every signed module has an amos7 octal bit-header in its footer first line.
the rightmost octal digit encodes the endline state (5+delta), but adjacent
positions encode harmonization metadata including step count — how many
correction passes were needed before the checksum converged.

```perl
## decode octal header from footer first line ##
my $header = <[amos7.decode_octal_bit_header]>->($footer_first_line);
## extract harmonization step count ##
my $steps = $header->{'harmonization-steps'} // 0;
```

fewer steps = structure already aligned with harmonic basis = cleaner code
more steps = entropy fighting the basis = structural issues, latent bugs, clutter

## phase 1: corpus scan

scan all ~3900 signed modules:
- decode amos7 octal header from each file's footer first line
- extract harmonization step count
- build: `{ module_path => step_count }` index

tools already available:
- `<[amos7.decode_octal_bit_header]>->($footer_first_line)` for decoding
- `v7.sourcecode report-endline-state` already iterates modules this way
- extend `sourcecode.console.report-endline-state` or write new command:
  `v7.sourcecode report-harmonic-steps [pattern]`

## phase 2: llm quality scoring

submit each module to a batch of coding zenka models for quality review.
use `kimi-web.cmd.dispatch_parallel` with multiple models for consensus scoring.

prompt structure (no_tools, single round):
```
rate this protocol-7 perl module for code quality on a scale 0-10.
consider: clarity, correctness, structure, naming, absence of clutter.
output only: { "score": N, "reason": "one sentence" }
```

aggregate: mean score across models = harmonic quality score per module.
models don't see step counts → no circular reasoning.

## phase 3: correlation analysis

- plot: step_count (x) vs quality_score (y) for all ~3900 modules
- compute: pearson correlation coefficient r
- test: statistical significance (p-value, confidence interval)
- expected: r significantly negative (high steps → lower quality)

**if correlation holds:**
- step count becomes a free quality proxy on every commit
- files above anti-entropic threshold auto-flagged for review
- llm review only needed on anomalies → massive reduction in review cost

**if correlation doesn't hold:**
- the harmonization metric measures something orthogonal to quality
- still useful: may correlate with other metrics (complexity, bug density)
- still interesting: the null result is informative

## phase 4: commit history expansion

if phase 3 shows correlation, extend analysis into git history:

```bash
## for each commit: extract changed files, decode step counts before/after
git log --format="%H %s" | while read hash msg; do
    git diff-tree --no-commit-id -r --name-only $hash
done
```

correlate step count deltas with commit semantics:
- **bug fixes**: step counts should decrease on fixed files
- **bug introductions**: step counts should increase before the fix commit
- **refactors/cleanups**: step counts decrease significantly, quality improves
- **rushed commits**: step counts high, quality lower, later stabilizes

**visualizations:**
- time series: rolling mean step count across commit history
- quality arc: project-wide quality score over time
- anomaly map: commits where step counts spiked (predict bug introduction)
- cleanup signatures: step count drops correlating with cleanup commits
- the harmonic quality arc of the entire 4000-commit history

## the anti-entropic threshold

the signing system already encodes which direction improvement lies in —
files that consistently harmonize in few steps are already near their optimal
structure. the threshold between "converging" and "fighting" is the boundary
where the step count distribution changes character.

if the commit history shows the project crossing this threshold in aggregate,
that is the measurable moment the codebase became self-consistent.

## future structure upgrade detection

files with persistently high step counts that also score low in llm review
are candidates for structural improvement. the harmonics are already encoding
the delta toward a more coherent state — the review queue writes itself.

automated pipeline (future):
1. on each commit: decode step counts for changed files
2. flag files above threshold
3. dispatch to fast llm for quality pre-screening
4. escalate anomalies to full kimi review
5. track quality arc over time automatically

## prerequisites

- `amos7.decode_octal_bit_header` field mapping documented (which position = steps)
- batch llm review infrastructure stable (dispatch_parallel working — done session 34)
- scoring prompt validated on known-good and known-bad modules first
- git history accessible to batch scripts

## style notes

- all comments lowercase, bracket annotations `[ word ]` not `( word )`
- use `<[amos7.decode_octal_bit_header]>` for header decoding
- batch scoring: `no_tools: true`, single round, structured json output
- results stored in data tree: `tree_write harmonics.quality_study.*`

#,,..,..,,,..,,,.,,,,,.,.,...,.,,,.,.,,,,,,,,,..,,...,...,...,,..,...,...,,,.,
#NLEYGI7EXYOOEO2LT43FZG2MAM6QO7G4W3TADWGSDA5IJAYAVSRVZ736FKGVIYG3E6HSTK33LGORK
#\\\|6BS237NBOA6O6JQVIK6OUPYXCENHA5P6ASWQXGYV5IYFX7KP5DF \ / AMOS7 \ YOURUM ::
#\[7]6H56WQWU2MZGGMWOY7CVZVPWMDHL47SOI6SZ26B5Z7EU7RT4GWDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
