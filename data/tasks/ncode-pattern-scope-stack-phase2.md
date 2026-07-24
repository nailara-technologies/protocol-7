## [:< ##

# name  = task: ncode pattern-learning-loop phase 2 -- namespace scope-stack
# descr = generalize single-namespace applicability match into a nested
#         scope stack, gate widening the same way phase 1 gates graduation,
#         and close the ncode.regex.apply status-bypass gap first

## background

Phase 1 (landed, see data/ai-mem/claude/topic-ncode-pattern-learning-loop.md
"Phase 1 built and verified, 2026-07-24") added a `status`
(`auto-apply`/`llm-required`) field to every `<ncode.patterns>` record and
enforced it in `ncode.cmd.apply`: a fix using an `llm-required` pattern is
skipped unless `ncode.cmd.review` marked it `reviewed`. Graduating a
pattern to `auto-apply` requires an explicit `ncode.cmd.graduate` call that
re-checks a live approval streak -- crossing the streak threshold alone
never flips status.

This task is phase 2: scope a pattern's trust to a namespace, narrow first,
widening only as it earns it -- same self-earned-trust shape as the
review/graduate streak, applied to *breadth* instead of *approval count*.

## part 0 -- prerequisite, do this first, independently useful on its own

`modules/ncode.regex.apply` is a **second, separate apply engine** (used by
`ncode.transform.wave`/`ncode.cmd.transform`, not by `ncode.cmd.apply`) that
reads the same `<ncode.patterns>` store but has **no concept of `status` or
`reviewed`** -- it auto-applies purely based on its own
`<ncode.cfg.auto_apply_threshold>` confidence check. It's currently
unreachable via `p7c` (`ncode.cmd.transform` isn't in `ncode`'s start-file
command list or subroutine whitelist -- confirmed by grep), so this isn't
an active hole, but it must be fixed **before** anyone ever whitelists
`transform`, or doing so silently bypasses the entire phase-1 gate.

Fix: in `modules/ncode.regex.apply`, before the existing confidence-vs-
threshold check (~line 75, `if ( $conf < $threshold or not defined $replace
or $mode eq qw| scan | )`), add: treat a pattern whose `status` is
`llm-required` (i.e. `$def->{'status'} // 'llm-required' eq 'llm-required'`)
the same as below-threshold -- push to `@flagged` with
`action => 'requires_review'`, `$def->{'stats'}{'skipped'}++`, `next`, same
as the existing flag-only branch. Only patterns with `status eq
'auto-apply'` may reach the apply branch below. Do not otherwise change
this module's behavior (its own `auto_apply_threshold` check stays --
`status` is an *additional* gate, not a replacement for it).

## part 1 -- generalize namespace match into a scope stack

Current state, already working, to build on rather than replace:
- `applicability.namespace` is a single string on the pattern record
- `ncode.regex.apply` already matches it: `$app->{'namespace'} eq '*'` or
  `$namespace =~ m|^\Q$app->{'namespace'}\E|` (simple prefix match against
  a caller-supplied namespace string -- read `modules/ncode.regex.apply`
  lines 40-44 and `modules/ncode.transform.wave` for how `namespace` gets
  passed in from a caller)
- `ncode.regex.assess`/`ncode.cmd.assess` already accept a `namespace`
  context param (`modules/ncode.regex.assess` line 12) but it's currently
  unused beyond being threaded through to the candidate's
  `applicability.file_type` -- it does NOT get set as
  `applicability.namespace` on the candidate today. Confirm this before
  changing anything (read `ncode.regex.assess` fully -- the candidate hash
  built around line 71-84 does not include a `namespace` key at all
  currently).

Change `applicability.namespace` (single string) to `applicability.scope`
(arrayref, innermost-first), e.g. `["ncode.regex.*", "ncode.*", "*"]`. On
candidate creation (`ncode.regex.assess`), if `context.namespace` is given,
build the initial stack from it: the exact namespace as scope[0], then
progressively widen by stripping the last dot-segment and appending `.*`,
ending in `*`. Example: namespace `ncode.regex.expand` produces
`["ncode.regex.expand", "ncode.regex.*", "ncode.*", "*"]`. Track which
stack index is currently *active* (the trust boundary) as a new field,
`applicability.scope_active_idx`, starting at `0` (narrowest).

Matching logic (replace the single-string prefix match in both
`ncode.regex.apply` and, new, `ncode.cmd.apply`): a pattern applies to a
given target namespace only if that namespace matches
`scope[scope_active_idx]` (prefix match against the glob, same `\Q...\E`
approach as today, `*` matches everything). `ncode.cmd.apply` currently has
**no namespace/scope check at all** on the target file being modified, and
-- checked directly, this is not an oversight to route around but a real
gap -- **no file-path-to-namespace derivation exists anywhere in ncode
today.** `ncode.cmd.suggest` (which is what populates `<ncode.pending>`,
the thing `ncode.cmd.apply` later reads `$fix->{'file'}` from) has no
`namespace` handling at all; only `ncode.regex.apply`/`ncode.transform.wave`
accept a caller-*supplied* namespace string, they don't derive one from a
path either. This needs new logic, not reuse of existing logic: derive a
namespace string from the target file's basename using P7's dot-notation
module-naming convention -- strip the `modules/` directory and any
extension, e.g. `modules/ncode.regex.expand.util.process_candidate` ->
namespace `ncode.regex.expand.util.process_candidate`. Add this as a small
new helper (e.g. `ncode.util.file_to_namespace` or similar, check
`ncode.util.run_cmd` for the existing naming convention for small ncode
helpers) rather than inlining it, since both `ncode.cmd.apply` and
wherever `ncode.cmd.suggest`/`ncode.cmd.assess` end up needing scope-aware
matching will need the same derivation. Once available, gate on it exactly
like the status check phase 1 added -- out-of-scope fix is skipped (not
applied, not failed), reported as its own counter alongside
`review_required_count`.

## part 2 -- widening is earned, same shape as graduate

New module `modules/ncode.cmd.widen-scope`, same p7c JSON-args adapter
shape as `ncode.cmd.review`/`.graduate` (copy that pattern exactly). Params:
`{ pattern_name, confirm }`.

- Requires `confirm` truthy, same as `graduate`.
- Uses the **same streak mechanism phase 1 already built**
  (`review.approved_streak` / `<ncode.cfg.review_streak_needed>`) --
  do NOT invent a second, parallel streak counter for scope. Widening
  consumes the same earned trust graduation does: re-check the live streak
  meets threshold (same re-check-don't-trust-a-stale-ask discipline as
  `graduate`), then:
  - increment `applicability.scope_active_idx` by 1 (widen to the next,
    broader entry in the stack) -- reject if already at the last index
    (`*`, nothing broader to widen to)
  - **reset `review.approved_streak` to 0** -- trust at the new, broader
    scope has to be re-earned from zero, exactly like a decline resets it
    within a single scope (this task's analogous decision to phase 1's
    "decline resets the streak" pin -- do not silently let one streak
    cover multiple scope levels)
  - log via `<[base.logs]>->(1, ...)`, same security-relevant-event
    logging level as `graduate`
- Does NOT touch `status` (`auto-apply`/`llm-required`) -- scope and status
  are independent axes: a pattern can be narrow-scope+auto-apply or
  wide-scope+llm-required. Do not conflate widening with graduating.

## explicitly out of scope for this task

- Any human-approval UI/routing channel -- still not being built.
- Changing how `ncode.regex.assess` extracts/scores candidates, beyond
  populating the initial `scope` stack from `context.namespace` when given.
- Whitelisting `ncode.cmd.transform` itself -- part 0 makes it *safe* to
  whitelist later, it does not whitelist it.

## verification (demonstrate, don't just claim)

a. A pattern with a 3-level scope stack cannot be applied (via either
   `ncode.cmd.apply` or, if you also smoke-test it, `ncode.regex.apply`) to
   a target outside `scope[scope_active_idx]`, even if `status ==
   'auto-apply'` and confidence is high.
b. `ncode.cmd.widen-scope` without confirm, or without streak met, is
   rejected -- same error-shape discipline as `graduate`.
c. A successful widen: `scope_active_idx` increments, `review.
   approved_streak` resets to 0, `status` is unchanged.
d. Part 0's fix: construct an `llm-required` pattern, run it through
   `ncode.regex.apply` directly (or via `ncode.transform.wave` if that's
   easier to drive), confirm it's flagged not auto-applied even though its
   raw confidence would have cleared `auto_apply_threshold` on its own.
e. `bin/ptd -c` syntax-ok on every file touched, same as phase 1.

## style

- $ARG not $_, lowercase comments, `[ word ]` bracket annotations
- match the existing adapter/error-message shape of
  `ncode.cmd.review`/`.graduate` exactly for the new `widen-scope` module
- no signature stubs on new files -- the repo's own pre-commit signs them

## dispatch

Not yet dispatched -- review this spec first (same reasoning as phase 1:
this is the security-sensitive gate itself, don't let a cold dispatch
invent the scope-matching semantics). Once confirmed, this is
self-contained enough to hand to Kimi K3 the same way phase 1 was.

#,,.,,..,,,.,,,,,,,,.,,,.,,,.,.,,,..,,,.,,,..,..,,...,...,.,.,.,,,,..,,,,,,,.,
#66J5BTV2U4XCJIYSRU2AJBLZWHWMLP2ZMC5H4GOVDFJ4LGTQE3ONICEKJXQMOPSZX6RKRGDISF3U2
#\\\|EYXYB4LIUI5NDHHNZKVJDIBDLZYIQ63IDNFQ6KYTFCJOZBVOQMC \ / AMOS7 \ YOURUM ::
#\[7]WDMPR2EUHGPSQBA5JIQIAZR7LTP3LXYSMRKGQQEYNJQQBNVEEGCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
