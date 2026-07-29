# security intelligence embedding domains — task

## context

track: [[EMBEDDING-INFRASTRUCTURE-TRACK]] (data/md/design/)
pipeline: [[FASTTEXT-MEMORY-PIPELINE]] (this extends it with new categories)
related: [[nessus-agent]], [[forensic-report-pipeline]], [[dep-graph-semantic-embeddings]]
source: duck.ai design conversation 2026-07-29 (prompts 64)

security knowledge bases become loadable, memoizable awareness domains —
same pattern as the codebase embeddings: structured on-disk trees where
name = filepath, plus a FastText embedding model per domain. agents query
nearest neighbors and load only the relevant entries into context.

domains (all greenfield — nothing exists yet):

    protocols/cve/       CVE-2024-1234        ← NIST NVD feed
    protocols/nvt/       1.3.6.1.4.1.25623..  ← greenbone community feed (PRIMARY)
    protocols/mitre/     ATTACK-T1190         ← mitre cti repo json
    protocols/weakness/  CWE-79               ← cwe.mitre.org json
    protocols/cisa/      KEV-2024-0001        ← cisa known-exploited list
    protocols/nessus/    plugin-10662         ← nessus plugin export (OPTIONAL,
                                                only when a nessus backend exists)

the nvt domain is primary because the openvas agent is built first and
the greenbone feed is free — scanner and knowledge base come from the
same source. nessus plugin ids and nvt oids stay SEPARATE domains;
cross-domain nearest-neighbor queries bridge them semantically.

consumers: openvas agent enrichment (task 2.1), forensics investigation,
coding zenka security tasks. unified loader queries multiple domains in
parallel and merges into one context bundle.

## phase 1 — domain corpora + embeddings

### task 1.1 — fetch + normalize per domain
```
## dispatch + prompt
for each of the 5 domains: fetch the public source (urls below),
normalize into one-file-per-entry under protocols/<domain>/, and emit a
skipgram training file (one line per entry: id + name + first ~10
description tokens, id repeated 3x for weighting).
  cve:   https://nvd.nist.gov/feeds/json/cve/2.0/ (json.gz per year)
  mitre: https://raw.githubusercontent.com/mitre/cti/master/enterprise-attack/enterprise-attack.json
  cwe:   https://cwe.mitre.org/data/json/cwe_2_0.json.zip
  cisa:  https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json
  nvt:   greenbone community feed (synced by the openvas agent's feed
         machinery — reuse, don't duplicate); nessus: SKIP until a
         nessus backend exists (see [[nessus-agent]] ordering)
output layout: protocols/<domain>/<id> files + data/training/<domain>.txt
```

### task 1.2 — train domain embeddings
```
## dispatch + prompt
extend the train-embedding wrapper from [[FASTTEXT-MEMORY-PIPELINE]]
phase 2 (or create bin/dev/train-embedding first if it still does not
exist) to train one model per domain:
  fasttext skipgram -input data/training/<domain>.txt
      -output data/embeddings/<domain> -epoch 100 -dim 300 -minn 3 -maxn 6
register the domains in the retrain-trigger config so source updates
(new CVE year feeds) trigger retraining automatically.
```

## phase 2 — unified loader

### task 2.1 — security-intel unified context loader
```
## dispatch + prompt
new module set embeddings.securityintel.* (or security.intel.*):
load_unified_context(query, scope, limits) — queries each enabled
domain's embedding model in parallel, converts hit ids directly to
protocols/<domain>/<id> filepaths (name = filepath, no registry),
loads files, returns a merged context bundle keyed by domain.
include per-scan memoization (cache key = query + scope).
perl sketch exists in the conversation transcript (prompt 64) —
use as reference, adapt to existing module conventions.
```

### task 2.2 — retrain triggers + freshness
```
## dispatch + prompt
wire the domains into embeddings.check-retrain-triggers /
embeddings.cmd.retrain-category (existing design, may need
implementation): cve/cisa retrain on feed update, mitre/cwe on version
bump, nessus on plugin export. add a weekly freshness check that
reports stale domains to the forensics channel.
```

## notes

- all sources are public data — no confidentiality issue; the privacy
  boundary applies to FINDINGS, not to the knowledge bases.
- subword embeddings (minn/maxn) handle CVE ids, plugin numbers and
  vendor jargon gracefully.
- keep domains loadable independently — an agent should be able to run
  with only cve+cwe loaded (small memory footprint).

#,,,.,,,.,,,,,,..,,,.,,..,,..,.,.,,,,,,,.,,..,..,,...,..,,,.,,,,,,,,.,,,,,.,,,
#H35UUIB2N73LL4XN5DLM3DRGMGUFTFPQG5Y6QRM45BOCDRSHSXXA44DT65UMK42SCNFUV4U5I2X3C
#\\\|US3TKKUJTOHUQWQDFODLOD2CCVFB6F6IOBLDMYGM5YL6HPO2YD5 \ / AMOS7 \ YOURUM ::
#\[7]D4E2ZPRJBQAZL2TOI2SNBESNQJHV7IA7GTSAKPZ4H2NFF6BH7WBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
