---
name: job pipeline
description: job search automation — site-yaml, job-site-scan, assessment, sync
type: project
originSessionId: 240f9c26-e26e-4714-956a-72bd2bd2048d
---
## Implemented (2026-05-10, session 20)

**site-yaml zenka** (on-demand):
- `site-yaml.import <url>` — fetch stepstone search page → JSON-LD per job → store.yaml
- Store: `/var/protocol-7/site-yaml/store.yaml` (moved from /var/protocol-7/jobs/)
- Status flow: new → assessed → applied/rejected/skipped/archived
- Proxy bypass: no_proxy('stepstone.de', 'www.stepstone.de')
- 0.5s delay between job page fetches (rate limiting)

**job-site-scan zenka** (on-demand, coordinator):
- Stage engine: idle → scanning → assessing → reviewing → idle
- State: `/var/protocol-7/job-site-scan/scan-state.yaml`
- Profile: `/etc/protocol-7/job-site-scan/profile.txt`
- Commands: scan, status, list-jobs, list-jobs [stage], approve, reject,
  set-threshold, clear-tasks, get/set/dump/del (devmod)
- Default categories: linux-sysadmin, ki-automation, devops, platform-engineer
  (add linux-entwickler next session)

**Assessment pipeline (fully wired, first run in progress as of session 20)**:
- fetch-done builds full inline prompt: profile + job details embedded in description
- task description: `:local: :simple: <full prompt>` (4000+ bytes, B32-encoded)
- :local: → models routes to coding.ask-reply
- :simple: → coding.cmd.ask-reply sets no_tools=TRUE, max_rounds=1
- assess-done extracts JSON score from result, updates store + scan state
- Sequential dispatch: one task.create at a time (dispatch.next chain)
- Restart recovery: rewire-all handler re-wires task.wait-done for orphaned jobs

**Key bugs fixed in session 20**:
- models.handler.task-poll-step: task.show header parser now requires \s+ before ':'
  (embedded job 'description:' line was overwriting the task metadata 'description : ...')
- Kimi disabled in v7 config — all assessment goes to local coding zenka
- clear-tasks command added for clean resets
- buffer-erase enabled in models zenka

**web template**: space.v7.ax/jobs.html.tmpl — dark card list with score color coding

## First-run checklist (next session)
1. Check HAODVZA result: p7c task.result HAODVZA
2. p7c job-site-scan.status — should show some 'review' jobs
3. If scored: p7c job-site-scan.list-jobs review
4. If not scored: check coding zenka result + assess-done JSON parsing
5. Reset all 100 to new + clear-tasks + scan (full production run)
6. Add linux-entwickler category to job-site-scan start file

## Planned
- Multi-page search: stepstone 25 jobs/page — cfg.max_pages per category
- HTTP sync endpoint — /api/jobs/sync on httpd, C25519-signed YAML
- jobs.html.tmpl filter tabs — need ?filter= query param wiring
- Remove debug logs from models.handler.task-poll-step
- Consider changing models.task.default_model from 'kimi' to 'local'

#,,,,,...,,,,,,,.,,..,..,,,.,,...,...,,,,,,,.,..,,...,...,.,,,..,,,..,,,.,..,,
#FSL7RXPPRNJ4VBG33CZI3KSWCHYEN6EGHNRABHOYVKL4LTYSWKET4C6RPOIFNFJOIAENOTQCME2MA
#\\\|JYEWK7IJGA4RTDNV3F64SHZARX5WOOCZQTYSDJ2DJUWNXOVREEI \ / AMOS7 \ YOURUM ::
#\[7]L7PQEEMMHXUGDAW6FO3OUGR2HIGJSCZCLDJOUDK4UG45VEJ3V6BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
