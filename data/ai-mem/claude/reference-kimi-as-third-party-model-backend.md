---
name: reference-kimi-as-third-party-model-backend
description: Kimi K3/K2.7 can run as the model backend inside Claude Code itself (via ANTHROPIC_BASE_URL override) or inside opencode — separate integration path from the existing kimi_dispatch/kimi_continue MCP bridge
metadata:
  type: reference
---

**2026-08-04, user-provided docs, not yet tried.** Kimi publishes docs for
running its own K3/K2.7 models as the backing model for third-party agent
CLIs, distinct from this repo's current `bin/mcp-server-p7`
`kimi_dispatch`/`kimi_continue` MCP-bridge approach
([[feedback-kimi-dispatch-pattern]]).

- **Inside Claude Code**: https://www.kimi.com/code/docs/en/third-party-tools/claude-code
  — set `ANTHROPIC_BASE_URL=https://api.kimi.com/coding/`,
  `ANTHROPIC_API_KEY=<kimi key>`, `ANTHROPIC_MODEL=k3-256k` or `k3[1m]`,
  `CLAUDE_CODE_EFFORT_LEVEL=high`, plus `CLAUDE_CODE_AUTO_COMPACT_WINDOW`/
  `CLAUDE_CODE_MAX_CONTEXT_TOKENS` for the larger context. Requires an
  active Kimi Code-plan API key (separate from Anthropic's). Note:
  disabling "thinking" silently downgrades both K3 and K2.7 Code to K2.6 —
  keep thinking enabled. `k3-256k` has no video input. Verify via `/status`.
- **Inside opencode**: https://www.kimi.com/code/docs/en/third-party-tools/opencode.html
  — `opencode auth login` → select "Kimi For Coding" → paste API key from
  the Kimi Code Console. Model/context picked via `/models` and
  `/variants` (thinking-effort: Default/low/high/max) at runtime; no env
  vars or base-url config needed, unlike the Claude Code path. Requesting
  a model/context beyond your plan tier just errors.

**How to apply**: relevant to [[topic-next-steps]]'s queued opencode trial
— when that trial happens, it can be run either on opencode's own default
model or specifically on Kimi K3 as the backend, which would let the same
opencode evaluation also serve as a natural-habitat comparison of K3's
tool-calling behavior outside the existing MCP-bridge dispatch pattern.
Not yet tried either integration path as of this note.

#,,.,,,,,,..,,,,,,.,,,,,.,.,.,,,.,,.,,...,,,.,.,.,...,...,,..,..,,.,,,,.,,,,.,
#SYWXFDNUTMOGKXFTWY2MG3VO4JSY7EZWPOMEYRIJJEJYXGJYIWXTDUI2LEJTOAQYDNKBNIOYPPKCI
#\\\|3HGHJTIDBIE5UB26RY3CZLCS4DH5MGGBODGCPAYX23XOFS2Q6JX \ / AMOS7 \ YOURUM ::
#\[7]WVTC53LKLX5NNVMBNDDB5N3QMAUZG4LCIZTEJDXWM6KEWRZODCBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
