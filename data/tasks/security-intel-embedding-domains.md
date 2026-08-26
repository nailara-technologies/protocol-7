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

    data/protocols/cve/       CVE-2024-1234        ← NIST NVD feed
    data/protocols/nvt/       1.3.6.1.4.1.25623..  ← greenbone community feed (PRIMARY)
    data/protocols/mitre/     ATTACK-T1190         ← mitre cti repo json
    data/protocols/weakness/  CWE-79               ← cwe.mitre.org json
    data/protocols/cisa/      KEV-2024-0001        ← cisa known-exploited list
    data/protocols/nessus/    plugin-10662         ← nessus plugin export (OPTIONAL,
                                                     only when a nessus backend exists)

the nvt domain is primary because the openvas agent is built first and
the greenbone feed is free — scanner and knowledge base come from the
same source. nessus plugin ids and nvt oids stay SEPARATE domains;
cross-domain nearest-neighbor queries bridge them semantically.

consumers: openvas agent enrichment (task 2.1), forensics investigation,
coding zenka security tasks. unified loader queries multiple domains in
parallel and merges into one context bundle.

## phase 1 — domain corpora + embeddings

### task 1.1a — fetch + normalize CISA KEV (scoped first slice)
```
## dispatch + prompt
scoping decision (2026-07-29): start with cisa KEV only — smallest,
highest signal-to-noise, single bounded JSON file (~1-2k entries), no
multi-decade archive to page through. proves the fetch → normalize →
skipgram → data/protocols/<domain>/<id> pipeline end-to-end before
committing to the larger feeds.
  cisa: https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json
fetch, normalize into one-file-per-entry under data/protocols/cisa/, emit a
skipgram training file (one line per entry: id + name + first ~10
description tokens, id repeated 3x for weighting).
output layout: data/protocols/cisa/<id> files + data/training/cisa.txt

update (2026-07-29): completed. 1655 files under data/protocols/cisa/
(6.6MB), data/training/cisa.txt (297KB). path corrected from a bare
top-level protocols/ to data/protocols/ for consistency with everything
else fetched/generated this session (data/training/, data/embeddings/,
data/patches/) — src/ is the only legitimate top-level exception,
being the executable code tree, not fetched reference data. tracked in
git: small, public data, and this IS the knowledge-base data the
unified loader reads at runtime, not a regenerable build artifact.
this size/tracking judgment does NOT automatically extend to task
1.1b's other domains — full NVD CVE history in particular could be
orders of magnitude larger; revisit per-domain when 1.1b is dispatched.
```

### task 1.1b — fetch + normalize remaining domains (do not dispatch yet)
```
## dispatch + prompt
once 1.1a's pipeline is verified, repeat the same fetch/normalize
pattern for the other 4 domains:
  cve:   https://nvd.nist.gov/feeds/json/cve/2.0/ (json.gz per year —
         large multi-decade archive, page/rate-limit deliberately)
  mitre: https://raw.githubusercontent.com/mitre/cti/master/enterprise-attack/enterprise-attack.json
  cwe:   https://cwe.mitre.org/data/json/cwe_2_0.json.zip
  nvt:   greenbone community feed (synced by the openvas agent's feed
         machinery — reuse, don't duplicate); nessus: SKIP until a
         nessus backend exists (see [[nessus-agent]] ordering)
output layout: data/protocols/<domain>/<id> files + data/training/<domain>.txt

compression note (2026-07-29): cisa KEV (task 1.1a) was left as plain
text — entries average ~700 bytes, git's own blob delta-compression
already handles that well, and individually xz-compressing files that
small barely shrinks them (~23% in testing) while breaking git's
delta-compression across near-duplicate entries. cve/nvd entries are a
different case: full paragraph-length descriptions, not a handful of
short fields. WHEN this task runs, evaluate per-file xz
(data/protocols/cve/<id>.xz, decompressed on read by the phase-2 loader)
specifically for the cve domain — decide based on actual fetched entry
size, not by assumption. do not tar/archive a whole domain into one
compressed blob regardless of size: that breaks the "name = filepath,
no registry, direct load" property the unified loader depends on.

update (2026-07-29): partial completion — mitre + cwe domains done.
  mitre: bin/dev/mitre-attack-corpus, 697 live attack-pattern entries
  [ techniques + sub-techniques, revoked/deprecated excluded ] under
  data/protocols/mitre/ (2.8MB), data/training/mitre.txt (96KB).
  cwe: bin/dev/cwe-corpus, 944 weakness entries [ deprecated excluded ]
  under data/protocols/cwe/ (3.8MB), data/training/cwe.txt (124KB).
  source deviation: the cwe_2_0.json.zip url above is stale [ 404 —
  CWE no longer publishes a json feed ]; the official xml catalog
  cwec_latest.xml.zip [ v4.20 ] is parsed instead, same weakness data.
  compression sanity check: cwe averages ~4KB/entry with only ~24%
  xz -9 saving in sampling — the cve-domain xz concern does NOT apply
  here; total volume is a few MB, git blob delta-compression is the
  right tool, left as plain text. cve/nvd still deferred [ needs its
  own size scoping pass ], nvt still bound to the openvas feed-sync
  machinery, nessus still blocked on a backend existing.
  signing note: bin/dev scripts + this file committed unsigned from
  an afk session [ key passphrase unavailable ] — user must run
  bin/Protocol-7 sourcecode update-signatures before the next hook-
  checked commit.
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
data/protocols/<domain>/<id> filepaths (name = filepath, no registry),
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

#,,,,,..,,.,,,,,,,,,.,...,..,,..,,.,.,.,,,..,,..,,...,...,..,,.,.,,.,,..,,...,
#4YVNJBYSBVDNTKAAFIWQB7LBUOWTSYWEIYQLBHVTI57VTWS6XQGVBPZH4PTPAK7MVXZPG3IWZSM6E
#\\\|JAQ4WDEGLUBBE62SZSJQJDKCIGHRGNMBHZUUIRFPKUL3XTFITPE \ / AMOS7 \ YOURUM ::
#\[7]57RYPKGVHDRM7CWDJG7A653TKAYW6EIRAQW76BJJ4ZXCJGLWCCAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
