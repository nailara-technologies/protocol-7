---
name: feedback-config-reload-clobber
description: zenka config placeholders for runtime-resolved values get clobbered by reload config/all — caused a long-standing coding GPU crash-loop bug
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8c6d0e32-9761-4414-82f0-d3c7a061e5d7
---

Declaring a runtime-resolved value as a placeholder in a zenka start config
(e.g. `inference.model.path = null  ## resolved during init via network request ##`)
is a trap: `base.cmd.reload`'s `config`/`all` path → `base.reload_config` →
`base.reload_values` re-parses the start file and re-applies *every*
`key = value` line straight into `%data`, silently overwriting whatever
runtime resolution code (here: `coding.resolve_model_path` →
`coding.handler.model_path_reply`) had set. The already-running server kept
working fine afterward (the resolved path was baked into its argv at spawn
time), completely masking the corruption — it only surfaced as
`model not found: null` crash-loop the next time something forced a fresh
respawn (e.g. a timeout-triggered restart). User noted "many sessions tried
[to find this] before" — found + fixed 2026-06-08, commit 89a6817c7
(removed the placeholder line from `cfg/zenki/coding/zenka.v7`).

**Why**: generic `base.reload_values` has no concept of "runtime-owned" vs
"config-declared" keys — it treats the start file as the sole source of
truth on every reload, clobbering any in-memory value for a key that also
appears there, regardless of how that value got there.

**How to apply**:
- Never declare a placeholder for a value resolved asynchronously at
  runtime — just omit the `key = value` line entirely. The consuming code
  already reads these with `// undef` fallbacks (confirmed for
  `coding.async_spawn_inference_servers`), so an absent key is harmless.
- When debugging "value X silently reverted to a stale/placeholder state"
  in ANY zenka: grep the **on-disk** zenka log
  (`/var/log/protocol-7/<hostname>.<zenka>.zenka.log`) for
  `< reload config >` / `< reload all >` markers between the
  last-known-good resolution and the failure. `coding.show-buffer` (the
  in-memory ring buffer) does NOT retain far back enough to catch this —
  this is what made the bug invisible across many prior debugging sessions.
- Likely the root cause (or a major contributor) of the still-open
  "coding queue stall" bug (`data/tasks/archive/coding-zenka-restart-queue-stall.md`,
  see [[topic-coding-state-machine]]) — worth re-testing that scenario now
  that this clobber is fixed.

#,,..,,..,,..,,.,,..,,.,.,,..,...,.,,,...,.,,,..,,...,..,,.,.,...,.,,,.,,,,.,,
#5XBFCVI2P2V2WVNP4TLD6GEK6YUOIO65R7BW7X3JDITUAH5GN3JFGVTE4B66LILZMLD3ITVLDGY6I
#\\\|ITUEG2J7MOF7NXZN7DFYECUPPZ74LQJYZBVF4PR6C6MDS3CVT5L \ / AMOS7 \ YOURUM ::
#\[7]F2QXG4QW7VYMIBSZRWTQ5ZL73UMKKK7Y4SSFWSK4VEFQYWZ7EGBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
