---
name: style-dedup-self-recreation
description: "style formatting → ncode pattern-dedup → self-morphing code: three stages of one lineage, user's own framing, 2026-07-25"
metadata:
  node_type: memory
  type: project
  originSessionId: 10c54b94-5d67-41ab-a52a-127a6a5170be
---

## the framing, verbatim

user, closing a session that had just finished porting `bin/ptd`'s syntax-check
fix into `bin/format-code`:

> "and now with the ncode style parsing round we are upgrading that to the
> next level, before self-recreatability with semi-idoeptency.. and that is
> the step before [self-]morphing code."

> "yes, that transformation process translates the entire project style
> essence into a set of deduplicating templates.. so it can eventually
> recreate itself in waves with stable and improving quality, as a
> consequence.."

## the three stages, as one lineage

1. **deterministic formatting** [ `bin/ptd`, `bin/format-code` ] — originated
   2015 as a SciTE perltidy-filter hotkey (raw code without endlines,
   reformat-on-hotkey instead of enter — doubled/tripled writing speed).
   perltidy options finetuned over a long time until acceptable. became
   *convention* even before LLMs existed to need it — "then it became more
   and more obvious that something like that might need to become
   convention, even before LLM style adherence jitter hammered the point
   solidly into the ground." this stage: fixed rules, deterministic output,
   no learning.

2. **ncode style-pattern extraction / dedup templates** [ current work,
   pattern-learning-loop with approval gate — see MEMORY-active.md ] — not
   just reformatting, but extracting *the entire project style essence*
   into a set of deduplicating templates. this is what [[dedup-tree-unifying-mechanism]]
   is doing for style specifically: convergent patterns across the codebase
   become reusable templates, the same convergence-is-confidence primitive
   applied to "how this codebase writes code" rather than to reasoning
   chains or task routing. this stage: the system builds a model of its own
   conventions, self-correcting via approval-streak trust rather than
   static thresholds.

3. **self-recreatability with semi-idempotency** — the direct consequence of
   stage 2: once style-essence is captured as deduplicating templates, the
   system can recreate itself in waves, each wave stable and of improving
   quality (not a single big-bang rewrite — incremental, template-guided
   regeneration passes).

4. **[self-]morphing code** — the stage *after* semi-idempotent
   self-recreation; not yet worked on, explicitly named by the user as the
   next horizon once stage 3 is solid.

## why this matters for future work

when evaluating ncode pattern-loop changes, the bar is not "does this
reformat code correctly" (stage 1's bar, already solved) — it's "does this
correctly capture reusable style-essence templates that a future
regeneration pass could recreate this code from." approval-gate trust
(self-earned via review streaks, see MEMORY-active.md ncode entries) exists
specifically because stage 3 requires the system's own judgment about its
patterns to become reliable enough to act on without per-instance human
review — that reliability *is* the bridge from stage 2 to stage 3.

cross-links: [[dedup-tree-unifying-mechanism]] (same convergence primitive,
applied to reasoning/task-routing rather than style — same author framed
that file as "the one that can fully represent the others"; style-dedup may
be a fifth application, not yet folded in there), [[self-improving-system]]
vision (task-queue autonomy — a parallel, not identical, self-improvement
axis: that file is about *coordinating work*, this one is about the system
*recreating its own code*).

#,,,,,,,,,,,,,,.,,,.,,.,,,,.,,...,,,,,...,.,.,..,,...,...,...,..,,.,,,,,,,,,,,
#7IHNFGEUCEONPKITVN3W3M22N2APS2VZFUCK5JWU5RZFZ3X6P4O6DQATLGNV2FBI7CV4MJQLZ4JSU
#\\\|GTV2HURVDV5D6WVG42SIHRADTUP22RE7XY3ASVNQH4RFGSBXO7F \ / AMOS7 \ YOURUM ::
#\[7]F75YSPG2ZWCOHL2FF3KPRQQFVXCLQJ7WDABLZSVCWHW3H7SR4KBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
