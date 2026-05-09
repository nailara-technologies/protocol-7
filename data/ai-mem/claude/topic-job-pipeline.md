---
name: job pipeline
description: job search automation — site-yaml, job-site-scan, assessment, sync
type: project
originSessionId: 720400ec-fa5d-4bd0-a47c-8b05d3612ca3
---
## Implemented (2026-05-10)

**site-yaml zenka** (on-demand):
- `site-yaml.import <url>` — fetch stepstone search page → extract JSON-LD per job → store.yaml
- `site-yaml.list-jobs [status]` — list job store
- `site-yaml.set-status <id> <status>` — manual status update
- Store: `/var/protocol-7/jobs/store.yaml`, keyed by job ID
- Status flow: new → assessed → applied/rejected/skipped/archived
- Proxy bypass: `$ua->no_proxy('stepstone.de')` — proxy at 10.0.110.7:4040 blocks stepstone

**job-site-scan zenka** (on-demand, coordinator):
- Stage engine: idle → scanning → assessing → reviewing → idle
- State namespace: `<job-site-scan.tasks.JOBID.*>`, persisted to scan-state.yaml
- `pending_count` var watcher fires stage.review when all assessments land (no polling)
- Named categories in start file: `cfg.categories` + `cfg.url.<category>` per entry
- Default categories: linux-sysadmin, ki-automation, devops, platform-engineer
- Assessment: task.create → task.wait-done (deferred reply via task zenka, no polling)
- Commands: scan, status, list, approve, reject, set-threshold

**job-assess template** (`data/yaml/context-templates/job-assess.yaml`):
- no_tools=true, max_rounds=1 — single LLM call, returns JSON
- Profile injected from `/var/protocol-7/jobs/profile.txt`
- Output: `{"score": N, "reason": "...", "apply": true/false}`

**web template** (`data/web-root/vhosts/space.v7.ax/jobs.html.tmpl`):
- plugin.web.jobs.list + plugin.web.jobs.stats read store.yaml directly
- Dark theme card list with score color coding

## First-run checklist
1. `p7c v7.restart cube` — load new auth/access entries
2. Create `/var/protocol-7/jobs/profile.txt` — CV/skills context for LLM scoring
3. `p7c job-site-scan.scan` — trigger first scan cycle
4. `p7c job-site-scan.status` — check progress
5. `p7c job-site-scan.list review` — see jobs above threshold
6. `p7c job-site-scan.approve <id>` — approve for application

## Planned: HTTP sync between nodes

**Why:** local node has larger GPU models for better assessment quality; remote nodes
(when installed) have CPU inference with smaller models. Need to sync job store +
scan state so both nodes see the same pipeline state.

**Design sketch:**
- `httpd` exposes `/api/jobs/sync` endpoint (POST to push, GET to pull)
- Payload: YAML dump of store.yaml + scan-state.yaml, signed with zenka's C25519 key
- Receiver verifies signature against known node public keys (same key exchange as
  existing zenki auth — `crypt.C25519.*` modules already present)
- Merge strategy: last-write-wins per job ID, with `updated_at` ntime timestamp
- Node identity: zenka name + instance AMOS checksum (already in P7 routing)

**What already exists:**
- `crypt.C25519.*` — key generation, signing, verification
- `httpsd` TLS endpoint — already deployed on pri.v7.ax
- `base.chk-sum.amos` — for node identity checksums
- Route-send plumbing — could also sync via P7 route rather than HTTP

**Simpler first approach:** sync via P7 route directly (if both nodes share a cube
federation in future). HTTP only needed for nodes that aren't in the same P7 network.

**Status:** planned, not started. Defer until remote server is set up and CPU
inference model is selected.

## Open items
- Profile file: needs to be written (key skills, preferred roles, location prefs)
- Assessment quality: test with Qwopus vs smaller model on same job listing
- Multi-page search: stepstone returns 25 jobs/page — add pagination to site-yaml.import
  for deeper scans (cfg.max_pages per category)
- Score persistence across restarts: scan-state.yaml survives, store.yaml survives —
  but if coding zenka is restarted mid-assessment, pending tasks orphan. Add timeout
  or re-queue on restart if tasks older than N hours are still in 'assessing' stage.

#,,.,,,.,,.,,,.,.,,,,,,,.,.,,,,..,..,,,,,,..,,..,,...,...,...,,,.,,,.,...,,.,,
#IYEB23FL6Q47G6O2X75PBB2NTPUK7R7T5WFCO6S7Q7YMBKQODLQWJJ7NZMKLIK5OYRQW325Z5CTVQ
#\\\|XL43LAU64EDQPMA44VAHXMCLTO2NRAYUMZ7QZMT2FQPR7QXIDT6 \ / AMOS7 \ YOURUM ::
#\[7]2F2QQ7ATIAVQVXV5LRWUJKGG5TKHZQW77FZMJAX3ZQTWNYRO5ADI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
