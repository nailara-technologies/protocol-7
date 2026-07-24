---
name: topic-ncode-pattern-learning-loop
description: "design for a self-reinforcing format-code/review automation: two-tier mechanical-vs-LLM pattern model, existing stats/confidence fields as the reinforcement mechanism, LLM-prefers-editing-patterns interaction model, namespace-scoped gating, nested-dispatch to avoid confirmation storms"
metadata: 
  node_type: memory
  type: project
  originSessionId: 10c54b94-5d67-41ab-a52a-127a6a5170be
  modified: 2026-07-24T16:20:53.369Z
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

## update, same day: the tier-A blocker is fixed, this loop's first real dispatch

The pattern-schema mismatch that made tier-A patterns no-op in `apply`
(`pattern`/`replace` present, no `steps`) is fixed — `cb45d56d0`, full
detail in [[project-ncode-write-path-2026-07-24]]. `single-quote-to-qw-scalar`
now genuinely applies. This was also the first real production use of
the nested-dispatch pattern this file describes: dispatched via
`claude_dispatch`, needed one `claude_continue` nudge (it got stuck
without the debugging info it needed — see the "how to apply" note in
[[feedback-claude-dispatch-summarize-hang]], a related but distinct
infra rough edge hit on the *second* continue, where the auto-summary
layer returned a garbled non-answer rather than relaying the real
session's output). Lesson for next time: **don't trust a dispatched
session's self-report at face value — check the actual repo state
directly** (`git status`/`git diff`, syntax-check, re-run the live test
yourself) before treating dispatched work as done, especially when the
summarization layer is what's actually visible to you, not the
underlying session.

**Still open, next real gap:** `regex.expand`/`regex.assess` aren't
exposed to `p7c` for the persist-a-new-candidate step —
`ncode.cmd.assess` only *returns* a candidate for review; nothing writes
an approved one into `<ncode.patterns>` (in-memory) or back to YAML
(`regex.save`) yet. That's the actual next piece needed before this
loop can run for real, now that the mechanical tier-A path underneath
it is proven correct.

## update, 2026-07-24: approval-gate design settled (self-learning, not threshold-configured)

Design conversation to close the "still open, next real gap" above — what
gates a new candidate from landing in `<ncode.patterns>`, and what governs a
pattern's confidence/scope growing over time. Key reframe: **the graduation
decision is a question posed to the LLM, not a config number picked in
advance.** Settled shape:

1. **Tier A (mechanical)** unchanged from above — regex-extraction alone is
   confident enough, no LLM involved, `ptd -c` is the only gate. This is the
   dead `confidence_threshold` fetched in `ncode.regex.expand` but never
   applied in `ncode.regex.expand.util.process_candidate` — the actual
   currently-existing gap: any syntactically-valid candidate lands today
   regardless of confidence. Wiring this check up is the first concrete fix.

2. **Tier B (LLM review), default for everything else.** Every match gets
   reviewed by the LLM against the pattern; each outcome (approve/decline)
   is logged on the pattern record (reuse `stats.applied`/`false_positive`,
   or a sibling field if review-outcome needs to differ from apply-outcome).
   - **Decline is terminal, no human escalation.** A conservative LLM "no"
     doesn't need a second opinion — it's a normal outcome, not an error
     state that needs a human to unstick it.
   - **Approve accumulates a streak.** Once a streak threshold is crossed
     (a *count* — e.g. N consecutive approvals, zero false_positives since —
     not a confidence float), the next review becomes a distinct
     **graduation ask**: *"should future matches of this specific pattern
     skip review and auto-apply?"* Answered by the LLM itself from its own
     accumulated track record, not by a number set in advance. A "yes" flips
     the pattern `llm-required` → `auto-apply` (the tier progression already
     documented above).

3. **Human approval is the residual fallback, not a parallel channel.**
   Consistent with "LLM-prefers-editing-patterns" above: the LLM's first
   move is always to edit `pattern`/`replace`/`steps` toward something that
   clears assess/apply on its own. A manual/human decision request only
   fires when that fails outright — no generalizable pattern-edit exists for
   the case at hand. Human approval is never the answer to "should this
   graduate," only to "no better action was found." The LLM *may* still
   route a graduation-ask or landing through a human as a discretionary
   courtesy CC even when self-approving, but that's optional, never
   required.

4. **Scope-widening (namespace promotion)** uses the same streak/graduation
   mechanism, evaluated per-widening-step: a pattern's `scope` is a stack
   (innermost-first, e.g. `["ncode.regex.*", "ncode.*", "*"]`), and moving up
   the stack re-runs the same "ask the LLM once the narrower scope's stats
   justify it" logic rather than a separately-configured number — stats
   reset/re-accumulate at each new scope level rather than being assumed to
   transfer.

Net effect, stated directly by the user: this makes the pattern library
**self-learning and self-improving as its primary tendency** — reinforcement
happens through the LLM's own accumulated judgment on a given pattern, with
config-level thresholds limited to the streak-count trigger for *when to
ask* the graduation question, not to the graduation answer itself.

**Phase 1 built and verified, 2026-07-24** — dispatched to Kimi K3 (nested
dispatch, Claude overseeing) with a fully-specified spec pinning the three
sub-decisions the dispatch must not invent: (1) below-threshold candidates
persist as `llm-required`, never rejected outright; (2) a decline resets
`review.approved_streak` to 0 and is a normal terminal outcome, never
escalated; (3) crossing the streak only ever returns a `graduation_ask`,
status flips *only* on the separate explicit `ncode.cmd.graduate` call,
which re-checks the live streak rather than trusting a stale ask. Landed:
`status` field (`auto-apply`/`llm-required`) + `review` stats sibling to
`stats` on every pattern record (`modules/ncode.regex.expand.util.process_candidate`),
`<ncode.cfg.review_streak_needed>` (default 5, `modules/ncode.init_code`),
new p7c-facing modules `ncode.cmd.review`, `ncode.cmd.graduate`,
`ncode.cmd.expand` (the latter finally exposes `regex.expand`'s
persist-a-candidate step to p7c — the gap flagged above), and the actual
enforcement point in `modules/ncode.cmd.apply`: an `llm-required` fix with
no `reviewed` flag is skipped, not applied, reported separately from
`failed` as `review_required_count`. Verified directly (not just Kimi's
self-report, per the dispatch-summarize-hang lesson): `git diff`/`ptd -c`
on all 6 changed/created modules, code-read of the review/graduate/expand
logic against the spec, and live `p7c` smoke tests of the error paths
(unknown pattern, graduate-without-streak, invalid outcome) — all correct.

**Deferred to phase 2, deliberately not built:** the namespace/scope-stack
widening described earlier in this file (`scope: [...]` promotion across
namespaces) and any human-approval routing/UI channel — the phase-1 dispatch
prompt explicitly listed these as out-of-scope so Kimi wouldn't invent them.

**Found while scoping phase 2, 2026-07-24: a second apply engine exists
that would silently bypass the whole review/graduate gate if ever
exposed.** `ncode.regex.apply` (invoked via `ncode.transform.wave` /
`ncode.cmd.transform`, a multi-wave regex+LLM bulk text-transform pipeline)
reads the *same* `<ncode.patterns>` store phase 1 built the gate on top of,
but has its own, older, independent applicability check: a single-string
namespace prefix match (`$app->{'namespace'} eq '*' or $namespace =~
m|^\Q$app->{'namespace'}\E|` — already-working precedent for phase 2's
scope-matching, just not a stack yet) and its own confidence threshold
(`<ncode.cfg.auto_apply_threshold>`, distinct from the `confidence_threshold`
key phase 1 wired into `regex.expand`). **It has no concept of `status` or
`reviewed` at all** — it would auto-apply an `llm-required` pattern purely
because its own confidence clears `auto_apply_threshold`, bypassing
`review`/`graduate` entirely. Currently harmless: `ncode.cmd.transform`
isn't in `ncode`'s start-file command list or subroutine whitelist, so
nothing can reach it via `p7c` today — confirmed by grep, not assumed.
**But this is a landmine for whoever exposes `transform` later** (it looks
like genuinely useful functionality, multi-wave bulk transform with LLM
fallback) — doing so would silently reopen the exact hole phase 1 closed,
unless `ncode.regex.apply` is updated to check `status`/mark
review-required fixes the same way `ncode.cmd.apply` now does, *before*
`transform` ever gets whitelisted. Two follow-ups this implies:
1. Before ever whitelisting `ncode.cmd.transform`: make `ncode.regex.apply`
   respect `status` (skip/flag `llm-required` patterns, only auto-apply
   `auto-apply`-status ones), same enforcement shape as `ncode.cmd.apply`.
2. Phase 2's scope-stack should reuse `ncode.regex.apply`'s existing
   single-namespace prefix-match mechanism (`applicability.namespace`,
   already field-shaped, already exercised) as the per-scope-level matcher,
   rather than inventing new matching logic — just generalize it from one
   string to a stack, and apply the same matcher inside `ncode.cmd.apply`
   too (which currently doesn't check namespace/scope against the target
   file at all).

## update 2026-07-24, later same day: end-to-end chain dispatch found two
real phase-1 bugs, both fixed and verified directly

Dispatched the "run the whole loop live, one continuous chain" verification
to Kimi K3 (task `kbx4su758`) once `expand`/`review`/`graduate` existed.
Both findings independently confirmed against real repo/live state (not
taken on the dispatch's word):

**Bug A — `ncode.cmd.review` was unreachable via `p7c` due to a command-name
collision, not a routing bug.** `p7c ncode.review` was silently resolving
to `context.cmd.review` (an unrelated, pre-existing "batch review pipeline"
command — its own module family, used by both `context` and `coding`
zenki) instead of ncode's own module. Root cause, confirmed by reading
`bin/Protocol-7`'s loader directly (not the `.cmd.`-segment-stripped
routing gotcha already in [[feedback-cmd-segment-stripped]] — a different,
deeper issue): the loader keeps one **global, per-process, non-namespaced**
bare-command-name table (`$data{'base'}{'cmd'}{$cmd_name}`, `bin/
Protocol-7` lines 1841-1876). Two different modules registering the same
trailing name (after `.cmd.`/`.console.` is stripped) silently last-wins on
the *first* collision (only escalates to a hard, overwrite-blocking error
on a *third* colliding file) — and `ncode`'s own `modules.load` pulls in
`context` into the same process (`auth.client net protocol io.unix ui
ncode context`, needed for `context.diff.*`/`context.pattern.*` that
`ncode.regex.assess` depends on), so both `ncode.cmd.review` and
`context.cmd.review` compiled into one shared command-alias table.

**What actually determines which one wins — corrected, don't trust the
first guess:** initially attributed to `modules.load` list order
(`context` listed after `ncode`), which happened to agree with the
observed outcome but is not the real mechanism. Confirmed directly at
`bin/Protocol-7:1417`: the module/file scan order is `sort { length $a <=>
length $b } reverse sort <names>` — reverse-alphabetic as a stable
pre-sort, **then re-sorted by length ascending** as the actual final
processing order. For this pair, length alone decides it:
`ncode.cmd.review` (16 chars) sorts before `context.cmd.review` (19
chars), so `context.cmd.review` loads later and overwrites. Reverse-alpha
only matters as the tie-break for equal-length names.

**Fix, user-confirmed as the right direction (not a workaround):**
`context.cmd.review` is the established one, `ncode.cmd.review` is the new
one — renamed `ncode.cmd.review` → `modules/ncode.cmd.pattern-review`
(git mv + updated the `name` comment, `ncode.cmd.apply`'s two log/comment
references, `configuration/zenki/ncode/start`'s `access.cmd.usr.cube`
list, and `subroutine.white-list`). Live-verified post-reload:
`p7c ncode.pattern-review` now correctly hits ncode's own `unknown
pattern` logic (not `context`'s `no files matched`); `ls *cmd.review` in
`modules/` shows only `context.cmd.review` remains. User's framing,
matches an existing standing convention: zenki modules should avoid
generic names that could collide with base *or other zenka* commands —
prefer contextualized names (`pattern-review`, not bare `review`) from the
start, same instinct as avoiding collisions with `base.cmd.list`-style
names.

**Systemic follow-up, also landed:** the collision-detection log itself
was nearly invisible — first-time (2-module) collisions only logged via
`log.devmod` (verbose dev-only startup chatter), only escalating to the
always-visible `log.error` on a *third* colliding file. Since a same-name
collision between two different files is never an intentional feature in
this system (no legitimate "override" pattern uses it — the loader's own
"same file" branch already handles benign re-scans/reloads separately),
escalated the first-collision case to `log.error` too
(`bin/Protocol-7`, same block) — pure visibility change, zero behavioral
difference, `perl -c` syntax-clean. Not live-restart-tested (would require
restarting v7 broadly, out of scope for a same-session verification) —
flagged to the user rather than claimed as fully verified.

**Bug B — expand-created patterns applied "successfully" while writing the
file back unchanged.** `ncode.regex.expand.util.process_candidate` never
set a `steps` field on new pattern records — only YAML-loaded patterns
(via `ncode.regex.load`) got the `steps` synthesized from `pattern`/
`replace` (the `cb45d56d0` fix). `ncode.cmd.apply` executes
`$def->{'steps'} // []`, so an expand-created pattern had zero steps,
content never changed, yet `verify_pass && step_ok && syntax_ok` all
trivially passed (nothing to fail) and the fix was written back and marked
`applied` — a false-positive success, confirmed by Kimi via unchanged
sha1, and independently confirmed by reading `process_candidate`'s stored
hash directly (no `steps` key at all). Fixed by copying `ncode.regex.
load`'s exact synthesis logic into `process_candidate`: explicit
`candidate.steps` used as-is if present, else a single `{tool=>ncode,
search=>$pattern, replace=>$replace}` step synthesized, else `[]` for
detect-only candidates. `ptd -c` clean. This was a real gap in phase 1's
own scope, not something the phase-1 dispatch spec asked for — missed
because `ncode.regex.load`'s parallel synthesis wasn't cross-checked
against `process_candidate` at the time.

**Bug B live-confirmed end-to-end, after a real detour.** First attempts
to confirm via a real file write kept failing for reasons that turned out
to be unrelated to the fix itself, in order: (1) reusing the same pattern
*text* across repeated manual test candidates triggered
`process_candidate`'s duplicate-pattern merge path instead of creating a
fresh named entry, so filtering `suggest` by the new name matched nothing;
(2) `bin/ptd`'s `is_perl_code()` requires the literal `## [:< ##` P7
module header as the first line to recognize a file as Perl at all —
bare one-line scratch scripts were silently rejected, surfacing as
`ncode.cmd.apply`'s syntax-check failing; (3) `ncode.cmd.expand`'s
`REF(0x...)` display bug (already flagged by the phase-1 dispatch as a
minor issue) hides whether `expand` even succeeded, so failures upstream
were invisible. Once controlled for, a **fourth, real, separate issue**
surfaced: `ncode.cmd.apply`'s chmod-child write grant failed with
`Permission denied` on an otherwise-correct attempt. Diffed `ncode.
start.chmod_child` against `coding.start.chmod_child` (the module it was
ported from) looking for a divergence — none found; `ncode`'s `restore`
command handler is if anything *less* restrictive than `coding`'s `gw`
(no file-group-match gate at all, just `chmod($mode,$path)` gated only on
`-e $path`). Root cause was never fully isolated line-by-line, but
**resolved by `p7c v7.stop ncode`** (killing the long-running zenka and
its chmod-child together, letting both respawn fresh on the next
on-demand call) — strongly suggesting stale long-running process/pipe
state rather than a logic bug in the restore mechanism, consistent with
the known pipe-desync risk in [[feedback-chmod-child-restore-readline]]
(every `restore`/`create` send must pair with exactly one readline, or
the pipe permanently desyncs one step for every call after). **After the
restart, full live confirmation succeeded**: `expand` → `suggest` →
`apply` against a real scratch file in `data/scratchpad/`, content
genuinely changed (`'fresh_marker_9921'` → `'qw| fresh_final |'`),
`1 fixes applied`. Bug 2's fix is now confirmed correct both by code
review and by a real live write, not just by logic inspection.

**Minor, not chased further:** `ncode.cmd.suggest`'s `patterns` name-filter
param didn't match an exact, freshly-created pattern name during this
testing (dropping the filter entirely found it immediately) — separate
small bug, low priority, noted for whoever next touches `ncode.cmd.
suggest`.

**If chmod-child `Permission denied` recurs on a long-running `ncode`/
`coding` zenka:** try `p7c v7.stop <zenka>` first (on-demand respawn picks
it back up) before assuming a logic bug — this session's evidence points
at stale process/pipe state on a long-lived instance, not the restore
command's permission logic itself.

**Access-control gap found the same day, not yet resolved:** landing the
new `ncode.cmd.review`/`.graduate`/`.expand` commands on `ncode`'s own
start-file whitelist doesn't make them *reachable* — `access.zenki` has no
grant for any caller to reach `ncode.*` at all; only the `<admin-user>`/
`<unix-admin>` wildcard in `access.users` can, which is why phase-1's smoke
tests worked (they went out via `p7c` as `unix-taeki`). If the review loop
is ever meant to run from inside a zenka like `coding` natively rather than
via a `p7c`-shelling agent, that needs its own `access.zenki` grant. Full
detail, including the `taeki`/`unix-taeki` two-principal finding:
[[topic-write-access-security-infrastructure]].

## related

[[project-ncode-write-path-2026-07-24]], [[topic-write-access-security-infrastructure]],
[[feedback-claude-dispatch-strategy]], [[reference-opus-dispatches-kimi-workflow]]

#,,.,,,..,.,.,,,,,,..,,..,.,,,.,.,,..,,..,,,.,..,,...,...,...,..,,..,,,,.,...,
#LMFX7GZ3I5W452S5NQ3IL6PO7NN6BJX7AGYYWDXT2VIYC7ELDHN55XOWFJ2ZPOQRXAB6EUCRI3BEE
#\\\|YIXKARJXOJADXDMMLVK5N6NWW47EDJ7QZ2Z46FBBFRM4RSRZJF7 \ / AMOS7 \ YOURUM ::
#\[7]6ENZTJXYJ27ZOMQ7J77AAYDIHA4ZUHE44Z5PBZDDWHJYALHM36BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
