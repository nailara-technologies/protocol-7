---
name: distributed consensus vision
description: roadmap from MCP integration toward multi-model group chat, consensus groups, and distributed P7 nodes
type: project
originSessionId: 5557aaa4-3476-4c66-9002-955c73ae92a1
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

## Consensus template: independent-then-cooperative forensics report

A widely reusable consensus pattern for tasks where cross-contamination of
findings would reduce value:

1. **independent phase** — each model investigates the same artifact/notes/log
   in isolation, no visibility into other models' findings; each contributes
   its section to a shared forensics report structure
2. **synthesis phase** — models read each other's sections and cooperate on
   the joint report: fill gaps, flag disagreements, escalate items that
   multiple models flagged independently (stronger signal)

**Why independent first:** models with different training priors catch
different things; one model reading another's findings first would anchor
on them and suppress independent observations. critically: perspective
uniqueness comes not only from different model weights but also from
different startup contexts — two instances of the same model initialised
with different context templates (e.g. security-focus vs. style-focus vs.
debugging-focus) produce genuinely independent viewpoints. the context
zenka + dynamic template system is the mechanism that creates this
diversity without requiring different models for every participant.

**Implicit iterations:** after synthesis, the joint report becomes new
context that can seed another independent phase — each iteration narrows
uncertainty while preserving independence within the round. this creates
a natural convergence loop without a fixed coordinator.

**Applies broadly** — same pattern wherever multi-perspective independence
adds value before synthesis:
- forensics/security: note namespace audits, log analysis, incident review
- code review: each participant gets different context emphasis (security,
  style, performance, correctness) → independent findings → joint report
- debugging: each model starts from a different hypothesis template
- style checks: style model + logic model + consistency model in parallel
- any task where "what does each notice alone?" matters before combining

**Channels zenka** is the natural backbone — each model gets the same input
on its own channel, writes findings back, then a coordinator merges into
the report. `llm.service.consensus_vote` already provides aggregation logic
that can be extended for structured report merging rather than just voting.
context.* modules assemble the per-participant startup context dynamically.

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

#,,,,,,,.,,.,,.,.,,,.,...,.,,,.,.,,.,,.,.,,,.,..,,...,...,.,,,,,.,,..,..,,.,,,
#QLVGSJLL3G3UZEROTBZBOYJ2NDZJGVJIASK47VC3DGSB7S2T5AQ6NYUMGGWSVBP64FYGHA4JULKXQ
#\\\|7BFSCIMK2YHLRAM7TGF566MRUECB732JRAZK3P53MYOBEWUQVV4 \ / AMOS7 \ YOURUM ::
#\[7]FUEW5QOUTCH2LPUSU5LO5LFNRB5XOXY5C5UG7RTBVWGRQUDY44BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
