---
name: feedback-settings-json-repair-mode-does-not-persist
description: a syntax error in .claude/settings.local.json (e.g. a trailing comma from manual editing) makes the Claude Code shell boot into an in-session repair mode that spends tokens reasoning about the fix but never writes it back to disk -- the file stays broken until manually edited outside that session and Claude Code is restarted
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 83564cfc-ab4a-4884-b8a7-a0efaefe52e2
  modified: 2026-07-26T03:17:55.412Z
---

Observed 2026-07-26. A manually-introduced trailing comma in
`.claude/settings.local.json` (same class of error as the one fixed earlier
this session) caused the Claude Code shell to start in a broken-config state.
Instead of just failing to load MCP servers silently, it entered some kind of
repair mode that invested real reasoning/tokens toward fixing the file — but
that fix was never actually persisted to disk. The file was still broken
after the session ended.

Symptom this produced downstream: `/mcp` no longer listed the `protocol-7`
server even though `.mcp.json` and `enableAllProjectMcpServers` in
`settings.local.json` were both correct in isolation — the actual root cause
was the settings file's own syntax error preventing proper startup, not
anything about the MCP config itself. Spent real investigation time chasing
MCP-specific leads (checked `.mcp.json`, `~/.claude.json` enabled/disabled
lists, ran the server binary directly) before the user reported the actual
cause after fixing it manually.

**How to apply:** if `/mcp` (or any harness-level feature) looks broken with
no obvious cause, and `.claude/settings.local.json` was recently hand-edited,
check that file's JSON validity *first* — `python3 -c "import json;
json.load(open('.claude/settings.local.json'))"` — before investigating the
feature-specific config. Don't trust that an in-session "repair mode" (if one
triggers) actually wrote its fix back to disk; verify the file on disk
independently, and expect a full Claude Code restart to be required after a
manual fix, not just continuing in the same session.

#,,,.,.,.,,,,,.,.,,..,.,.,...,...,,,.,,,.,.,,,..,,...,..,,,,.,...,,..,..,,...,
#PCF2APO2BIWTARQ2S77TZLKDCM3JL3TKDMZDEEPHNWSYTN2S65XCOBJGHYAHRG2ODAYOYLLWON5RQ
#\\\|Z2GFFOCX2EIBPJP2D3TD32MGLS2X222JGZ5F4OYJ5XLE4DXYJNU \ / AMOS7 \ YOURUM ::
#\[7]7GFO7P2LCAK23ACGNSVGNNWWGVEGA2XR2MFBVLQWCR2XU4INE2AA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
