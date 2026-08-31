---
name: jobsite-assessment-accuracy
description: "single-inference job assessment drops/inverts soft profile constraints (e.g. optional Stuttgart preference, wrong tenure years); planned fix is multi-inference consensus, not prompt tweaking"
metadata: 
  node_type: memory
  type: project
  originSessionId: ffb857e0-c3c9-47c6-bcaf-15130d5aab0e
---

## 2026-08-31: different failure mode — content-free hallucination, gate added

Distinct from the soft-fact-dropping issue below: this is the pipeline sending a
job to assessment with an **empty description** (root cause: `clients.https`'s
http/1.1 fallback path never decoded/decompressed response bodies — only the h2
path got fixed the day before, see [[topic-clients-http]]). With no real job
content, the model's only rich material was the candidate profile block still in
the prompt, so it produced a full, confident, plausible-looking assessment that
was really just the profile reflected back as an "ideal" job — live-observed:
score 9/10, described the candidate's own unpaid research project as the
posting's "Besonderheit", never mentioned pay.

Fix: `jobsite.util.description_ok` gates every job before `build_prompt` ever
runs — checks minimum length (120 chars), a replacement-char (U+FFFD) cluster
cap, and a non-printable-byte ratio cap. First failure triggers one refetch;
still-bad on the second pass routes to `status: review` + `desc_check_failed`
flag (surfaced in the UI's own "fehler" badge/tab) instead of ever reaching the
LLM. See [[topic-plugin-web-jobs]] for the two desync gotchas hit implementing
this (dual job-store staleness, stage-derived-from-status overriding an
intentionally-blank stage).

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

**Related, separate dependency (2026-07-02)**: when a job gets deleted while its
assessment task is already in flight, jobsite currently lets the LLM call run to
completion and discards the result on arrival (`jobsite.handler.assess-done` no-ops
if `<jobsite.tasks>->{$job_id}` is gone — safe, but wastes the inference call).
Taeki confirmed actually *aborting* that in-flight call requires the coding zenka
to gain efficient abort-inference capability first — this is blocked on
[[coding-zenka-improvement-pipeline]], not a jobsite-side fix. Don't attempt a
jobsite-side cancellation hack before that infra exists.

#,,,,,,,.,,..,.,,,,..,...,..,,,,.,,,,,,.,,,,.,..,,...,...,.,.,,,.,.,,,..,,,.,,
#KGXQFYXMZ7DSZWBXSIG3MPW7NRQOFPRKLF3RXPMXRRHM3NV6XVTGKOQB5GG2LPT5CXX6JSI7GKQPG
#\\\|T64UIV62IZXLJAJX2YTQXOLVPWSP7H2MBFGXAFYZTPWZD4VKXRR \ / AMOS7 \ YOURUM ::
#\[7]CK2NEDI6FTLBIH5LHEMA2F3OE3CRWH6GCZSV3TEJFWSIMAEL7ACY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
