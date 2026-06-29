# Jobsite/Web Jobs Pipeline — 2026-06-28

## Context
A series of regressions and missing features in the jobsite/web jobs pipeline were fixed in a single session. The work touched indexers, sync handlers, the web UI, and orbital subscriber command syntax.

## Root Cause: `skipped` status omitted from active indexes
`skipped` jobs were manually asserted but disappeared from the web UI because no scanner treated `skipped` as an active status. Added `skipped` to active-status lists in:
- `modules/jobsite.job.index.build`
- `modules/jobsite.job.load_all`
- `modules/jobsite.index.rebuild`
- `modules/site-yaml.job.scan_stray`
- `modules/plugin.web.jobs.init_code`
- `modules/plugin.web.jobs.cache.read_all`

After the fixes, indexes were rebuilt and counts aligned (≈1409 jobs).

## Protected manual decisions during reassessment
`modules/jobsite.handler.assess-done` now treats `applied interviewed responded rejected skipped archived` as protected stages, so reassessment does not overwrite manual skip/reject decisions.

## Web sync improvements
- `modules/plugin.web.jobs.sync` now carries `assertions` in the pipeline field list so the UI can render score suggestions and badges.
- Delete action removes the job from web cache and in-memory index immediately.
- Sync endpoint and reverse-sync queue flush correctly now.

## UI changes (`data/web-root/vhosts/jobs.vhost/index.html`)
- Apply/skip suggestion badges only shown in `review` and `to_apply` stages (not in `skipped`, `rejected`, etc.).
- Added per-job delete button in the `löschen` tab and a delete option in the stage dropdown.
- Delete count shown in the stats bar.

## Orbital subscriber syntax fix
Several modules still used the old `.cmd.` form when calling orbital subscribers:
- `discover.list-orbital`
- `external.list-connections`
- `nodes.orbital-position`
- `graphics-matrix.orbital-sync`
Updated to current cube command syntax; `list-connections` also added to external zenka access whitelist.

## Open items
- ~6 stale web-cache entries remain (web cache 1415 vs jobsite 1409). They will reappear on sync unless individually deleted or pruned.
- Bulk delete is deferred until a custom search/filter + multi-select mechanism is built.
- Reverse-sync lag is expected: browser actions queue in web reverse queue and flush on the next sync pull.

## Related files
- `modules/jobsite.job.index.build`
- `modules/jobsite.job.load_all`
- `modules/jobsite.index.rebuild`
- `modules/site-yaml.job.scan_stray`
- `modules/jobsite.handler.assess-done`
- `modules/plugin.web.jobs.init_code`
- `modules/plugin.web.jobs.cache.read_all`
- `modules/plugin.web.jobs.sync`
- `modules/jobsite.sync.apply_reverse`
- `data/web-root/vhosts/jobs.vhost/index.html`
- `bin/vax-int`
- `configuration/zenki/external/start`

#,,..,,,.,,,.,.,,,,.,,.,,,,,.,,,.,,,.,,,,,.,,,.,.,...,...,..,,,..,,..,.,.,.,,,
#6N5GGUPZIOKPYKKCEH75NLOPK3DC7YYIDD7SDJZ3AR5JRSJTMSUR5X7CAQXXYFAPK4MY43PVRWRNM
#\\\|B66MRGVDKMF2KIS35JVF5JCXKQYYS5W6YRFVHBEQM7QDNV2EG4Z \ / AMOS7 \ YOURUM ::
#\[7]76WU2WJHZNRIVOGSNPA2USXSWOOJI3IYUO7Q7TWOOVGHIAAV52CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
## Reassess task-record preservation
`modules/jobsite.sync.apply_reverse` now copies the preserved `stage`/`status` from the on-disk job record into the in-memory task record before re-queuing an assessment. This closes a gap where `jobsite.handler.assess-done` treated reassessed jobs as unprotected and moved them to `assessed` even when they were already in `applied`/`interviewed`/`responded`/`rejected`/`skipped`/`archived`.

## Delete tab scope
The `löschen` tab and its counter now only show jobs whose `assertions.suggest.delete` is `true` **and** whose stage is not a user-owned decision (`to_apply`, `applied`, `interviewed`, `responded`, `rejected`, `skipped`, `archived`). Previously it also showed protected-state jobs such as `rejected` and `apply`.

## Commit batching
Changes were committed in four signed version-batched commits:
1. `jobsite: migrate job IDs and file ops to VAX encoding`
2. `web/sync: assessment preservation, jobs cache/sync, and orbital/zenki config`
3. `web-ui: jobs vhost controls, badges, bulk reassess, and dependency graph`
4. `docs: update kimi memory with jobs-pipeline work`
plus a follow-up commit `web-ui: keep user-owned stages out of the delete tab`.

#,,..,..,,.,,,.,,,,,.,,..,.,.,,,.,,.,,.,.,,,.,...,...,...,...,,,.,,.,,...,...,
#33DJ5OE6AZCWDCU5HB32GKQJMHX256QRHZ6M7MQU4GSYTHI5MNAMRZRZGMEUYSPORXGYXGVN2E3LI
#\\\|3FZYYDBWIR7HGT4B7NN4XYKYKFI64SY7RLVYJALVF6U5KZ2VR6S \ / AMOS7 \ YOURUM ::
#\[7]2L54YJBQ4GPCHASFTN5DS2PVSDPL3MZHJ3M4ZCOBF2G5NFVDW4AQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
