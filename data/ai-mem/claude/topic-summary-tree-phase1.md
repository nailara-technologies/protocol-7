---
name: topic-summary-tree-phase1
description: "task-zenka summary topic tree, phase 1 — content-addressed cache relay for session_catchup + coding-zenka-native summaries; architecture, real bugs found, known limitations"
metadata: 
  node_type: memory
  type: project
  originSessionId: b501d766-3643-48ba-886f-cb86d42097e2
---

Design doc: `data/tasks/task-summary-topic-tree.md` — read it in full before
resuming, it has more detail than this memory and is kept in sync with the
actual build (check it's still accurate before trusting it blindly).

## Architecture (settled after two rejected drafts)

Goal: task-zenka-owned semantic topic tree of summaries, lazily deduplicated,
fed by (1) `session_catchup` session summaries and (2) coding-zenka-native
task summaries — so repeated catch-ups on the same content reuse a cache
instead of re-summarizing every time.

Two drafts were tried and rejected before landing on the real design:
- draft 1: new `task.summary-reference` command + note-based correlation
  registry. Rejected — the correlation problem was already solved by the
  existing `task.cmd.summarize` → `coding.cmd.summarize-context`
  (`callback_id`) → `coding.handler.deferred_reply` → `task.cmd.summarize-done`
  relay.
- draft 2: make the coding zenka the relay for *every* caller including
  `session_catchup`. Rejected — `bin/mcp-server-p7`'s `_do_summarize` chunks
  large sessions into a rolling-window loop and assembles the final summary
  itself; the coding zenka never holds the whole session text or the final
  result to relay from.

**Landed**: relay from whichever side actually holds the finished content.
- `session_catchup` → `_do_summarize` itself does the cache query (before
  chunking) and notify (after assembling the final result), synchronously,
  best-effort.
- coding-zenka-native top-level tasks → `coding.cmd.summarize-context`'s
  `tree=1`/`origin` flag + `coding.handler.deferred_reply`'s dual-action
  (reply-then-notify). **Built but nothing auto-triggers it yet** — wiring an
  auto-trigger into `coding.task.queue` completion is a deliberately deferred
  follow-up, not bundled into phase 1.

Single source of truth is the task-zenka-owned tree (`task.cmd.summary-tree-query`/
`-notify`, flat storage for now). No cache in the coding zenka or mcp-server-p7.

## Three real bugs found live during verification (not hypothetical)

1. **`<[base.chk-sum.amos]>` registration-key mismatch** in the coding zenka —
   fixed with the same defensive `$code{'chk-sum.amos'} // $code{'base.chk-sum.amos'}`
   dispatch `task.cmd.create` already used (commented "swap-boundary safe
   dispatch" there).
2. **Command-name length limit**: `base.regex`'s `cmd` pattern caps a
   dot-segment at 23 chars. `coding.cmd.summary-tree-query-reply` (24 chars)
   silently failed with "protocol mismatch" — renamed to `tree-query-reply`.
3. **UTF-8 double-encode**: `Encode::encode('UTF-8', $x)` was called on `$x`
   that was already a raw UTF-8 byte string (everything `cube_command`
   returns in this codebase is unflagged bytes, never perl-decoded chars).
   Encoding already-encoded bytes treats each byte as Latin-1 and
   double-encodes — classic mojibake ("—" → "â"). Fixed in `_tree_notify`.
   **Rule going forward**: only `Encode::encode()` text known to be real perl
   character data (e.g. MCP JSON-RPC args, decoded by `$json->decode`) — never
   something that already came back from `cube_command` or `$json->encode`.

## BMW-L13 checksum switch (same session, after phase 1 landed)

User asked to switch the cache/dedup key from 7-char `amos_chksum` (~35 bits,
real collision risk) to bmw-L13 (13-char base32, ~65 bits,
`src/base.chk-sum.bmw.*`, the project's own division-by-13 harmonic-truth
identity primitive).

**A real incident happened mid-implementation**: first attempt routed
`bin/mcp-server-p7`'s checksum computation through the cube-exposed `bmw-L13`
command (`cube_command("bmw-L13 :B32:<encoded content>")`). This sent the
tail-truncated session content (~400KB → ~640KB after B32) as a single
command-line argument — `base.handler.command`'s buffer caps at **242707
bytes**. Hit it live: a `session_catchup` call against a 30MB session file
appeared to hang. No buffer-exceeded error showed in the log; the connection
was just left in a bad state. User correctly diagnosed it from architecture
knowledge before any error appeared.

**Fix**: never ship content-sized payloads through a cube command line —
short values only (the resulting 13-char chk itself is fine for query/notify).
`bin/mcp-server-p7` now computes bmw-L13 **locally**, standalone, by porting
the `harmonize_L13` division-by-13 loop directly (no P7 module form exists as
a standalone `AMOS7::*` package — only as a zenka module
`src/base.chk-sum.bmw.harmonize_L13`). Uses the same lib-path `BEGIN`
trick `bin/amos-chksum` uses, plus `Digest::BMW`, `AMOS7::Assert::Truth`,
`AMOS7::TEMPLATE` (all standalone-usable, confirmed via CLAUDE.md). Verified
byte-identical to the live cube `bmw-L13` command's output for the same
input, and ~0.13s for a 400KB string (no hang, no risk).

The coding zenka's own chk computation was never at risk — `<[chk-sum.bmw.L13-str]>`
is an in-process function call, not a cube command line, so no buffer limit
applies there.

## Known limitations (both documented in the design doc, neither blocks phase 1)

1. **Cross-origin chk mismatch**: the coding zenka hashes `$content` as raw
   bytes; `_tree_chk` builds its input from perl-decoded character strings
   (`$instruction`/`$text`). Same logical text, not necessarily the same byte
   sequence into `Digest::BMW::bmw_512`. Invisible in phase 1 (the two
   origins' caches never need to match each other yet — coding-native
   auto-trigger doesn't exist). **Will silently defeat cross-origin dedup in
   phase 2** if not unified deliberately first. Do NOT rush this — the
   byte-vs-char mismatch that caused the UTF-8 bug above lurks in any
   unification attempt too.
2. **Cross-zenka tree path unexercised**: `coding.cmd.tree-query-reply`'s
   `callback_id` branch / `task.summarize-done` route has never been hit by a
   live caller — every test used the direct/local-reply branch.

## Process notes for next time

- Every module-file edit needs a `coding.reload` or `v7.restart <zenka>`
  before it takes effect live — easy to forget mid-debugging-loop and chase a
  phantom bug that's actually just stale code.
- Every `bin/mcp-server-p7` edit needs the MCP connection killed + user runs
  `/mcp` to reconnect — I can't do the reconnect step myself, only the kill.
- `access.zenki` edits need `p7c reload config` separately from zenka
  module reloads — easy to edit-then-forget-to-reload and get a confusing
  "no perm" error that looks unrelated to the actual edit just made.
- The user catches real architectural constraints from memory/experience
  faster than I can verify them empirically (the 242707-byte buffer cap, the
  23-char command-name cap, the "container of many message-turns under one
  sessionId" jsonl structure) — when they state a hard constraint, trust it
  and act on it rather than re-deriving/re-verifying from scratch first.

#,,.,,,,.,..,,.,,,.,,,,..,.,,,,.,,,.,,,..,.,.,..,,...,...,.,,,..,,.,,,,,,,,,,,
#KZU42ETOVLP4GJEH5VO3MWIQWY4PNFXJYBHLGXZPYPOIJ4QARAK47HQGPXTLOSI7CHEYT5CPYRT3W
#\\\|6ZZQL7MIWPH2AX3IREUY4YKZ7XYE6N6M57GMGK627NUIYXZ7X3D \ / AMOS7 \ YOURUM ::
#\[7]5YA4T3FDD24G5BLSBWNBOHMTLTN63TVYB7R7KCJSHEOGUAGB2IBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
