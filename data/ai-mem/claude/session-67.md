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

## additional commits (late session)

- `310e85a80` — feat: status/stage reconcile, progress bar fix, interviewed tab, prune wiring
- `1aee4bb85` — feat: UI card refinements, reassess button, flexible export + arch designs
- `96f3b93e6` — fix: ES5 compat (?./??→&&), sync_url fallback (//→||), sync multiplex
- `7451502ca` — feat: web plugin status-dir layout (phase 2)
- `1b0ff79f0` — fix: sync push status-dir awareness + apply_reverse path via index

### checksum store status-dir expansion — DONE ✓ (kimi 3e42231f)
12 files: titles/ per-status subdirs, `update_status` action (rename on
status change), `check` returns `resolved_status`, `interviewed` added to
all enumerations. `dispatch.assessments` inherits status from checksum store.

### status/stage reconcile — DONE ✓
`assess-done`: `status=review` set when score >= threshold (not just stage).
`job.load_all`: status overridden from dir index (authoritative). Migration
in `init_code` moves assessed+stage=review jobs to `jobs/review/`.

### progress bar — DONE ✓
counts from `<jobsite.job.index>` by dir name; `rev:152` shows correctly.
format: `new:0 | rev:152 | assessed:725 | apply:0`

### UI card refinements — DONE ✓
assertions.suggest.apply badge (✓/✗); dimension score row with detail
toggle; error tab wired to repair_failed; archive dimming; NaN filter fix
(`!isFinite(norm)`); repair_failed passthrough in jobs.data.

### reassess ↺ button — DONE ✓ (UI live; backchannel not yet propagating)
`jobsite.sync.apply_reverse` handles `action=reassess` (resets job, injects
at front of assess_queue). button appears subtly in cards. POST to /sync
works; forwarding to jobsite pending sync push update.

### flexible export — DONE ✓
export config panel: stage checkboxes + since-last-export filter (tracks
exported IDs in localStorage).

### web plugin phase 2 — DONE ✓
`plugin.web.jobs.cache.write` routes by status subdir, atomic rename.
`plugin.web.jobs.sync.merge`: priority map interviewed:8>applied:7>...
`plugin.web.jobs.store.prune`: two-phase epoch cleanup.

### sync push status-dir aware — DONE ✓
`jobsite.sync.push`: status from index, skip blocked/deleted.
`jobsite.sync.apply_reverse`: delete resolves path via index.

### ES5 compat fix — DONE ✓
all `?.` and `??` replaced with `&&`/ternary — mobile DuckDuckGo renders.

### arch design task files written (not dispatched)
- `data/tasks/web-auth-plugin.md` — plugin.web.auth.*, dual-loadable
- `data/tasks/web-sessions-distributed.md` — signed session tokens, cross-node
- `data/tasks/jobsite-sync-multiplex.md` — multi-endpoint + multi-jobsite

## reassess ↺ button — fully working — commit 00c2e2605

full loop confirmed working. multiple bugs fixed:

1. **action entries not queued** — browser POST `{action: reassess}` not in
   `@browser_fields` → `%changed` empty → nothing queued. fix: detect `action`
   field after browser_fields loop in `plugin.web.jobs.sync`, queue directly.

2. **reverse queue drained by browser POST** — `reverse.flush` called for ALL
   POSTs; browser POST consumed the reassess entry before jobsite ping arrived.
   fix: gate `reverse.flush` to `$is_batch` only in `plugin.web.jobs.sync`.

3. **pending_count off-by-one** — `apply_reverse` set
   `pending_count = 1 + scalar @{queue}` (queue had 1 item → count=2); after
   assess-done decremented once → stuck at 1, cycle never returned to idle.
   fix: `pending_count = scalar @{queue}` (= 1).

4. **sync push skipped** — `sync_interval=300` but push was skipping when no
   local changes, never collecting reverse entries. fix: send empty ping
   (`chunk=[]`) every sync cycle so reverse queue is always delivered.

5. **full resync instead of delta** — `assess-done` called `sync.push(undef,TRUE)`
   which bypasses the watermark (`$last_ntime_num = 0 if $force`) → sent ALL
   jobs. fix: `sync.push(undef, FALSE)` — only sends job with fresh last_modified.

result: click ↺ → web queues reverse entry → jobsite ping delivers it → assessment
runs at front of queue → delta push sends just the updated job → browser delta
poll picks it up. all cards in 'alle' tab now complete.

## open items

- **auth plugin** — dispatch next (`web-auth-plugin.md`); needed before atom sync
- **atom data recovery** — two layers:
  1. atom jobsite YAMLs (flat layout) → merge script using priority rules
  2. atom browser localStorage (applied/rejected stages) → extract via DevTools,
     POST as reverse-sync batch to `/jobs-sync`
- **multi-endpoint sync** — after auth + atom recovery
- **web-sessions-distributed** — low priority
- nshell `(0)` on first command — still open
- nshell stray cursor after index search — still open
- STRM fix review needed (had_local_consumer)

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

#,,,.,..,,.,.,,,,,,,.,,.,,,..,,,.,,..,,..,,,.,..,,...,...,,.,,,.,,,,,,.,,,,.,,
#7AR3A7BFZGLGH6LBO4SEZFVDIAJECKHS6WXWF2ECPBKJIGPNVDNK2R65OGOHNW5X4247XLPLHMFLI
#\\\|4OIQ7JJ7ZK7NARUT3S5ZRH3RMOKIVZEPEAD3UHWYIT3HPDJVAFV \ / AMOS7 \ YOURUM ::
#\[7]YT6Y53I7GX7N2JA4K3VDHQPT4S7GI7HZTLFWDRJZNCKMS5RFN6BI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
