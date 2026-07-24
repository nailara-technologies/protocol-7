---
name: topic-format-code-bugs-fixed
description: "full arc of bin/format-code hardening across one extended session: 17 real bugs/features fixed via dogfooding on real zenka files, landing on a 5-category pattern-template pipeline (bracket block, loose paragraph, list, box, commented-code) plus N-way string splitting -- now applied clean to 11 real zenki/namespaces (jobsite-discovery, letsencr, bin/Protocol-7, web-browser, httpd, ticker, source, sourcecode, AMOS7 modules, base, coding); one known perltidy-rejoin idempotency gap deliberately left open on 3 files"
metadata:
  type: project
---

**Landed 2026-07-24, one extended session.** `bin/format-code` is a
PPI-based preprocessing pass (quote-splitting, comment reflow) that runs
before perltidy. Every fix below was found the same way: ship a fix, ask
the user to dogfood on a real file (`format-code -n` dry-run, diffed), fix
what that surfaces, repeat — never synthetic tests up front. See
`data/yaml/reasoning-templates/canonicalize-then-derive.yaml` for the
methodology this session converged on and documented mid-flight.

## Final state : what ships as of `bf5ceaa4d`

`preprocess_source` runs a fixed step pipeline per line: step0 (rejoin +
resplit an existing multi-line `.`-concat chain), step4 (align a
`##`-comment block OR a single over-budget `##`-line — same renderer for
both), step5 (normalize a `##[ title ]###...` fill-bar to `LINE_MAX`),
step3 (relocate a trailing inline comment), step1 (split a long quoted
string), step2 (reflow a long `##`-comment line that step4 didn't claim).

`step4_align_comment_block` recognizes five pattern categories against one
shared segment/wrap pipeline (not five separate renderers — see the
"combinable dimensions, not exclusive categories" note below):
bracketed block (`## text ##`), loose paragraph (no closing marker
anywhere), numbered/bulleted list (2+ marker recurrence), symmetric box
(blank framing line present, author's own padding depth preserved), and
commented-out code (2+ code-shaped lines — passed through byte-for-byte
untouched, never reflowed).

## The bugs, in landing order

1. **Comment silently dropped** (`step3_relocate_trailing_comment`,
   `5a1d3ae7f`): relocating a trailing comment that didn't actually help
   returned just the code line, discarding the comment. Fixed: falls back
   to the original line.

2. **Unbalanced string splits** (`step1_split_long_string`, `5a1d3ae7f`):
   greedy-maximal split left tiny leftover fragments. Fixed: picks the
   split closest to the midpoint among positions satisfying both lines'
   budgets.

3. **Missing feature: multi-line `##` block alignment** (`f9954e3cf`,
   corrected `88369cd59`): no mechanism kept a block's right-hand `##`
   bars aligned. New `step4_align_comment_block`. **Two wrong detection
   rules before the right one**: "every line individually closed" broke on
   paragraphs where only the last line closes; "stop the run at the first
   closed line" broke on a properly-closed first line that's still the
   start of a bigger paragraph. Right rule: collect the maximal contiguous
   run first, THEN check only whether the run's last line is closed.

4. **Trailing-marker width-budget miscalc** (`step2_reflow_comment`,
   `5de8c6b2f`): wrap width computed before subtracting the reattached
   trailing `##` marker's length, so a line could look like it fit and
   skip wrapping, then land over `LINE_MAX` once the marker came back.

5. **UTF-8 bytes vs characters** (`slurp_file`, `1be569b06`):
   `decode_utf8`/`encode_utf8` imported but never called; every
   `length()`/`substr()` was counting bytes not characters, so any
   multi-byte UTF-8 char (em-dash, arrows) made a line look 2-3 cols wider
   than its true width. Found on a real em-dash in `web-browser.open_window`.
   Same bug class the user predicted by instinct mid-session, unprompted,
   before this specific instance turned up.

6. **Whitespace-collapse idempotency bug** (`618b2324b`): `s{\s+}{ }g`
   collapsed ALL internal whitespace runs, destroying intentional
   double-spaces the sentence-join logic itself had inserted on a prior
   pass — a second run would then re-derive different spacing than the
   first. Fixed: strip only leading/trailing whitespace, leave internal
   runs untouched.

7. **Break-heuristic too narrow** (`618b2324b`): only terminal punctuation
   was treated as an intentional line break. A real 3-line block of
   note-style sentences with no terminal punctuation got merged into
   run-on prose. Generalized: a line ending well short (>15 cols) of the
   width budget is also treated as an intentional break — a forced wrap
   fills close to budget by definition, so stopping well short with no
   punctuation is still a real authorial signal.

8. **List structure destroyed** (`d764a4381`): a numbered list folded into
   flowing prose, numbers becoming inline text fragments. Fixed: detect a
   marker (`\d+[.)]`, `[a-zA-Z][.)]`, bullets) recurring 2+ times at
   line-start — the same repetition-threshold rule used throughout this
   session to dodge "everything is a group parent."

9. **Box-padding shrunk** (`b6952dcb6`): a symmetric box's author-chosen
   padding depth (e.g. 2 spaces) collapsed to the tool's own 1-space
   default even though symmetry was preserved. User's framing: "restoring
   symmetry is repair; shrinking correct padding to the tool's default is
   erasure wearing the mask of tidiness." Fixed: detect the author's own
   padding depth from the input, reconstruct using THAT value.

10. **Commented-out code reflowed as prose** (`af6859753`): a `##`-block
    containing real Perl code shapes (control-flow keywords, `{`/`}`/`;`
    terminators, `$var->`/`$var{` chains) got joined/rewrapped like
    ordinary prose, scrambling it. Fixed: 2+ code-shaped lines → pass the
    whole block through completely untouched (even indentation is part of
    what's being preserved).

11. **3-hash (or N-hash) close marker not recognized** (`7f0b039ba`):
    `comment_block_line_parts` only stripped exactly 2 trailing `#`,
    leaving a stray `#` glued into `content` whenever the close marker
    used 3 (`## title ###` — a real, common convention in this file, not
    a typo). That stray char defeated box blank-line detection and
    corrupted titles. Fixed: match `\#{2,}` (2-or-more) as one unit. This
    is what un-mangled `bin/Protocol-7`'s "compiling subroutine" box,
    which an earlier dogfood run (before this fix existed) had corrupted
    into `## #  compiling subroutine #  # ##` — required reverting
    `bin/Protocol-7` to pre-mangle state and re-running once the fix
    landed (`244d36cb3`).

12. **New step5: `##[ title ]###...` fill-bar normalization** (`7f0b039ba`):
    a third bracket convention (`##[` — no space before the bracket)
    entirely bypassed every existing step. Corpus analysis across
    `modules/`+`bin/` (452 real occurrences, filtered to 4+ trailing
    hashes to exclude the unrelated short `##[ title ]##` label
    convention) showed 74% already sit at exactly `LINE_MAX` with only
    single-off drift around it and no secondary cluster at any other
    width — unlike box-padding, there was no legitimate alternate value to
    preserve, so the fill is normalized unconditionally, not
    threshold-gated. `base.handler.command` alone had accumulated years of
    imprecise manual correction passes here.

13. **step2/step4 disagreement — oscillating fixed point** (`82717d31c`):
    a single over-budget `##  text  ##` line (`block_len == 1`) went
    through step2's simpler wrap, producing 2 lines that only THEN
    qualified as a step4 block on the NEXT run, which re-rendered them
    with step4's padded-both-sides style — first-pass output never equaled
    the converged form. Fixed: route a lone over-budget `##`-line through
    step4's renderer too (same `any_close`-aware padding logic), not just
    genuine 2+-line blocks. An already-fitting single line is untouched
    either way.

14. **N-way string split collapsed to 2-way, silently overflowing**
    (`82717d31c`, the most serious correctness bug found): both
    `step0_rejoin_concat_chain` and `step1_split_long_string` only ever
    tried ONE split point regardless of how much content remained. A real
    4-fragment `.`-concat chain in `web-browser.cmd.replay-synth`
    (originally 4 lines, each fitting) got rejoined to a flat string then
    resplit into only 2 lines — the second massively exceeding `LINE_MAX`
    (132 chars). New shared `split_into_lines()`: tries the original
    tested balanced 2-way split first; falls back to greedy-maximal
    repeated fill (guaranteed to only stop once verified to fit, however
    many lines — 3, 4, ... — that takes) when 2 isn't enough. **First
    rewrite attempt was itself buggy**: a two-phase design (count needed
    lines via greedy-max simulation, THEN distribute content via balanced
    targeting) let the two phases disagree — balance took
    smaller-than-max chunks per line, so the precomputed count came up
    short, and the forced-final line silently absorbed the overflow.
    Caught by re-verifying against the ORIGINAL multi-fragment source, not
    just the already-broken 2-fragment collapse. Fixed by making
    termination a single authoritative check ("does whatever remains fit
    as final RIGHT NOW"), never precomputed and trusted separately.

15. **No margin for perltidy's own re-indentation** (`82717d31c`): budget
    math assumed a continuation line's indent equals the quote's own
    column, but perltidy (which runs AFTER this tool) sometimes indents a
    continuation 4 cols deeper than that — silently pushing an
    already-tight split over `LINE_MAX` after the fact. Confirmed
    pre-existing (reproduced with the pre-session committed tool too, on
    `web-browser.cmd.replay-play`) — not something the N-way fix
    introduced, just newly visible once N-way splitting was exercised
    broadly. Fixed: new `CONT_MARGIN => 4` constant reserved on every
    continuation-line budget calculation.

16. **Bracket-annotation exclusion protected content unconditionally**
    (`c5b78611a`): `## [ short remark ] ##` is a deliberate, widely-used
    atomic-remark convention (dozens of legitimate instances at 60-83
    cols across the codebase), so both `comment_block_line_parts` and
    `step2_reflow_comment` excluded it from reflow entirely. But
    `step2_reflow_comment` is only ever called once a line already
    exceeds `LINE_MAX` — so its exclusion was unconditionally protecting
    content that was, by definition, always over budget, with no
    fallback that ever wrapped it. Found on an 84-char annotation in
    `AMOS7/SHM.pm` that stayed overflowing forever. Fixed: removed the
    exclusion entirely in `step2_reflow_comment` (redundant given its own
    call-site guard); conditioned `comment_block_line_parts`'s exclusion
    on the line already fitting. A within-budget annotation stays fully
    protected; an over-budget one reflows like ordinary content. 318
    other over-budget annotation lines exist across the codebase that
    will benefit from this as their namespaces get their turn.

17. **List-marker detection missed colon-labeled items** (`bf5ceaa4d`):
    only numeric/lettered markers and bullets counted as list anchors, so
    recurring `Label:`-prefixed items (`Phase 1:`, `tree_read:`, `port
    resolution:`) got merged into run-on prose. Found on real damage in
    `coding.tool.detect_loop` (two separate labeled lists) and
    `coding.tools.handler.summarize_context` (two repeated `port
    resolution:` lines) while dogfooding `coding`. **First version had
    its own false-positive**: admitting a space before the colon into the
    label character class let ordinary `' : '` punctuation ("trigger :
    only true stuck retries..") false-trigger the same block's threshold
    alongside one legitimate `Pattern:` line and corrupt an unrelated
    paragraph. Tightened to require the colon immediately follow a word
    character. Verified via a full-pipeline sweep across every
    previously-committed namespace (~1400 files) with zero attributable
    diffs. Two related-but-distinct gaps found and deliberately NOT
    fixed here — neither matches a `Label:` prefix, each needs its own
    detection signal: quote/arrow example-demonstration lists
    (`coding.parser.query_prefix`) and format-template strings with
    embedded `\n` escapes (`coding.handler.models_discover_reply`) still
    merge into prose.

## Still open, found but not fixed : perltidy can rejoin what step0 split

Discovered while re-verifying `coding` after bug #17: perltidy doesn't
only re-indent continuation lines (bug #15's finding) — it can also
**rejoin** a `key => 'string'` pair that `format-code` left on separate
physical lines back onto ONE line, when that fits perltidy's own
formatting preference. On the NEXT `format-code` run, `step0`'s rejoin
step re-measures `$before` (the prefix up to the opening quote) from the
file *as it currently exists* — which now includes the literal
`'description' => ` text on that line, not just whitespace — shrinking
the effective budget compared to the original computation. The split
point shifts, and on `coding.tools.definitions` this cascaded into an
extra 3rd fragment (`. ']'` isolated on its own line) that wasn't there
after the first pass. Content stays correct either way (no data loss, no
overflow) — this is a stability/aesthetics gap, not corruption. Affects
a small slice (3 of 112 files in the `coding` batch:
`coding.cmd.switch-model`, `coding.task.chunk_and_summarize`,
`coding.tools.definitions`). User's call: sign as-is, defer the fix
rather than block on it. Same underlying class as bug #15's "reserve
margin for what happens after you, out of view" but harder to margin
around, since it's not a depth difference — it's whether an entire prior
line boundary still exists at all after perltidy reshapes it.

## Verified real-world application (all re-run fresh + signed, this session)

- `letsencr` zenka (44 files) — `dc5b69ea9`. Also required a one-off source
  cleanup: an orphaned `#` in a comment (leftover decorative
  vertical-alignment attempt from the file's original authoring, confirmed
  via `git blame` back to creation, not a tool artifact) was manually
  stripped rather than teaching the tool to guess which stray `#`
  characters are meaningful (would misfire on real cases like `#fff` hex
  colors or `#123` issue refs elsewhere).
- `bin/Protocol-7` — `d6cc6e069`, then re-run + `244d36cb3` after bug #11
  landed (the first pass had corrupted the box before the close-marker fix
  existed).
- `web-browser` zenka (20 files) — `82717d31c`, after bugs #13-15 fixed the
  oscillation and overflow bugs those specific files exposed.
- `httpd` zenka (23 files) — `b9a6ba512`.
- `ticker` zenka (25 files) — `fabafec2d`, alongside the unrelated
  [[topic-fake-signature-footer-detection]] fix that same commit needed
  (`ticker.cmd.next-monitor`'s fake+real footer pair had to be stripped
  clean and re-signed before the reflow could land).
- `source` namespace (7 of 8 changed files; `source.AMOS-center-bit.desc`
  exempted — see "still open" below) — `47c76bb39`.
- `sourcecode` namespace (7 files) — `e834bbe8c`.
- AMOS7 standalone Perl modules (`data/lib-path/pm/AMOS7*`, 27 files) —
  `c5b78611a`, alongside bug #16 which that same batch surfaced.
- `base` namespace (123 files, the largest and highest-blast-radius batch
  this session — loads on nearly every zenka) — `e1e24abc1`.
- `coding` namespace (112 files) — first attempt reverted after bug #17
  was found live; re-applied clean after the fix landed, with the
  perltidy-rejoin idempotency gap above knowingly left unresolved on 3
  files.

## Verification pattern used throughout

Every fix: `perl -c` / `bin/ptd -c` syntax check (Protocol-7 module files
fail plain `perl -c` for unrelated reasons — custom `<[...]>` syntax isn't
standalone Perl — so `ptd -c` is the correct check, it accounts for that),
full accumulated synthetic regression suite re-run, idempotency check (run
twice, diff must be zero — **discovered mid-session that testing with `-n`
alone is misleading**: perltidy's own re-indentation, which runs as part of
the real pipeline, resolves some apparent drift that `-n`-only testing
flags as a bug), and for string-rejoin specifically, runtime value
equality via direct `perl -e` eval-and-compare, not just visual diff.

## Design principle affirmed, not just followed

These five categories are **combinable dimensions feeding one shared
pipeline** (detect anchors → segment → canonicalize → wrap → render), not
mutually exclusive templates to dispatch between. Confirmed via a design
review before starting the (correctly aborted) full-registry refactor: a
block can be closed AND boxed at once; a registry-of-templates would force
orthogonal dimensions into exclusive buckets and duplicate the shared
segment/wrap logic across entries. The user's own call, unprompted: "we
should prioritize keeping already established functionality and work in
strategic predictable improvement steps even if smaller instead" — this
whole 15-bug arc is that principle in practice.

## Still open

- Regex-literal (`qr{}`, `m{}`, `s{}{}`) line-splitting safety — flagged
  as "itself a special but even more complicated case for later [ regex
  awareness ]" by the user; not started. Different, harder safety analysis
  than the quote-token interpolation-awareness already built for
  step0/step1 (only safe under `/x`, only outside character
  classes/escapes).
- A nested-perltidy idea for commented-out code (strip `##`/space prefix,
  run the code itself through perltidy, re-prefix) was scoped and
  explicitly deferred as its own separate, riskier feature — noted that
  the wrap threshold would need adjusting for the stripped prefix length
  when it's eventually built.
- Not yet applied broadly across all of `modules/`+`bin/` — has been
  deliberate zenka-by-zenka dogfooding (jobsite → letsencr →
  `bin/Protocol-7` → web-browser → httpd → ticker → source → sourcecode →
  AMOS7 modules → base → coding) rather than a mass apply, matching the
  "smaller predictable steps" principle above. `jobsite` itself — the
  zenka the whole session's dogfooding started with — still hasn't
  actually been applied+committed; only ever used for early bug
  discovery. Confirmed the current tool now handles its known pending
  overflow (`jobsite.sync.push_chunk`) cleanly, via a scratch-copy test,
  when it's picked up.
- `source.AMOS-center-bit.desc` exempted from the `source` namespace
  batch: an outdated ASCII bit-table with column-aligned spacing that
  resists every existing binary detection predicate. Motivated a new
  "probability scoring for ambiguous content" section in
  `canonicalize-then-derive.yaml` (weighted signals — interleaved
  non-word spacing, uppercase/base32 charset runs, irregular positional
  bracket markers — voting past a threshold, rather than a sixth ad-hoc
  binary category) as the anticipated eventual fix; not implemented.

## related

[[topic-p7-text-formats-landed]], [[feedback-base-swap-subs-promote-pattern]], [[topic-fake-signature-footer-detection]]

#,,,,,...,,..,...,,..,.,,,,..,.,,,,..,,,.,,,,,..,,...,...,...,..,,,,.,,,.,,.,,
#3U3UNV6B3G6MNLFPHHVNBW22EJ3VA7JSSOAQMMKCB2H5L7F3KF3YXFTF5ZKZILHSKIOX4J4UGADZE
#\\\|5I4X2DUCTTU7FYLYR6HQO2OLE3OFSLDQO662LNZB7EGNUFUEJIQ \ / AMOS7 \ YOURUM ::
#\[7]YDW7ZIG7C26TGIEG653TIPACMCJMHJLUJPBVYS4JZE25YEWP4SBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
