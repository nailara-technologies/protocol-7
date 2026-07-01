---
name: plugin-web-jobs-web-jobs-data-plugin
description: plugin.web.jobs.* for bi-directional job pipeline sync via web zenka — sync bugs, localStorage layer, multi-backend
metadata: 
  node_type: memory
  type: project
  originSessionId: 095ef9b6-c744-46c5-bac8-4d54a2d5ce45
---

## Session 2026-07-01 (later) — reassessment-trashing incident: root cause chain, 3-tier cache divergence, fixes

**Trigger**: an already-`applied` job got silently trashed by an automated re-assessment
pass, despite trash being documented as "recoverable". Investigation escalated into a
much larger "all data is corrupted" report — three simultaneously-open views (backend
`jobsite.status`, user's real Firefox, the `web-browser` zenka) showing different
`beworben`/`interviewed` counts for the same dataset.

**Landed fixes (commits `73891350a`, `5da0f2b99`, `db26e9960`)**:
- `jobsite.handler.repair-done` / `jobsite.handler.assess-done`: added `%protected_stage`
  guard (`applied interviewed responded rejected skipped archived`) so pipeline reassessment
  can no longer silently overwrite a user-committed stage — preserves stage, derives matching
  status instead of forcing review/trash.
- `jobsite.handler.task-created`: the actual deepest root cause — was unconditionally setting
  `stage='assessing'` on reassess dispatch, destroying the protected stage *before*
  assess-done/repair-done ever got a chance to check it. Now skips the overwrite when the
  current stage is protected.
- `jobsite.job.index.build`: never scanned `trash/` at all (only `blocked`/`deleted`), and used
  the wrong file extension even if it had — trashed jobs became permanently unreachable via
  `job.read`/`job.write` after every reload. Fixed to scan all three epoch-bucketed dirs with
  per-status file regexes.
- New `jobsite.cmd.rescue <id> [stage]` — no recovery mechanism existed before this session;
  decodes vax-int id, restores status/stage, clears trash/deleted/blocked epoch fields.
- `plugin.web.jobs.sync`: added optimistic-concurrency guard — a browser's `stage` push is
  rejected (not silently applied) if the record's `last_modified` has moved since that browser
  last synced; response includes a `conflicts` array so the frontend can drop its stale local
  override and adopt the server's current stage instead of disagreeing forever.
- `jobsite.init_code` / `plugin.web.jobs.init_code`: unconditional root-owned path-ownership
  fixup (`check-zenka-paths`) ran on *every* reload, not just cold start, spamming "operation
  not permitted" once privileges were dropped — guarded with `$EFFECTIVE_USER_ID == 0`.
- Frontend `renderCard()`: `löschen`/`archiv` suggestion badges + card-dimming now respect
  `USER_OWNED_STAGES` like the `apply` badge already did — were showing on already-committed
  jobs.

**Structural gap found, NOT fixed (documented as known)**: `jobsite.sync.push` deliberately
skips jobs with `status` in `blocked|deleted|trash` — meaning a job trashed on the jobsite
side never gets a "removal" signal propagated to httpd's `plugin.web.jobs` web-cache. A job
moved to trash stays visible/stale in the web-cache forever unless its cache file is deleted
by hand. This is why trashing 17 bad `to_apply` entries didn't remove them from `/jobs.json`
until their cache files were manually `rm`'d and `web` reloaded.

**Three-tier cache architecture, confirmed the hard way**: jobsite's own store
(`/var/protocol-7/jobsite/jobs/`) → httpd's `plugin.web.jobs` web-cache
(`/var/protocol-7/web/jobs/`, a *separate* directory tree, fed by periodic
`jobsite.sync.push`) → each browser's own `localStorage` (`jobs_[vhost]_v1` cache +
`jobs_user_decisions_v1` overlay). All three can independently drift. `mergeJobs()` always
lets a browser's local `userDecisions[id].stage` win for `USER_OWNED_STAGES`, so a stale
local decision silently overrides a genuinely newer server stage forever, with no expiry —
this is what the new conflict-guard (above) now catches on the write side.

**Frontend key gotcha (cost real time, caused a wrong "fix")**: `jobs`/`userDecisions` in
the browser are keyed by the **vax-int encoded short id** (e.g. `DEQ5M`), NOT the decoded
numeric job id (`14033177`) — `/jobs.json`'s `id` field is already encoded via
`<[base.vax-int.encode]>`. A localStorage console fix using the numeric id silently no-ops.
Use `bin/vax-int <numeric-id>` to get the right key before touching `userDecisions` by hand.

**Self-inflicted regression, caught and fixed same session**: ran a diagnostic curl POST
against `plugin.web.jobs.sync` intending to test the new conflict-guard read-only, but had
only reloaded `httpd` (wrong zenka — httpd is a thin proxy, doesn't load `plugin.web.jobs.*`
directly, `web` does) — so the request hit the *old*, unpatched code and was processed as a
genuine browser write, queuing a stale reverse-sync entry. A later `jobsite.manual-sync
force=true` then applied that stale entry to the authoritative jobsite store, reverting a job
from `interviewed` back to `applied`. **Lesson: before treating an API call against a running
zenka as read-only/diagnostic, confirm the code you intend to test is actually the code
currently loaded there — reload the right zenka first.**

**Decisive verification technique**: when counts disagree across tiers and "just resync"
doesn't settle it, cross-reference against an independent, out-of-band ground truth by
numeric job ID (user had sent a CSV report to the Jobcenter). Extract numeric ids from
stepstone URLs, `bin/vax-int encode` each, `find` the matching file across all status dirs —
this immediately surfaces (a) genuine misclassifications with a name attached (found N26 GmbH
wrongly in trash instead of rejected) and (b) stale duplicate files left in the wrong status
directory from the original incident (directory-scan order happens to make duplicates
resolve "correctly" by luck — `new < assessed < review < apply < applied < interviewed <
rejected < skipped`, last dir scanned wins — but they're still landmines).

**Two Firefox-only CSS bugs found by user, WebKit-blind to both (see
[[feedback-webkit-vs-firefox-css-blindspots]])**: fixed same session (`db26e9960`).

**Aftermath, accepted as unresolved by user's own choice**: 4 of 5 "skipped" jobs never
recovered — no distinguishing signal exists between "reviewed and skipped due to complexity"
and any other similarly-scored trashed job; a broad score>=7 sweep of trash returned 89
candidates, too noisy to act on without a company name or date to anchor the search. User
explicitly said not worth chasing further.

## Session 2026-07-01 — jobs web UI: collapsible text + search filter + apply filter

### Collapsible assertion text (c4b6dd92c)
- **Per-stage defaults**: `review` + `to_apply` expanded; all other stages collapsed.
  Encoded via `ASSERT_OPEN_STAGES = new Set(['review', 'to_apply'])`.
- **Single click** on card body (outside interactive elements): toggles per-card, 270ms
  timer so double-click still fires. `collapsedOverrides` Set persists across `render()`.
- **`text` button** (leftmost in ctrl-row 2): global inversion toggle — updates all visible
  cards in-place without re-render. `assertGlobalInverted` XOR'd with per-card override.
- **CSS**: `.assert-collapsed .card-summary, .assert-collapsed .card-reason { max-height:0 !important; }`

### Search-as-you-type filter (this session, staged)
- Input at right end of filter bar (`type="search"`, 90px, `margin-left:0.5rem`).
- 150ms debounce on `input` event → updates `searchQuery` → `render()`.
- ESC clears; native × fires `search` event (also clears).
- **Auto-focus**: `document keydown` handler — any printable key focuses search input
  when focus is outside inputs/buttons. Backspace also steals focus when `searchQuery` is
  non-empty (so editing the query still works after clicking elsewhere).
- **Search haystack**: title, company, city, summary, reason, industry, note (AND-matched,
  space-separated terms, case-insensitive).
- **Match highlight**: `highlightTerms(text, terms)` — escapes first, then wraps matches in
  `<mark class="search-hl">` (amber glow `#e0c040`). Applied to title, company, city,
  summary, reason, note-preview in `renderCard`. `hlTerms` computed from global `searchQuery`.
- **`✓ apply` button** in ctrl-row (after archiv): `filterApplySug` toggle — filters to
  `j.assertions?.suggest?.apply === 'true'`. Turns teal when active. Stacks with tab +
  search filters.

### Open design work (not yet implemented)
- **jobsite/site-yaml refactor** (claude 06-29 design doc): make `site-yaml` a pure fetch
  service, `jobsite` owns all job-state logic. New modules: `jobsite.cmd.import`,
  `jobsite.handler.search-done`, `jobsite.handler.job-fetched`, `jobsite.job.upsert`.
- **Bulk URL-checksum dedup** (claude 06-30 design doc): `jobsite.stage.fetch` computes
  URL checksums from in-memory index, passes as skip-set to `site-yaml.cmd.import` via
  file handoff (Variant B) to prevent re-fetching reposted listings with different IDs.

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

#,,..,,..,.,.,,.,,...,.,.,,..,,,,,,,.,.,.,.,,,..,,...,...,.,.,,..,...,.,,,...,
#SDYV232YPYD6XKID5HAEHGWY4GYDJMASZE6FEAQR4Q67Z4FCHVWMQDHIWJIPU4S4YNZNO2ETILGQA
#\\\|H6R2UT5W6MKRNA7O4WYNSDVNR7N6QMLY5EW3RWU4EFBQZBJSWVX \ / AMOS7 \ YOURUM ::
#\[7]YJRZC443AZAFY522SL25AJKQKPECNPRYWRNWKA65ERMK3TA2TWBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
