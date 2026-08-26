---
name: bug-mcp-kimi-dispatch-undefined-sub
description: "RESOLVED: branch.session.dag.parallel_dispatch's undefined mcp.kimi_dispatch call stubbed out, branch zenka reload [all] now succeeds"
metadata: 
  node_type: memory
  type: project
  originSessionId: f868a396-75dc-4799-8328-ff97ebc7b708
---

`src/branch.session.dag.parallel_dispatch:26` called
`<[mcp.kimi_dispatch]>->({...})` — but `mcp.kimi_dispatch` is an MCP
tool name (`mcp__protocol-7__kimi_dispatch`), not a `src/*` P7
module. This was the actual cause of the `reinit source [error]` /
"found call to 1 non-existing subroutine" on every `branch` zenka
reload (pre-existing, unrelated to the 2026-06-12 `branch.space.*`
inline-sub extraction — see [[feedback-kimi-reload-baseline-noise]]).

**Root cause:** design-doc mistake in `data/tasks/branch-session-dag.md`
("dispatch to kimi session via `<[mcp.kimi_dispatch]>`") — MCP tools
live in the Claude session, not the P7 module namespace, and can never
be called from zenka code. `parallel_dispatch` had no live callers
anywhere (WIP/aspirational code from the branch-session-dag design, not
yet wired into the task-scheduling loop).

**Fix landed 2026-06-12:** replaced the call with a logged stub
(`<[base.logs]>->(2, 'parallel_dispatch stub: would dispatch ...')`,
returns 0) plus a `[LLL]` comment noting no zenka→kimi cross-zenka
dispatch path exists yet. `p7c branch.reload` now reports `reinit
source [success]`. Verified via `branch.show-buffer compile-errors`
(only pre-existing perltidy/masking warnings remain) and `perl -c`.

**Still open / future work:** if `branch.session.dag.parallel_dispatch`
is ever wired into a real scheduling loop, it needs a real zenka→kimi
RPC path (e.g. route via cube to `kimi.task.enqueue` — `branch`'s
`cfg/zenki/branch/zenka.v7` doesn't load any kimi modules, and
`base.protocol-7.command.send.local` is cube-side session routing, not
a zenka-callable RPC primitive). Not scoped.

#,,,,,,,.,...,...,...,,.,,...,,..,,..,..,,.,,,..,,...,...,.,.,..,,.,,,.,,,,..,
#QU45GMKJ4P6ATKFPTGYCSEM4BJFR7626OQPFU77M3TAILHBG3ADZGMXD3MR6XBQ55IQGT7PST4G7I
#\\\|FLNBQEHUCV6PKFWGTEGZFRBE7V6CDKEVT63KVTRLETUE7WTHNPV \ / AMOS7 \ YOURUM ::
#\[7]PV66PU4HFQHXHA3GX2W5LFX7TPMRLDQ2Z66RIPDRTIPMJKCQ7YBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
