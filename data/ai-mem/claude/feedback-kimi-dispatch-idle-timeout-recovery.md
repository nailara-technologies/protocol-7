---
name: feedback-kimi-dispatch-idle-timeout-recovery
description: "kimi_dispatch and claude_dispatch MCP calls abort after 1800s of silence, but the underlying process/session keeps running and finishing normally -- use session_catchup with the session_id to recover the result, not a re-dispatch"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 595555b6-24d1-4413-a879-05d05128d8ab
  modified: 2026-07-26T21:00:00.000Z
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

**confirmed to also apply to `claude_dispatch` (2026-07-26)**: an
`opus`-model `claude_dispatch` design-review task (reviewing
`data/tasks/audio-waveform-visualization.md` against reference
screenshots) hit the identical 1800s idle-abort. `session_catchup(client:
claude, limit: 5)` listed the session by its prompt prefix without
needing a session_id first — the title-prefix list alone was enough to
find it — then a second `session_catchup` call with that `session_id` and
a targeted `instruction` recovered the full recommendation via the local
9B summarizer. The user separately confirmed via `claude -r <session_id>`
directly (bypassing MCP) that the underlying session had in fact finished
normally with the same content `session_catchup` returned — a second,
independent recovery path when the MCP wrapper itself is degraded (e.g.
right after an MCP server restart).

#,,,,,,,,,,,.,,,,,,..,,..,.,,,.,.,.,.,.,,,.,.,..,,...,...,..,,,..,.,,,,.,,.,,,
#ISI2L3WKQLG3UQERSHC6F3NJREDCNV5IJZVHUPUN6YEOKO2MHCFOGCBR4VOMVROK5D6F3LGAA73WE
#\\\|NSICFKKCIOMD24ZNJMXVHYQYWLPRN3QFZ56KCSPU3WTE446XKTI \ / AMOS7 \ YOURUM ::
#\[7]T4SQSSRKHSZGQSQ3IAPV3IVCN55CHA4LJNFUC6F3LN5FYJUEEUAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
