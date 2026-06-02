---
name: coding-zenka-session8
description: May 1 session: llama-server rebuild, model comparison, tool JSON repair, nshell fixes, kimi regression cleanup
type: project
originSessionId: 6f91985c-b3f0-4cfc-b8d2-1a26499a7881
---
## llama-server binary status (May 1 2026)
- Version 4266 (`542988773`, Mar 9) — last stable before PR #1369 broke Jinja+tools
- PR #1369 (version 4268+) introduced new Jinja PEG engine that segfaults on Qwen3.5 + tools
- Config toggle: `coding.jinja.enable` in coding/start (yes = pass --jinja to server)
- Config toggle: `coding.inference.reasoning_effort = low` — prevents runaway <think> spirals
- Rebuild tip when upstream fixes the Jinja crash (track ik_llama.cpp #1369-related issues)

**Why:** New binary needed for VRAM fixes; Jinja engine regression blocks immediate upgrade.
**How to apply:** When rebuilding, check if tools + --jinja works before switching default symlink.

## Default model (May 1 2026)
- `SJCPFAQ:AGKY7YQ` — Qwen3.5 4B Claude 4.6 Reasoning Distilled v2 Q8 (119 community likes)
- Replaces Huihui 4B Opus Abliterated (BVFPWBA) — less stable, JSON errors, think spirals
- 9B Claude distilled v2 (WZIZD6Y) available for heavy tasks via switch-model

## Tool executor JSON repair
- `coding.async.tool_executor`: 3 repair patterns before JSON parse fails
  1. Literal newlines/tabs in string values
  2. Trailing commas
  3. Illegal backslash escapes (\[ \< \$ etc)
- On parse failure: return exact error to model (not empty args) so model can fix its JSON

## nshell first-command (0) bug — FIXED 2026-06-02
- **Root cause:** `base.handler.command` orphaned route handler generated `(0)!TERM!` when processing prefix-less replies (`cmd_id == 0`). The `clear` command triggers this via SIZE reply orphan paths.
- **Fix:** Added `$cmd_id > 0` guard to both orphaned-route `!TERM!` paths (lines ~1470, ~1516).
- **Defense in depth:** `base.protocol-7.command.send.local` line 107 changed wrap regex from `^(\d+)$` to `^([1-9]\d*)$` so `0` never gets wrapped as `(0)`.
- Historical: commit `01b6be26e` removed trailing space from cmd_id formatting, changing appearance without fixing root cause.
- Cube alias `setup.aliases.source_zenka_sid` (config/zenki/cube/command_aliases) auto-prepends SOURCE_ZENKA SOURCE_SID to p7-log.append — do NOT add manually.
- Kimi session archived: `data/asc/coding-chats/kimi-session-nshell-bug.jsonl.xz`

## nshell Ctrl+O fix
- `history_add` uses push+shift at max capacity — shifts all indices down by 1
- Fixed: `search_idx = $shifted ? $cur_index : $cur_index + 1`

## kimi regression (May 1 2026) — REVERTED
- kimi modified `base.log.send-buffer.send-idle-callback` to prepend node.zenka+sid
  for ALL zenki, doubling the prefix for non-cube zenki (cube alias already does it)
- Also modified `p7-log.cmd.append` with broken @param_arr code — both reverted
- p7-log.cmd.append is intentionally strict with 6-field format — defensive by design
- notify_online retry loop was kimi's regression, confirmed gone after revert

## kimi zenka insight
- kimi-cli gives kimi a more optimizing/complementary context than raw API
- More token-efficient and interactive — worth merging with coding zenka commands
- Dynamic contexts already partially implemented — natural next expansion
- Sliding window paragraph compaction idea: center paragraph compacted with prev/next
  as anchors; group sizes adjustable; works for trees/networks too (neighborhood compaction)

#,,..,,.,,.,.,..,,,,.,,,.,...,.,,,,,,,...,.,.,..,,...,...,.,,,.,,,,,.,,,.,,.,,
#QRCQAFIL3JLW6FKK66IFBQYDBWNWV6COJ5NASVMCGG6QCQEEBS642URVGFOBIFZKHKSQRDGCJGX6O
#\\\|Z6LFFZQC4FUDYIK7GQKSNT2OCGBUF4UWRPS5XXKB6IHPZS3Y4EN \ / AMOS7 \ YOURUM ::
#\[7]OGUBK7X65I2WINPUB6KW75XA4UUHSRI4Y6V3CJHI34OC6A4XYKDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
