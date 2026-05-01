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

## nshell first-command (0) bug
- `( echo clear ; sleep 2 ; echo close ) | p7.nshell | grep invalid` triggers error
- Cube receives `(0)clear\n` on first command only
- Earlier form was `(cmd_id)(route_id)p7-log.append...` — the commit `01b6be26e`
  ("STRM cancel + protocol cmd_id format fixes") removed trailing space from cmd_id
  formatting, changing the appearance of the bug without fixing root cause
- Root cause still unconfirmed: something writes to session output buffer before first
  user command. send.local debug showed it's NOT from log send system. YYOPDKA template
  produces "FALSE..." with no (0) when cmd_id empty. Likely: something that was undef
  (no prefix) is now 0 (produces (0) prefix) due to the format fix.
- Cube alias `setup.aliases.source_zenka_sid` (config/zenki/cube/command_aliases)
  auto-prepends SOURCE_ZENKA SOURCE_SID to p7-log.append — do NOT add manually
- Kimi session archived: `data/asc/coding-chats/kimi-session-nshell-bug.jsonl.xz`
- Proper fix: cube raw mode + VTerm line session buffers (large feature, deferred)

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

#,,,,,..,,,,.,.,.,,,,,,,,,.,.,,,.,,..,.,.,.,,,..,,...,...,..,,...,.,,,...,,,.,
#NSHMYAGZBLOQKWVLGGRAJ52GZR3XR76DXDD7MAKTMREJB4VNN7PZ2PEDJNKOEC3G264IK3IEB7ZYC
#\\\|3G4TRL64AYOYQB7JLEGPBH5D7XG42BAL64HSPTK3CL6TVDHG77K \ / AMOS7 \ YOURUM ::
#\[7]VTRT2N2XWSACNRAT6TJSFP6LLSP52WSKV2SFBKIKXF32BCAS3SDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
