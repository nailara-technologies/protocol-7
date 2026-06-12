---
name: bug-mcp-kimi-dispatch-undefined-sub
description: "branch.session.dag.parallel_dispatch calls undefined module mcp.kimi_dispatch, fails branch zenka reload [all]"
metadata: 
  node_type: memory
  type: project
  originSessionId: f868a396-75dc-4799-8328-ff97ebc7b708
---

`modules/branch.session.dag.parallel_dispatch:26` calls
`<[mcp.kimi_dispatch]>->({...})` — but `mcp.kimi_dispatch` is an MCP
tool name (`mcp__protocol-7__kimi_dispatch`), not a `modules/*` P7
module. `base.list.subroutines` has no `mcp.kimi_dispatch` entry, so
`p7c branch.reload` fails post-init with "found call to 1 non-existing
subroutine ... reloading [all] was not successful".

**Why it matters:** this is the actual cause of the `reinit source
[error]` seen on every `branch` zenka reload (pre-existing, confirmed
unrelated to the 2026-06-12 `branch.space.*` inline-sub extraction —
see [[feedback-kimi-reload-baseline-noise]]).

**How to apply:** needs a real fix — either implement an
`mcp.kimi_dispatch`-equivalent P7 module/route (e.g. a
`branch.session.dispatch_via_mcp` wrapper that shells out / routes to
the kimi dispatch mechanism used elsewhere), or replace the call with
whatever P7-native dispatch mechanism `branch.session.dag.*` is
supposed to use. Not yet scoped or fixed as of 2026-06-12.

#,,.,,,,.,.,,,,.,,,,.,..,,..,,,.,,,,.,,.,,.,,,..,,...,..,,.,,,,,.,,.,,,,,,.,,,
#IJJBSRNZPQTKNC5IOWQ6HEJLJDCDREB3C5VTGTIMWZUMJ7BIYGFBNU2WSRRLHL46AOEOE3Y5HP54I
#\\\|3Y2ZWM5WERQGULY4MSUNXWQVLIPI5CT6OTW5TZS7BVMVNTT6PJZ \ / AMOS7 \ YOURUM ::
#\[7]6ORDKSBPHZSWJBLGTM5GVUI7ENH6KXZEYV53SWTAUA6OSOANQQCY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
