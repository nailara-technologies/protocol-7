# openvas agent — task

## status [ 2026-07-29 ] — phase 1 DONE, live-verified (7539ab70a, fixes 24e84da2d + 2f11bc91c); phase 2 (finding enrichment) blocked on security-intel-embedding-domains's nvt domain; phase 3 (integration) not started

## context

source: duck.ai design conversation 2026-07-29 (INCOMING/duck.ai_2026-07-29_01-27-33.txt, prompt 50+)
related: [[nessus-agent]], [[forensics-agent]], [[forensic-report-pipeline]], [[security-intel-embedding-domains]]
reasoning: [[anti-entropic-threshold]]

PRIMARY vulnerability-scanning agent — built FIRST, before any nessus
variant. reasons:

- openvas (greenbone) is open source — matches protocol-7's public-domain
  nature; the whole pipeline stays reproducible by anyone, no license
  friction, no vendor dependency (which would be ironic for a security
  stack built on vendor-independence principles)
- free NVT community feed doubles as the plugin knowledge base for
  [[security-intel-embedding-domains]] — scanner and intelligence
  domain come from the same source
- nessus becomes an optional later variant ([[nessus-agent]]) that plugs
  into the pipeline this task builds, for environments that already
  hold a license

no prior art exists anywhere in the repo — this is the first task file
for vulnerability-scanning capability. the agent is the external
reconnaissance layer: it runs scans, enriches every finding via the
embedding domains, and hands off to the [[forensics-agent]] for deep
investigation; results flow into the [[forensic-report-pipeline]] and
from there into the self-improvement reasoning branches.

## goals

1. openvas scan orchestration as a zenka (target, port range, profile)
2. per-finding enrichment: CVE / MITRE / CWE / NVT context via embedding
   domains
3. handoff to forensics agent for deep investigation
4. results stored in a form the report pipeline can consume
5. everything local — no scan data leaves the network

## phase 1 — zenka scaffold + backend

### task 1.1 — create openvas zenka
```
## dispatch + prompt
create cfg/zenki/openvas/ following the pattern of an
existing single-purpose zenka (e.g. letsencr for zenka-startup.v7 +
start script; cube or transport for access.zenki, since letsencr has
none). bootable, stoppable, registered in network configs. no modules
yet.
```

### task 1.2 — openvas backend wrapper
```
## dispatch + prompt
decide the control path by what is installable on the host: gvm-tools
(python lib over gvmd socket) vs ospd-openvas CLI vs greenbone community
container. document the choice in the module header.
new module openvas.scan.run: args target, ports, profile; returns
structured findings (nvt oid, severity, name, target) written as yaml
to the zenka data dir. keep the wrapper thin — the value of this zenka
is orchestration + enrichment, not scanner internals.
```

## phase 2 — finding enrichment

### task 2.1 — per-finding unified context load
```
## dispatch + prompt
new module openvas.enrich.finding: for each scan finding, query the
security-intel embedding domains (cve, mitre, cwe, nvt — nvt domain
built from the same greenbone feed, see
[[security-intel-embedding-domains]]) for nearest neighbors, load the
matching protocol files from disk, attach as enrichment context.
depends on [[security-intel-embedding-domains]] phase 1.
fallback if domains not trained yet: attach finding as-is, mark
enrichment 'pending'.
```

### task 2.2 — openvas.cmd.report-to-forensics
```
## dispatch + prompt
new module openvas.cmd.report-to-forensics: sends enriched findings to
the forensics zenka via standard zenka routing. include target, raw
finding, enrichment context, and a correlation id so the report
pipeline can join scanner findings with forensic investigation results.
```

## phase 3 — integration

### task 3.1 — event slot (optional)
```
## dispatch + prompt
evaluate adding a periodic scan slot to cfg/zenki/events/
(daily/weekly, scoped targets only). default: manual invocation only
until the forensics agent is live — do not scan without a consumer.
```

## notes

- scan profile presets matter more than raw coverage: fast recon vs
  full NVT run vs compliance-shaped — encode as named profiles in the
  zenka config from day one.
- the greenbone feed is also the corpus source for the nvt embedding
  domain — keep the feed-sync and embedding-retrain steps adjacent
  (weekly freshness, see security-intel task 2.2).
- no external AI calls for enrichment — embeddings + local models only.

#,,..,,,.,.,.,,,,,..,,,,.,.,.,...,,.,,,,,,,.,,..,,...,...,,,.,.,,,..,,.,.,.,.,
#C2Z4VUFEMEWDTDIBDCV76FDIGOGY4SUUZQPGO4CXFD7BTNNSQ3P4L5PBBMBIT6LXKS3PWDFLG76O6
#\\\|FAFWUBTEHC4VXNIZY5D3RZ2JOY5GOU56BTLGLHUNCLN5NG6W7FJ \ / AMOS7 \ YOURUM ::
#\[7]CGWM5QDM5BKT43RKBSSKHBDIYKNM6KA4STEV45LOFH2YG3PERUBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
