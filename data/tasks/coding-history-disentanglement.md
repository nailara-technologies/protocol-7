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

#,,.,,..,,,..,,,.,.,,,...,.,.,,,.,,,,,..,,,,,,..,,...,...,.,.,..,,.,,,.,.,,,,,
#5M3QP2NNO3AUITNM6WLSZHQZ4QC2FTJKH3LOPXH4OUVYTU3ADLVSDHP55OROWCFU3VHXTWWOBDY4A
#\\\|FWFEXXORWJQJ6PW3JJTNOUH63YPXZTHUPNHOZVBLYTBL77NGAYR \ / AMOS7 \ YOURUM ::
#\[7]5H5WOCGPYYZH7TR2M2CUSKB3SHYEPPOG6L7A54U7SS4YWTTNJKDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
