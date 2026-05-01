# Session Handover — 2026-05-01

## Completed This Session

### llama-server rebuild (ik_llama.cpp)
- Rebuilt to version 4447 (latest) — new Jinja PEG engine (PR #1369, Mar 9) crashes with
  `--jinja` + tools on Qwen3.5 model (stack overflow in libc, segfault)
- Rebuilt to version 4266 (commit `542988773`, one before the broken Jinja engine) — works
- Binary: `/data/source/ik_llama.cpp/llama-server-cuda-fa` (symlink → `llama-server-cuda-fa-12.5.0`)
- Repo is back on `main` branch; binary is pinned at 4266 via the build symlink
- Config toggle added: `coding.jinja.enable = yes/no` in `configuration/zenki/coding/start`
  (set to `yes` — 4266 handles `--jinja` + tools correctly)
- Upstream bug: new Jinja engine crashes on Qwen3.5 tool template; multiple related issues
  open on ik_llama.cpp (#1514, #1518 etc). Rebuild to tip when a fix lands.

### Coding zenka improvements
- `coding.async.tool_executor`: JSON repair pass (3 anti-patterns: literal whitespace in
  strings, trailing commas, illegal backslash escapes like `\[`). On repair failure: return
  exact parse error to model instead of dispatching with empty args.
- `coding.sanitize.jinja_messages`: fix illegal backslash escapes in tool_call arguments
  before sending to server (prevents Jinja crash on round retry)
- `coding.handler.http_io`: init `$buffer = ''` to silence undef concat warning
- `coding.spawn_inference_server`: `coding.inference.reasoning_effort` config — passes
  `--chat-template-kwargs '{"reasoning_effort":"..."}''` to server. Set to `low` by default
  to prevent runaway `<think>` spirals on the 4B model.

### Model selection
- Tested 4 models on same benchmark task (kimi auto-approve fix):
  - 4B Huihui Q8 (BVFPWBA): unstable, JSON errors, think spirals
  - 4B Claude distilled v2 Q8 (SJCPFAQ): clean 3-round result, no errors, fast — **new default**
  - 9B Q6_K (MBZAAII): correct but basic
  - 9B Claude distilled v2 Q8 (WZIZD6Y): detailed reasoning, no 500s — available for heavy tasks
- New default: `coding.cfg.start_model = SJCPFAQ:AGKY7YQ` in coding start
- 9B Claude distilled v2 stays available via `p7c coding.switch-model WZIZD6Y:2BIZKWY`

### kimi auto-approve race condition fix
- `modules/kimi.handler.approval_request`: moved `auto_approve` check BEFORE session guard
  so reconnects no longer block auto-approval. Previously queued then lost during reconnect.

### nshell Ctrl+O history off-by-one
- `modules/nshell.handler.ctrl_o_cycle`: `history_add` pushes then shifts when at max
  capacity — all indices shift down by 1, so `search_idx` must be `cur_index` not
  `cur_index + 1`. Fixed by detecting size change after add.
  Result: Ctrl+O now correctly cycles through the last N entries indefinitely.

## Open / Next

### nshell first-command `(0)` prefix bug
- `( echo clear ; sleep 2 ; echo close ) | p7.nshell | grep invalid` → `invalid command id syntax or length`
- Cube receives `(0)clear\n` instead of `clear\n` on the very first command only
- Root cause: log reply from cube (reply to nshell's startup log send) arrives in nshell's
  session buffer before the first user command. `base.handler.command` processes it,
  generates a protocol mismatch response via `YYOPDKA` with `cmd_id=0`, written to the
  output buffer. First user command appends after it.
- Earlier form: `(cmd_id)(route_id)p7-log.append...` — a fix attempt stripped it down to
  just `(0)` but didn't fully eliminate it.
- Documented in: `data/yaml/coding-tasks/nshell-session-protocol-tunneling.yaml`
- Kimi session (100 rounds): investigated `v7.notify_online` reply loop in send-buffer.
  Key finding: cube's `setup.aliases.source_zenka_sid` alias auto-prepends
  `SOURCE_ZENKA SOURCE_SID` to `p7-log.append` for non-cube zenki — kimi accidentally
  broke this by adding a manual prefix in `send-idle-callback` (reverted). The `(0)` source
  is still unconfirmed — `send.local` debug showed it's NOT from the log send system.
  All `YYOPDKA` template writes produce `"FALSE..."` with no `(0)` prefix when cmd_id empty.
  Best theory: commit `01b6be26e` removed trailing space from cmd_id formatting —
  something that was undef (no prefix) is now `0` (produces `(0)` prefix).
- `v7.notify_online` retry loop was kimi regression (reverted), confirmed gone after revert.
- cube alias `setup.aliases.source_zenka_sid` auto-prepends SOURCE_ZENKA SOURCE_SID
  for non-cube zenki — do NOT add manually in send-idle-callback.
- Kimi session archived: `data/asc/coding-chats/kimi-session-nshell-bug.jsonl.xz`
- Pre-existing bug, not worsened this session.
- Proper fix: cube raw mode + VTerm line session buffers (large feature, deferred).

### llama-server tip rebuild
- When ik_llama.cpp fixes the Jinja engine crash (track #1369-related issues), rebuild
  from tip to get VRAM improvements in 4268-4447 range.
- Toggle: set `coding.jinja.enable = yes` (already set) and rebuild with build script.

### context ceiling
- With 4B Claude distilled v2, context auto-calc gives ~110K. Check if ceiling can move
  up now that server is stable. `coding.cfg.context_max = 110007` in coding start.
