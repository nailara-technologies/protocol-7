---
name: feedback-git-log-all-false-duplication
description: "AI agents investigating git history sometimes misreport 'commit duplication' — root cause confirmed: personal core.pager strips diff +/- symbols, relies on color alone, colors get lost before the agent reads it"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3c264315-73af-4677-a8b4-23ce085cb5a8
---

Seen at least twice (most recently 2026-07-17, from a kimi re-verification
pass) — a dispatched agent investigating git history claims something
like "commit entries appear twice under `--all`, filter-repo artifact."
Checked directly: **not a repo problem**. `git log --all --format="%H" |
sort | uniq -d` finds zero duplicate hashes, and `--all` legitimately
shows ~2x the commit count of one branch because this repo has ~140 refs
(many old backup/working branches with overlapping-but-distinct history)
— that's expected, not corruption.

**Actual root cause, confirmed via `~/.gitconfig`:** `core.pager =
diff-modified | less --tabs=4 -RFX --mouse --wheel-lines=4`
(`bin/dev/diff-modified`, a modified `diff-so-fancy`) is the personal git
pager. It defaults `stripLeadingSymbols` to `true` — meaning it removes
the `+`/`-` prefix from diff lines and relies purely on ANSI color to
distinguish added vs. removed content. Any `git log -p` / `git diff` run
through this pager, then captured through a channel that loses ANSI
color codes (very common when an agent's terminal-output capture
normalizes/strips escape sequences before the text reaches the LLM),
produces exactly this: a changed line's old and new content printed
back-to-back, uncolored, with no `+`/`-` marker at all — which reads as
literal duplication to anything parsing plain text. This is fully
reproducible given the pager config, not a one-off misread — explains
why the same claim has come up more than once.

**How to apply:** if an agent (yours or dispatched) reports git history
"duplication" in this repo, this pager/color-loss interaction is the
first thing to suspect, not repo corruption. Check
`git log --all --format="%H" | sort | uniq -d` to rule out real
duplicate commits (always comes back empty), and if the agent was
reading paged/piped diff output, assume color was stripped along the way
before trusting any "duplicate line" observation from that output.

#,,.,,,,.,.,,,,,.,,,.,,.,,,,,,.,,,.,,,,,,,,,.,..,,...,...,..,,...,,.,,,..,...,
#3S7ZWIDE6JQXXMQPXDZ6UZD3JDD4FAAQLWAQGPPJIL7VOFT4RGS7MCVNF6GE3TJLMQCE5STXEW3NS
#\\\|G366AKUFZJROED7OCC2KXEJFKLE4TSC2YHEDJKJUM46YVVETBV5 \ / AMOS7 \ YOURUM ::
#\[7]4LBARAS2TTFIQ3X3AYSMPJXQLVJFMECEWMW6Z5UQGENGV5YKS4BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
