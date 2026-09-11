## [:< ##

# name  = task: mine real git history for P7 idiom training data
# descr = build a real (worse -> better) idiom-correction corpus from
#         this repo's own commit history, instead of another synthetic
#         instruction dataset, as input for a future LoRA retry

## context

raised 2026-09-10, fourth follow-on in the idiom-adherence thread, after
`coding-control-vector-p7-idioms.md`, `coding-lora-p7-idioms.md`
(original synthetic-dataset attempt), and `coding-idiom-gate-p7-idioms.md`
(the shipped non-ML fallback, commit `12271bf2c`). that closure commit
already named the real gap directly: a mean-diff control vector and a
from-scratch synthetic SFT dataset both lack "the in-distribution
training data every prior ML attempt lacked and had to synthesize" --
and the LoRA re-attempt this session ran (rank 16, 378 synthetic examples,
loss 0.336) confirmed it empirically: **`invoke` stayed at 0/18 zero-shot
hits, a fourth honest negative**, while the adapter's one measurable
effect was pushing the model toward generic Perl conventions absent from
its own training data's narrow phrasing -- see `coding-lora-p7-idioms.md`'s
2026-09-10 validation section for the full numbers. **this session built
the wrong type of corpus** -- another synthetic one -- when the project
had already reasoned its way past that exact choice one closure commit
earlier. this task exists to not repeat that a second time.

user's framing, recorded verbatim because it sets the actual scope: "we
have memory entries, reasoning templates, context templates, actual
history with diffs, it cannot be impossible to extract, correlate or
'infer' usable input data... it could even be a coding zenka workload
itself, given we wanted to improve its iteration capabilities."

## candidate real-data sources, ranked by expected signal quality

1. **git history diffs, the primary target.** 9392 commits total,
   **6381 touching the code directory across all three of its historical
   names** (`src/` / `base-code/` / `modules/` -- see "mining approach"
   below, an initial count that only checked the current `src/` name
   undercounted this by ~4x). confirmed live 2026-09-10: `<[module]>->(`
   invocation sugar already appears in 2016 commits -- the modern idiom
   syntax has been stable since then, giving a large relevant window
   (2016-present) against a smaller pre-2016 prototype-import slice that
   predates the convention and should be excluded. **unlabeled**,
   though: most commits are ordinary feature work, not idiom fixes --
   see "mining approach" below for the filter.
2. **`data/idioms/corpus/*.jsonl`, the purpose-built source.** cleanest
   possible signal (real generated-then-corrected pairs, already
   category-tagged against `rules.yaml`) but currently near-empty: one
   file, 4 entries, all `kind:gated` with `after:null`/`target:null`
   (rejected violations, not corrections), and `coding.cfg.idiom_gate`
   is itself still commented out in `cfg/zenki/coding/zenka.v7` -- the
   gate has never actually run against real traffic. turning it on
   (`scan` first -- logs only, never rewrites, safest starting point)
   and letting it accumulate is a prerequisite, not optional, if this
   source is to contribute anything.
3. **reasoning/context templates** (`data/md/development/CODE-STYLE-
   AND-LLM-INTEGRATION.md`, `data/yaml/code-style/CONVENTIONS.yaml`) --
   better for diversifying PROMPT phrasing/scenarios than for answer
   quality; these are prescriptive documentation, not (prompt,
   completion) pairs. useful augmentation, not a primary source.
4. **`data/ai-mem/claude/*.md` memory entries** -- lowest expected
   yield. narrative prose with occasionally-embedded before/after code
   snippets, not structured pairs; would need real NLP extraction with
   an uncertain hit rate. deprioritize unless 1-2 prove insufficient.

## mining approach for source 1 (git history), not yet built

**the code directory has been renamed three times -- a plain `git log
-- src/` misses most of history because of it, confirmed live 2026-09-
10 after an initial (wrong) dormancy claim got corrected in-session:**
`src/` -> `base-code/` (renamed `b4389cc64`, 2021-03-27) -> `modules/`
(renamed `8a46ac4b3`, 2021-07-07) -> back to `src/` (renamed
`5255a50a3`, 2026-08-20). any history-mining tool MUST query all three
path names for their respective date ranges, or `git log --follow`
per-file (directory rename detection needs the explicit multi-pathspec
form, `--follow` alone only tracks a single file through renames).

corrected per-year commit counts, right path per era:

| year | commits | path used |
|---|---|---|
| 2021 | 609 | 274 as `src/` [to 03-27] + 335 as `base-code/` |
| 2022 | 40  | `modules/` |
| 2023 | 21  | `modules/` |
| 2024 | 1   | `modules/` |
| 2025 | 538 | `modules/` |
| 2026 | 1966 | 1846 as `modules/` [to 08-20] + 120 as `src/` |

**full historical total across all three names: 6381 commits** -- NOT
the 1627 first reported (that count only ever matched the current
`src/` name, an undercount by ~4x). no real dormancy ever existed; 2022-
2025's apparent silence was entirely a path-filter blind spot.

**process newest-first, not chronologically.** recency correlates with
idiom-convention relevance, and now also with genuine volume: 2026
alone is ~1966 commits, nearly a third of all code-history ever, so a
backward scan hits the richest and most relevant material first by a
wide margin, not just a marginal ordering preference. cap the window at
2016-present (per the earlier `<[module]>->(` first-appearance check)
if volume needs trimming, not before checking whether 6381 commits is
actually too many to process rather than assuming it is.

**commit-message keyword match as a complementary prioritization
signal, not a replacement for the diff-content filter below -- two
precision tiers, both checked live 2026-09-10:**

- **high-precision tier: 122 commits with `style` literally in the
  SUBJECT line** (`git log --format=%s | grep -i style`, no path
  restriction), 28 of those also containing `clean`. Per the user
  (session-verified, not inferred): personal commit habit was
  subject-line-only, no body text, for exactly this class of change
  ("style clean-up in 'base.net.send_to_socket'", "minor style
  adjustment in 'v7.callback.register_ondemand'", etc.) -- these are
  human-authored, explicitly self-labeled pure style/idiom commits,
  the closest thing to ground truth this repo has without a labeled
  corpus. distribution: 2021:23, 2022:5, 2023:3, 2025:21, **2026:65**
  (2026's share plausibly mixes in LLM-assisted sessions, per the same
  clarification -- older years' subject-only-style commits are the
  more reliably pure-human signal).
- **broad-recall tier: 586 commits matching `style|cleanup|idiom|
  convention|refactor.*to use|swap.*to|normalize` across subject+body**
  (`git log --grep`, which searches the FULL message even though
  `--oneline` only displays the subject -- sample-verified real, not a
  regex artifact: `ce29896e3`'s body reads "Fixed using the File::stat
  OO idiom already established elsewhere in P7", invisible from a
  subject-line skim). Lower precision -- a body can mention "idiom" or
  "convention" incidentally inside an unrelated bugfix writeup -- but
  wider net.

use the high-precision tier as the FIRST pass (near-ground-truth,
mine these completely before expanding), the broad-recall tier as a
second pass once tier 1 is exhausted, and the diff-content score.py
delta as the actual admission criterion throughout either way -- a
commit self-labeled "style clean-up" can still contain hunks that
aren't idiom-relevant (whitespace-only, unrelated to the four rubric
categories), so the message tier picks WHICH commits to look at first,
not which hunks to keep.

for each commit touching the code directory (by its era-correct name)
in the resulting window, newest-first (commit-message keyword matches
prioritized within that order), per-hunk (not per-commit -- a single
commit routinely mixes idiom-relevant and unrelated changes):

1. score BOTH sides of the hunk with `data/control-vectors/score.py`'s
   existing frozen rubric (`invoke`, `cfgaccess`, `truefalse`,
   `modedata`, plus the anti-idiom counters) -- reuse it unmodified,
   don't fork a second scoring definition (this repo already has one
   confound-story about a rewriter and a scorer drifting apart, see
   `rules.yaml`'s own header note on why it stays independent from
   `score.py`).
2. keep only hunks where idiom density INCREASED old -> new, i.e. a
   real correction happened, not just an unrelated edit that happens to
   touch a line near some idiom usage.
3. this produces (before, after, category, commit, file, date) tuples
   -- the same shape `data/idioms/corpus/*.jsonl` already uses for its
   `kind:repaired` entries (once any exist), so both sources can feed
   the same downstream pipeline without a format split.

## open hazards, not yet resolved -- read before building anything

- **granularity choice (hunk vs. commit vs. file) is unverified.** a
  hunk-level diff may lack surrounding context (what module, what
  calling convention) that made the "after" version correct -- may need
  to carry N lines of context, not just the changed lines, unresolved.
- **volume is unknown before running the miner once.** worth a cheap
  dry-run count (how many qualifying hunks exist in the 2016-present
  window) before investing in the full pipeline -- if the real number
  is in the dozens, not hundreds, this may need to combine with source
  2 rather than stand alone.
- **rating / deduplication, per the user's own framing** -- once raw
  pairs exist, the categories will almost certainly be skewed (the 4
  sample corpus entries above already show 2 of 4 hitting the same
  `format.use_pragma` rule) -- needs a per-category cap or weighting
  pass before training, same discipline as the original 378-example
  set's "~120/100/100/90" category targets, but now driven by rating
  real pairs rather than authoring synthetic ones to a quota.
- **not every real "before" is a fair training input.** some pre-fix
  code may have been broken/buggy for reasons unrelated to idiom style
  -- a filter on commit message / diff shape may be needed to exclude
  bug-fix commits being mistaken for style-fix commits.
- **the "coding zenka as its own workload" framing is a real design
  choice, not just an implementation detail.** running this as a coding-
  zenka-driven pipeline (using its own `search_code`/`read_file`/git
  tooling access) rather than a standalone script fits the loadable-
  memory vision directly -- the zenka mining its own history to improve
  its own weights, self-sustaining as more commits land -- but it's a
  genuine new capability (git-log/diff access, hunk-level scoring loop),
  not a quick add-on to existing tools. worth scoping as its own build
  step once the mining APPROACH is validated by a plain script first.
  **decided 2026-09-10: that plain script should be Perl, not Python.**
  unlike `train_lora.py` (a genuine constraint -- torch/transformers/
  peft have no Perl bindings), git-history mining is just `git log`/
  `git show` shelling-out, diff parsing, and regex scoring -- nothing
  here needs a Python-only library. `score.py`'s rubric regexes port
  directly (plain regexes, no Python-specific syntax), and a native P7
  module composes with the zenka-workload framing above for free
  instead of needing a separate bridge/venv later.

## real quality hazard, confirmed live 2026-09-11 -- the idiom-density
## filter has no semantic-correctness check

**the mining approach's admission test (does idiom density increase old
-> new) says nothing about whether the "after" is actually CORRECT.**
found live in the curated output: `87b5c3a27` ("screenshot zenka: style
refresh fixes...") substituted `time` (a plain unix timestamp) with
`<[base.ntime]>->(0) // time` for a screenshot filename. `base.ntime.*`
is real, legitimate P7 infrastructure -- confirmed there was a genuine,
intentional large-scale unix-time-to-network-time migration across this
codebase, `base.ntime.harmonized_epoch`'s own file exists and is used
correctly elsewhere (e.g. `base.chk-sum.reference`) -- so this is NOT a
case of "the module doesn't belong in this codebase." The bug is
narrower and more instructive: `base.ntime.*` returns a harmonic-encoded
epoch value hard-capped at `<= 385279`, incompatible in scale/meaning
with `time()`'s raw unix seconds -- so `<[base.ntime]>->(0) // time` is
an incoherent hybrid (Perl's `//` only makes sense between compatible
fallback values), left that way mid-migration and never corrected in
any later commit (checked via `git log --follow` on the file). 7 hunks
from this one commit were removed from `mined.curated.jsonl` (309 -> 302)
once caught -- by inspection, not by any automated check, because none
exists for this failure class.

**implication for anything built on top of this corpus**: a commit
message sounding like a style/idiom fix, and a hunk that genuinely
scores higher on the rubric, are BOTH insufficient evidence of
correctness on their own -- a mechanical migration commit can leave a
broken hybrid mid-transition and still "look like" a clean idiom
improvement to `score.py`'s regexes, which only detect surface pattern
presence, not semantic coherence. **no automated fix is proposed
here** -- this needs a human (or a separate, non-regex-based check) to
spot-review at least a sample of any future mining run's output before
training on it, same discipline as manually reading the sample outputs
this session already did for the `truefalse`/`comment` examples that
turned out fine. Do not assume a larger, unreviewed mining run (tier2,
`--all`) is automatically clean just because this session's smaller
tier1 run mostly was.

## dry-run result [ 2026-09-10, tier-1 commits only, read-only, no
## corpus written yet ]

ran the score.py-delta filter (see "mining approach" above) against
all 122 tier-1 subject-line "style" commits, `--unified=0` diffs
restricted to `src/ modules/ base-code/ bin/`, per-hunk:

- 5028 total hunks
- 4582 "real correction-shaped" (both before/after non-trivial -- pure
  additions/deletions excluded, since a brand-new file trivially scores
  higher "after" than an empty "before" without representing any actual
  correction)
- **664 hunks where idiom density genuinely increased** -- already
  1.75x this session's entire synthetic dataset (378 examples), from
  ONE high-precision slice of history, before touching the 586-commit
  broad-recall tier or the remaining ~6259 commits in the full pool.

sample-verified real, not noise: `6ebb4219` alone contributes a clean
run of `# Capitalized comment` -> `## lowercase comment` pairs (exactly
the `comment` rubric category) across `# Check APT packages`, `# Check
CPAN modules`, `# Install APT packages`, etc. -- genuine, human-made,
same-shape corrections, not cherry-picked. some hunks in the sample are
messier (a color-value change bundled with a comment addition,
`7471f3b2`) -- expect real noise at this stage, the rating/dedup pass
in scope item 4 exists specifically to handle that, not a reason to
distrust the volume estimate.

**conclusion: source 1 alone has more than enough volume.** no need to
fall back to source 2 (idiom-gate corpus) or widen past the tier-1/
tier-2 message-keyword commits to answer the "is there enough real
data" question -- there clearly is. Next real step is building the
actual miner (not just counting) and extending the dry-run's delta
filter to the broad-recall tier + full newest-first pool for a true
total, before the rating/dedup pass.

## scope [ dry-run done above; steps 1 (volume check) is answered --
## everything else below still not started ]

1. ~~cheap dry-run: count qualifying hunks~~ DONE above -- 664 from
   tier-1 alone, real volume confirmed, no need to repeat before step 3.
2. turn on `coding.cfg.idiom_gate = scan` (log-only, no rewrite) and
   leave it running to start accumulating source 2 in parallel --
   independent of source 1, no reason to wait.
3. if volume from step 1 looks real: build the actual hunk-scoring
   miner (plain script first, per the hazard above -- not the zenka-
   workload version yet).
4. rating/dedup pass per the hazards above, before any training run.
5b. **decided 2026-09-11**: user manually spot-checked the 302-row
    curated corpus after the `87b5c3a27` removal -- acceptable, small
    but genuinely P7-idiomatic. Proceeding to train on it as-is rather
    than a full systematic review first; if validation shows real
    influence, THEN invest in refining/expanding the corpus further
    (Kimi sweeps for correctness-checking mined pairs at scale, coding-
    zenka background tasks for continuous mining as new commits land)
    -- explicitly contingent on this run proving the real-data premise
    first, not built speculatively ahead of that confirmation.
5. THEN, and only then, a second LoRA attempt against this real corpus
   -- reusing this session's infra unchanged (target-module methodology,
   `train_lora.py`'s masking/tokenization, `lora_to_gguf.py`'s SSM
   tensor mapping, `coding.lora_train_spawn`'s orchestration, the
   `--flash-attn off` fix in `coding.spawn_inference_server`) --
   none of that was dataset-specific and all of it is still correct.

#,,.,,,,.,,,,,,,,,.,.,,..,,,,,.,,.,,,,,,,,..,,,.,,.,,,,.,,,..,..,,,,,,,..,,,,,,

#,,,,,,,,,..,,,.,,.,,,,.,,,,.,..,,.,.,..,,...,..,,...,...,...,...,,,,,..,,..,,
#V2GDYFP3VOGLZ3IM65DHPNK5D6EJNMTQPMPESDR642JZQTTI3S5VZPV3XCHGKD3TLYEYWTSWST3Q6
#\\\|E3UY35HKPY5BXA2XYYMUK2FZGJL53KGOXHPGBW673YOV4RKPHM4 \ / AMOS7 \ YOURUM ::
#\[7]WLVMBDQ77LS5RZOWDIEWJGA7FWEERWFWNIMMQB4BV7DZPUM5S2CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
