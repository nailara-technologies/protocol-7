---
name: topic-ncode-pattern-learning-loop
description: "design for a self-reinforcing format-code/review automation: two-tier mechanical-vs-LLM pattern model, existing stats/confidence fields as the reinforcement mechanism, LLM-prefers-editing-patterns interaction model, namespace-scoped gating, nested-dispatch to avoid confirmation storms"
metadata:
  type: project
---

**Design conversation, 2026-07-24, same session as
[[project-ncode-write-path-2026-07-24]] which landed the actual
`assess`/`suggest`/`apply` plumbing this design builds on.** Not started
beyond `ncode.cmd.assess` itself — this file is the shape agreed on for
what comes next, not yet built.

## the goal, as stated

[Semi-]automate `format-code`-style review by grouping suggestions by
category/similarity/confidence, so that with proper segmentation the
highest-rated suggestions are simply applicable — approaching a state
where common issues are all covered and detection is sharp enough to give
round-based feedback purely from fix-pattern-match confidence.

## two-tier pattern model

**Tier A — mechanical, regex-sufficient.** Simple substitutions (quote
style, identifier swaps) where old→new diffing alone is enough:
`regex.assess` extracts pattern+replace, one human approval,
`regex.expand` persists it, then it auto-generalizes to every future
occurrence. No LLM needed at apply time; `ptd -c` is the only gate needed.

**Tier B — contextual, needs judgment.** Cases where a regex can *detect*
the smell but can't safely *generate* the fix — the user's example: raw
`/var/`/`/etc/`/temp-file literals that should route through
`<[file.zenka_dir]>`/`<[file.temp]>` instead. Picking the right helper
requires understanding what the file is for, not just pattern-matching
text. Coding zenka generates the suggested replacement here, but the
result must still clear the same bar as tier A: `ptd -c` syntax gate, plus
a **positive** structural verify (not just `no_match` — reject if the
replacement doesn't actually contain `<[file.`, i.e. catches a
hallucinated or no-op "fix"), and optionally a second LLM pass as reviewer
before auto-apply. Same checksum-addressed fix-ID mechanism either way —
tier B fixes carry `origin: llm-suggested` instead of `origin: manual` so
review UI/dispatch can treat them differently.

**Tier B → maturity, the third state.** Once a fuzzy pattern has enough
`stats.applied`/confidence behind it, it graduates from "needs LLM
judgment each time" down to "template match + trivial variable-name
substitution, no LLM call needed" — same schema as tier A, just arrived at
by promotion instead of hand-authoring from day one. Full progression:
`llm-required` (low stats) → `llm-suggested + var substitution` (medium
stats, mechanical fill-in) → `auto-apply` (high stats/confidence, direct
match).

## self-reinforcement reuses existing schema, needs no new infrastructure

The pattern record in `<ncode.patterns>` already has the hooks for a
rated before/after example database — they're just dead fields right now:
`stats: {applied, false_positive}` never gets incremented anywhere, and
`applicability.confidence` is only ever set once at creation, never
updated from real outcomes. The actual missing pieces, in order:

1. Make `apply` actually increment `stats.applied`/`false_positive` on
   each real outcome.
2. Store a representative before/after snippet alongside each pattern
   when first assessed/applied (one more field on the existing record,
   not a parallel store).
3. When dispatching a tier-B fix-suggestion task to coding zenka, pull the
   top-N patterns by `stats.applied`/confidence and inject their
   before/after snippets into the prompt as few-shot context.

That closes the loop for free: patterns that keep getting approved
accumulate both a higher confidence score *and* become the exemplars
future fuzzy-pattern generation gets shown, while rejected/flagged ones
fade out of the few-shot pool on their own. Nothing here needs a database
separate from the pattern YAML files — it's "start using fields that
already exist."

## preferred LLM interaction model: edit the pattern, not the one-off text

Stated directly by the user: the optimal model is the LLM **preferring to
edit the regex pattern definition itself** (refine `pattern`/`replace`/
`steps` into something properly generalized) and using the existing
tools (`assess` to test, `apply` to use) for the current case — rather
than generating an ad-hoc one-off replacement each time. That way every
fix becomes a durable, reusable asset by default. Falling back to a
manual, single-case-only decision is explicitly the **exception**, only
when no matchable/generalizable pattern can reasonably be formed for the
occurrence at hand.

This fallback trigger already exists mechanically: `ncode.regex.assess`
returning no candidates (or, per the live test in
[[project-ncode-write-path-2026-07-24]], a candidate too low-quality to
trust — e.g. captures that the `replace` doesn't reconstruct from) *is*
the "fall back to manual" signal. The architecture doesn't need new
plumbing for this distinction, just discipline in how it's used —
whichever model is doing tier-B work should be instructed to prefer
editing the pattern YAML over emitting a bare replacement string.

## namespace-scoped gating ("parent context layering")

For patterns too generic/context-dependent to trust codebase-wide, scope
them to a namespace or set of files where they're known-safe first,
widening as confidence grows — narrow → safe-zone → whole-codebase →
(eventually) "safe for the codebase's future state too," not just a
one-time cleanup. This also reuses existing schema rather than inventing
new structure: `applicability` already carries `file_type`, and
`ncode.regex.assess` already accepts (but doesn't yet use) a `namespace`
context param — the hook is sitting there unused, same shape as the
stats/confidence situation above.

## nested dispatch to avoid confirmation-request storms

Established, working pattern already in this project (see
[[feedback-claude-dispatch-strategy]],
[[reference-opus-dispatches-kimi-workflow]]): `claude_dispatch`/
`kimi_dispatch` spawn independent CLI sessions with their own permission
mode, used specifically to keep batch/orchestration work out of the
interactive parent session's confirmation loop. The `Agent` tool's
subagents, by contrast, run inside the current session and inherit its
permission mode — their risky actions still surface confirmations back to
the human there, which is the real distinction (not a quirk to route
around).

Shape agreed: dispatch a `claude_dispatch`/`kimi_dispatch` task that owns
the whole "walk the confidence-sorted, grouped suggestion list, `apply`
everything above threshold, stop and report anything below it or that
fails the `ptd -c` gate" loop autonomously — one summary comes back, not N
confirmations. `ptd -c` is what makes this tolerable to automate: the
dispatched session can move fast because the hard "never write broken
syntax" backstop doesn't depend on it being careful.

**Sequencing note, agreed but not yet started:** building the
dispatch/batch-runner is explicitly *lower* priority than closing the
`regex.assess`→`regex.expand`→stats reinforcement loop first — right now
there's almost nothing worth batching (only 2 patterns in
`data/yaml/ncode-patterns/*.yaml` have real `steps`), so the dispatch
runner would mostly be automating confirmation-avoidance for two patterns
until the pattern library actually has a backlog worth walking.

## related

[[project-ncode-write-path-2026-07-24]], [[topic-write-access-security-infrastructure]],
[[feedback-claude-dispatch-strategy]], [[reference-opus-dispatches-kimi-workflow]]

#,,,,,,..,,.,,.,.,.,.,,,,,,..,.,,,.,.,.,,,..,,..,,...,..,,,..,...,...,,.,,,,.,
#OXZLH6ESOIA5YKVER7A6XR3FDK6VI3T2J6CHWJ3KT6IZAXXT4N76P257PTIFXTL6HH3SSW2XT3TYW
#\\\|ITIL3S6JY262ELF3N4ETUISFXBGU4SOMHCQVU4ZRDJPMGIOVRXD \ / AMOS7 \ YOURUM ::
#\[7]TXTQVF4UXTIMSNVYDGCFJ357N232DSWZX3HYVANZCDPD5QPNQUAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
