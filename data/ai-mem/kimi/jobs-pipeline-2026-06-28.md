# Jobsite/Web Jobs Pipeline — 2026-06-28

## Context
A series of regressions and missing features in the jobsite/web jobs pipeline were fixed in a single session. The work touched indexers, sync handlers, the web UI, and orbital subscriber command syntax.

## Root Cause: `skipped` status omitted from active indexes
`skipped` jobs were manually asserted but disappeared from the web UI because no scanner treated `skipped` as an active status. Added `skipped` to active-status lists in:
- `src/jobsite.job.index.build`
- `src/jobsite.job.load_all`
- `src/jobsite.index.rebuild`
- `src/site-yaml.job.scan_stray`
- `src/plugin.web.jobs.init_code`
- `src/plugin.web.jobs.cache.read_all`

After the fixes, indexes were rebuilt and counts aligned (≈1409 jobs).

## Protected manual decisions during reassessment
`src/jobsite.handler.assess-done` now treats `applied interviewed responded rejected skipped archived` as protected stages, so reassessment does not overwrite manual skip/reject decisions.

## Web sync improvements
- `src/plugin.web.jobs.sync` now carries `assertions` in the pipeline field list so the UI can render score suggestions and badges.
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
- `src/jobsite.job.index.build`
- `src/jobsite.job.load_all`
- `src/jobsite.index.rebuild`
- `src/site-yaml.job.scan_stray`
- `src/jobsite.handler.assess-done`
- `src/plugin.web.jobs.init_code`
- `src/plugin.web.jobs.cache.read_all`
- `src/plugin.web.jobs.sync`
- `src/jobsite.sync.apply_reverse`
- `data/web-root/vhosts/jobs.vhost/index.html`
- `bin/vax-int`
- `cfg/zenki/external/start`

## Reassess task-record preservation
`src/jobsite.sync.apply_reverse` now copies the preserved `stage`/`status` from the on-disk job record into the in-memory task record before re-queuing an assessment. This closes a gap where `jobsite.handler.assess-done` treated reassessed jobs as unprotected and moved them to `assessed` even when they were already in `applied`/`interviewed`/`responded`/`rejected`/`skipped`/`archived`.

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
- `src/plugin.web.jobs.sync` now maps `assessed` → `review` and `apply` → `to_apply`, and overwrites pipeline-owned stages (including `assessed`) while preserving user-owned stages (`to_apply`, `applied`, `interviewed`, `responded`, `rejected`, `skipped`, `archived`, `delete`).
- `src/plugin.web.jobs.data` normalizes legacy `assessed`/`apply` stage values to UI stages on read, so existing web-cache entries show up immediately without waiting for a fresh jobsite push.

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
- `src/jobsite.init_code`: migrate `status=assessed` jobs with empty/missing stage to trash.
- `src/plugin.web.jobs.cache.read_all`: drop `assessed` from active statuses so stale files are ignored.
- `src/plugin.web.jobs.sync`: skip re-adding jobs that have a pending reverse-delete and remove any resurrected on-disk cache copy.
- `src/plugin.web.jobs.reverse.queue/flush` and `plugin.web.jobs.init_code`: persist the reverse queue to `reverse-pending.yaml` and reload it on startup.

Status: staged and version-bumped; needs `bin/Protocol-7 sourcecode update-signatures` and restart of `jobsite` + `web` zenki.

#,,,.,..,,,..,,,,,,.,,.,,,.,.,,..,.,.,,.,,..,,..,,...,..,,.,,,...,.,.,,,.,..,,
#WSB5IYWYYT3HA4UDAQBW3HSQ645XEIJD5YWDJOUVYJ46P6XI4ESZBX4UTXTESHBGAA2PNRC2NNYXY
#\\\|N3SZDL6O6YZNBVZ3MMW6LL3CN2ZMPAPEWWZWDYFNRQKMJMT33WA \ / AMOS7 \ YOURUM ::
#\[7]2BAYZZDI6T243Q65G7ZPEDXQZSQQD4RHYNVRVQY3DL4SMW4X54DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
## 2026-06-28 (continued) — Checksum store inherits legacy `assessed`

After restart, the log showed duplicate jobs inheriting `status=assessed` from the checksum store. The checksum store's title dedup still resolves to the old `assessed` directory (and some entries are in `deleted`), so every duplicate title was resurrected as assessed and then migrated to trash.

Fix staged in `src/jobsite.dispatch.assessments`:
- Map checksum `resolved_status` `assessed` → `trash`
- Map checksum `resolved_status` `deleted` → `trash` (keeps duplicates recoverable)
- Set `stage=trash` and `trash_epoch` when inheriting trash

Status: staged and version-bumped; needs `bin/Protocol-7 sourcecode update-signatures` and restart of `jobsite` zenka.

#,,,,,,,,,,,,,,,,,,.,,.,,,.,.,,.,,.,.,..,,.,.,..,,...,..,,...,,,.,...,,..,.,,,
#Y4XQFFEUTNMQ6VM3MEXPCZ6XHRMTM55DSPQKRHFJI2CLNJPMX4ZRTBLBR7AHENMO7G3KXWMAIKMYS
#\\\|TMB7GQQY7K35SHMFQN7O37AEURQRDNBP5YID77S2Q7JJOTGADUL \ / AMOS7 \ YOURUM ::
#\[7]ROSEJHI2BHUP7ID3J6XTPHQCM534MJCD33I26DNX22ZEQWKCMADA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
## 2026-06-28 (continued) — Web cache rot and trash push bug

After both zenki restarted, the empty review card for the reassessed job (LLF5Q) remained because:
- `jobsite.sync.push` was setting `status` to `trash:V7L36RQ` (including epoch) for trash jobs, causing `plugin.web.jobs.cache.write` to create a `trash:V7L36RQ/` directory.
- The web cache cleanup only pruned entries loaded from active directories, so stale files in the deprecated `assessed/` dir and the weird `trash:V7L36RQ/` dir were never removed.
- Browser localStorage can also keep a deleted job visible until cleared.

Additional fixes staged:
- `src/jobsite.sync.push`: strip `trash:<epoch>` to `trash`, and skip trash jobs from the push entirely.
- `src/plugin.web.jobs.init_code`: remove the legacy `assessed/` cache directory and any `trash*` directories on startup; also keep the in-memory prune for active dirs.

Status: staged and version-bumped; needs `bin/Protocol-7 sourcecode update-signatures` and restart of `jobsite` + `web` zenki. After restart, clicking the UI "reset" button will clear any leftover localStorage ghosts.

#,,,.,,,,,..,,..,,..,,,..,...,..,,.,,,..,,.,,,..,,...,...,.,,,,,.,,.,,,,.,,.,,
#K6FR5EV6WSL6BEW4YTYJBZX67XAXNVDLQLLFALRHDRYXOJ2LYN5SAP3UCZ6IAJQ53ZKYIUK4UPK7Q
#\\\|ZPYF5STXLXI5IVTBFGCKOZADBAWHBVFG2WHPLBX6ATARXE5OXBW \ / AMOS7 \ YOURUM ::
#\[7]MCOQ4IINWE25Q53DY2WGELZ7FDXY74RMVNNFTECNVMAKVG3GR6CA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
## 2026-06-28 (continued) — Cache cleanup used wrong index; regex warning

Two regressions introduced by the previous fix:

1. **`plugin.web.jobs.init_code` used `jobsite/index.yaml`**, which is incomplete (only ~45 entries). The cleanup treated all loaded cache entries as stale and wiped the entire web cache.
2. **`jobsite.sync.push` regex had no capture group**, causing `undef value $1` warnings because the pattern used non-capturing `(?:blocked|deleted|trash)`.

Fixes staged:
- `src/plugin.web.jobs.init_code`: build the active-job set by scanning the jobsite status directories directly.
- `src/jobsite.sync.push`: use a capturing group `^((?:blocked|deleted|trash)):.*` so `$1` is defined.

Status: staged and version-bumped; needs `bin/Protocol-7 sourcecode update-signatures` and restart of `jobsite` + `web` zenki.

#,,..,,,.,.,.,,,,,,,,,...,...,,,,,.,,,..,,..,,..,,...,..,,...,...,,.,,,.,,,.,,
#MOGAROZBLOTRS5MC2Z3VI4F7BNK2VXPUTIJ7Y24QCUJZGUECAJE2LZDIWQMSXLFYU3X3GJ64ZON4A
#\\\|VI7K3OMFRYHP4DSS2XQJEF6LHRPXS5RWN2H24B5LJ5EWZ6NATXI \ / AMOS7 \ YOURUM ::
#\[7]LYHWARWZNRLFMQQRNQ63XTORXOHWDJLOZTCRSHLCMC6QIVBBRCCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
## 2026-06-28 (continued) — UI bulk action buttons

The user noticed the bulk action buttons had wrong stage targeting:

- `REASSESS_ALL_STAGES` was `['applied','interviewed','responded','rejected','skipped']`, causing a "re-assess all" button to appear in the skipped tab, which makes little sense.
- The intended use was for empty cards in the `review` tab.
- A bulk "delete all" button would be more useful in `skipped`.

Fix staged in `data/web-root/vhosts/jobs.vhost/index.html`:
- `REASSESS_ALL_STAGES = ['review']` (only when visible cards lack score/summary).
- New `DELETE_ALL_STAGES = ['delete', 'skipped']`.
- `deleteAllVisible()` now targets assertion-delete jobs in the delete tab and all visible jobs in other delete-all stages (e.g., skipped).

Status: staged and version-bumped; needs `bin/Protocol-7 sourcecode update-signatures` and restart of `web` zenka (or browser hard-refresh for static file).

#,,..,...,..,,,.,,...,.,,,,,,,,,,,,,.,...,...,..,,...,...,,,.,...,,,.,..,,,..,
#2HHQXKJSTMXT4CSNTSLDMKR5WTEBJQPD3WAAYG6NQ7Q3RDJO4FYONVBCXIN7BO6TNFPIHRUOIJZSC
#\\\|M4S5USB23CI5TAVMYQLN52BXODI7HWEWTBPWX2M2Q5BC42GYUIZ \ / AMOS7 \ YOURUM ::
#\[7]YG4VRY374CDGWO5AOZIYFIMC4LJIZTV5OM2CCCAJD7EPVYAN5YCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
## 2026-06-28 (continued) — Export/print table empty

The export/print table showed 0 entries because `saveExportPrefs()` read checkboxes that only exist after the export panel was opened. If the user clicked "show table" without first opening the CSV export panel, the stage set was empty.

Fix staged in `data/web-root/vhosts/jobs.vhost/index.html`:
- `saveExportPrefs()` falls back to `DEFAULT_EXPORT_STAGES` when no checkboxes are present.
- Also guards checkbox reads with optional chaining.

Status: staged and version-bumped; needs `bin/Protocol-7 sourcecode update-signatures` and restart of `web` zenka / browser hard-refresh.
## 2026-06-28 (continued) — Export table refinements

The export/print table was showing rejected entries and an internal "Del" column, which is unsuitable for a jobcenter report.

Changes staged in `data/web-root/vhosts/jobs.vhost/index.html`:
- `DEFAULT_EXPORT_STAGES` changed to `['applied','interviewed','responded']` (removed `rejected`).
- Removed the "Del." column from the print table overview.
- Added an age slider in the export panel (7–365 days, default 90) to limit how old included entries can be.
- `getExportRows()` now filters by `maxAgeDays`.

Status: staged and version-bumped; needs `bin/Protocol-7 sourcecode update-signatures` and restart of `web` zenka / browser hard-refresh.
## 2026-06-28 (continued) — Export date + editable city

Additional staged changes:
- `data/web-root/vhosts/jobs.vhost/index.html`:
  - Print table now shows `date_applied` when set, otherwise `date_added`.
  - Added inline editable city input in each job card; changes persist to `userDecisions`, local cache, and are pushed to the server.
  - `mergeJobs()` restores user-edited `city` from `userDecisions` after server merge.
- `src/plugin.web.jobs.sync`: `city` added to browser-owned fields for single-browser updates.
- `src/jobsite.sync.apply_reverse`: `city` added to reverse-applied fields so browser edits reach the jobsite store.

Status: staged and version-bumped; needs `bin/Protocol-7 sourcecode update-signatures`, commit, and restart of `web` and `jobsite` zenki + browser hard-refresh.
## 2026-06-28 (continued) — Print dimension spacing

- `data/web-root/vhosts/jobs.vhost/index.html`: dimension list in print details now formats as `name : score -` with two spaces between items.

Status: staged and version-bumped; needs signature + commit + restart `web` and `jobsite` zenki.
## 2026-06-28 (continued) — City backfill from jobsite

Root cause of empty city fields: the web-cache copies of jobs did not contain the `city` field even though the jobsite YAMLs did (the field was likely added to jobsite after the initial sync, so the web cache never received it).

Fix in `src/plugin.web.jobs.init_code`:
- When the web zenka initializes, scan active jobsite status directories.
- For any active web-cache job that is missing `city`, load the corresponding jobsite YAML and copy `city` into the web cache.
- Bump `last_modified` on the web-cache copy so browsers receive the update via delta sync.

This runs automatically at web zenka startup and is idempotent.

Status: staged and version-bumped; needs signature + commit + restart `web` and `jobsite` zenki.

#,,..,.,.,.,,,.,.,...,..,,.,,,,,,,,..,,,,,...,..,,...,...,.,,,...,,,,,.,.,,.,,
#HVJ2QAEBJNDJW3MVRX6TGF7VNHD6FRC7ZTG3ICW3CPVX2LSVD7PVCPFZZP5MNOSXOXPLHZSEVJSWA
#\\\|QVUK3PGIQLAWM7HNWTZP3GQ4C434UXTYEEVQBVFMU2FUYAJFKI7 \ / AMOS7 \ YOURUM ::
#\[7]M4TIDIW4GRF3MEDMC2RGMALWU223FAKWFFIPQOAQYNHXPLK5NMDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
## 2026-06-28 — Export/city fixes committed

Commit `edda48f11` landed:
- `data/web-root/vhosts/jobs.vhost/index.html`: print table uses `date_applied`, editable city input, dimension spacing.
- `src/plugin.web.jobs.init_code`: backfills missing `city` from jobsite YAML at web zenka startup.
- `src/plugin.web.jobs.sync` + `src/jobsite.sync.apply_reverse`: `city` is a browser-owned field.

Verified: after `v7 restart web jobsite` and browser hard-refresh, city fields populated.
## 2026-06-28 (continued) — Export rejected usability

- `data/web-root/vhosts/jobs.vhost/index.html`:
  - Export stage checkboxes now show German labels (e.g., `absage` for `rejected`) with the raw stage as tooltip.
  - Added a "letzten export vergessen" button in the export panel. This clears `jobsite_last_export_ids` so previously-exported rejected entries can be reported again.

The ability to export rejected entries already existed via the stage checkboxes; the new labels and clear-history button make it discoverable.

Status: staged and version-bumped; needs signature + commit + restart `web` zenka.
## 2026-06-28 (continued) — Visible export stage toggles

- `data/web-root/vhosts/jobs.vhost/index.html`: added a visible row of stage checkboxes directly in the `.export-section` below the table buttons.
  - Toggles: `beworben`, `interviewed`, `rückmeldung`, `absage`.
  - They share the `export-stage-cb` class with the advanced panel, so `saveExportPrefs()` captures both sets.
  - Toggling updates the print table live if it is open.

Status: staged and version-bumped; needs signature + commit + restart `web` zenka.
## 2026-06-28 (continued) — Visible age + since-last filters

- `data/web-root/vhosts/jobs.vhost/index.html`: moved the age slider and "bereits exportierte ausblenden" checkbox out of the hidden export panel into the visible `.export-section`.
  - `max. alter` slider limits included entries by age (default 90 days).
  - `bereits exportierte ausblenden` hides entries already exported before.
  - `letzten export vergessen` clears the export history.
  - The hidden panel now only holds additional stage checkboxes and "current filter only".

Status: staged and version-bumped; needs signature + commit + restart `web` zenka.
## 2026-06-28 (continued) — date_added backfill + table tweak

- `src/plugin.web.jobs.init_code`: backfill now also copies `date_added` from jobsite YAML into web cache when missing. It tries `date_posted` first, then `fetched_at`.
- `data/web-root/vhosts/jobs.vhost/index.html`:
  - Slider step changed to 1 day; styled to match the min-score slider; clear-history button opacity reduced.
  - Removed the internal `Bew.` column from the printable overview table.

Status: staged and version-bumped; needs signature + commit + restart `web` zenka.

#,,..,...,.,,,,.,,.,,,,.,,,..,,,,,..,,,,,,...,..,,...,...,.,,,,.,,,.,,..,,,..,
#GQ7ME37YAUMVUL4RB5WIONRRDCHWSYPKTBWU7DRXQNN5NK2WHS4FWON4B5C5OSGLV7VD2MANV56B6
#\\\|7VKXWWERBQCXOJ2HYDLNL3R5I2VONGXBXSOGFJRAMNPVPZ54KIS \ / AMOS7 \ YOURUM ::
#\[7]2SGSTXFPKU4V7WXC2JI6JYKAYCR4MKQIVLQFWGTQNPA4K4KFT4CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
## 2026-06-28 — Final export/city/date fixes committed

Commit `a8994ac5d` landed:
- 1-day step age slider, styled like min-score slider.
- Visible stage toggles + age + since-last filters in export section.
- Removed internal `Bew.` column from print table.
- Backfill `city` and `date_added` from jobsite YAML at web zenka startup.
- `city` editable inline and synced browser ↔ jobsite.

Next: restart `web` zenka and hard-refresh browser.

#,,,,,,,,,.,,,..,,,.,,,,.,..,,..,,..,,,..,.,,,..,,...,...,.,,,...,.,,,,,,,,.,,
#M3VAKEU7ROBXGVALSXK3FUVI4QIULXORYSEBSJ575XF5KRMXCRK2THFLI622SBH6V3ULRYPEWFBPA
#\\\|6HCH5H75MIVU2XAE2KRDCTZ5KC3KO4A257F6R3KMDKQZ2AZ4C4G \ / AMOS7 \ YOURUM ::
#\[7]GM3HWWDIJGY5AX7K66Y5SF77S7P5U2QUMMEAAVIRE7DNOEIKEMBY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
