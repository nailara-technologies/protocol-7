---
name: feedback-kimi-dispatch-idle-timeout-recovery
description: "kimi_dispatch MCP calls abort after 1800s of silence, but the underlying kimi-legacy process keeps running and finishing normally -- use session_catchup with the session_id (from session_catchup client:kimi list) to recover the result, not a re-dispatch"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 595555b6-24d1-4413-a879-05d05128d8ab
  modified: 2026-07-22T22:56:14.917Z
---

Two parallel `kimi_dispatch` (k3) calls both hit the MCP tool's 1800s
idle-progress abort ("sent no response or progress for 1800s; aborting")
on 2026-07-22/23. In both cases the underlying `kimi-legacy` process
(visible via `ps aux | grep kimi`) was still alive and running past the
MCP-side failure, and both actually completed their work correctly on
disk / in the kimi session transcript — the "failed" status only meant
the MCP wrapper gave up on waiting, not that the dispatch itself failed.

**Why this matters:** re-dispatching the same task after seeing "failed"
would duplicate work that's still in flight or already done, burning
tokens twice for one task. This is distinct from a real dispatch
failure (crash, bad prompt, tool error) — check process state and the
session transcript before assuming failure.

**How to apply:** on a `kimi_dispatch`/`claude_dispatch` MCP idle-timeout
failure: (1) `ps aux | grep -i kimi` (or claude equivalent) to check if
the underlying process is still alive — if so, wait for it to finish
rather than re-dispatching; (2) once it's gone (finished), use
`session_catchup` with `client: kimi` and no `session_id` to list recent
sessions and find the one matching the dispatched prompt (title is the
first ~60 chars of the prompt), then call `session_catchup` again with
that `session_id` and a focused `instruction` to get a token-free 9B-
model summary of what it actually did — this works even though the
`kimi_dispatch` MCP call itself returned "failed" and lost the return
channel. Confirmed working end to end this session for both the
log-anonymization phase-1 dispatch (real changes recovered from disk +
`git status`, no `session_catchup` needed since files were visible
directly) and the ncode-zenka-modules dispatch (no disk changes to
inspect — `session_catchup` was the only way to learn it had correctly
found the zenka already fully implemented and made no changes, rather
than silently having failed or duplicated work).

#,,,.,...,.,.,.,,,,,.,.,,,,,.,..,,,,,,..,,...,..,,...,...,.,,,,.,,...,,..,,,.,
#E5D2GODFK4IYNMJZ7RE2X5HFF7VPICGFHZONPOIEBP7L2KMYL7B64OXBFUYYI7JDHJ7LOYKACNUUW
#\\\|YOSARTGA45DRBHNBALTSFWXJHFAAE7L6JC4JG5NWYI54UZ27IUF \ / AMOS7 \ YOURUM ::
#\[7]CCNP6YII4NPBX7ODJ3YEQIPDS5SHPIUZHIBW6M7D4WG5HBGSPGCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
