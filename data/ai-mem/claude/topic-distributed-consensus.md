---
name: distributed consensus vision
description: roadmap from MCP integration toward multi-model group chat, consensus groups, and distributed P7 nodes
type: project
---

## Near-term direction (as of Mar 20 2026)

MCP server completed → Claude Code has direct tool-call access to P7 network.

**Next milestones:**
- **channels zenka**: backbone for multi-participant chat; not yet implemented
- **chat zenka**: built on channels; `models.chat` exists but rudimentary
- **multi-model consensus groups**: channel + voting handler;
  `llm.service.consensus_vote` already provides aggregation logic
- **distributed nodes**: inter-node P7 routing makes model location transparent;
  two newest remote servers have enough RAM for CPU-only models via ik_llama.cpp

**Why:** self-improving P7 network where multiple models collaborate,
local and remote nodes share workload, and consensus improves output quality.

**How to apply:** when working on models/chat/channels features, design for
multi-participant async patterns from the start; keep routing transparent
so local vs remote is just a node prefix difference.

## Role fluidity and agreement-based coordination (Mar 25 2026)

Delegation is NOT a fixed hierarchy (kimi→coding). Roles are negotiated:
- Any model can be coordinator or executor depending on task context
- Role assignment can shift mid-session based on capability fit
- Agreement-based dispatch: which model leads is itself a consensus decision
- Flawed courses of action are unlikely to pass multi-perspective agreement
- Openness to always-desirable outcomes adds inherent task safety and security

**How to apply:** Phase D delegation modules must NOT hardcode caller/callee roles.
Design `context.delegate.*` with symmetric role negotiation — the "delegator" and
"executor" are parameters, not assumptions. Role swap should be a config change,
not a code change.

#,,..,.,,,.,.,...,,,.,,,,,,,,,,..,..,,,..,,,.,..,,...,...,.,.,...,,,,,..,,,,.,
#2WYOOM3YZ4RJBZXEIFLYEF6IT5GKNHYQVXQ6V6MA5YMEYHMUKDI5ZA7FOU2YWMJKJAMABMQQPOSLA
#\\\|U2IGYK36I4CO2S3LTCNGT7XIVLL2JVIT6575ERVIFEPOC63J3P6 \ / AMOS7 \ YOURUM ::
#\[7]OUVEERII4ZLXXWJ7SOMMNSR2KKMV27KNAWJPKT75YOOKW5XZ2EBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
