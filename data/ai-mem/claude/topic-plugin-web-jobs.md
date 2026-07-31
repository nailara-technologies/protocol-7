---
name: plugin-web-jobs-web-jobs-data-plugin
description: plugin.web.jobs.* for bi-directional job pipeline sync via web zenka — sync bugs, localStorage layer, multi-backend
metadata: 
  node_type: memory
  type: project
  originSessionId: 095ef9b6-c744-46c5-bac8-4d54a2d5ce45
---

## Status update 2026-07-11: both pending_count/cycle-stuck bugs below are landed

Both confirmed COMMITTED, checked against git log (memory had gone stale, said
"staged, not yet committed" / "OPEN (CRITICAL)"):
- delete-during-assessing fix (session below): `beb1129e5`, 2026-07-09 19:46
- restart-mid-batch pending_count orphan gap (the older, separately-tracked
  CRITICAL item — `state.load` reset `cycle` across a restart but left
  `pending_count`/`assess_queue` carrying forward stale in-flight counts,
  wedging `cycle` on `assessing` forever): `d5f9ba894`, 2026-07-10 21:34 —
  also fixed two related decrement bugs in the same pass (`task-created`'s
  failure branch could drive `pending_count` negative, no floor clamp;
  `repair-created`'s failure branch corrupted the `job_id` key instead of
  decrementing). No longer CRITICAL, removed from that section in MEMORY.md.

## Session 2026-07-09 — delete-during-assessing stuck bug, fixed (staged, not yet committed)

**Reported by user**: deleting a job while it's still `assessing` (coding zenka mid-inference)
never gets a resolution signal back to jobsite — job stays stuck in `assessing` forever
(`pending_count`/`cycle` never clear). Distinct from the older restart-mid-batch orphan gap
(see CRITICAL line above) — this is a delete-triggered stall, not a restart-triggered one.

**Investigation found two separate id spaces, not one bridged system**: jobsite's generic
`<task.queue>` task_id (from `task.cmd.create`, resolved via `task.wait-done`/`task.fail`/
`task.complete`) is entirely disjoint from the coding zenka's internal `<coding.task.queue>`
id (`task-<checksum>` format, used by `coding.cmd.abort-inference`/`coding.async.complete`).
Nothing in `jobsite.*` ever calls into `coding.cmd.abort-inference` — no translation path
exists between the two id spaces in this codebase.

**Fix scoped to the generic task_id jobsite actually holds** (doesn't touch coding-zenka
internals — the underlying inference will still run to completion in the background,
wasting compute; that's a separate resource-efficiency task, not this stuck-state bug):
- `jobsite.sync.apply_reverse` (delete branch): now checks if the deleted job's
  `<jobsite.tasks>` record had `stage eq 'assessing'` with a live `task_id`; if so, deletes
  the tasks-hash entry *first*, then sends `task.fail` on that task_id. Ordering matters —
  deleting first means the async `task.wait-done` reply lands on `assess-done`'s
  "unknown job" branch instead of re-writing the job file that was just marked `trash`.
- `jobsite.handler.assess-done` "unknown job" branch: was missing BOTH the idle-transition
  check (`pending_count<=0` → `cycle=idle` → push) AND the `dispatch.next` call that the
  normal completion path already has — meaning any job that went missing by the time its
  task resolved (not just newly, via this delete path — could already happen if a task
  resolved after some other removal) would silently stall the whole pipeline waiting for a
  slot that would never free up. This was a real pre-existing bug independent of the new
  delete-triggered abort, now fixed by mirroring the normal path's logic exactly.

**Self-caught bug during the fix**: first draft used `my $was_assessing = ref $rec eq 'HASH'
and (...)` — the classic Perl `and`-in-my-assignment precedence trap
([[feedback-perl-and-or-precedence-in-my-assignment]]), only assigns the left side. Caught
before commit, changed to `&&`.

**Verification**: `p7c jobsite.reload source` succeeded, zenka stayed alive (uptime
didn't reset). No live end-to-end test yet — `jobsite.status` was `idle` all session, no
job in `assessing` state to exercise the delete-mid-flight path. User expects a real test
opportunity by 2026-07-13 (Monday) at the latest when the next scan finds new jobs. Signed
and staged, not yet committed as of this writing — **watch for the Monday test result and
update this entry with pass/fail**.

## Session 2026-07-01 (latest-2) — dispatch-race self-heal, orphaned-file cleanup, self-match regression + 14-job rescue

**Landed (commits `87a3469c4`→`c4b6aec62`, same session continued)**:

- **Stranding race, fixed**: `site-yaml`'s queue-depth hitting 0 (in `site-yaml.handler.fetch_tick`, the item is `shift`ed off the queue *before* its detail fetch + route-send to `jobsite.job-upsert` even happens) races ahead of the last 1-2 upserts actually landing back in jobsite. `jobsite.dispatch.assessments` fired on that depth=0 signal could snapshot the store too early and declare "no new jobs, idle" with jobs still in flight, permanently stranding them (no automatic retry — `rescan_interval=0`, manual-only). Fix: new `jobsite.handler.new-job-settle` — every `job-upsert` for a genuinely new job (re)arms a 2s debounce timer; once arrivals stop, it calls `dispatch.assessments` itself. Made `dispatch.assessments` safe to call while a batch is already mid-flight: `$was_idle = (<jobsite.cycle> ne 'assessing')` captured at entry, queue is *appended* not replaced, and `dispatch.next` (which would double-dispatch a task) is only called when `$was_idle`.

- **Orphaned duplicate files, fixed**: `jobsite.job.write`'s rename-based old-file cleanup trusts `<jobsite.job.index>` (one location per id, globally) for the "old path" — if an id was blocked once before (e.g. the historic `V7L36RQ` bulk-import batch) and a repost resurrects it into `new/`, the index still says `blocked`, so writing a fresh blocked stub renames *that* old blocked file instead of touching the actual `new/` duplicate, leaving it orphaned and endlessly re-detected-but-never-cleaned, surviving restarts. Fix: `dispatch.assessments` now deletes the known `new/<enc_id>.yaml` source file directly when blocking a job, since it just loaded it from there — doesn't rely on the index at all for this specific cleanup. 12 pre-existing orphans (all verified to have a real `blocked/` counterpart first) removed live via `jobsite.eval-code` (protocol-7-owned fs, no sudo).

- **Self-match regression, found and fixed (the big one)**: the settle-timer fix above unmasked a **latent bug that the old race had accidentally been protecting against**. `jobsite.checksum.index`'s `add` action registered a job's own url checksum *unconditionally* — `job-upsert` on every new job, `jobsite.init_code`'s startup backfill (skips only `blocked|deleted|trash`, NOT `new`!), and the dispatch-time backfill all called it. Once `dispatch.assessments` reliably ran *after* a job's own `add` had already landed (guaranteed by the settle timer waiting for things to settle), every genuinely-new job would self-match its own just-registered hash on the very next checksum check and get silently "blocked" — this is what looked like "all new jobs disappear after a few seconds". Confirmed empirically: computed a blocked job's own url hash independently and it exactly equalled its `checksum_hit` field. **Fix, at the chokepoint** (per-caller patching was rejected as fragile — advisor call correctly predicted a restart-triggered `init_code` backfill would be the next self-match source, and it was): `checksum.index`'s `add` action now no-ops (`return TRUE`) if the job's status is still `new`/empty — a checksum means "this job was decided" (blocked or assessed), never "this job was seen". `assess-done` is unaffected since it always sets a decided status first.

- **14 real jobs (BMW, WidasConcepts, genua, AKDB, IABG, Rheinmetall, etc.) wrongly self-blocked, rescued live** — multi-round process, each round exposing the next residue: (1) `jobsite.reset job_id=...` back to `new` — but their *stale* self-registered checksum hashes (from before the code fix existed) were still sitting in the store, so they'd immediately re-self-match on the next check; had to `unlink` each specific hash file directly first. (2) once genuinely reassessed, several came back with hollow, generic-hedge-language reviews ("die Stelle bietet **anscheinend**...") because `jobsite.job.write`'s `blocked` branch **permanently discards title/company/city/description**, keeping only `{id,url,status,epoch,checksum_hit}` — these jobs had already been through that stub-write once, so `reset` had nothing real left to restore. Root-caused by the LLM's own raw response literally saying it had no real posting to analyze; the repair/validation retry then fabricated a plausible-looking score anyway (8-9, landing in `review`) — **scores generated from empty content, not just a missing-field display bug**. Fix: re-fetched real content per job via `p7c "site-yaml.fetch <url>"` (domain-aware extractor, works standalone), merged into a fresh upsert. (3) a restart mid-batch orphaned `pending_count` (persisted) while `assess_queue` (memory-only) was lost — `cycle` got stuck on `assessing` forever, which combined with the `$was_idle` reentrancy guard would have silently blocked all *future* dispatch too; caught and cleared via `jobsite.clear-tasks`. (4) some victims got re-self-matched a *third* time because their decided-but-garbage status (`review`/`trash`/`assessed`) had triggered `assess-done`'s own (legitimate, by-design) `add` call before the chokepoint fix was reloaded — had to re-clear+re-reset+re-upsert after reload. **This gap is still open, flagged not fixed**: a restart during an in-flight assessment batch orphans `pending_count`/`assess_queue` — needs its own fix later.

- **New reusable finding**: `p7c` silently mangles/truncates large single-line command arguments somewhere around 2-4KB (a JSON job-upsert payload with a full description at 4361 bytes landed with *only* `status` set — everything else vanished with no error; the same payload capped to ~1.7-1.9KB via truncating `description` to 1200 chars landed perfectly). Matches the known "oversize single-line protocol" limitation ([[feedback-oversize-single-line-protocol]]) but this is the first time it silently ate structured JSON rather than visibly wedging a buffer — worth remembering when scripting any `jobsite.job-upsert`-style call with real description text via `p7c` from the shell.

- **Fourth bug in the same chain, landed (`ba901b488`)**: after the checksum chokepoint fix, the same 5-14 rescued jobs kept getting re-dispatched — log showed `remaining: 46` for what should've been ≤5, and an already-`trash`ed job got assessed a second time. Root cause: `jobsite.job.load_all` refreshed `<jobsite.tasks>{id}{stage}` unconditionally from the on-disk file on every call; a still-`new` job has no `stage` field on disk, so this wiped the in-flight `queued`/`assessing` marker `dispatch.assessments` had just set moments earlier, defeating its own "already in flight" skip-check — any re-entrant call (settle-timer firing again, a manual `exec-sub dispatch.assessments` while a batch was running) re-queued the same jobs, unbounded. Fixed at both ends: `load_all` now preserves the in-flight marker instead of clobbering it from disk, and `dispatch.next` independently rechecks a queue entry's job is still `status=new` before dispatching, so stale duplicates from *any* cause get skipped rather than trusted blindly. **Pattern note**: this was the third guard spawned by the settle-timer re-entrancy chain (stranding-fix → pending_count orphan → duplicate-queue) — advisor flagged that repeatedly patching per-symptom was accumulating interacting guards, and suggested eventually collapsing them into one coalesce flag ("dispatch running? set recheck-when-done instead of re-scanning") rather than adding a fifth guard next time this class of bug resurfaces.

- **Also investigated, ruled out as a red herring**: suspected a numeric-vs-vax-int-encoded job_id mismatch between `dispatch.next` (sends raw numeric id) and `task-created`/`assess-done` (both call `vax-int.decode` on it) could be corrupting `<jobsite.tasks>` lookups. Tested directly: `vax-int.decode('14223340')` returns `14223340` unchanged (passthrough for this input) — not the cause. The "unknown job" log line that prompted the suspicion was just fallout from a manual `jobsite.clear-tasks` call racing an already-in-flight task's reply.

- **Final verification**: after both fixes reloaded, a fresh `dispatch.assessments` pass logged `remaining: 5` (matching the actual pending count exactly) and drained monotonically (5→4→...→1) with no re-growth. All 14 originally wrongly-blocked jobs ended up genuinely assessed with real, distinct titles/companies and content-specific reasoning (1 review/WidasConcepts score 8, rest correctly trashed on real low scores) — hollow "Stellenanzeige fehlt" responses stopped appearing once each job's real content had actually stuck.

## Session 2026-07-01 (latest) — export-panel twin-control bugs + title-checksum dedup removal

**Landed (commits `87a3469c4`, `5cf4f4855`)**:

- **Frontend twin-control bug pattern**: the export panel's age-slider and since-last
  checkbox each exist twice in the DOM (quick CSV panel + bericht/table panel), synced
  via a shared class and a single `document`-level delegated listener. Two bugs from
  this pattern: (1) the wheel handler dispatched a synthetic `input` event without
  `{bubbles:true}` — worked for native drag (bubbles by default) but silently no-op'd
  for wheel-scroll since the consuming listener is delegated on `document`, not bound
  directly like `min-score`'s wheel handler. (2) the since-last checkbox's `change`
  handler called `saveExportPrefs()` *before* syncing its twin — `saveExportPrefs()`
  re-derives state via `querySelector` (always first DOM match), so toggling the
  second instance got immediately overwritten by the stale first one. Fix pattern:
  always sync twins to the new value *before* calling the save/read-back function.
  **Lesson**: any control duplicated across synced panels via shared class + delegated
  listener needs this same "sync-before-save" ordering checked on every handler, not
  just the one that happened to get fixed first.

- **Title-based checksum dedup removed from `jobsite.checksum.index`**: title matching
  would trash any incoming posting whose exact title matched one seen before,
  regardless of company/location — flagged as "too broad" and removed from the
  pre-fetch import path (`site-yaml.cmd.import`) previously, but never removed from
  the post-fetch checksum store used in `jobsite.dispatch.assessments`. Same root
  cause as a prior incident (`jobs-pipeline-2026-06-28.md`) where duplicates
  resurrected as `status=assessed` from stale `titles/assessed`/`titles/deleted`
  entries. Removed: title check/add in `jobsite.checksum.index`, the title-only
  `update_status` action + its call site in `jobsite.job.write`, the flat→assessed
  title migration, title counting in `stats`, and the now-unreachable "inherits
  status from checksum store" trash branch in `jobsite.dispatch.assessments` (only
  ever triggered by a title hit). Only company blacklist + URL dedup remain.
  Verified live: `jss.fetch-done [linux-developer]: import queued: 3 new, 97
  skipped, 0 errors` post-fix. **On-disk `checksum-store/titles/` (1859 files, 10
  status dirs) is orphaned but untouched** — separate data cleanup, needs
  `protocol-7`-owned access, not yet done.

- **Verification technique**: computed checksums standalone via `bin/bmw-L13`
  (raw-string L13) combined with `perl -MCrypt::Misc=encode_b32r` (base32-encode
  first, matching `chk-sum.bmw.str-b32.L13`'s two-step algorithm) to cross-check
  which job IDs were legitimately in `/var/protocol-7/jobsite/block-list.seed`
  (format `<V7-epoch>:ID:<L13-hash>`, raw-string L13 — no base32 pre-step, unlike
  the title/url checksum-store hashes) without needing filesystem read access to
  the `protocol-7`-owned `checksum-store/`.

- **Mistake caught by user**: confused `bin/vax-int` (32-bit VAX-int/BASE32) with
  the unrelated "V7 epoch" scheme used for epoch-bucket dir names like `V7L36RQ` —
  see [[feedback-vax-int-vs-v7-epoch]] for the full writeup and the correct tool
  (`p7c localtime <str>`).

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

**Watermark-ordering gotcha (fixed 2026-07-31, commit cab203d14, see
[[topic-job-pipeline]] for the full writeup)**: `plugin.web.jobs.data`
now stamps the `ntime` watermark it hands back to the client at the very
*start* of the handler, before reading the job cache or the
`removed_log`. Stamping it at the end (the original bug) let a tombstone
appended mid-request slip past the already-built `removed` array while
the client was still handed a watermark newer than it — permanently
orphaning that tombstone, since a client's `since=` watermark only moves
forward. Any future endpoint here that hands back a delta watermark
should stamp it before reading the data it's answering from, not after.

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

#,,..,..,,.,,,,,,,...,.,.,...,.,.,.,,,...,.,.,..,,...,...,.,.,..,,...,,,.,,.,,
#RPXFEEUKFRCA4X4IJOFBALDJBXQ7PSNJDOFEOE4IEIXJBHWFFDAE2KVZVQ2MDQPBNYVOHEL55XA7I
#\\\|ZTG5UX2T6J74VAWT35UH3EYH2KJCQOFQATA5GWJ2ERZX6RZMI5Y \ / AMOS7 \ YOURUM ::
#\[7]BWCPSJ2O3OYHRBM2GHR75X5YHT7572RFUERYMO7ILSWWRUBVCYAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
