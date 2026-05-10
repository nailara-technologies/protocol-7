---
name: job pipeline
description: job search automation — site-yaml, job-site-scan, assessment, sync
type: project
originSessionId: 5557aaa4-3476-4c66-9002-955c73ae92a1
---
## Implemented (2026-05-10, sessions 20-21)

**site-yaml zenka** (on-demand):
- `site-yaml.import <url>` — fetch stepstone search page → JSON-LD per job → store.yaml
- Store: `/var/protocol-7/site-yaml/store.yaml`
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

**Assessment pipeline — FULLY WORKING as of session 21**:
- fetch-done builds full inline prompt: profile + job details embedded in description
- task description: `:local: :simple: <full prompt>` (4000+ bytes, B32-encoded)
- :local: → models routes to coding.ask-reply
- :simple: → coding.cmd.ask-reply sets no_tools=TRUE, max_rounds=1
- assess-done extracts JSON score, updates store + scan state, dispatches next
- Sequential: one task in flight at a time (dispatch.next called from assess-done)
- models.task.default_model = local (no kimi fallback)
- First real scored run: 6+ jobs in review, scores 7–8.5, reasoning correct

**Key bugs fixed in session 21**:
- task.cmd.show was emitting multiline description as raw newlines in the header
  block — task-poll-step only captured the first line (`:local: :simple: ...`)
  and discarded the entire profile + job data. Fix: task.show now escapes \n in
  description + context fields; task-poll-step unescapes after header parse.
- task-created handler was calling dispatch.next immediately, dispatching all 100
  tasks at once — coding zenka saturated, most returned "awaiting_data". Fix:
  dispatch.next moved to assess-done (and failure path) so only one task runs.
- assess-done regex: now also matches "fit_score", "reasons" array, "recommendation"
  in addition to canonical "score"/"reason" keys.
- models.task.default_model set to 'local' in models/start config.
- Store reset for full re-run: perl -MYAML::XS to set all status='new', then
  p7c job-site-scan.clear-tasks && p7c job-site-scan.scan

**web template**: space.v7.ax/jobs.html.tmpl — dark card list with score color coding

## Current state (session 21 end)
- 100 jobs being assessed sequentially, ~6+ in review already
- threshold = 6 (scores are 0-10 but model may use 0-100; both work since anything
  >= 6 on 0-10 is also >= 6 on 0-100 for high scores)

## Planned
- Multi-page search: stepstone 25 jobs/page — cfg.max_pages per category
- Add linux-entwickler category to job-site-scan start file
- HTTP sync endpoint — /api/jobs/sync on httpd, C25519-signed YAML
- jobs.html.tmpl filter tabs — need ?filter= query param wiring
- Remove debug logs from models.handler.task-poll-step (cmd=/len=/preview=)
- Task zenka persistence (zenka_dir routines) — task state lost on idle shutdown

#,,,.,,.,,,,,,,..,,..,..,,,,,,,..,...,.,,,,,,,..,,...,...,..,,,..,,..,.,,,.,,,
#4PYDXMHFVVZAXRBS7JDR5RWGHCJ5EH6TIUJSLHEJIFWPLEOR4T4R4PFLVMICVMJX67IUB6VVNBFG6
#\\\|4KW4NDGIXP7XVUY7WGZ55WYP6FKNBZDGA33F4WGEULPHRPGK6U2 \ / AMOS7 \ YOURUM ::
#\[7]YK5CWQLYSFQUTZQ6WWURCT2MQUZFE6SWQ7EWQCSUP5CYK4QYGGBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
