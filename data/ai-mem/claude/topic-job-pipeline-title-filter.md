---
name: job pipeline title pre-filter
description: batch title screening via AMOS checksums before full page fetch+assessment
type: project
originSessionId: 5557aaa4-3476-4c66-9002-955c73ae92a1
---
## Design: title pre-filter pass

**Problem:** current pipeline fetches every job page and runs full inference — wasteful
for obvious mismatches (insurance sales, Windows-only, Vertrieb, SAP, junior roles).

**Solution:** insert a lightweight batch screening step after search page parse,
before individual page fetches:

1. Search page already returns all titles + IDs (no extra fetches)
2. Compute AMOS checksum of each title → use as opaque batch handle
3. Send one `:simple:` inference call with all [checksum, title] pairs
4. Model returns JSON array of checksums to exclude
5. Skip fetch + assessment for excluded IDs entirely

**Prompt shape:**
```
Du bist ein Job-Filter für einen Senior Linux/Unix/Security Engineer.
Welche dieser Stellentitel sind offensichtlich unpassend (Vertrieb, Versicherung,
Windows-only, SAP, nicht-technisch, Junior)?
Antworte nur mit JSON-Array der auszuschließenden Checksummen.

[["a3f9b2", "Versicherungsberater (m/w/d)"],
 ["c7d441", "Senior DevOps Engineer Linux"],
 ["e12f88", "Außendienstmitarbeiter Vertrieb"]]
```

**Response:** `["a3f9b2", "e12f88"]`

**Why AMOS checksums:**
- Protocol-native, compact
- Model never needs to interpret the ID — just echoes back what to exclude
- No URLs or job IDs leaking into reasoning context
- Batch of 25 titles fits in minimal context (one search page worth)

**Expected savings:** 30-50% fewer page fetches and inference passes per scan.

**Integration point:** `site-yaml.cmd.import` — after collecting `$links` from search
page, before the per-job fetch loop. Checksums computed from `$link->{'title'}`.
Excluded IDs added to a skip set alongside the already-known check.

**Future extension:** also filter by location pre-fetch (title often contains city),
could add score_title as a lightweight pre-score stored in the job record.

#,,.,,.,,,,.,,,.,,..,,.,,,.,.,,,.,...,.,.,,,.,..,,...,...,.,.,...,,..,..,,,,.,
#EGQG35HMBA7XYNP6AXMVPYZR4QWX4M4SDD6EQAH353XKDN7F2ZCQFOY3YVXRU2FPZTABYS7KC5CYS
#\\\|RSQAKH43PYJ77BGEIQWDS2E6NPM55I5EXIHEQ56QFJBSPNG2ZE2 \ / AMOS7 \ YOURUM ::
#\[7]76G7CCGT2ESQYZBMGJS44HYB4STNS7RXLFGGDCYOLFXM5DNBFCCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
