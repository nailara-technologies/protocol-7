---
name: job pipeline
description: job search automation — site-yaml, job-site-scan, assessment, sync
type: project
originSessionId: 5557aaa4-3476-4c66-9002-955c73ae92a1
---
## Implemented (2026-05-10, sessions 20-22)

**site-yaml zenka** (on-demand):
- `site-yaml.import <url>` — fetch stepstone search page → JSON-LD per job → store.yaml
- Store: `/var/protocol-7/site-yaml/store.yaml` — delete to force full re-fetch
- Status flow: new → assessed → applied/rejected/skipped/archived
- Proxy bypass: no_proxy('stepstone.de', 'www.stepstone.de')
- 0.5s delay between fetches; retry queue for timeouts (3s wait + 2s between retries)

**job-site-scan zenka** (on-demand, coordinator):
- Stage engine: idle → scanning → assessing → reviewing → idle
- State: `/var/protocol-7/job-site-scan/scan-state.yaml`
- Profile: `/etc/protocol-7/job-site-scan/profile.txt`
- Commands: scan, status, list-jobs [stage], approve, reject, set-threshold,
  clear-tasks, get/set/dump/del (devmod)
- Categories: linux-sysadmin, ki-automation, devops, platform-engineer
  (TODO: add linux-entwickler)
- Full re-run: `rm store.yaml && p7c job-site-scan.clear-tasks && p7c job-site-scan.scan`

**Assessment pipeline — FULLY WORKING, session 22**:
- Prompt: German from the start — asks for score + reason + summary in one pass
- JSON format: `{"score": 0-10, "apply": bool, "reason": "1-2 German sentences (fit)",
  "summary": "2-3 German sentences (job overview, skills, remote/location, highlights)"}`
- reason = why candidate fits/doesn't; summary = what the job actually is
- Sequential: one task in flight (dispatch.next from assess-done)
- models.task.default_model = local
- No separate translation pass — model outputs German natively
- assess-done stores: score, score_reason, score_summary in task state + store.yaml
- Future: score_tech + score_location as separate fields (structure ready)

**jobs.vhost — LIVE**:
- Vhost: atom.protocol-7.network (46.101.115.180), TLS via letsencr
- Repo: `data/web-root/vhosts/jobs.vhost/` (domain not disclosed)
- Manifest: `hostname_pattern: jobs.*` + `install_matching: yes` — resolves against
  deployed /var/httpd/jobs.* dirs at install time
- `httpd.vhost.read_manifests` extended to handle wildcard pattern vhosts
- Page features: score filter (slider, default 6), filter tabs, sort score↓/↑/datum,
  table toggle, CSV export, notes, status changes, drag-reorder, manual add
- Card layout: title+score → company/city/industry → reason (italic) → summary (muted)
  both click-to-expand
- Export: `bin/dev/export-jobs-json [outfile]` — reads store.yaml → jobs.json
  prefers score_reason_de (legacy) then score_reason; to_unicode() fixes Latin-1/UTF-8
- Update cycle: `perl bin/dev/export-jobs-json /tmp/jobs.json && scp ... atom:/var/httpd/jobs.vhost/`

**letsencr fix (session 22)**:
- x509_field/der_to_pem/extract_aia_url/fetch_intermediate_via_aia were only loaded
  in child branch — parent crashed in save_certificate. Fix: load all four in parent
  branch of fork_letsencr_child alongside letsencr.parent.

**Key bugs fixed across sessions**:
- task.show multiline description truncated to first line — escapes \n now
- 100 tasks dispatched simultaneously — dispatch.next moved to assess-done
- store reset: delete store.yaml (no reset-scores command yet)

## Planned
- Search category management: add/remove/list-categories commands + zenka_dir
  persistence — so categories don't require editing the start file
- Multi-page search: cfg.max_pages per category (stepstone: 25/page)
- Task zenka persistence (zenka_dir) — state lost on idle shutdown
- HTTP sync endpoint — auto-push jobs.json after each run
- Remove debug logs from models.handler.task-poll-step
- Apply workflow: send application email from review card
- Exclusion filter from past CSV data (already-applied companies)
- score_tech + score_location split in assessment JSON

#,,,.,,.,,,..,,.,,.,.,,..,.,.,.,.,.,.,,..,,..,..,,...,...,,..,..,,...,,..,,..,
#CY6F4NB7EIRWW477E5WDKSBCJEFS2VNGLERKTJZQAESGCMEXL3BYIIXEAR7OQTZX6RIWTM5MWNYKG
#\\\|SXMCH3AIHYPZ7NEK5TSJPVYEKZ3RNSBLUQZJE73Z7LMWEL63ERB \ / AMOS7 \ YOURUM ::
#\[7]ICSTWOHBI63OYF26IUVSWCUJPPZUKLV7T5BVO6P3IWD5TBLIDWAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
