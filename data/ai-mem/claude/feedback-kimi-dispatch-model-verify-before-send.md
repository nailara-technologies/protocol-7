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
for the right model string for the task's scope -- `kimi-code/k3-256k`
for single/few-file well-scoped bug fixes and small features,
`kimi-code/k3` (short alias `k3`) only for wide-context tasks (large
multi-file sweeps, long log/session analysis, video input). If a wrong
model is discovered after dispatch, at any point, use
`session_catchup(client: "kimi")` to find the session UUID and
`kimi_continue` with the corrected model -- do not `TaskStop` and
re-dispatch.

#,,,,,.,.,,,,,,,,,,..,,.,,,,.,,.,,...,.,,,...,..,,...,..,,,..,,.,,,,,,,.,,...,
#O4GOGQ65ZBM7UKLC4HZ4VJX6OFIVMQ6LZSFXR74RCZF6ZIVVBYM5TRAGCZ2B6SNQG5YDUU5S7LBV2
#\\\|3RY772EGL4FZD2M3AQI3J3QVUO5SERP643H4KVGFCLFELVIYLSN \ / AMOS7 \ YOURUM ::
#\[7]QTY6DOMWMRAPL4BHUQCBQDELSIXTCAZPQNBPCTKQEFGGZ56DIEAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
