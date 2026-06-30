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
Updated to current cube command syntax; `list-connections` also added to external zenki access whitelist.

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

## Reassess task-record preservation
`modules/jobsite.sync.apply_reverse` now copies the preserved `stage`/`status` from the on-disk job record into the in-memory task record before re-queuing an assessment. This closes a gap where `jobsite.handler.assess-done` treated reassessed jobs as unprotected and moved them to `assessed` even when they were already in `applied`/`interviewed`/`responded`/`rejected`/`skipped`/`archived`.

## Delete tab scope
The `löschen` tab and its counter now only show jobs whose `assertions.suggest.delete` is `true` **and** whose stage is not a user-owned decision (`to_apply`, `applied`, `interviewed`, `responded`, `rejected`, `skipped`, `archived`). Previously it also showed protected-state jobs such as `rejected` and `apply`.

## Bulk delete button
A `✗ alle löschen` button in the `löschen` tab deletes all visible delete-suggested jobs with 5 concurrent workers. The confirmation dialog was removed because WebKit suppresses `confirm()`.

## Commit batching
Changes were committed in several signed version-batched commits:
1. `jobsite: migrate job IDs and file ops to VAX encoding`
2. `web/sync: assessment preservation, jobs cache/sync, and orbital/zenki config`
3. `web-ui: jobs vhost controls, badges, bulk reassess, and dependency graph`
4. `docs: update kimi memory with jobs-pipeline work`
5. `web-ui: keep user-owned stages out of the delete tab`
6. `web-ui: remove confirm() blocker and add bulk-delete button for delete tab`
7. `jobsite: archive deletions to deleted/ and block re-imports`
8. `jobsite: two-stage delete with compressed trash and configurable retention`

## Two-stage delete (trash → deleted)
Deletion now uses a recoverable compressed stage before permanent removal:

- **Stage 1 — `trash`**: `jobsite.sync.apply_reverse` sets status `trash`;
  `jobsite.job.write` stores the full job as `jobs/trash/<epoch>/<id>.yxz.B32`
  (xz-compressed YAML, base32-encoded). Retention is `jobsite.cfg.trash_keep_epochs`.
- **Stage 2 — `deleted`**: `jobsite.store.prune` decompresses trash files to
  `jobs/deleted/<epoch>/<id>.yaml` once `trash_keep_epochs` is exceeded.
  They remain for `jobsite.cfg.deleted_keep_epochs`, then the files are purged.
- **Repost blocking**: title/url checksum entries stay in `checksum-store/`
  (under `titles/deleted/` and `urls/<epoch>/`) so reposted offers remain blocked
  even after the job files are gone.
- `site-yaml.jobs.upsert` skips any job whose index status is `blocked`,
  `deleted`, or `trash`.
- `jobsite.init_code` runs `jobsite.store.prune` on startup so rotation/purging
  happens automatically.

#,,,.,...,,.,,...,...,,,.,,..,,,,,...,..,,,,,,.,.,...,...,..,,,..,,,.,,.,,..,,
#NLRWSNVVNHSRRORYUI7OWP5L367REYN65OAJVL56LPWYCMWKWSFPHHMFGKGJZ6AMXBKP32YSDF2JE
#\\\|JRLAJZIC632REGN47VUT4IKV3YA2DQCVFQGFYN3YR5UFEFZ56V5 \ / AMOS7 \ YOURUM ::
#\[7]6YQDP4RH2DEBGWD4YKSRZFXP5KWG5SWST55YXM2VENDLBQ37QMBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
## 2026-06-28 — Assessed jobs missing in web UI

Root cause: `plugin.web.jobs.sync` derived the UI `stage` from backend `status` only when `stage` was absent, and only mapped `apply` → `to_apply`. Legacy jobs with backend status `assessed` were stored in the web cache with `stage: assessed`, which the UI filter tabs do not include, so they never appeared.

Fix:
- `modules/plugin.web.jobs.sync` now maps `assessed` → `review` and `apply` → `to_apply`, and overwrites pipeline-owned stages (including `assessed`) while preserving user-owned stages (`to_apply`, `applied`, `interviewed`, `responded`, `rejected`, `skipped`, `archived`, `delete`).
- `modules/plugin.web.jobs.data` normalizes legacy `assessed`/`apply` stage values to UI stages on read, so existing web-cache entries show up immediately without waiting for a fresh jobsite push.

Status: code edited, needs `bin/Protocol-7 sourcecode update-signatures` and restart of `web` and `jobsite` zenki to take effect.

#,,,.,,,.,.,.,.,,,,..,,..,,.,,,,.,.,,,,.,,..,,..,,...,...,.,.,.,.,,.,,,..,..,,
#KG3YI7JA4SL6CF7ZJEFMKFC32LE4TF5CVMQWC37G4G3UAR3D762FH2P7LGYPAFA3F2FJGDKXSUWGI
#\\\|XP5BA7ECMCLRV5Y7LLSKBID37PBEGUMLH4V466XOUKDQYOOKPCI \ / AMOS7 \ YOURUM ::
#\[7]OS7LU6IIKSW6FSHH4M345OCW2WHQNAW4K3S2FGCXM7XTXPXDHKBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
## 2026-06-28 (continued) — Manually deleted jobs resurrected as assessed

After mapping `assessed` → `review`, the review tab filled with jobs the user had manually deleted. Root causes:

1. **Stale jobsite `assessed/` directory:** Old pipeline jobs with `status: assessed` and no `stage` field were never migrated by `jobsite.init_code` (the migration only matched `stage: assessed`). They kept being pushed to the web cache.
2. **Web cache still read `assessed/`:** `plugin.web.jobs.cache.read_all` treated `assessed` as an active status, so these stale files were loaded.
3. **Reverse-delete race:** A batch push from jobsite could re-add a job in the same sync cycle that the browser had asked to delete, before jobsite processed the delete.
4. **Reverse queue not persisted:** Pending browser delete/reassess actions were held only in memory and lost on web-zenka restart.

Additional fixes staged:
- `modules/jobsite.init_code`: migrate `status=assessed` jobs with empty/missing stage to trash.
- `modules/plugin.web.jobs.cache.read_all`: drop `assessed` from active statuses so stale files are ignored.
- `modules/plugin.web.jobs.sync`: skip re-adding jobs that have a pending reverse-delete and remove any resurrected on-disk cache copy.
- `modules/plugin.web.jobs.reverse.queue/flush` and `plugin.web.jobs.init_code`: persist the reverse queue to `reverse-pending.yaml` and reload it on startup.

Status: staged and version-bumped; needs `bin/Protocol-7 sourcecode update-signatures` and restart of `jobsite` + `web` zenki.

#,,,.,..,,,..,,,,,,.,,.,,,.,.,,..,.,.,,.,,..,,..,,...,..,,.,,,...,.,.,,,.,..,,
#WSB5IYWYYT3HA4UDAQBW3HSQ645XEIJD5YWDJOUVYJ46P6XI4ESZBX4UTXTESHBGAA2PNRC2NNYXY
#\\\|N3SZDL6O6YZNBVZ3MMW6LL3CN2ZMPAPEWWZWDYFNRQKMJMT33WA \ / AMOS7 \ YOURUM ::
#\[7]2BAYZZDI6T243Q65G7ZPEDXQZSQQD4RHYNVRVQY3DL4SMW4X54DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
