---
name: session-68
description: MCP dispatch tooling debugging session — auto_summarize root cause found and fixed; new task files; session_catchup tested
metadata: 
  node_type: memory
  type: project
  originSessionId: 546a6382-2218-4560-9b23-674b363b64b6
---

session 68 — 2026-06-01 — auto_summarize chain fully debugged and fixed

## completed

**session_catchup MCP tool** — confirmed working (both listing and summarizing modes)

**auto_summarize root cause: `decode_json` vs `from_json`** — CRITICAL fix (commit b59d38c3c)
- `-C31` shebang flag makes `qx()` return Perl unicode strings, not raw bytes
- `decode_json` expects raw UTF-8 bytes — fails silently on unicode strings in `eval{}`
- Result lines containing non-ASCII (em-dash `—` in descriptions) caused `$@` to be set
- `next if $@` skipped the line → last-resort passthrough of raw JSON stream
- Fix: `from_json($line)` handles decoded unicode strings correctly
- **Status: committed, needs one more /mcp restart to test**

**other auto_summarize fixes (all committed)**
- `2>&1` → `2>/dev/null` — stderr was potentially interleaving with stdout JSON > PIPE_BUF
- `FD_CLOEXEC` on cube socket in `cube_connect` — prevents subprocess chain inheriting it
- `cube_disconnect()` before `_do_summarize` — clean reconnect after subprocess exits
- `_extract_stream_content` — extracts clean text from `{"type":"result",...}` line (15x reduction)
- coding context_length: 42K → 40K (42K caused VRAM KV cache timeout at 77s)

**chunk size formula** — fixed `_model_chunk_size`: `(context - 4000) * 3.2 / 2` instead of `(context - 5000) * 4`; safe for JSON-of-JSON content

**task files written**
- `data/tasks/strip-dispatch-json-boilerplate.md` — COMPLETED (kimi implemented it)
- `data/tasks/dispatch-template-param.md` — `template=` param for kimi/claude dispatch
- `data/tasks/dispatch-create-template.md` — `create_template=` param; post-dispatch YAML template

## next session

1. `/mcp` restart to test `from_json` fix — should finally see compact auto_summarize output
2. If working, test nested dispatch (session_catchup → claude_dispatch → auto_summarize chain)
3. Dispatch `dispatch-template-param.md` to kimi
4. Dispatch `dispatch-create-template.md` to kimi (after template-param is done)
5. Rate limit resets in ~1h from end of session-68

**Why:** decode_json/from_json bug traced through -C31 unicode flag; all three socket fixes (FD_CLOEXEC, cube_disconnect, 2>/dev/null) are defensive but from_json is the actual root cause.

#,,,,,...,,,.,...,..,,.,,,...,,.,,,..,,,.,,,.,..,,...,...,.,.,.,.,.,.,,..,...,
#7UKNLKVQ4ZU5UANG3GARXWV3XX3OKFHDF3GEZ5ZYMT7W7VT5URAUZMYNCOMTCBJI6Y2WDP7GM6D56
#\\\|B32PR4XPAHVV7AODCUZ57ULWQG6PMGVNK2ZBHY2GLR5A3RTHKP6 \ / AMOS7 \ YOURUM ::
#\[7]YVQ5H7KCIDOLADN2RDILQ4WOF2RRJIUFCI67OBNHECSXU6KEDKCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
