# forensic report pipeline — task

## status [ 2026-07-31 ] — phase 1 DONE, live-verified (`378f269ac`); phase 2
(self-improvement task-tree wiring, ncode pattern-candidate extraction) and
phase 3 (external template-refinement gate) not started

## context

related: [[nessus-agent]], [[forensics-agent]], [[HYBRID-LLM-GOVERNANCE]]
task-tree hook: data/yaml/task-tree/branches.yaml → branch `self-improvement`
source: duck.ai design conversation 2026-07-29 (prompt 50)

the combined forensic report generation pipeline: joins scanner findings
(openvas first, nessus later) with forensics investigation results (by
correlation id), produces generalized reports, and feeds the reasoning
branches of the self-improvement pipeline. nothing connects report generation into the
reasoning-branch loop yet — this is that connection.

key principle (from the conversation): reports are GENERALIZED. the
pipeline emits abstract patterns and recommendations, never operational
detail — which is what makes the output safe to route through external
models later (template refinement), and safe to feed back into public
reasoning corpora. agents that write reports never need to have seen or
mentioned an exploit.

## phase 1 — report assembly

### task 1.1 — forensics.report.assemble
```
## dispatch + prompt
new module forensics.report.assemble: joins nessus findings and
forensics investigation records by correlation id for a given period,
produces a structured report record (yaml): per finding — abstract
pattern description, risk category (not exploit path), verification
status, proposed control. store under the forensics zenka data dir
as reports/YYYY-MM-DD.yaml.
```

### task 1.2 — generalization pass
```
## dispatch + prompt
new module forensics.report.generalize: transforms a report record into
its public-safe form: strips target identifiers, operational detail,
exploit specifics; keeps pattern classes ("device firmware lacks
signature verification"), risk categories, control recommendations,
and standards mappings (IEC 62443 SL levels where applicable).
two outputs: internal (full) stays local; external (generalized) may
leave the network.
```

## phase 2 — self-improvement integration

### task 2.1 — feed reasoning branches
```
## dispatch + prompt
wire the generalized report into the self-improvement task-tree branch:
each report creates/updates task entries under the self-improvement
branch (data/yaml/task-tree/branches.yaml), one per distinct pattern
class, deduplicated against open entries. recurring patterns increment
a counter instead of duplicating tasks — frequency is priority signal.
```

### task 2.2 — pattern-candidate extraction
```
## dispatch + prompt
for findings whose root cause is a code-level pattern (style, missing
check, known-bug shape), emit ncode pattern candidates into the
<ncode.patterns> review queue (tier B, llm-required status) instead of
plain tasks — the fix then flows through the existing pattern-learning
loop (see data/ai-mem/claude/topic-ncode-pattern-learning-loop.md).
```

## phase 3 — template refinement (external models)

### task 3.1 — report-template refinement gate
```
## dispatch + prompt
implement the gated template-refinement step from
[[HYBRID-LLM-GOVERNANCE]]: generalized report TEMPLATES (structure,
phrasing, compliance mapping — never findings) may be sent to external
models with the question "how can this be clearer / more compliant?".
suggestions return as diff proposals against the template file, applied
only after local review. core pipeline remains fully offline-operational;
external refinement is optional enrichment per wave.
```

## notes

- ordering matters: openvas-agent and forensics-agent phases 1–2 first;
  this pipeline has no inputs without them.
- the nightly 04:07 forensics slot is the natural trigger for assemble
  + generalize (nightly sweep → report).
- reports are also training corpus for the security FastText domains —
  see [[security-intel-embedding-domains]].

#,,,,,,.,,.,.,.,.,,,,,,,,,...,..,,...,...,,..,..,,...,...,.,,,.,.,,..,,,,,..,,
#S6ATYNNHDGTRFEZIODSKRXP5T24QX2BNHOWL4WI3USXJUGSEJQ54SILUKQQG54ZIUN7HSIT4KFWTK
#\\\|NRYJJVXFOIVGFKBDTCABWTADWLUS5QH2BJ7W2G6HKCWEG7BIOCZ \ / AMOS7 \ YOURUM ::
#\[7]QLWMSPLA5TJBHRORXFUVHH5S4PGO7OTRPKGIMTQTPWISCZ7SPWBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
