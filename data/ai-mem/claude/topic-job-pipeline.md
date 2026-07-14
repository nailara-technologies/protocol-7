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
  table toggle, CSV export, print report, notes, status changes, drag-reorder, manual add
- Card layout: title+score → company/city/industry → reason (italic) → summary (muted)
  both click-to-expand
- Print report: hybrid layout — overview table + KI-Analyse per job (summary+reason+note);
  filter: applied/responded/rejected only (same as CSV); light mode at print time, dark preview;
  "drucken" button appears when table is visible; refreshes on sync + tab switch
- CSV export: applied/responded/rejected only
- Export: `bin/dev/export-jobs-json [outfile]` — reads store.yaml → jobs.json
  prefers score_reason_de (legacy) then score_reason; to_unicode() fixes Latin-1/UTF-8
- Update cycle: `perl bin/dev/export-jobs-json /tmp/jobs.json && scp ... atom:/var/httpd/jobs.*/`
  (actual dir matched by wildcard — not kept in repo; personalized)

**letsencr fix (session 22)**:
- x509_field/der_to_pem/extract_aia_url/fetch_intermediate_via_aia were only loaded
  in child branch — parent crashed in save_certificate. Fix: load all four in parent
  branch of fork_letsencr_child alongside letsencr.parent.

**Key bugs fixed across sessions**:
- task.show multiline description truncated to first line — escapes \n now
- 100 tasks dispatched simultaneously — dispatch.next moved to assess-done
- store reset: delete store.yaml (no reset-scores command yet)

## Session 24 changes (2026-05-14)
- zenka renamed job-site-scan → jobsite (89 files, all modules, config, /etc/, /var/)
- assessment prompt switched JSON → YAML heredoc template (cleaner model output)
- assess-done + repair-done: YAML::XS::Load primary parser, JSON regex as fallback
- validate.assessment: assertion check updated for YAML format
- YAML::XS autoload moved to init_code (was duplicated inline in handlers)
- task files written for kimi: flush_on_acquisition extraction + per-element storage

## Current state (session 22 end)
- 96/106 jobs with German reason+summary; 2 being re-assessed (English from old run)
- jobs.vhost live: score-gradient cards, gestures, review default tab, culture scoring
- Profile: Freiburg + Stuttgart as alternates; company culture ±1-2pt signals added
- Encoding fully fixed: fetch-done UTF-8 decode + export 2-pass Mojibake repair

## Planned
- Search category management: add/remove/list-categories commands + zenka_dir
  persistence — so categories don't require editing the start file
- Multi-page search: cfg.max_pages per category (stepstone: 25/page)
- Task zenka persistence (zenka_dir) — state lost on idle shutdown
- plugin.web.jobs.* — bi-directional sync endpoint, B32 backups, replaces
  export-jobs-json+scp; see topic-plugin-web-jobs.md for full design
- Remove debug logs from models.handler.task-poll-step
- Apply workflow: send application email from review card
- Exclusion filter from past CSV data (already-applied companies)
- score_tech + score_location split in assessment JSON
- site-yaml: extract Stepstone's own salary estimate range (min/max) into
  structured fields alongside the JSON-LD job data — grounds the
  `compensation` assertion dimension in a real number instead of guessing from
  company size/industry. Not every listing has one; "field absent" must be a
  regular, unambiguous state (no 0/null default), since other salary sources
  (market-average APIs, trend data) will be layered in later and need the same
  absent-vs-zero distinction.

## Vision (2026-07-14, agreed with user)
End state for jobsite: system prepares a full application (cover letter,
answers, salary ask) grounded in structured signals like the above, presents
it to the user for review, and on approval sends it and tracks replies.
When the user edits the generated application before sending, that diff is
the training signal — future applications should incorporate the accumulated
edits/insights automatically, not just repeat the same draft pattern.
See [[topic-plugin-web-jobs]] for the existing sync/apply-workflow substrate
this would build on.

#,,.,,,..,,..,.,,,...,...,.,.,,,,,...,..,,,..,..,,...,...,,,.,,,,,.,,,.,.,,..,
#4QLG5H23WCUNZ7GIXJKXLQU74QELQQ7DF7QHC5LWYUED2PTE7PYZUJX2RLVYLGH3DPNHHAEDWQUXO
#\\\|CLV7ELRF674SNHTLL4L24YMGS3Q2NGFOBUDOUQ3OY5CVA57E5NJ \ / AMOS7 \ YOURUM ::
#\[7]X5G2ELPT6EEVDUQPI26DWNPX67PDD56QFRBML7LRL6M6EUW6JIBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
