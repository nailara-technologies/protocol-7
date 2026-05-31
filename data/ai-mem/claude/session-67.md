---
name: session-67
description: "jobsite dedup false positive fix, status-dir layout, checksum store rewrite, job.read utf8 fix"
metadata:
  type: project
  originSessionId: session-67
---

## commits this session

- `f70d841eb` — fix: jobsite dedup false positives + reset for off-memory jobs
- `5846902bc` — feat: filesystem directory-based checksum store for jobsite dedup

## jobsite dedup false positive fix — DONE ✓

`jobsite.checksum.index` `add` action was writing company checksums into the
same `companies` index used by `blacklist_company`. after assessing any job,
its company was permanently added to the in-memory index → all future jobs from
that company blocked as "duplicates". fix: removed company from `add` — only
title + url checksums written on assessment. 64 blocked jobs reset to new and
re-assessed.

## jobsite.cmd.reset fix for off-memory jobs — DONE ✓

`reset status=blocked` returned 0 because blocked jobs were never added to
`<jobsite.tasks>`. fix: when `status=` filter given, scan job files directly
for matching status. also: `next unless defined $rec` replaced with conditional
in-memory update, allowing file-only reset when rec not in memory.

## inline sub extraction: jobsite.util.fix_encoding — DONE ✓

extracted `_build_mojibake_table` → `jobsite.util.fix_encoding.mojibake-table`
and `_score_candidate` → `jobsite.util.fix_encoding.score-candidate`.
whitelist regenerated via `./bin/dev/gen-sub-whitelist jobsite`.

## filesystem checksum store rewrite — DONE ✓

`jobsite.checksum.index` rewritten from single YAML file to directory tree:
```
checksum-store/
  companies/blacklisted/<amos_chksum>   ← file exists = blacklisted
  titles/<bmw_l13_chksum>               ← file exists = title seen (flat, pre-expansion)
  urls/<V7EPOCH>/<bmw_l13_chksum>       ← epoch-bucketed url dedup
```
- `add`: writes title + url via `file.zenka_dir.write` (NOT company)
- `check`: `-e` file existence checks + scan all epoch dirs for url
- `blacklist_company`: writes to companies/blacklisted/
- `prune`: removes url epoch dirs older than keep_epochs (default 100)
- `load`/`persist`: no-ops (filesystem IS the store)
- migration: reads old YAML blacklist on first run → writes to companies/blacklisted/
- uses `file.zenka_dir.write` for all writes (proper ownership, auto subdir creation)

## jobsite status-dir layout — DONE ✓ (kimi, in-progress expansion)

kimi dispatched task `jobsite-status-dir-layout.md`. migrated flat
`/var/protocol-7/jobsite/jobs/*.yaml` to per-status subdirs:
```
jobs/new/ assessed/ review/ apply/ applied/ interviewed/ rejected/
jobs/blocked/<epoch_v7>/ jobs/deleted/<epoch_v7>/
```
new modules: `jobsite.job.index.build`, `jobsite.store.prune`
modified: `jobsite.job.read/write/load_all`, `jobsite.init_code`,
`jobsite.dispatch.assessments`, `jobsite.cmd.reset`, `jobsite.handler.rescan-timer`

### job.read utf8 fix — DONE ✓ (uncommitted)
`file.zenka_dir.load` with `:utf8` returns utf8-flagged string;
`YAML::XS::Load` needs bytes. fix: load raw, `utf8::encode` before YAML parse.
caused "jss.job.read: load error for X:" during assessment cycle.

## checksum store status-dir expansion — IN PROGRESS (kimi continue)

kimi continue session `3e42231f-76f9-4a62-9e61-a9ddaa442070` expanding:
- `titles/` from flat → per-status subdirs (`assessed/`, `review/`, `apply/`,
  `applied/`, `rejected/`, `interviewed/`)
- new `update_status` action: rename checksum file on status change
- `check` returns `resolved_status` field — caller routes directly without assessment
- new job status: `interviewed` (between applied and terminal)
- `dispatch.assessments`: on checksum hit with resolved_status, inherit status directly

## phase 2 task file — written, not dispatched

`data/tasks/web-jobs-status-dir-layout.md` — mirrors status-dir layout in
web plugin, adds sync path awareness, merge conflict resolution (highest
priority status wins), delta sync compatible.

## additional commits this session

- `3df3f7a49` — feat: jobsite progress bar, scan-state slim, reset enc_error/rep-err
- `bd877527c` — doc: memory maintenance

### jobsite.cmd.progress — DONE ✓
new module: ascii progress bar matching bin/ptd style. 13-char `:` fill
proportional to (total-new)/total. right bracket: cycle-aware — shows
"assessing: N remaining" when active, "scanning sites.." when fetching,
"assessed: N  review: N  new: N" when idle. TRUE reply, no trailing \n.
access added to cube line in jobsite/start.

### scan-state slim — DONE ✓
`state.load` and `state.persist` now handle only 4 fields: cycle,
last_scan, pending_count, sync_last_ntime. `<jobsite.tasks>` rebuilt from
filesystem via `job.load_all` on every restart. no more divergence.

### jobsite.cmd.reset enc_error/rep-err rename — DONE ✓
`encoding_broken` → `enc_error` (harmony TRUE), `repair_failed` → `rep-err`
(harmony TRUE). param line uses `<>` mandatory syntax at 54 chars.

### repair_failed jobs reset — DONE ✓
30 jobs with `repair_failed: 5` reset via `jobsite.reset rep-err=1` and
re-assessed via `jobsite.scan`.

## open items

- kimi continue session `3e42231f` — checksum store status-dir expansion
  (titles/ per-status, resolved_status, interviewed status); may be complete
- phase 2 (web-jobs-status-dir-layout.md) not dispatched yet
- remote atom divergence: atom has applied jobs, local doesn't — sync/merge pass needed
- nshell `(0)` on first command bug — still open
- nshell stray cursor after index search — still open
- `review: 0` in progress bar — `<jobsite.tasks>` uses `status` field but
  review jobs have `status=assessed` + `stage=review`; needs investigation

## design notes

- `gen-sub-whitelist jobsite` → use `./bin/dev/gen-sub-whitelist jobsite` (bash, NOT p7c)
- `file.zenka_dir.write` takes relative path from `/var/protocol-7/<zenka>/`, handles
  subdir creation + ownership automatically
- `file.zenka_dir.load` returns SCALAR REF; needs `utf8::encode` before YAML::XS::Load
- epoch distance calculation: `int(<[base.ntime.epoch_dec]>)` - decoded epoch number
- checksum sync-only pattern: title checksum in `applied/` dir → any future scrape of
  same title inherits `applied` status without assessment → enables multi-site sync
  via checksum store deltas only

#,,,,

#,,..,,,,,,,.,.,.,,..,..,,.,.,..,,,.,,.,,,.,,,..,,...,...,...,,,,,,.,,...,...,
#PA22L5Q43VDCBYM66KSJSKTQDBV7HRS7EE6VCXM2LWGQSSTIO2RLWT6C24YZVR6CM2HP2IBQMYP6S
#\\\|N3ISSYF76JCA66VKZSJPKMUCIDHEPHWRPIY757NXHOVZ6YX3NK5 \ / AMOS7 \ YOURUM ::
#\[7]HDBUQNYKESYVJKHSMPZA4CB6ATXDFSNRLUYJO5EZIZHLA75KFIBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
