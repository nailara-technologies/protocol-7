---
name: jobsite-assessment-accuracy
description: "single-inference job assessment drops/inverts soft profile constraints (e.g. optional Stuttgart preference, wrong tenure years); planned fix is multi-inference consensus, not prompt tweaking"
metadata: 
  node_type: memory
  type: project
  originSessionId: ffb857e0-c3c9-47c6-bcaf-15130d5aab0e
---

Observed 2026-07-02: the jobsite assessment pipeline (single LLM inference pass per
job, see [[topic-plugin-web-jobs]]) sometimes gets soft/detail-dense profile facts
wrong — inverted or dropped an optional "prefers Stuttgart due to family" preference,
and separately misstated tenure at a company (said 10 years, was actually 5 years
over 10 years ago). Not a sync/storage bug — this is assessor-content accuracy,
orthogonal to the sync pipeline bugs fixed the same session.

**Planned direction (taeki's framing, not yet scoped)**: multi-inference consensus
summaries — run assessment through multiple passes/models and reconcile — rather
than trying to prompt-engineer a single pass into never dropping details. Treated
explicitly as a "drop-in upgrade later," not urgent.

**Reuse candidate**: this codebase already has `llm.service.consensus_vote`
(multi-model voting / response aggregation) per the coding-zenka infra — likely the
right mechanism to route job assessments through when this gets built, rather than
inventing a separate consensus path. See [[topic-distributed-consensus]] for the
broader consensus-mechanism context in this project.

#,,.,,,,,,.,,,,.,,..,,.,,,..,,..,,...,,,,,,..,..,,...,...,,..,,,.,...,...,.,.,
#JJZD6HGXMEZAHYBJB4W5UUMZWMBMERQMP52QPTROPOPBYKDSYTRM7MH2UQ66H4DWJFKTJX6LCZZBE
#\\\|XVARNSVSF3ALOYSZX2WNVYLI6YCQ3QBBXKCIVBJLCBPBIS6YXQC \ / AMOS7 \ YOURUM ::
#\[7]F6U4IXIF2JHYLCRBT5V2OBXBSNGPIBE5BL4XUE7WZYCZHLA63KAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
