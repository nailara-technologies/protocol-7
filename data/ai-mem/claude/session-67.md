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

`jobsite.checksum.index` `add` action wrote company checksums into `companies` index used by `blacklist_company` → all future jobs from that company blocked. Fix: removed company from `add`; only title + url checksums written. 64 blocked jobs reset and re-assessed.

## jobsite.cmd.reset fix for off-memory jobs — DONE ✓

`reset status=blocked` returned 0 because blocked jobs never added to `<jobsite.tasks>`. Fix: scan job files directly for status filter; conditional in-memory update when rec undefined.

## inline sub extraction: jobsite.util.fix_encoding — DONE ✓

`_build_mojibake_table` → `jobsite.util.fix_encoding.mojibake-table`; `_score_candidate` → `jobsite.util.fix_encoding.score-candidate`. Whitelist regenerated via `./bin/dev/gen-sub-whitelist jobsite`.

## filesystem checksum store rewrite — DONE ✓

Migrated from single YAML file to directory tree:
```
checksum-store/
  companies/blacklisted/<amos_chksum>
  titles/<bmw_l13_chksum>          ← pre-expansion flat
  urls/<V7EPOCH>/<bmw_l13_chksum>  ← epoch-bucketed
```
- `add`: writes title + url via `file.zenka_dir.write` (NOT company)
- `check`: `-e` existence checks + epoch scan
- `blacklist_company`: writes to companies/blacklisted/
- `prune`: removes url epochs older than keep_epochs (default 100)
- `load`/`persist`: no-ops (filesystem IS the store)
- migration: old YAML blacklist → companies/blacklisted/ on first run

## jobsite status-dir layout — DONE ✓

Migrated flat `/var/protocol-7/jobsite/jobs/*.yaml` to per-status subdirs:
```
jobs/new/ assessed/ review/ apply/ applied/ interviewed/ rejected/
jobs/blocked/<epoch_v7>/ jobs/deleted/<epoch_v7>/
```
New modules: `jobsite.job.index.build`, `jobsite.store.prune`. Modified: `job.read/write/load_all`, `init_code`, `dispatch.assessments`, `cmd.reset`, `handler.rescan-timer`.

### job.read utf8 fix — DONE ✓

`file.zenka_dir.load` with `:utf8` returns utf8-flagged string; `YAML::XS::Load` needs bytes. Fix: load raw, `utf8::encode` before YAML parse.

### checksum store status-dir expansion — DONE ✓

- `titles/` → per-status subdirs (`assessed/`, `review/`, `apply/`, `applied/`, `rejected/`, `interviewed/`)
- `update_status` action: rename checksum file on status change
- `check` returns `resolved_status` — caller routes directly without assessment
- new job status: `interviewed`
- `dispatch.assessments`: inherits status directly on checksum hit

### scan-state slim — DONE ✓

`state.load`/`persist` handle 4 fields only (cycle, last_scan, pending_count, sync_last_ntime). `<jobsite.tasks>` rebuilt from filesystem via `job.load_all` on every restart.

### enc_error/rep-err rename — DONE ✓

`encoding_broken` → `enc_error`, `repair_failed` → `rep-err` (harmony TRUE). Param line uses `<>` mandatory syntax at 54 chars.

### repair_failed jobs reset — DONE ✓

30 jobs with `repair_failed: 5` reset via `jobsite.reset rep-err=1` and re-assessed.

### reassess ↺ button — DONE ✓

Full loop working (commit 00c2e2605). 5 bugs fixed:
1. action entries not queued — detect `action` field after browser_fields loop
2. reverse queue drained by browser POST — gate `reverse.flush` to `$is_batch` only
3. pending_count off-by-one — `pending_count = scalar @{queue}`
4. sync push skipped — send empty ping (`chunk=[]`) every cycle
5. full resync instead of delta — `sync.push(undef, FALSE)`

### status/stage reconcile — DONE ✓

`assess-done`: sets `status=review` when score >= threshold. `job.load_all`: status overridden from dir index. Migration in `init_code` moves assessed+stage=review jobs to `jobs/review/`.

### progress bar — DONE ✓

Counts from `<jobsite.job.index>` by dir name. Format: `new:0 | rev:152 | assessed:725 | apply:0`.

### UI card refinements — DONE ✓

Assertions.suggest.apply badge; dimension score row with detail toggle; error tab wired to repair_failed; archive dimming; NaN filter (`!isFinite(norm)`); repair_failed passthrough.

### flexible export — DONE ✓

Export config panel: stage checkboxes + since-last-export filter (tracks exported IDs in localStorage).

### web plugin phase 2 — DONE ✓

`cache.write` routes by status subdir, atomic rename. `sync.merge`: priority map (interviewed:8>applied:7>...). `store.prune`: two-phase epoch cleanup.

### sync push status-dir aware — DONE ✓

`sync.push`: status from index, skips blocked/deleted. `sync.apply_reverse`: delete resolves path via index.

### ES5 compat fix — DONE ✓

All `?.` and `??` replaced with `&&`/ternary — mobile DuckDuckGo renders.

## additional commits (late session)

- `310e85a80` — feat: status/stage reconcile, progress bar fix, interviewed tab, prune wiring
- `1aee4bb85` — feat: UI card refinements, reassess button, flexible export + arch designs
- `96f3b93e6` — fix: ES5 compat (?./??→&&), sync_url fallback (//→||), sync multiplex
- `7451502ca` — feat: web plugin status-dir layout (phase 2)
- `1b0ff79f0` — fix: sync push status-dir awareness + apply_reverse path via index

## auth plugin — DONE ✓ commit 142da4c44

15 new modules: `plugin.web.auth.*` — session file store at `sessions/active/<token_hash>/session.yaml`, AMOS-checksum token, verify_session (Bearer/cookie), create/destroy/prune, login/logout/status. POST `/jobs-sync` gated; GET `/jobs.json` public. Dual-loadable in web + httpd.

## import-atom-jobs script — DONE ✓ commit 142da4c44

`bin/dev/import-atom-jobs <dir>` — merges atom flat-layout YAMLs into local status-dir store. Priority map tiebreaker. Prints imported/merged/skipped summary.

## CSV/HTML import — DONE ✓

47 applied, 3 interviewed, 5 rejected, 16 apply imported. Stale `/var/protocol-7/jobsite/index.yaml` deleted. `jobsite.cmd.status` reads from `<jobsite.job.index>`; vertical alignment; `base.sort` key order.

## jobsite.status fix — DONE ✓ commit 4b930b439

922 total with correct per-status counts. Format: `  %-12s : %d` with base.sort order.

## claude_dispatch + claude_continue — DONE ✓ commit 1adbf83d2

MCP tools in `bin/mcp-server-p7`. Claude CLI dispatch with `--dangerously-skip-permissions`, `--output-format stream-json`, model aliases (haiku/sonnet/opus), max_budget_usd guard, resume line. Tested: full kimi dispatch workflow. Strategic pattern: route kimi through claude_dispatch to keep parent context lean.

## arch design task files written (not dispatched)

- `data/tasks/web-auth-plugin.md` — plugin.web.auth.*, dual-loadable
- `data/tasks/web-sessions-distributed.md` — signed session tokens, cross-node
- `data/tasks/jobsite-sync-multiplex.md` — multi-endpoint + multi-jobsite

## iris tasks status

- alpha-density v2 — DONE ✓ (signature stub removed, impl already in c80c2a69e)
- ring ledger — DONE ✓ (already in c80c2a69e)
- route-commitment — next in queue: `data/tasks/iris-route-commitment.md`

## open items

- atom browser localStorage extraction — pri server jobs dir empty; extract via DevTools and POST as reverse-sync batch
- multi-endpoint sync — after auth settled
- web-sessions-distributed — lower priority
- ~~nshell `(0)` on first command~~ **FIXED 2026-06-02** — orphaned route handler generated `(0)!TERM!` for prefix-less replies
- nshell stray cursor after index search — still open
- STRM fix review needed (`had_local_consumer`)

## design notes

- `gen-sub-whitelist jobsite` → use `./bin/dev/gen-sub-whitelist jobsite` (bash, NOT p7c)
- `file.zenka_dir.write`: relative path from `/var/protocol-7/<zenka>/`, auto subdir + ownership
- `file.zenka_dir.load`: returns SCALAR REF; `utf8::encode` before YAML::XS::Load
- epoch distance: `int(<[base.ntime.epoch_dec]>)`
- checksum sync-only pattern: title checksum in `applied/` → future same-title inherits `applied` without assessment

#,,.,,,.,,.,.,.,.,,.,,,,,,.,.,,,,,..,,,,,,..,,..,,...,.,.,.,.,.,,,,,.,..,,,,,,
#Q3LX5NY2QTMKY5LSENLOE5XHIHBKRQSHUXWJ2HNKYS6HY63M5I4NGRIJNCU3RPQULPFL2MYEML6DW
#\\\|UYAF4DYCHSZSGCU7TALTX3YPPHDR23OCPJWB7J3DOVQ5CZ7CKCK \ / AMOS7 \ YOURUM ::
#\[7]SHDBCSVAKPS44XNP3JJJARSN6JOOQY3HSQRLXUOGBELFFEG6Q2AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
