## [:< ##

# name  = task: does the signature footer's iteration counter correlate with code quality
# descr = a free, already-computed per-file metric (amos-iterations-remaining)
#         -- test whether it's a usable review-priority signal, properly

## context

Every signed file in this codebase carries a `amos-iterations-remaining`
value in its signature footer's first line — the number of harmonization
iterations `bin/amos-chksum`'s convergence loop needed to reach a TRUE
state while signing. It's free to read (no computation needed, already
baked into every file) via `src/amos7.decode_octal_bit_header`.

**Motivating observation, NOT yet evidence**: `amos-chksum -v LOVES` took
5 iterations, `amos-chksum -v FRICTION` took 163. Tempting to read that as
"meaningful/quality content converges faster." **Already tested and
disproven for short words**: a controlled comparison (real words vs.
gibberish vs. single-letter typo variants of the same two words) showed
no separation — `FRIKTION` (one letter changed from `FRICTION`) dropped
from 163 to 7 iterations, and `LOVSE` (a typo of `LOVES`) converged
*faster* than the correctly-spelled word. The iteration count is highly
sensitive to exact byte content in a way that doesn't track meaning or
correctness for short strings. Full trace of that negative result is in
this session's conversation history, not yet written to a memory file —
write it up in `data/ai-mem/claude/topic-harmonic-correlation-ledger.md`
if you want a citable record before starting, since it's directly
relevant prior art for this task and currently only exists in chat.

**This task tests the same hypothesis differently and more rigorously**:
real files, not short words; independent quality scoring, not assumed;
and a controlled within-file distortion-injection test as a second,
cleaner check. Both need to actually be run before concluding anything.

## part 1 — extract the iteration counters (cheap, do this first)

1. Glob every file under `src/` (currently ~5055 files).
2. For each, read the signature footer's first line (the
   `#,,,...`/`#..........,...` style line — see
   `src/kimi.wire.question_respond`'s footer for a real example, or
   any signed file) and decode it via
   `<[amos7.decode_octal_bit_header]>->($line)`.
3. Extract `amos-iterations-remaining` from the returned hash. Handle the
   inverted-mode (all-zero) case correctly — already documented in
   `data/md/design/CROSS-READOUT-RING-KEY-ADDRESSING.md`'s "zero-
   transparency mechanism" section if you need the reference.
4. Produce a sorted list: file path + iteration count, ascending and
   descending. This alone is useful output even before part 2 runs —
   sanity check it looks reasonable (real numbers, not all-zero, not all
   identical) before moving on.

## part 2 — independent quality scoring via coding zenka batch review

1. Take a real sample from part 1's list — not all ~5000 files, pick a
   sample size you can justify statistically (a few hundred, stratified
   across the iteration-count range so both low and high ends are
   represented, not just whatever sorts first).
2. Dispatch each sampled file to the coding zenka (or a batch review
   mechanism it already has — check for one before building new
   infrastructure) for an independent quality score. The scorer must NOT
   see the iteration count when scoring — keep the two measurements
   blind to each other until correlation is computed, or the "neutral
   datapoint" claim doesn't hold.
3. Decide the scoring rubric concretely (style adherence per
   `data/yaml/code-style/CONVENTIONS.yaml`, comment quality, structural
   soundness — pick specific, checkable criteria, not a vague "quality"
   feeling) and state it explicitly in your results so the correlation
   is reproducible.

## part 3 — correlation

1. Compute the actual correlation (Pearson or Spearman — Spearman is
   probably more appropriate here since "iteration count" isn't
   obviously linear with "quality score", and the earlier word-test
   showed the relationship, if any, is likely non-monotonic/chaotic
   rather than smooth) between iteration count and quality score across
   the sample.
2. Report the actual correlation coefficient and its significance, not
   just "looks correlated" — this task exists specifically to avoid
   repeating the two-anecdote mistake the motivating observation made.
3. State plainly whether the hypothesis holds, partially holds, or
   doesn't hold, same discipline as the rest of this session's harmonic-
   math ledger (STRONG / REAL-BUT-WEAK / REJECTED-ON-CHECK tiering).

## part 4 — controlled distortion-injection test (do this regardless of part 3's result)

1. Pick one real, already-high-quality file from the sample.
2. Note its current iteration count.
3. Introduce one deliberate, realistic distortion (a genuine typo-class
   bug, not a random byte flip — e.g. an off-by-one, a wrong variable
   name, a swapped comparison operator) and re-sign it via
   `sourcecode.console.sign`/`bin/Protocol-7 sourcecode update-signatures`
   on a scratch copy — do NOT commit or sign the real file with a
   deliberately broken change.
4. Compare the iteration count before and after. Repeat with 5-10
   different distortion types on the same base file to see if there's a
   consistent direction of change or if it's as chaotic as the short-word
   test suggested.
5. This test isolates the variable properly (same file, one change) in a
   way part 1-3's cross-sectional comparison can't — weight this result
   more heavily if it conflicts with part 3's finding.

## style / house conventions

- comments lowercase, `[ word ]` not `( word )` for annotations.
- do not commit — leave staged for the user to review/sign/commit.
- read `data/ai-mem/kimi/coding-style.md` and `data/ai-mem/kimi/
  MEMORY.md` first for P7 conventions already logged this session
  (bracket-call syntax, `$SIG{PIPE}` danger, cmd-module scope gotchas).
- this is a research/analysis task, not a bug fix — the deliverable is a
  results writeup (new file under `data/tasks/` or `data/ai-mem/`), not
  necessarily new production code, unless part 1's extraction genuinely
  warrants becoming a real `bin/dev/` tool once proven useful.

## if you learn something non-obvious

Add to `data/ai-mem/kimi/coding-style.md` and/or `data/ai-mem/kimi/
MEMORY.md` in your own established format.

#,,..,...,..,,..,,,,,,,..,,..,.,.,,,,,,,,,...,.,.,...,...,.,.,,..,..,,,..,.,,,
#BMZACVGWMQDXYZB7KBOM6HILNAJS5BOO7PMQ7B5PT22KU56FWTFJH5PYFEVQOFIJF2LGJJBPCMX72
#\\\|VFAEKX752BGPO4ZOGSZQF75MWUYR25JQIDIG7FUQTKVT5XVAUAS \ / AMOS7 \ YOURUM ::
#\[7]OZOO5X2BWKXN27QRMHWVB4VI2EWD4WK3B3WTM5DMRTCOTW26A2AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
