# nessus agent — task

## status [ 2026-07-29 ] — phase 1 DONE, live-verified (a47ac3659) up to a hard license boundary: trial has scan_api:false, REST scan creation is blocked entirely (UI-only), not a code defect; phase 2 (enrichment, shared schema with openvas) not started and moot on this license

## context

source: duck.ai design conversation 2026-07-29 (INCOMING/duck.ai_2026-07-29_01-27-33.txt, prompt 50+)
related: [[openvas-agent]], [[forensics-agent]], [[forensic-report-pipeline]], [[security-intel-embedding-domains]]
reasoning: [[anti-entropic-threshold]]

VARIANT task — do this AFTER [[openvas-agent]], not in parallel.

nessus is proprietary. protocol-7's scanning pipeline is built first on
openvas (open backend, free NVT feed, public-domain compatible). this
zenka is the optional variant for environments that already hold a
nessus license — e.g. an employer's professional engagement where
nessus is the house standard and its plugin output must be consumed
directly.

ordering rationale:

1. the orchestration + enrichment + handoff pipeline is built once in
   [[openvas-agent]] — this task only adds a second backend
2. building nessus first would make the core stack depend on a
   proprietary tool nobody else can reproduce
3. the transcript's "nessus agent" phrasing named the capability, not
   the backend brand

## goals

1. nessus scan orchestration as a zenka, backend-compatible with the
   pipeline contract established by openvas.scan.run
2. same enrichment, same forensics handoff, same report-pipeline
   contract — findings must be indistinguishable in shape from openvas
   findings downstream

## phase 1 — zenka + backend

### task 1.1 — create nessus zenka
```
## dispatch + prompt
create cfg/zenki/nessus/ (zenka-startup.v7, access.zenki,
start) mirroring the openvas zenka scaffold (see openvas-agent task
1.1 for the access.zenki source pattern — letsencr has none).
bootable, stoppable, registered. no modules yet.
```

### task 1.2 — nessus.scan.run
```
## dispatch + prompt
new module nessus.scan.run: wraps the nessus CLI/API available on the
host; args target, ports, profile; emits the SAME yaml findings shape
as openvas.scan.run (plugin-id, severity, name, target) so downstream
modules need no backend branch. if a shared scan-result schema does not
exist yet, extract it from the openvas implementation into a shared
module first (scan.result.schema) rather than copy-pasting.
```

## phase 2 — pipeline reuse

### task 2.1 — shared enrichment + handoff
```
## dispatch + prompt
the enrichment and forensics-handoff logic from openvas-agent phase 2
must be generalized: move openvas.enrich.finding /
openvas.cmd.report-to-forensics to backend-neutral modules
(scan.enrich.finding, scan.cmd.report-to-forensics) used by both
zenki, keyed off the scan.result.schema. nessus-specific context
(nessus plugin ids vs nvt oids) is handled by the embedding domains —
see note below.
```

## notes

- plugin id namespaces differ (nessus plugin-10662 vs nvt oid): the
  security-intel domains keep them as SEPARATE domains
  (data/protocols/nessus/ vs data/protocols/nvt/) so embeddings stay clean;
  cross-domain nearest-neighbor queries bridge them semantically.
- never install nessus on infrastructure without a license for that
  context — the openvas path is the always-legal default.
- same rule as openvas: no scanning without a live consumer; manual
  invocation until the forensics agent exists.

#,,,.,...,,.,,.,,,.,.,,.,,...,,,,,,,.,,,.,...,..,,...,...,,.,,,.,,..,,,.,,.,.,
#KHINQNSVUI5RNPKGJRPZFK7O5GTWZFDVGPTBDYSFYT47UPKKNAF5S4CWKSYDUUXPRPV5ZR5POBORS
#\\\|IVV67VO3AVM7QQLLNUVVBGAPRPGIUXQQ5TQTUVGILYQTDA4JFQU \ / AMOS7 \ YOURUM ::
#\[7]FAPH53E762COWXEAMDYTCB35H4JPCPOPNUB2XR7VPOXTB34AV2BA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
