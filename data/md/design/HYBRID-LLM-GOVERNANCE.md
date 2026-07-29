# HYBRID-LLM-GOVERNANCE — layered isolation between local and external models

## status

design — extracted from duck.ai design conversation 2026-07-29
(INCOMING/duck.ai_2026-07-29_01-27-33.txt, prompts 52–56).
no existing file covers this: local-model infrastructure exists
(llm.service.*, coding.async.*, 67 checksum-addressed models), but
"external" there means local backends (lmstudio/ollama on 127.0.0.1),
not frontier/cloud APIs. the governance layer between those two worlds
does not exist.

philosophical grounding: [[TRANSLUCENT-LAYERING-SECURITY-MINDSET]] —
translucent layers, not walls. this document is the mechanism for that
mindset applied to model traffic.

## the problem

external models (frontier APIs) are powerful but structurally hostile
to security work:

- sensitive data leaves the network (firmware, client infra, findings)
- refusal walls on legitimate security reasoning
- vendor can change policy, log, or be compelled — overnight
- "the AI said so" is not an acceptable answer to "why did you
  quarantine this production segment?"

local models are safe but weaker. the naive hybrid (ad-hoc scripts
stitching API calls) has no auditability. this design is the proper
hybrid: governance as architecture.

## the layered isolation model

```
layer 1 — local security reasoning (airgapped semantics)
    forensic agents, vulnerability analysis, threat modeling.
    local specialized models only. these agents never emit exploit
    paths, target identifiers, or operational detail upward.

layer 2 — generalization boundary
    findings are transformed into abstract patterns:
      "device firmware lacks signature verification"
      "network segment allows unauthenticated service discovery"
    no specifics. this is the ONLY form that crosses upward.
    (mechanism: forensic-report-pipeline task 1.2)

layer 3 — external enrichment (optional, gated)
    generalized patterns + TEMPLATES (report structure, phrasing,
    compliance mapping) may go to external models:
      "how can this template be clearer / more compliant?"
    external models touch templates, never data.

layer 4 — generic functions (unrestricted)
    report polish, scheduling, documentation formatting, metrics —
    no security semantics; external models excel here freely.

layer 5 — bi-directional learning (gated)
    anonymized aggregate findings may flow out for research synthesis;
    published research flows back in as local training corpus.
    local system ingests, validates, and integrates — on its own terms.
```

## the core invariant

**the system remains fully operational offline.** external models are
optional enrichment, never infrastructure. if they go down, refuse, or
disappear: forensics still runs, reports still generate, templates are
slightly stale but functional. dependency on anything external is a
regression against this invariant and must be caught in review.

## why protocol-7 specifically

the governance layer is not bolted on — the existing architecture IS
the governance:

| mechanism | governance property |
|---|---|
| agent orbital field | every decision made by an agent in a bounded scope — models cannot wander off |
| work ring / shared memory | every action logged, visible, traceable to its spawning decision |
| harmonic routing | task distribution is verifiable math, not mystery assignment |
| nightly event timetables | execution bounded in time; no drift, no infinite loops |
| checksum-addressed models | model identity/version pinned; swap is an auditable event |

AI acceleration with a skeleton that keeps it honest: the network
governs the models, not the other way around.

## template refinement waves

external models participate in template EVOLUTION, not data processing:

1. local agents update templates (anonymized findings, report shapes,
   reasoning templates) through normal operation
2. a template marked ready may be sent outward for refinement
3. suggestions return as diff proposals against the template file
4. local review gates application (checksum-addressed change, revertible)
5. improved templates make the NEXT cycle's findings clearer
6. improvements propagate non-linearly across categories in waves —
   report clarity improves pattern recognition improves threat models
   improves hardening suggestions

not a pipeline — a resonance chamber. the system learns in loops, and
the loops are auditable at every step because templates are versioned
text on disk.

## open questions

- which external backends get a sanitized-request adapter first
  (duck.ai? anthropic API? openrouter?) — needs a `sanitize.request`
  module that enforces the layer-2 boundary mechanically, not by
  prompt discipline
- template submission gating: manual review per wave vs streak-based
  auto-apply (cf. ncode pattern graduation)
- versioning scheme for template waves (generation counters in the
  template headers?)

#,,.,,,,.,..,,.,,,..,,..,,,,,,,,.,..,,..,,.,,,..,,...,...,..,,.,.,,..,,.,,,,,,
#NDNIGANDBRFRWMN3AHEW3F7OWD6KYLJDAXPOZEKAXDRKV4HFZCRTFXR5CIPEERFJFDHKWHY2ZR5LW
#\\\|UQTHDDYTRO2LUKP4RNPDB5YHKIVXWDS5TSJT5GYYH2N2YOFZWH2 \ / AMOS7 \ YOURUM ::
#\[7]52UW4XL564GQEJTUZN2TY7FFZEHWBYQ24N4W2RQHNVH4IQYX7KBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
