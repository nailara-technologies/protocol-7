---
name: feedback-kimi-dispatch-model-verify-before-send
description: verify the exact kimi_dispatch model string before sending, not after -- restarting from scratch instead of session_catchup+kimi_continue wastes tokens even though the session is always recoverable
metadata:
  type: feedback
---

Dispatched a task with `model: "k3"` (full `kimi-code/k3`, 1M context, more
expensive) when the intent was `kimi-code/k3-256k` (see
[[reference-kimi-k3-256k-model]]) for a well-scoped single-file bug fix.
Caught mid-run by the user; reacted by `TaskStop` + full re-dispatch from
scratch, which cost real session tokens for a mistake that a 5-second
check against existing memory would have avoided.

**Correction:** the re-dispatch-from-scratch reaction was itself wrong,
not just wasteful. I assumed a run stopped before printing its own
"resume this session" line had no recoverable UUID. It does --
`session_catchup(client: "kimi")` (no `session_id`) lists recent kimi
sessions with their UUIDs regardless of whether the run ever completed a
turn or printed its own resume line; the session log exists on disk as
soon as kimi starts, not only at completion. So the actual mid-run
model-swap path is: `session_catchup` to find/confirm the UUID, then
`kimi_continue` with the corrected model -- never `TaskStop` + restart.

**Why:** kimi sessions support switching between k3 model variants
mid-session via `kimi_continue` with no reported issues, and the session
is discoverable via `session_catchup` at any point after it starts, not
just after it finishes. There is no state where restarting from zero is
actually necessary for a wrong-model catch.

**How to apply:** before calling `kimi_dispatch`, check
[[reference-kimi-k3-256k-model]] (or equivalent current model reference)
for the right model string for the task's scope. **STALE as of the
2026-09-17 alias rename below -- don't follow the old `k3-256k`-vs-bare-`k3`
split literally, read the rename note first.** If a wrong model is
discovered after dispatch, at any point, use `session_catchup(client:
"kimi")` to find the session UUID and `kimi_continue` with the corrected
model -- do not `TaskStop` and re-dispatch.

**ROOT-CAUSE FIXED 2026-09-17, same session, commit `e9f78a211`**: the bare
`k3` alias now means the 256k-ceiling variant; the expensive full-context
one is now explicitly named `k3-1m`. This wasn't just a config tweak --
per the user, it fixes the actual mechanism behind every recurrence below.
The recurring mistake was never really "forgot to check context size
separately from reasoning quality" (a discipline/memory framing) -- it's
that reaching for "k3" is a *reasoning-quality* thought ("this needs
k3-tier correctness"), and the old naming silently smuggled a *context-size*
commitment into that same word, with nothing about the name itself
signaling that coupling. **General principle, stated directly by the
user: align a mnemonic to the natural thought flow that reaches for it,
don't design safety to depend on remembering an unstated fact.** The
fix is naming, not a checklist: the option someone reaches for by default
(bare `k3`, thinking "quality") is now the cheap one, and the expensive
outlier has to be named explicitly enough (`k3-1m`) that picking it is a
deliberate act, not an accident of the natural mnemonic. Also worth
noting: fixing this doesn't recover the tokens already lost to past
recurrences -- but it's not merely "worth it going forward" in the
abstract either. Every session between when this was first noticed and
when the rename actually landed paid the same tax again; the savings
compound with how early the real fix lands, not just whether it
eventually does. See [[feedback-fix-immediately-reduces-cognitive-load]]
for the same point made more generally.

Current, correct guidance post-rename: bare `k3` (or `k3-256k`, still a
working explicit alias) for anything correctness-critical regardless of
file count -- it's the default, cheap-by-design option now. `k3-1m` only
when context genuinely exceeds 256k or video input is needed -- deliberately
the unambiguous, harder-to-reach-for name for the expensive path.

**RECURRED 2026-09-17**: dispatched a ~7-file, task-doc-driven
implementation (a coding-zenka state-machine extension) on plain `k3`,
reasoning correctly that the task was concurrency/correctness-critical
(worth k3-tier reasoning) but never checking whether the *context*
actually needed the full 1M ceiling -- it didn't, the whole file set
was a handful of Perl modules + one task doc, nowhere near 256k. Same
underlying miss as [[kimi-dispatch-pattern]]'s 2026-08-15 note ("k3
reasoning tier" and "needs >256k context" are two independent
questions; picking k3 only answers the first). User caught it same
turn by asking "would k3-256k also have worked?"

**refined mechanism, per user citing kimi's own API docs**: switching
between k3 variants via `kimi_continue` has **no disadvantage** as long
as the session's context still fits the target variant's ceiling at
switch time -- kimi only auto-compacts first on an actual context-size
mismatch (e.g. session grew past 256k, then continuing on `k3-256k`).
So a wrong-tier-for-context dispatch is *not* just recoverable, it's
recoverable at zero cost in the common case: don't hesitate to
`kimi_continue` a running `k3` session down to `k3-256k` (or the
reverse) purely because the model differs from the last call --
only worry about it if context has actually grown past the smaller
ceiling.

#,,..,,..,.,.,,..,..,,,,.,,..,.,.,..,,...,,..,..,,...,...,...,,.,,,.,,,,.,.,,,
#AIHX4HHAB4V2Q7PI5JYHRH26O6QQ6CFVZQ3XOLD57PY25SADYMGW62UFJBKMC5RS6EQ77IVGJIZK4
#\\\|63E2FPRQ7WM637GXX44ZLDN4KJTOC53CT7OLQS65GJK572N2QGY \ / AMOS7 \ YOURUM ::
#\[7]CPATCC3ILVFHZGKA4QWOHLGVGTK3P5X6IAIWHH6YCT3SIO5RACBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
