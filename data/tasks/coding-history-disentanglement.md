## [:< ##

# name  = task: per-file git history disentanglement
# descr = filter bulk/mechanical commits out of per-module history
# param = does not depend on review or harvested data -- buildable now

## context

raised 2026-09-09 during the module-catalog embedding thread, logged as
backlog item 3 in `data/tasks/coding-src-review-iteration.md` [ see that
file for the two sibling ideas -- round-2 review refinement and blind
alternate-history translation -- both of which DO depend on data that
doesn't exist yet, unlike this one ].

**re-read `data/tasks/coding-catalog-retrieval-phase2.md`'s closing
state before starting this.** that thread's standing conclusion is that
query distribution, not corpus content, was the bottleneck in every
embedding-retrieval attempt -- three different corpus-enrichment
strategies (descr-anchored, source-mined, review-prose) all failed to
move retrieval. **this task is not a fourth attempt at that.** its
value is independent : a clean per-module history digest is useful
input to the src-review corpus [ `data/tasks/coding-src-review-
iteration.md` ] and to anyone trying to understand why a module looks
the way it does, whether or not it ever touches an embedding domain
again. don't reopen the retrieval question here.

## the problem, precisely

per-file git history mining has a known noise source: bulk or
mechanical commits [ mass signing passes, version bumps, wide
refactors ] touch many files at once without being meaningfully "about"
any one of them. this repo has real examples : this session alone
produced version-bump commits touching 3-15 files each purely as
signing-tool side effects, and the phase-2 investigation found "one
commit in the window touches 5293 modules" while checking for a
different confound. a naive per-file `git log -- <path>` mixes these in
with commits that are genuinely about that file, degrading any
downstream summarization or history-based analysis.

## hazards

1. **`color.ui = always` is set in this repo's git config.** confirmed
   2026-09-09 debugging the phase-2 leakage probe -- git emits ANSI
   escapes even into a pipe, which silently broke a `^\+#` line-start
   regex anchor and produced a systematic false negative that looked
   like a broken instrument for an entire investigation round before
   being caught. **any git command whose output gets parsed
   programmatically in this task needs `-c color.ui=false`** [ or
   `--no-color`, or `GIT_CONFIG_COUNT`-based override -- your call on
   mechanism, but verify it actually suppresses escapes, don't assume ].
   this is the single most expensive mistake to repeat from the prior
   thread ; check for stray ANSI bytes in captured output before trusting
   any regex-based parsing of it.
2. **bulk-commit detection needs an explicit, defensible threshold.**
   "touches many files" is a spectrum, not a boolean. decide and record
   a specific rule [ e.g. file-count threshold, or commit-message
   pattern matching known bulk operations like signing/version-bump,
   or both ] BEFORE looking at results, same discipline as every other
   task this session -- don't tune the threshold to make output look
   clean after the fact.
3. **don't conflate this with query-register translation.** the
   deferred sibling idea [ backlog item 2 in the src-review task ] is
   about rephrasing commit text into query-shaped language. this task
   is about which commits belong to a file's story at all, before any
   rephrasing happens. keep them separate -- if this task's output ever
   feeds that one, the boundary should be a clean handoff, not a merged
   pipeline.

## addendum [ 2026-09-10 ]

consolidated into the src-review layout : `data/src-history/<module>.
history` -> `data/src-review/<module>/history`, alongside that same
module's `review.md`, rather than a separate top-level tree -- the
`.history` extension was redundant once the directory itself was named
for the module, and two parallel per-module directory trees
(`src-history/`, `src-review/`) served no purpose once a single one
could hold both artifacts. `bin/dev/git-history-disentangle`'s `OUTDIR`
updated accordingly ; `data/src-history/*.history` removed from
`src/sourcecode.source_path_set_up`, replaced by `data/src-review/*/
history`. moved with `/usr/bin/rename`, `data/src-history/` removed
[ empty after the move ]. references to the old path below are
historical and accurate for what was built 2026-09-09 ; read
`data/src-review/README.md` for the current layout.

## results [ 2026-09-09 ]

### what was built

`bin/dev/git-history-disentangle` [ unsigned, no AMOS7 stub, per this
thread's convention ] : streams the full history once via
`git -c color.ui=false log --no-renames --format=... --name-only`,
hard-aborts if any ESC byte survives [ hazard 1 -- suppression was
verified empirically first : plain `git log` into a pipe emits
`\033[38;5;54m...` on this host, `-c color.ui=false` produces clean
bytes, and the script re-asserts on the captured stream ], classifies
every commit KEEP or BULK per the rule above, and writes one
`data/src-history/<module>.history` file per current `src/` file :
genuine commits first, flagged bulk commits in a separate auditable
section. output is tracked in git [ deliberately NOT gitignored,
unlike data/catalog-corpus/ -- this is a fixed one-time analysis of
already-public history, same durable-reference status as
data/src-review/ ], and `data/src-history/*.history` was added to
`src/sourcecode.source_path_set_up` matching the `data/src-review/*.md`
precedent. 5472 files, 23MB total, ~4KB average.

### hazard-1 handling

verified, not assumed : byte-level `od` comparison of piped output with
and without `-c color.ui=false`, plus an in-script ESC assert. zero ESC
bytes in all 5472 output files [ checked with grep -rEl ].

### filter rule outcome in practice

9383 commits scanned [ history back to 2012 ]. final tally :
**144 bulk [ 139 count-rule, 1 message-rule-only, 4 both ], 9239 kept.**
across all per-file edges : 17281 kept, 25909 flagged-bulk -- **~60%
of file-commit edges were mechanical noise**, dominated by a handful of
repo-wide signing/rename passes [ the largest touched 11428 paths ].

the single message-rule-only catch was `a2622fdd2` [ 5 files,
"resigned an updated version after 'base.path.open' fixes and renaming"
] -- a genuine mechanical re-sign pass far under the count threshold,
exactly the class the message branch exists for.

### honest rule-revision disclosure [ hazard 2 discipline ]

the pre-registered v1 message branch [ broad \b(version bump|re-?sign|
signing|signature update|checksum update)\b anywhere in the subject ]
was spot-checked before acceptance and found to produce **systematic
false positives** : genuine signing-INFRASTRUCTURE development matched
on the words themselves [ "Fix RS256 signing: switch to CryptX...",
"source signing: TOCTOU guard...", "Improve signature update output" ].
the message branch was revised to v3 [ anchored, purely-mechanical
subjects only : `^(docs:)?version[ _-]?bump[\s\d.]*$` or `^re-?sign` ]
and the revision is recorded here and in the script header rather than
silently retuned. the count threshold [ >=100 ] was NOT touched after
seeing results. noted observation : recent history contains no small
pure-"version bump" commits, so the message branch's practical yield is
small ; the count rule does nearly all the work.

### spot-check findings

- `base.cfg_bool` [ reviewed in data/src-review/ ] : genuine section
  lists exactly the commits that built its current behavior [ the
  2021-08-22 'true'/'false' parser expansion, the 2021-06-29 5/-1
  addition, its own rename from base.cfg_boolean ] ; the src-review
  draft documents precisely that behavior, so history and current
  content corroborate each other. all signing passes and both directory
  renames correctly flagged.
- `coding.task.complete` : 8 genuine commits, all plausibly about the
  module [ jobqueue wrappers, async completion, auto-resume, result
  persistence -- matching the code as it reads today ] ; flagged : the
  rename commit and a 179-file line-length remediation, both correctly
  mechanical.
- `coding.catalog.track_write` [ committed today ] : exactly one
  genuine commit [ e1b1292f4 ], zero bulk. correct.
- `base.cfg_bool` also exposed two real methodology gaps, both fixed
  before accepting output : [a] git's own rename detection does NOT
  follow the 2026-08-20 modules/->src/ rename [ signing rewrote file
  content, similarity too low ] -- pre-rename history had to be
  recovered by explicit path aliasing [ modules/<name> and, one
  generation deeper, base-code/<name> per the 2021-07-07 rename ] ;
  [b] rename commits list both old and new path, double-counting every
  file until deduped per commit.

### scope note [ stated as observation, not an issue ]

the sweep covered **the full src/ tree [ 5472 files ]**, not a bounded
sample of reviewed modules -- the whole-history single-pass design made
the full tree the natural unit, and the spot-checks above sampled its
correctness. output volume [ 23MB ] is correspondingly larger than the
task's framing implied, but is fixed-size reference data, not growing.

### boundary kept [ hazard 3 ]

no query-register translation, no rephrasing, no embedding anything :
output is commit metadata partitioned KEEP/BULK, nothing more. if the
deferred sibling idea ever consumes this, the handoff is the
`## genuine commits ##` section boundary.

## filter rule [ recorded BEFORE looking at any results, 2026-09-09 ]

a commit is classified BULK/MECHANICAL -- and excluded from a module's
"genuine" history -- if EITHER :

1. **file-count** : the commit touches >= 100 files total [ across the
   whole repo, counted via `git log --name-only`, renames off ].
   rationale chosen up front : the repo has ~5462 src modules ; the
   known mass pass touched 5293 of them ; a commit genuinely about one
   module essentially never needs to touch three figures of files. 100
   is deliberately high so genuine subsystem-wide refactors [ tens of
   files ] are NOT swallowed by the count rule alone.
2. **message pattern** : the commit subject matches
   m{\b( version[ _-]?bump | bump[ _-]?version | re-?sign | signing |
        signature[ _-]?( update | refresh | pass ) |
        checksum[ _-]?( update | refresh ) )\b}ix
   -- the mechanical operations this repo is known to produce [ mass
   signing passes, signing-tool version bumps of 3-15 files each ],
   which the count rule alone would miss.

commits failing both tests are KEEP. in the output, BULK commits are not
silently dropped from the record : each module file lists them in a
separate flagged section, so the disentanglement is auditable rather
than lossy.

all git invocations whose output is parsed use `git -c color.ui=false`
and the captured byte stream is checked for ESC [ 0x1b ] before parsing
[ hazard 1 -- verified, not assumed ].

[ note : the count rule above was applied unchanged. the v1 message
rule above was found over-broad in spot-checking and revised to an
anchored, purely-mechanical v3 -- see the results section, which
documents the revision openly rather than silently retuning. ]

## scope

1. define the bulk-commit filter [ hazard 2 ], applied to full `git
   log` history [ with `-c color.ui=false`, hazard 1 ], per file under
   `src/`.
2. produce a disentangled per-file history : for each module, the
   commits that genuinely touch it, with bulk/mechanical noise removed
   or clearly flagged rather than silently mixed in.
3. spot-check the result against a handful of modules with known,
   understandable histories [ e.g. ones already reviewed in
   `data/src-review/`, since their current content is already
   understood ] -- confirm the filter removes what it should and keeps
   what it should, not just that it runs without error.
4. decide the output format and location [ your call -- consider
   whether this belongs alongside `data/src-review/` as input material,
   or as its own `data/` directory ; if the latter, remember it likely
   needs a `sourcecode.source_path_set_up` entry the same way
   `data/src-review/*.md` did, if any output needs signing ].
5. write a results section into this task file when done, including
   the filter rule chosen and why, and honest spot-check findings --
   not just "it ran."
6. no AMOS7 signature stubs on any new file.

#,,..,.,.,.,.,,,,,.,,,,.,,.,,,.,,,...,,.,,,.,,..,,...,.,,,.,.,,.,,...,.,,,,.,,
#XXYLL744J3UTHMXI5LZUIEHSJW2PRJKLZEFZXQRCJBYJPFOD4G3FVV5KAONKEYXXFWS7FPZZFLJDI
#\\\|SUKUNLUD3E6K6FXTTILHXXEXL5D4KF7AS3NC6MEBK3QG3PPR7GM \ / AMOS7 \ YOURUM ::
#\[7]RLOI3AT67QAX4MHIJ4G6T2K4APUQIALHACXPPWO4P5KWZOYZ6KCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
