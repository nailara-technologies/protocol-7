---
name: kimi-reload-baseline-noise
description: "don't ask kimi to verify pre-existing reload warnings/errors are unrelated to its change — these are stable and regenerable per-command"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f868a396-75dc-4799-8328-ff97ebc7b708
---

`p7c <zenka>.reload` output (perltidy "masks earlier declaration" /
"separate words with commas" warnings, `reinit source` errors from
unrelated undefined subs, etc.) is **stable per command** — it doesn't
change based on an unrelated module's edits. When dispatching an
inline-sub-extraction (or similar narrow refactor) task to kimi, don't
include "verify reload has no NEW errors via git-stash baseline
comparison" as an acceptance criterion — kimi will spend a full
extra round doing `git stash` / `git stash pop` gymnastics to prove a
pre-existing error is pre-existing.

**Why:** session 2026-06-12 — `branch-space-extract-inline-subs` task
asked kimi to confirm `p7c branch.reload`'s `reinit source [ error ]`
wasn't caused by the refactor. kimi did a full stash/restore cycle to
prove it. The error (`undefined routine 'mcp.kimi_dispatch'` in
`branch.session.dag.parallel_dispatch:26`, see [[bug-mcp-kimi-dispatch-
undefined-sub]]) was unrelated and already present — visible just by
running the reload command once before dispatching.

**How to apply:** before dispatching a refactor task, run
`p7c <zenka>.reload` myself once to capture the baseline output. Either
fix/flag unrelated pre-existing errors separately, or tell kimi
explicitly "the following warnings/errors are pre-existing and out of
scope, don't investigate them" with the baseline output pasted in.

#,,,.,,,.,..,,,,,,.,.,..,,,,.,..,,,..,.,.,,,,,..,,...,...,...,..,,.,.,,,,,..,,
#TUFO5RNY4JREEBOX27MRVDT6ZQBVNZWTVG4RPPYFW2KUDUSLSLN6GTNCQAV437W73PYUT6KDO55OK
#\\\|BOYEQTA5IHDJ6BSNI77GNQMO54J276D3YPXUWQ35ZX7RJMUKNDC \ / AMOS7 \ YOURUM ::
#\[7]57VZBOYZTSZMWZ3K5DROSWHOPTQDGNZNPKSVTOGI4SCCGYHBO2DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
