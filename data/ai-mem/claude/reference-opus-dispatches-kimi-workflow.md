---
name: reference-opus-dispatches-kimi-workflow
description: "Opus can itself call kimi_dispatch (auto-summary + model=K3) to plan-then-implement, using session_catchup to retrieve the resulting kimi session id and kimi_continue to resume it; subagent support now exists for both claude and kimi"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 2d7f74d1-9a12-4f1d-a522-f128bdffe22d
  modified: 2026-07-19T19:22:30.396Z
---

For tasks that split naturally into "stronger model plans, cheaper/
specialized model implements" (e.g. coding.vision-model round 2's
`:switch:` param — idle-detection hook, timeout semantics), the intended
workflow in this project is:

1. Dispatch an Opus agent to write the plan.
2. That Opus agent itself calls `kimi_dispatch` (MCP tool) with
   auto-summary enabled and the model parameter set to K3, handing K3
   the plan to implement.
3. Opus gets the auto-summary back from the dispatch.
4. Use `session_catchup` to obtain the actual kimi session id (the
   summary alone doesn't carry it).
5. Use `kimi_continue` with that session id to resume/steer the K3
   session further if needed (e.g. after reviewing a diff).

Subagent support now exists for both claude and kimi dispatch paths
[ as of 2026-07-19 ], so this Opus-plans / K3-implements loop can run
with either model spawning sub-agents of its own mid-task.

Related: 2026-07-19 the user granted read access to
`/dev/shm/.7/STDOUT/NIW7OAQ` [ a live zenka stdout stream/socket path ]
specifically to simplify testing and improve early visibility for
agents working this way — worth checking if that access is still
relevant/live in future sessions before assuming it.

See [[project-kimi-k2.7-vs-k3-tier-economics]] for when K3 vs K2.7 is
worth the price difference, and [[topic-kimi-dispatch-infra-hardening]]
for the --afk flag / MCP bridge timeout gotchas that apply to any
kimi_dispatch call regardless of who initiates it.

#,,,.,,,.,.,.,.,,,...,.,,,,..,,.,,,..,..,,,,,,..,,...,...,..,,.,,,.,,,.,.,,,,,
#2CKY4RGYOLP4V2JRJNA2V75T7LF2ZLMDDUIKZYEVDLYSI5FGKG5WSZMVX74DEQMLDL3EAXSZYVNOK
#\\\|QOXBT6SG4GLKENJ222W6RTNFXPSZDYHIR5AGDFMVFNFKS7EYXSV \ / AMOS7 \ YOURUM ::
#\[7]5NCSTXVLFDGKZHPLYUEXNS44YG5Y2JLJL5MJ6X6AJWFSE6O4ZMAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
