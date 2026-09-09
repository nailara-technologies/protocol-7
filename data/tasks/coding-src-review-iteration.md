## [:< ##

# name  = task: prioritized, resumable module-review iteration
# descr = build the iteration primitive first, real review data second
# param = data/src-review/

## context

follow-on from the module-catalog embedding thread
(`data/tasks/coding-module-catalog-embedding.md`,
`coding-catalog-retrieval-phase2.md`). that thread deferred "generated
per-module summaries" as an embedding-corpus fix specifically -- the bar
for that use case (beat free source-mining by 10+ points, on harvested-
not-authored negatives) was not shown to be worth 18-55 GPU-hours plus
ongoing refresh. **this task is deliberately NOT that.** it is a
standalone, real, useful thing on its own terms -- a persistent per-
module review/summary corpus -- decoupled from whether it ever helps
retrieval. don't inherit that thread's deferred verdict as if it applied
here; it was scoped to one specific use case.

the user's explicit priority for this task: build the **iteration
mechanism** -- prioritized, checkpointed, resumable, idempotent -- and
prove it end to end by actually producing a first real batch of review
data with it. don't over-invest in review-content quality/prompt design
yet; that can be refined later without redoing the iteration engineering.
this is also an explicit dogfooding opportunity for a general "walk a
big prioritized worklist safely" capability the project doesn't have yet
-- lean toward a reusable shape rather than a bespoke one-off script, but
don't build a speculative framework beyond what this concrete task needs.

## why the directory is named what it is

`data/src-review/` -- chosen by running the project's own `harmony`
[ `bin/is-true`, `AMOS7::Assert::Truth`, mod-13 harmonic truth ] against
the three plausible names (`data/review/src/`, `data/src/review/`,
`data/src-review/`). only the last returned TRUE. this is how naming
gets decided here; don't rename it to something that "looks more
conventional" without re-running the same check.

## confirmed mechanism [ read directly from this checkout ]

- **priority input, already free**: `data/md/documentation/module-
  dependency-graph.asc` is `source : callee ...` adjacency
  [ confirmed format ]. `bin/dev/depgraph-corpus` already computes
  reverse edges [ callee -> callers ] from this file for its own corpus-
  weighting purposes -- reuse or adapt that reverse-edge computation for
  ranking, don't reimplement graph parsing from scratch. caller count
  [ in-degree ] is the prioritization signal the user asked for
  [ "zenka + overall reference count" ] : most-depended-on modules
  reviewed first, since they're the ones most likely to matter if this
  data is ever consulted by anything.
- **no existing bulk-iteration-with-checkpointing primitive found** --
  checked `coding.tools.handler.subtask_spawn` [ model-initiated single
  sub-task dispatch, not a bulk background walker ],
  `coding.handler.process-queued-task` [ per-task-queue execution, not
  a large-list batch walk ]. build this new, but keep it small : a
  cursor file [ which module was last completed ] plus a done-set
  [ skip already-reviewed modules on resume, matching the module's
  current content hash so a changed module gets re-reviewed ] is
  probably sufficient -- don't build a generalized job-scheduling
  framework speculatively.
- **existing convention/format checks to ground the review in facts,
  not just LLM impression**: `coding.validate.module` [ header/format
  issues ], `coding.tools.handler.module_convention_check` [ descr/line-
  length convention violations ], `list_inline_subs` [ inline sub
  declarations ]. a review that at minimum records what these
  deterministic checks already know is more trustworthy than one that's
  pure narrative -- consider running the relevant one(s) per module and
  folding the result into the stored review record, not just a free-text
  summary.
- **existing descr convention** [ confirmed via this session's earlier
  work ]: `# descr =` line, 55-char cap enforced on `.cmd.`/console
  modules only [ `module_convention_check` + `.git/hooks/pre-commit` ],
  uncapped elsewhere. read it as one of the review's inputs, don't
  duplicate its job -- the review is a separate, richer artifact, not a
  replacement for descr [ that's the separately-standing, documentation-
  motivated "improve descr accuracy" idea from the same parent thread --
  out of scope here, don't conflate the two ].

## hazards

1. **idempotency matters more than speed here.** this will get
   interrupted [ every prior long-running dispatch this session hit a
   step limit or got cut off at least once ] -- the cursor/done-set
   design must make "run it again" always safe and always resume
   correctly, verified by actually killing it mid-run and restarting,
   not just reasoned about.
2. **don't claim a review is accurate without checking.** an LLM
   summary of what a module does can be wrong, especially for anything
   using conditional/dynamic dispatch [ see
   `data/ai-mem/claude/project-depgraph-conditional-calls-blindspot.md`
   if it's relevant -- dep-graph itself has a known blind spot around
   conditional calls, worth being aware of when trusting caller-count
   rankings too ]. keep review records honestly scoped -- generated
   description, not asserted fact -- and note in the format itself that
   it's LLM-generated with a timestamp/model-id, not presented as
   equivalent to hand-verified documentation.
3. **cost.** a real per-module inference call across thousands of
   modules is real, non-trivial spend. start with a bounded first batch
   [ e.g. top 50-100 by caller count ] to prove the pipeline, not the
   full 5462-file sweep in one run. the iteration mechanism should make
   "run another batch later" trivial regardless of batch size chosen for
   the first proof.
4. **no placeholder AMOS7 signature stubs on new files** -- this has
   been a repeated mistake this session. leave new files unsigned, a
   human signs separately.

## scope

1. priority-list builder : reuse/adapt `depgraph-corpus`'s reverse-edge
   logic to rank all modules by caller count, descending.
2. iteration primitive : cursor + done-set [ content-hash keyed ],
   resumable, idempotent, small and generically usable rather than
   bespoke to this one task if that's a natural fit -- your call, but
   say explicitly in the task-file results whether you made it reusable
   or task-specific and why.
3. per-module review generation : one real inference call per module,
   grounded with at least one deterministic check's output [ hazard 3
   above ], written to `data/src-review/<module.name>.<ext>` [ pick a
   sensible format -- markdown or JSON, your call, document the choice ].
4. run a real first batch [ hazard 4 ] and confirm the resume/idempotency
   property by actually interrupting and restarting it.
5. write results into this task file [ append a results section, same
   pattern as every other task this session ], including: how many
   modules reviewed, the format chosen and why, confirmation the resume
   test was actually performed [ not just designed ], and whether the
   iteration mechanism ended up reusable or task-specific.

## backlog [ 2026-09-09, not scoped, do not build yet ]

raised in conversation while this task was being scoped/dispatched --
recorded here rather than designed further, since three of the four
depend on round-1 review data existing and the fourth risks stacking
speculative design before anything real lands. revisit once this task's
real results are in hand.

1. **round-2 review refinement** -- once round-1 reviews exist and are
   dense/consistent enough to embed, build that embedding domain from
   the review text itself [ not commit messages -- different, richer
   register ], then have a second review pass consult nearest-neighbor
   reviews of related modules before writing/refining its own. each pass
   gets strictly more cross-module context than the last. depends on
   round-1 data.

2. **blind alternate-history translation** -- reuse the existing ~400+
   commit history as a query-training/eval set for the deferred module-
   catalog embedding work, by having a model translate/rephrase each
   commit's own diff+message into query-shaped intent language [ "what
   would you ask to find this" rather than "what changed" ], addressing
   the phase-2 finding that commit messages are the wrong register for
   that use case. **must be done blind to the specific target module's
   own review** -- giving the translator direct access to the review of
   the module(s) that commit touched leaks the answer into the query,
   the same circularity phase-2's gate C already guards against for
   summary generation. depends on round-1 data existing to even test
   properly for leakage.

3. **history disentanglement** -- per-file/per-module git history
   mining that filters out sticky, incidental co-occurrence from bulk or
   mechanical commits [ mass signing passes, version bumps, wide
   refactors -- one commit in this repo's window touches 5293 modules ]
   before any summarization happens, so review generation [ or anything
   else consuming history ] gets a clean per-module story instead of
   noise. **does NOT depend on review data** -- pure git-history
   analysis, buildable against what's on disk today. distinct from idea
   2 : this is about which commits belong to a file's real story, not
   about rephrasing them into query language.

4. explicit reminder for whoever revisits this list: ideas 1 and 2 need
   real round-1 review data to scope or validate against ; idea 3 does
   not and could be scoped independently whenever there's appetite for
   it, without waiting on this task's completion.

## results [ 2026-09-09, kimi session ]

### what was built

1. **priority-list builder** : `bin/dev/src-review-priority` — ranks all
   5470 `src/` modules by caller count [ reverse-edge in-degree from
   `module-dependency-graph.asc`, adjacency parse adapted from
   `bin/dev/depgraph-corpus`, not reimplemented ]. outputs
   `data/src-review/worklist.txt` + `caller-counts.asc`. top-10 verified
   against an independent one-liner computation.
2. **iteration primitive** : `bin/dev/worklist-iterate` — cursor +
   done-set keyed by per-item content hash [ `--hash-cmd`, default sha1
   of item string ], failed-set, atomic done-writes [ tmp+rename, only
   after per-item command exits 0 ]. line-based worklist, per-item shell
   command with `{}` substitution, `--limit` for bounded batches.
3. **review generator** : `bin/dev/src-review-one` — per module: runs
   BOTH deterministic checks via the coding zenka [
   `module_convention_check` + `validate_module` through
   `p7c coding.call-tool` ], one inference call against the local
   ik_llama.cpp server [ 127.0.0.1:8000, model
   `Qwen3.8-9B-heretic-uncensored.i1-Q4_K_M` / AMOS `OFSQC4I:QDBKEXY`,
   reasoning_effort=low ], atomic write of the record.

### how many modules reviewed

**93 modules** [ top 90 by caller count + 3 processed during a --limit
verification run ], **0 failures**, ~16s/module average. every record
grounded in both deterministic checks [ recorded verbatim in the file ].

### format chosen and why

markdown with YAML-ish frontmatter at `data/src-review/<module>.md`.
markdown because the primary consumer is a human [ or an LLM ] reading
a review; frontmatter because the honesty metadata must be machine-
checkable : `generator: llm`, `status: llm-generated, NOT hand-verified`,
`generated_at`, `model`, `model_amos_id`, `prompt_version`,
`source_sha1` [ staleness detection ], `dep_graph_callers` +
`dep_graph_caveat` [ the conditional/dynamic-dispatch blindspot is
stated in every record ]. the deterministic check outputs are appended
verbatim in a clearly-separated section so narrative claims can be
audited against ground truth. documented in `data/src-review/README.md`.

### resume/idempotency test — actually performed, not just designed

- synthetic worklists : skip-on-rerun, hash-change reprocesses only the
  changed item, failure recording + retry, kill -TERM mid-flight leaves
  done-set containing only completed items. all verified.
- **real batch** : started the top-75 run, let 10 modules complete,
  killed it with SIGTERM mid-item-11 [ background task, exit -15 ].
  post-kill state inspected : 10 done markers, no orphan processes, one
  stale `.req.<pid>.json` tmp [ fixed — `src-review-one` now cleans
  stale request bodies at startup ]. restarted with the identical
  command : exactly the 10 completed items skipped, the in-flight item
  re-processed. a second idempotency run and a deliberate done-marker
  hash corruption confirmed : up-to-date items always skip, a mismatched
  hash re-reviews exactly that module.
- one real-world note : a killed in-flight item's side effects can land
  after the kill [ at-least-once semantics ] — per-item commands must
  write atomically; `src-review-one` does [ tmp+rename ].

### reusable or task-specific ?

**the iteration primitive ended up reusable.** `bin/dev/worklist-iterate`
knows nothing about modules, reviews, or inference : any line-based
worklist + per-item command + optional hash command fits [ e.g.
`--cmd './process.sh' --hash-cmd 'sha1sum blobs/{}'` was the exact form
used in synthetic tests ]. the task-specific parts are cleanly outside
it : `src-review-priority` [ ranking ] and `src-review-one` [ what a
"review" is ]. this was the natural fit the task file hoped for : the
state machine [ skip-if-current / redo-if-changed / record-failure /
atomic-done ] is generic by construction, and making it generic cost
less than hardcoding module logic into it would have. next batch is one
command : `bin/dev/worklist-iterate --worklist data/src-review/worklist.txt
--cmd bin/dev/src-review-one --hash-cmd 'sha1sum src/{}' --limit <N>`.

### environment facts worth keeping [ also in data/src-review/PROGRESS.md ]

- p7c needs DOT notation : `p7c coding.call-tool <tool> '<json>'` [
  space form -> "command does not exist" ]
- `validate_module` wants nested args :
  `{"function":{"arguments":{"module":..}}}`
- `http_proxy` env var breaks 127.0.0.1 curl -> `curl --noproxy '*'`
- new files left unsigned by design [ no AMOS7 signature stubs ] —
  human signs separately.

#,,,.,,,.,.,,,.,,,..,,,..,..,,,..,...,,..,..,,..,,...,...,.,,,,.,,,.,,,..,,,.,
#ZLSIUG5TPVTYIJACMVF4ZCVFIJIEA4UXAKAYDDLZ7XUPMABYYUOHA5TFZMMURGH6AE5ABWGHRRTCO
#\\\|C2CL7PBXDLMRNE72U3SRJDDRWDPEIYVHD7HJOACHORSITL7543Z \ / AMOS7 \ YOURUM ::
#\[7]5A26YUGVOVPELNFGFOPT22BUFPMUCA6YQOEXTXZ6ZMVEGRHSEABQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
