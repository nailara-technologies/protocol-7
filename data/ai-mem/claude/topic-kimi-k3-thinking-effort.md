---
name: topic-kimi-k3-thinking-effort
description: "K3 thinking-effort Low/High/Max — vendor UI ahead of API docs and ahead of installed kimi-cli; nothing to wire yet"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3c264315-73af-4677-a8b4-23ce085cb5a8
---

**2026-07-17, not yet actionable.** User saw a live `kimi-legacy` model-select
TUI with a `Thinking (←→ to switch)  Low  High  [Max]` picker for K3
(Alt+S = session-only save). Investigated whether this can be set
non-interactively for `kimi_dispatch`/`kimi_continue` in `bin/mcp-server-p7`.

**Findings:**
- Moonshot's own K3 API docs (`platform.kimi.ai/docs/guide/kimi-k3-quickstart`)
  say `reasoning_effort` (top-level request field) "currently supports only
  the `max` level (default); more levels are coming soon" — so even if a
  lower effort were requested, the API would presently ignore it.
- The installed `kimi-legacy` (kimi-cli v1.49.0, via
  `~/.local/share/uv/tools/kimi-cli`) has no CLI flag or `config.toml` key
  for effort level — only the boolean `--thinking`/`--no-thinking` (the
  K2.x-style toggle the vendor docs say not to use for K3). Grepped the
  actual installed Python source, not just `--help`: `kosong.chat_provider`
  defines the `ThinkingEffort` literal type (`off|low|medium|high|xhigh|max`)
  and a `.with_thinking(effort)` method, but `kimi_cli/llm.py` only ever
  calls it with `"high"` or `"off"` — no code path plumbs a caller-supplied
  level through yet. No `"Low"` string anywhere in the installed package,
  confirming the picker UI the user saw is from a **newer** kimi-cli release
  than what's installed locally.
- Conclusion (user-confirmed): vendor's UI is ahead of its own API docs.
  User also confirmed `kimi-legacy` was updated the day before this check
  (v1.49.0, `kimi`/`kimi-legacy` are the same symlink target) — so this
  isn't a stale-install artifact. Exhaustive grep across `ui/`, `llm.py`,
  and `kosong.chat_provider` still finds no code path that plumbs a
  caller-selected effort level through anywhere in this package; wherever
  the Low/High/Max picker widget itself renders from, it isn't connected
  to anything controllable non-interactively in this install.

**How to apply:** don't build a `thinking` param into `kimi_dispatch` yet —
there's nothing for it to control. Revisit when `kimi-legacy --version`
shows a release past 1.49.0 with the level picker; check its CHANGELOG.md
for a `reasoning_effort`/`thinking` entry, then grep
`kimi_cli/llm.py:with_thinking(...)` calls for a plumbed-through level
before assuming it's usable — mirror the existing `k3|k2.7|k2.7-fast`
model-routing param pattern in `bin/mcp-server-p7` (~line 3048) once real.

## related

[[topic-kimi-dispatch-infra-hardening]]

#,,,.,.,.,,,.,.,,,,,,,...,..,,..,,...,,..,..,,..,,...,...,...,,.,,.,,,.,.,..,,
#JVIHUILNLKGYGDPGOHTR5FREGWB3GEQ3ZSRGJLOS2E76VVECZW4N5H472XYOUICZ6TMYZY5PHWG3Y
#\\\|BMOGQO6MM2TRRJRRKXOIG42FO6S3FP2NUN7VJFNXYW4J2E4HWEC \ / AMOS7 \ YOURUM ::
#\[7]BAQ4XHFOJN47S6CPGF3TLX3PNLVVASNF2WBPXP2DM2B3LNFCPWBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
