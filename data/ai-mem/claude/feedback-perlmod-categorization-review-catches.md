---
name: feedback-perlmod-categorization-review-catches
description: "reviewing kimi K2.7's perlmod.load/autoload categorization output caught 6 real misclassifications (templated/vague reasoning not matching real caller counts), widened to a 59-row K3 re-verification (only 11 survived) and then an 11-file K3 refactor dispatch. also caught a false-positive in MY OWN grep methodology (nested-namespace collision). settled the precise justification for MOVE: base.perlmod.load short-circuits to one hash lookup so per-call overhead is never the reason -- the real one is whether deferring the one-time module-load cost to first-use risks a felt latency hit on an interactive path, not raw call frequency in isolation"
metadata:
  type: feedback
---

Landed 2026-07-26, reviewing `data/tasks/perlmod-categorization-results.md`
(K2.7 dispatch output, see [[project-kimi-k2.7-vs-k3-tier-economics]] for the
K2.7/K3 split this was part of) before handing MOVE-recommended files to a
K3 refactor pass.

## the 4 real misclassifications found

`base.devmod.dump_var`, `base.ntime.epoch_to_ntime`, `base.parser.txt_box`,
`jobsite.chksum.branch-color` were all marked `MOVE` with near-identical
templated reasoning ("called on every ... invocation, modules should be in
init_code") despite each having **one real caller** (or, for
`base.parser.txt_box`, four — mostly console/admin files). All four also
happen to already guard their load call with
`if not <[base.perlmod.loaded]>->(...)`, which independently already
suppresses the log noise this whole cleanup exists to chase — but that
guard's presence isn't itself evidence for or against MOVE, since it only
silences the log line, not the eager-vs-lazy timing question underneath it.
The real tell was the reasoning text reading as boilerplate rather than
something derived from actually checking who calls the file.

**How to apply:** when reviewing a dispatched categorization/classification
task, don't just spot-check a couple of rows and trust the rest — grep the
real caller count for any row whose reasoning text looks templated/reused
across multiple rows verbatim. A templated-sounding justification is itself
a signal worth checking, independent of which recommendation it attaches to.

## methodology gap on my own side

My first instinct after finding those 4 was to grep caller counts for *all*
59 remaining `MOVE` rows the same way — this doesn't work. `.cmd.*` and
`.handler.*` files are invoked through cube's dynamic string-based command
routing (a client sends the literal command name over the wire), not through
a static `<[module.name]>->()` reference anywhere in `modules/`. Zero grep
hits for one of these is completely expected and proves nothing about real
invocation frequency — it's not the same signal as zero hits for a genuine
helper sub (which *is* always called via a real, greppable macro call site).

**How to apply:** the caller-count grep technique only validates helper
subs (bare namespaced names like `base.foo.bar`, invoked via
`<[base.foo.bar]>`-style references from sibling code). It cannot say
anything about `.cmd.*`/`.handler.*` network entry points' real call
frequency — those need either runtime data (traffic patterns,
`access.cmd.usr.cube` grants suggesting broad vs. narrow reachability) or
honest "can't verify statically" acknowledgment, not a confident-sounding
guess from either a dispatched model or from grep.

## 2 more catches, plus a false-positive in my OWN check

Re-running the same caller check on the `base` namespace's remaining MOVE
rows (before drafting a namespace batch for K3) found two more real misses:

- **`base.file.tie_array`**: 0 real callers, reasoning ("core file helper
  called whenever tied arrays are needed") wasn't even templated this
  time — proof the vague-reasoning problem isn't confined to the one exact
  boilerplate sentence. This is why the re-verification scope widened from
  "the 28 rows using that exact phrase" to "all 59 current MOVE rows."
- **`base.tmp_dir`**: its one real caller is `base.root.drop_privs`, which
  per `CLAUDE.md`'s own documented zenka startup sequence runs **exactly
  once per zenka lifetime** (step 5 of the typical start flow). A callee
  reached only through a proven one-shot caller is itself one-shot,
  regardless of how "core" its own name sounds — fan-in depth matters, not
  just fan-in count.

Also caught, this time in my *own* verification technique, not kimi's:
grepping for `llm.service.subprocess_wrapper` matched
`llm.service.subprocess_wrapper.estimate_tokens`'s own `# name = ...`
header line — a sibling file in a nested namespace, not a real call site.
**How to apply:** before counting a grep hit as a real "caller," confirm it's
an actual `<[module.name]>->()` invocation, not just another file whose own
declared name happens to contain the searched string as a prefix.

## the real justification for MOVE, precisely (2026-07-26)

K3's re-verification confirmed `base.perlmod.load` short-circuits to a
single `<base.perlmod.loaded>` hash lookup on repeat calls — so a redundant
per-call load is not a real CPU cost, and "reduce per-call overhead" is
never the right justification for moving a load into `init_code`. User's
precise framing of what the real justification *is*: deferred/lazy loading
doesn't eliminate the one-time actual module-load cost, it just defers
*when* it's paid — from boot time to the moment of first real use. That's
fine for a rarely-exercised admin path, but genuinely undesirable for
anything on a latency-sensitive interactive path (e.g. a GUI window open,
or reacting to a user-triggered action) — the user shouldn't feel a load
stall exactly when they're waiting on something to respond. So the correct
lens for MOVE is "does deferring this specific load risk a felt latency
hit at first use," not "is this called often" in isolation — a
rarely-called but latency-sensitive load can still be worth moving, and a
frequently-called one on a background/batch path might not be.

## current state (as of this note, 2026-07-26)

6 rows corrected by hand in `data/tasks/perlmod-categorization-results.md`
(search for "corrected 2026-07-26"). K3 re-verification of all 59 MOVE rows
landed (`data/tasks/perlmod-move-reverification-results.md`): only 11 of 59
confirmed, spot-checked and held up well (verified `base.perlmod.load`'s
short-circuit directly in source, verified a caller-of-caller chain for
`base.file.temp`, verified `zulum.cmd.export-streams`'s exact 200ms timer).
A K3 refactor dispatch is now in flight (task spec:
`data/tasks/perlmod-move-confirmed-refactor.md`) making the actual edits for
those 11 files. **When that dispatch returns**: verify each edited file with
`bin/dev/ptd -c`, confirm nothing outside the 11-file list got touched, and
confirm no per-call guard was left as dead code after its load line was
removed — same "verify, don't just trust" discipline as the two
verification passes before it. Namespace batching plan (biggest first),
kept for reference from before the count dropped to 11:
`base` (originally 29 candidates, now down to ~6-7 after corrections),
`channels` (9), `coding`/`vision-batch` (8 each), etc. — see
`data/tasks/perlmod-load-autoload-categorization.md` for the original full
namespace breakdown.

## design tangent this surfaced: `base.devmod.dump_var` / `*main::dump_var`

Investigating `base.devmod.dump_var`'s real caller turned up that its only
"caller" is `base.init_code`'s `*main::dump_var = $code{'base.devmod.dump_var'}`
— a glob alias assignment, not an invocation. This is a deliberate developer
convenience: `dump_var(...)` callable from anywhere without the full P7
macro syntax, explicitly meant for ad-hoc debug use never committed. User's
refinement: gate it on the `devmod` module actually being loaded (as a
*policy* signal that debug tooling is active, not a technical dependency —
`base.devmod.dump_var` is fully self-contained and doesn't actually need
anything from the `devmod.*` namespace to run). `devmod.cmd.unload-devmod`
already establishes the exact canary check to reuse:
`ref($code{'devmod.dump'}) eq 'CODE'`. Settled on a wrapper-checks-every-call
design over a swap-on-load/restore-on-unload design — same behavior, but
needs zero changes to `devmod.pre_init`/`devmod.cmd.unload-devmod`, so
nothing to forget to keep in sync.

#,,.,,..,,,..,...,..,,,,,,,.,,.,,,,..,,.,,.,,,..,,...,...,,.,,.,.,,.,,,.,,.,,,
#2Z66H3N6ORSYYODIRYNBEG6VD3KHKSUZCCUBIMDIXP6WOBPRAX4HMLTFWMVNCVVT6PB2KINJPNNOK
#\\\|RZBTE2JS5U6XIPZTZYYXSQXJOLSPN5UXUJUBPJBOVYV7R3VEPYP \ / AMOS7 \ YOURUM ::
#\[7]SQZIUHYNXFGBKCRNPJZGPFNGC2B3YUKSUTKS65UBABIET4NL3ICI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
