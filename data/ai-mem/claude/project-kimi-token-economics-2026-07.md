---
name: kimi-token-economics-2026-07
description: kimi 5x plan token usage/reset pattern and speed-tier tradeoff (6x speed = 3x usage); site-yaml zenka refactor context
metadata: 
  node_type: memory
  type: project
  originSessionId: ffb857e0-c3c9-47c6-bcaf-15130d5aab0e
---

2026-07-02: taeki hit ~97% of the Kimi 5x-plan token allotment this cycle, driven
partly by running the 6x-speed model tier, which burns tokens at ~3x the normal
rate — had to switch back to regular speed mid-cycle to avoid running out sooner.
Tokens have now reset, so both speed tiers are available again.

**Why this matters going forward**: speed tier should be toggled selectively
(6x only where latency actually matters), not left on by default, given the
usage multiplier. Regular speed is the default; 6x is an intentional spend.

**Kimi work landed despite the crunch**: completely refactored the `site-yaml`
zenka to be generic again (was a driver of the workflow fallout autonomous seen
mid-week, but taeki judged the refactor direction worth the disruption — system
still sent applications/reports throughout). See [[topic-plugin-web-jobs]] for
the sync/pipeline bugs surfaced and fixed the same window (separate from this
refactor, though compounding confusion at the time).

**Established dispatch pattern being reused for future work** (e.g. the planned
coding-zenka inference-abort feature): Opus (cheap input tokens) writes the task
spec, `claude_dispatch` oversees the `kimi_dispatch` to keep parent context lean,
prepares the result for review/sign-off. See [[feedback-claude-dispatch-strategy]]
and [[feedback-kimi-dispatch-pattern]] for the mechanics.

#,,,,,,.,,,,.,..,,,..,,,.,,,.,,,.,,,.,..,,...,..,,...,...,.,.,...,,,,,,,,,..,,
#7SGM72IFXCAUKVSI2DPFNUMKFPRX4XYH7VXZDM6KCMLKSU65TFXDG2J42BLWEZZ73T5NUGOAPLHVQ
#\\\|NUKQE6BQVJUBQT5CKQ7HHWU2O656HUZO2FWSVSRCFXMUPPGYLFD \ / AMOS7 \ YOURUM ::
#\[7]A66ENEXCXHD2T4BBUSUKJS3IC477XOJKMDY6NO64U2XSRAZDMGDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
