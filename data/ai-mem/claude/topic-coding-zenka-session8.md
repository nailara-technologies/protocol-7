---
name: coding-zenka-session8
description: May 1 session: llama-server rebuild, model comparison, tool JSON repair, nshell fixes
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
- Cube receives `(0)clear\n` on first command only — `(0)` from log reply mismatch response
- Earlier form: `(cmd_id)(route_id)p7-log.append...` prepended; fix attempt left `(0)` remnant
- Documented: `data/yaml/coding-tasks/nshell-session-protocol-tunneling.yaml`
- Proper fix: cube raw mode + VTerm line session buffers (large feature, deferred)

## nshell Ctrl+O fix
- `history_add` uses push+shift at max capacity — shifts all indices down by 1
- Fixed: `search_idx = $shifted ? $cur_index : $cur_index + 1`

#,,..,,.,,,,.,...,..,,.,.,...,..,,.,.,,,,,...,..,,...,...,.,,,...,,,,,..,,...,
#4DPKGQKZQYZEUKV25F737FHZC5MXXPCJOELRYF5BIMLIWMR2CKQUEEYG3DZWMXACGTYZNLB4E2S7Q
#\\\|HSP3OGBFZDGE32V7SMSBGEQL4QX3YQUEXYET53CRXJFUGRSTSCO \ / AMOS7 \ YOURUM ::
#\[7]AFQ5QOQGI77D2VJYSSUMDMTXOV5QBRTSSRQOAEMGRXMYN4YJRSDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
