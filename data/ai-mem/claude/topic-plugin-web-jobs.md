---
name: plugin-web-jobs-web-jobs-data-plugin
description: plugin.web.jobs.* for bi-directional job pipeline sync via web zenka — sync bugs, localStorage layer, multi-backend
metadata: 
  node_type: memory
  type: project
  originSessionId: 095ef9b6-c744-46c5-bac8-4d54a2d5ce45
---

## Session 2026-06-28 — sync fixes + browser localStorage layer (39c5626d1)

### Root bugs fixed

**Bug 1 (apply_reverse memory gap)**: `apply_reverse` updated job file stage on
disk but not `<jobsite.tasks>` in memory. `assess-done` protect check reads
`<jobsite.tasks>` — so it saw stale `stage: review` and clobbered browser-set
`stage: applied`. Fix: after writing job file, sync stage into `<jobsite.tasks>`:
```perl
my $tasks = <jobsite.tasks>;
$tasks->{$id}{'stage'} = $entry->{'stage'}
    if ref $tasks eq 'HASH' and defined $tasks->{$id};
```
Guard with `ref ... eq 'HASH'` — `//` only protects against undef, not `1` (which
`<jobsite.tasks>` can be in certain code paths, causing "string ('1') as HASH ref").

**Bug 2 (last_modified not bumped on browser updates)**: when browser POSTs stage
change to `/jobs-sync`, web cache was updated but `last_modified` was not bumped.
Other browsers' `?since=<ntime>` delta queries missed those changes. Fix: set
`$cached->{'last_modified'} = <[base.ntime.b32]>` in the browser-update path of
`plugin.web.jobs.sync` when `%changed` is non-empty.

### Browser localStorage layer (`jobs_user_decisions_v1`)

`userDecisions` map in localStorage tracks explicit user choices: `{id: {stage, notes, date_applied, ts}}`.

- `setStage()` writes to `userDecisions` before `saveCache()`
- note + date_applied input handlers also write to `userDecisions`
- `mergeJobs()` applies server data first, then overlays `userDecisions` on top for
  user-owned stages: `to_apply applied interviewed responded rejected skipped archived`
- reassess button clears `userDecisions[id]` so fresh assessment result can land
- user decisions survive server batch pushes — stage drift is eliminated

**Reset button** now clears BOTH `jobs` and `userDecisions` (and dialog is honest
about what's lost). The ↻ **sync button** now does `lastNtime = 0` full resync
without touching `jobs` or `userDecisions` — use this instead of reset for stale data.

### dblclick undo toast

Native `dblclick` replaced with custom 260ms timing on `click` events (tighter
than OS threshold). On trigger: shows `prevStage → newStage  rückgängig` toast for
3s. Clicking "rückgängig" calls `setStage(id, prevStage)` via `restoreFn` callback
passed to `notifyUndo(id, prevStage, setStage)`.

### Multi-backend readiness

Push side already supports multiple backends via `sync_urls` (space-separated).
Per-URL watermarks in `<jobsite.sync.last_ntime>->{$url}`. Reverse entries
accumulated from all backends into one `push_reverse` list. To enable:
```
jobsite.cfg.sync_url      =
jobsite.cfg.sync_urls     = http://host-a/jobs-sync http://host-b/jobs-sync
```
Web caches between backends are NOT peer-synced — jobsite is the hub. Changes on
backend A reach backend B only after next jobsite push cycle.

---

## Current State (session 34, 2026-05-19) — SYNC FULLY WORKING ✓

**delta sync confirmed working**: `jobsite: sync push skipped [ no changes since ... ]`

**root cause of full syncs**: `encode_b32r` is reverse-byte-order encoding — NOT
lexicographically sortable. `$mod gt $last_ntime` string comparison was always wrong.
Fix: use `<[base.ntime_BASE32_to_numerical]>` to decode both sides, compare numerically.
Diagnose with: `p7c localtime <ntime_b32>` — shows wall clock time for any ntime.

**watermark uses LOCAL ntime** (not server ntime) — `push_cycle_ntime` recorded at
cycle start, set as `last_server_ntime` after all chunks complete. Persisted via
`state.persist` so it survives jobsite restarts.

**site-yaml → jobsite.job.write stamps last_modified** on every upsert → newly
scanned/assessed jobs automatically appear in next incremental sync.

**chunked 30 jobs/POST** — stays within 242KB session buffer ceiling.

## Route flow

httpd route registry → httpd.route.handler.web-relay → route-send to web zenka
→ web.cmd.jobs-data / web.cmd.jobs-sync → plugin.web.jobs.data/sync → STRM reply
→ httpd.handler.web-relay.strm_open → HTTP client

## Module layout

- `plugin.web.jobs.init_code` — preloads JSON::XS + YAML::XS, creates var_P7/web/jobs/
- `plugin.web.jobs.data` — STRM reply handler: reads web cache, returns JSON
- `plugin.web.jobs.sync` — handles batch jobsite push OR single browser update
- `plugin.web.jobs.cache.write` / `cache.read_all` — in-memory + disk cache ops
- `plugin.web.jobs.reverse.queue` / `.flush` — browser reverse sync queue

## Storage

```
/var/protocol-7/jobsite/jobs/{status}/{job_id}.yaml  # directory = authoritative status
/var/protocol-7/web/jobs/{status}/{job_id}.yaml      # web cache (per httpd instance)
```

Status dirs: new assessed review apply applied interviewed rejected blocked deleted

## Merge strategy

Pipeline fields (batch push from jobsite): title company url score score_reason
score_summary fetched_at status stage description last_modified blocked_epoch checksum_hit

Browser fields (POST from browser): stage notes date_applied

stage appears in both — pipeline sets it, browser can override via reverse sync.
`userDecisions` localStorage ensures browser override survives subsequent pipeline pushes.

## Config (jobsite start)

```
jobsite.cfg.sync_url      = http://172.24.33.224/jobs-sync   # single backend
jobsite.cfg.sync_urls     =                                   # multi: space-separated
jobsite.cfg.sync_interval = 300
```

## Client-side architecture

- `jobs_[vhost]_v1` localStorage: full jobs map + lastNtime watermark + minScore
- `jobs_user_decisions_v1` localStorage: user-owned field overrides (survives mergeJobs)
- `jobs_user_decisions_v1` is NOT cleared by sync button, only by reset button
- ↻ sync button: resets lastNtime=0, does full `/jobs.json` fetch, keeps all local data
- reset button: clears jobs + userDecisions + lastNtime (destructive, dialog warns)
- 30s auto-poll via `startPoll()` using `?since=lastNtime` delta

#,,..,...,.,.,,..,,,,,.,,,..,,,..,,,.,,,.,.,.,..,,...,...,...,,.,,...,,.,,.,,,
#7XCYPR2QHWIELLB4WVWYMAUXXPKAG7LNIRUVXELZNVLJ2ESYWNNMJGE7ORDC2Z3JWUWRMH5RPS25K
#\\\|XVED355QMD2FP57MU57U3AWZPMULAJUM6EXNK7CXXXENS7CA4IA \ / AMOS7 \ YOURUM ::
#\[7]BI72QIP46ZY3MCC46TG6XWYYT243Q4APA4AU4W3FDLLDCVAE54BY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
