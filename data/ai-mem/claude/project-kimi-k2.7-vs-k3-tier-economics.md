---
name: kimi-k2-7-vs-k3-tier-economics
description: "K3 is a categorically stronger reasoning model than K2.7, pricing reflects it (~3.75x output, >3x input) — dispatch higher-impact tasks to K3"
metadata: 
  node_type: memory
  type: project
  originSessionId: e523a9e4-c458-47e5-b27c-c60766dd51a9
  modified: 2026-07-19T00:57:25.183Z
---

2026-07-19, user's assessment after the coding-zenka scratchpad-rescue task
([[topic-scratchpad-rescue-coding-zenka-task]]) landed cleanly: K3 no longer shows the "stream of
self-corrections that is just determined enough" pattern visible when reading K2.7-or-below thinking
traces directly — K2.7 gets to a working result mostly by brute-force iterate-until-convergence; K3
reasons cleanly with only minor course-corrections. This is a categorical difference, not a matter of
better-steered prompting (see the correction in [[topic-dynamic-context-prep-vs-model-size]] — human
hints given during that task were minor, not the main driver of quality).

**Pricing reflects the tier jump**: K2.7 = $4/1M output tokens; K3 = $15/1M output tokens (~3.75x).
Input tokens: K3 is also >3x K2.7's input price. Session usage on this task: 30% session budget, 47%
weekly, 92h remaining in the cycle — real cost, but user judged it a fair trade for this quality level.

**Confirmed via primary source** (buildfastwithai.com/blogs/kimi-k3-review, fetched 2026-07-19, K3
released 2026-07-16): input $3.00/1M, output $15.00/1M, cached input $0.30/1M — "5x above its own K2
family" in cost, pricing described as matching Claude Sonnet's tier. Specs: 2.8T-param MoE, 1M-token
context, text+image+video input, reasoning always-on (tunable effort locked to max at launch — matches
[[topic-kimi-k3-thinking-effort]]'s finding that lower effort isn't wired up yet). Benchmarks: GPQA
Diamond 93.5% (best open-weight published), Terminal-Bench 2.1 88.3% (near GPT-5.6 Sol's 88.8%),
BrowseComp 91.2% (web-agent record), AA Long-horizon Elo 1547 (second only to Claude Fable 5). Explicitly
weaker than K2.7 on high-volume routine coding due to the cost multiplier — matches the K2.7-for-token-
efficiency split below. Open weights promised by 2026-07-27.

**How to apply** (user's stated split, 2026-07-19): K3 is now the tier for tasks that would otherwise
have needed Sonnet or even Opus — "a cheaper Opus-light with its own neutral character," but billed on
the Kimi budget rather than the Anthropic one. Reach for it on higher-impact / correctness-critical work
(permission models, concurrency, protocol design — things where a wrong-but-plausible result is
expensive to catch later). K2.7 stays the right choice for regular or longer tasks where token
efficiency is itself a factor — i.e. don't default everything to K3 just because it's better; use it
where the quality jump is actually worth ~3.75x output / >3x input cost. See
[[topic-kimi-k3-thinking-effort]] for the model-routing param location (`k3|k2.7|k2.7-fast`,
`bin/mcp-server-p7` ~line 3048) and [[project-kimi-token-economics-2026-07]] for the separate
speed-tier (6x) vs regular-speed usage-multiplier finding — a different axis from the k2.7-vs-k3 choice.

#,,..,,,,,,,,,,,,,,..,.,.,,.,,,,,,,..,...,...,..,,...,...,...,,,.,,.,,,,.,,..,
#DR5OVIUP55QIHMKEN4FO5VBZ2PJ7FXAE4HHD3SD3UCTPGKKVCET7HFE2T2OWFBBIIXBX3V4C2H3UU
#\\\|NMRVD3XPVIAU7VQANHQST7DTN3QES75XFR2VPMBINSTJNV6L5VD \ / AMOS7 \ YOURUM ::
#\[7]ZOFGQUR2EAX6XCV6D3MVKAVONSU53RVODJBUY6NZZCN66DHN2MCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
