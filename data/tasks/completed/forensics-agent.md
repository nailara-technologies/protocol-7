# forensics agent — task

## status [ 2026-07-29 ] — phase 1 DONE, live-verified (86424b80c, 6b9cac588); phases 2-3 (investigation, rule synthesis, note-audit) not started

## context

design: [[CONCEPT-SECURITY-AND-FORENSICS-ARCHITECTURE]] (data/md/concepts/)
memory: data/ai-mem/claude/topic-context-and-forensics.md
related: [[openvas-agent]], [[nessus-agent]], [[forensic-report-pipeline]]
source: duck.ai design conversation 2026-07-29 (prompt 50)

rich design exists, zero implementation. the nightly event slot has been
reserved for years and currently no-ops:

    cfg/zenki/events/event-setup.base
        enabled    = forensics
        type       = zenka-present
        zenka-name = forensics
        at         = 04:07

(also enabled in cfg/zenki/events/event-setup.letsencr)

KEEP THE ZENKA NAME 'forensics' — the existing slot depends on it.

the forensics agent is the internal-audit layer of the security stack:
deep system inspection, log-pattern analysis, anomaly detection, and the
LLM rule-synthesis loop from the CONCEPT doc (anomaly → LLM analysis →
generated detection rule). it receives enriched findings from the
[[openvas-agent]] (and later the nessus variant), investigates them, and
feeds the [[forensic-report-pipeline]].

## phase 1 — bootable zenka

### task 1.1 — forensics zenka scaffold
```
## dispatch + prompt
create cfg/zenki/forensics/ (start.cfg, access.zenki,
start) so the existing 04:07 event slot fires against a real zenka.
verify: slot fires, zenka present-check passes, no-op but logged.
research first: data/tasks/research-knowledge-base-extraction.md topic 10
covers boot/tracer/quarantine details for this zenka — run that research
extraction before scaffolding if the findings file is still missing.
```

### task 1.2 — forensics.event.nightly-sweep
```
## dispatch + prompt
new module forensics.event.nightly-sweep: the 04:07 entry point.
first version: collect the day's forensics-channel log lines (MISS/BAD
patterns per data/tasks/completed/dep-graph-stdout-self-healing.md),
deduplicate, store as a dated sweep record in the zenka data dir.
no LLM calls in phase 1.
```

## phase 2 — investigation capability

### task 2.1 — forensics.investigate.finding
```
## dispatch + prompt
new module forensics.investigate.finding: accepts an enriched finding
from scan.cmd.report-to-forensics (correlation id preserved), inspects
relevant local state (logs, configs, module versions, recent commits
touching related modules), and produces an investigation record:
confirmed/false-positive/needs-manual-review + evidence references.
```

### task 2.2 — anomaly → rule synthesis loop
```
## dispatch + prompt
implement the LLM rule-synthesis loop from the CONCEPT doc: anomalies
found in sweeps are analyzed by the local coding zenka, which proposes a
detection rule (regex/pattern) that is stored as a candidate in the
ncode pattern store or a forensics rule dir, gated for review before
activation. detection rules must be auditable text on disk.
```

## phase 3 — awareness integration

### task 3.1 — note-namespace integrity audit
```
## dispatch + prompt
implement the cold-read audit from topic-context-and-forensics.md:
forensics zenka reads autonomous-loop notes out-of-band, checks for
prompt injection / drift / namespace integrity violations, reports to
the forensics channel. schedule: weekly event slot.
```

## notes

- escalation path per CONCEPT doc: p7 → channels zenka → multicast.
- P0–P3 wake-on-LAN priorities via nodes zenka are part of the CONCEPT
  doc but OUT OF SCOPE here — separate task when needed.
- all analysis local: local models + pattern store, no external calls
  with operational data (see [[HYBRID-LLM-GOVERNANCE]]).

#,,.,,,.,,,,,,,.,,.,,,,.,,..,,,.,,,..,.,.,,.,,..,,...,..,,...,..,,,..,.,,,,..,
#DO7X7VF2V55VALHHMBT5TCC6OSBI2PIEXT43SSNMBGUB7DT3OTSUVJP4AQWYK3PZ7JD567RCYTM7S
#\\\|MD4O5N5QJEB6QQ7GJMOK5OFQLAURDFHPHMG652XCEC6VT33ZHEY \ / AMOS7 \ YOURUM ::
#\[7]3W6KWPFLNKICDM276PY5SOQCGKWNODWOAHMF3VUCDE42TYE3SSDI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
