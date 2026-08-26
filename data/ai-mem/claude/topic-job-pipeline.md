---
name: job pipeline
description: job search automation — site-yaml, job-site-scan, assessment, sync
type: project
originSessionId: 5557aaa4-3476-4c66-9002-955c73ae92a1
---
## Implemented (2026-05-10, sessions 20-22)

**site-yaml zenka** (on-demand):
- `site-yaml.import <url>` — fetch stepstone search page → JSON-LD per job → store.yaml
- Store: `/var/protocol-7/site-yaml/store.yaml` — delete to force full re-fetch
- Status flow: new → assessed → applied/rejected/skipped/archived
- Proxy bypass: no_proxy('stepstone.de', 'www.stepstone.de')
- 0.5s delay between fetches; retry queue for timeouts (3s wait + 2s between retries)

**job-site-scan zenka** (on-demand, coordinator):
- Stage engine: idle → scanning → assessing → reviewing → idle
- State: `/var/protocol-7/job-site-scan/scan-state.yaml`
- Profile: `/etc/protocol-7/job-site-scan/profile.txt`
- Commands: scan, status, list-jobs [stage], approve, reject, set-threshold,
  clear-tasks, get/set/dump/del (devmod)
- Categories: linux-sysadmin, ki-automation, devops, platform-engineer
  (TODO: add linux-entwickler)
- Full re-run: `rm store.yaml && p7c job-site-scan.clear-tasks && p7c job-site-scan.scan`

**Assessment pipeline — FULLY WORKING, session 22**:
- Prompt: German from the start — asks for score + reason + summary in one pass
- JSON format: `{"score": 0-10, "apply": bool, "reason": "1-2 German sentences (fit)",
  "summary": "2-3 German sentences (job overview, skills, remote/location, highlights)"}`
- reason = why candidate fits/doesn't; summary = what the job actually is
- Sequential: one task in flight (dispatch.next from assess-done)
- models.task.default_model = local
- No separate translation pass — model outputs German natively
- assess-done stores: score, score_reason, score_summary in task state + store.yaml
- Future: score_tech + score_location as separate fields (structure ready)

**jobs.vhost — LIVE**:
- Vhost: atom.protocol-7.network (46.101.115.180), TLS via letsencr
- Repo: `data/web-root/vhosts/jobs.vhost/` (domain not disclosed)
- Manifest: `hostname_pattern: jobs.*` + `install_matching: yes` — resolves against
  deployed /var/httpd/jobs.* dirs at install time
- `httpd.vhost.read_manifests` extended to handle wildcard pattern vhosts
- Page features: score filter (slider, default 6), filter tabs, sort score↓/↑/datum,
  table toggle, CSV export, print report, notes, status changes, drag-reorder, manual add
- Card layout: title+score → company/city/industry → reason (italic) → summary (muted)
  both click-to-expand
- Print report: hybrid layout — overview table + KI-Analyse per job (summary+reason+note);
  filter: applied/responded/rejected only (same as CSV); light mode at print time, dark preview;
  "drucken" button appears when table is visible; refreshes on sync + tab switch
- CSV export: applied/responded/rejected only
- Export: `bin/dev/export-jobs-json [outfile]` — reads store.yaml → jobs.json
  prefers score_reason_de (legacy) then score_reason; to_unicode() fixes Latin-1/UTF-8
- Update cycle: `perl bin/dev/export-jobs-json /tmp/jobs.json && scp ... atom:/var/httpd/jobs.*/`
  (actual dir matched by wildcard — not kept in repo; personalized)

**letsencr fix (session 22)**:
- x509_field/der_to_pem/extract_aia_url/fetch_intermediate_via_aia were only loaded
  in child branch — parent crashed in save_certificate. Fix: load all four in parent
  branch of fork_letsencr_child alongside letsencr.parent.

**Key bugs fixed across sessions**:
- task.show multiline description truncated to first line — escapes \n now
- 100 tasks dispatched simultaneously — dispatch.next moved to assess-done
- store reset: delete store.yaml (no reset-scores command yet)

## Session 24 changes (2026-05-14)
- zenka renamed job-site-scan → jobsite (89 files, all modules, config, /etc/, /var/)
- assessment prompt switched JSON → YAML heredoc template (cleaner model output)
- assess-done + repair-done: YAML::XS::Load primary parser, JSON regex as fallback
- validate.assessment: assertion check updated for YAML format
- YAML::XS autoload moved to init_code (was duplicated inline in handlers)
- task files written for kimi: flush_on_acquisition extraction + per-element storage

## Current state (session 22 end)
- 96/106 jobs with German reason+summary; 2 being re-assessed (English from old run)
- jobs.vhost live: score-gradient cards, gestures, review default tab, culture scoring
- Profile: Freiburg + Stuttgart as alternates; company culture ±1-2pt signals added
- Encoding fully fixed: fetch-done UTF-8 decode + export 2-pass Mojibake repair

## Planned
- Search category management: add/remove/list-categories commands + zenka_dir
  persistence — so categories don't require editing the start file
- Multi-page search: cfg.max_pages per category (stepstone: 25/page)
- Task zenka persistence (zenka_dir) — state lost on idle shutdown
- plugin.web.jobs.* — bi-directional sync endpoint, B32 backups, replaces
  export-jobs-json+scp; see topic-plugin-web-jobs.md for full design
- Remove debug logs from models.handler.task-poll-step
- Apply workflow: send application email from review card
- Exclusion filter from past CSV data (already-applied companies)
- score_tech + score_location split in assessment JSON
- LANDED 3eaab1900 (2026-07-14): site-yaml salary estimate extraction. Real
  field is `CESalary` (isPredicted/min/max blob embedded in the job page,
  not the JobPosting JSON-LD) — dispatched via kimi_dispatch+kimi_continue
  (MCP), verified live against both known URLs (53k-77k, 43k-64k) before
  commit. `salary_estimate_min/max` omitted entirely when absent (no
  0/undef); wired into `jobsite.util.build_prompt` so compensation
  reasoning uses the real number. Other salary sources (market-average
  APIs, trend data) still to be layered in later, same absent-vs-zero rule.

## Vision (2026-07-14, agreed with user)
End state for jobsite: system prepares a full application (cover letter,
answers, salary ask) grounded in structured signals like the above, presents
it to the user for review, and on approval sends it and tracks replies.
When the user edits the generated application before sending, that diff is
the training signal — future applications should incorporate the accumulated
edits/insights automatically, not just repeat the same draft pattern.
See [[topic-plugin-web-jobs]] for the existing sync/apply-workflow substrate
this would build on.

## Session 2026-07-23 — reassess content-loss + stale-flag fixes, trash-history panel (commits bb4d9fe0e, 0d8901d14, 841891e41)

**Four backend bugs found and fixed, all in the reassess/repair path**:
- `jobsite.handler.assess-done`: when a job's `repair_attempted` was already
  `TRUE` from a prior cycle and a fresh full reassessment came back invalid
  again, the code logged "keeping original" but actually fell through and
  overwrote `score`/`score_reason`/`score_summary` with the new *empty*
  result anyway — no `return` after the repair-gave-up branch. This is what
  silently blanked a real user-reported review-tab card. Fixed by gating
  every downstream overwrite (assertions, score fields, the on-disk write)
  on a `$give_up` flag, reusing the prior values instead.
- `jobsite.handler.repair-done`: its `%protected_stage` list was missing
  `review` — `assess-done`'s has it (with an explicit comment explaining
  why), `repair-done`'s didn't. A repair pass that succeeded with a low
  score could silently trash a job the user was actively reviewing. Added
  `review` to match.
- `repair_failed` was memory-only (`<jobsite.tasks>`) in the *normal*
  completion path of `assess-done` — never written to the per-job disk
  file except in two narrow failure branches, and never explicitly cleared
  on a clean success. `jobsite.sync.push` only forwards a field to the web
  cache when `exists` on the source hash, so a flag set once could never
  self-clear on the web side. Fixed both ends: `assess-done` now persists
  `repair_failed` to disk on failure and explicitly deletes it (both
  `job_rec` and the on-disk `$job`) on a clean pass; `sync.push` now always
  emits `repair_attempted`/`repair_failed` with an explicit `// FALSE`
  default so an absence-meaning-cleared state actually propagates.
- jobs.vhost stage-dropdown reopened itself after every stage change: the
  click handler cleared `.open` *after* calling `setStage()`, but
  `setStage()` calls `render()` synchronously, which captures/restores
  whatever dropdown was still `.open` at that instant to survive
  poll-driven mid-edit rebuilds — so it faithfully reopened the very
  dropdown the user had just used. Fixed by reordering: clear `.open`
  *before* calling `setStage()`.

**Skipped-tab UI**: removed dblclick-to-archive (matches the
`review`/`interviewed`/`applied` precedent already noted in-file as "too
easy to trigger by accident"); added an `archivieren`/`löschen`
quick-actions row (bottom-right, `.card-quick-actions.end` — new CSS
variant using `justify-content:flex-end` instead of the default
`space-between`) and a long-press-to-review gesture instead.

**New: trash-history recovery panel** (papierkorb button, `🗑`) — a UI path
for the terminal-only `jobsite.cmd.rescue <id> [stage]` that existed but
had no UI:
- `jobsite.job.rescue` — restore-from-trash logic extracted out of
  `jobsite.cmd.rescue` into a shared module, so both the console command
  (mode=true/false text) and a new `jobsite.cmd.rescue-http` (mode=strm
  json) can call the same logic with different reply shapes.
- `jobsite.cmd.list-trashed` — lists recent trash entries (id/title/
  company/score/trashed_at) without decompressing the whole trash tree:
  stats every trash file's mtime first (cheap, ~1400 files), sorts, only
  `File::stat::stat(...)`-decompresses the top N. **Hit
  [[feedback-file-stat-shadowing]] live** — first pass used
  `my @stat = stat($path)`, which silently returns a 1-element list under
  P7's global `use File::stat`, so every mtime came back undef; this
  gotcha was *already documented* in memory but not indexed in
  MEMORY-feedback.md, so it wasn't surfaced during live debugging — fixed
  the indexing gap too, see that file's own note.
- Two new HTTP routes, `GET /jobs-trash` and `POST /jobs-trash-rescue`,
  route straight to `jobsite.*` (bypassing `web`/`plugin.web.jobs.*`
  entirely, since trash content was deliberately never pushed to the web
  cache) — required adding `jobsite.list-trashed`/`jobsite.rescue-http` to
  **both** `cube/access.zenki`'s `access.cmd.usr.httpd` and
  `jobsite/start`'s own `access.cmd.usr.cube` (same two-sided wiring
  lesson as [[topic-jobsite-stray-recovery]]).
- **`jobsite.cmd.*` files must NOT `my $call = shift` themselves** — the
  dispatcher pre-populates `$call` for that namespace already (existing
  `jobsite.cmd.rescue`/`reset` never shift it); doing so anyway shadows it
  and threw a compile warning, visible via `jobsite.show-buffer
  compile-errors`. Copied this from the unrelated `plugin.web.jobs.*`
  convention, which *does* shift its own `$call` — the two namespaces
  differ, don't assume they match.
- **Reply-mode gotcha**: `httpd.handler.web-relay.strm_open` only builds a
  real HTTP response for a `mode:strm` (or legacy `SIZE`) reply — a
  `mode:true/false` reply 502s over that path. Calling a `mode:strm`
  command directly via `p7c` (bypassing httpd) with no STRM consumer
  produced a genuine flood — `sort()` over ~1400 candidates with every
  comparator side `undef` (from the File::stat bug above, before it was
  fixed) warned once per pairwise comparison, reading exactly like a tight
  loop in the console. Not an infra bug, just a very noisy symptom of the
  other two bugs compounding.
- **Frontend**: the panel only fetches on the closed→open toggle
  transition — data that changed while it was already open (e.g. a
  browser-initiated stage-move/delete draining through the async reverse
  sync queue, up to `jobsite.cfg.sync_interval=300`s later) never showed
  until reopened. Fixed by hooking `loadTrashPanel()` into the same
  sync-driven refresh conditional `showPrintTable()` already uses in
  `syncPipeline()` (fires on `added>0||updated>0||removed>0||migrated`) —
  a trash transition already produces a `removed` tombstone signal on that
  same poll, so it's a well-correlated trigger, not just a loose proxy.
  Also added a clear-watermark (`✓ gesehen`, localStorage, no server
  state) + one-at-a-time reveal-back arrow (`▾ ältere`) for the "cleared
  too early" case — user's own design, confirmed working end-to-end live.
- Panel background switched from an ad-hoc blue-teal to the actual
  "blacklight" palette (`rgba(12,5,24,0.85)` bg, `#3030a0` border, purple
  glow) sourced from `visual.v7.ax/grid-v13-final-baseline.html`'s
  `.info-panel` — worth reusing directly for any future panel needing this
  project's actual visual identity instead of guessing colors.

**Reusable pattern worth lifting into a generic template later** (per
user, session-closing remark): the clear-watermark + reveal-counter
mechanism (pure client-side, no server round-trip) and the `end`-aligned
quick-actions row are both small and self-contained enough to become a
shared convention for any future "recently removed, quick undo" panel.

### Same-session follow-up — cross-browser watermark sync, debounce fixes, real export-data gap found (commit fae96e9d3)

**New generic sync primitive**: `jobsite.client_prefs.read/write` +
`jobsite.cmd.get-prefs/set-prefs` + `GET/POST /jobs-prefs` — a small
shared key→numeric-value blob on jobsite, persisted to its own
`client-prefs.yaml`. Merge rule is last-write-wins **by value** (`max`),
not arrival order — deliberately, so a browser that was offline while
another one advanced the shared value can't regress it back down by
pushing its own stale local copy on reconnect. Built to reconcile the
trash-panel watermark across Firefox and the web-browser zenka's WebKit
(which have entirely separate, and in WebKit's case ephemeral,
`localStorage` — a real user-visible "why doesn't gesehen stick" report
turned out to be exactly this, not a bug). Reusable for any future
purely-local-but-should-agree-across-profiles browser setting — see
[[topic-jobsite-ui-usability]].

**Two more frontend races/quirks fixed in the trash panel**:
- Overlapping-fetch race: rapid reopen while a prior `loadTrashPanel()`
  fetch was still in flight could let a slower/older response land after
  a newer one and silently overwrite it. Fixed with a generation counter
  (`trashLoadGen`, incremented per call, checked before each response is
  applied) — the technically correct fix for out-of-order async
  responses, stronger than a naive time-based debounce.
- **Double-click-event dispatch**: some browser engines [confirmed in
  the web-browser zenka's WebKit here, not Firefox] fire two native
  `click` events for one physical click/tap. Every trash-panel button
  handler was susceptible — the papierkorb toggle opened then
  immediately closed itself again, `▾ ältere` revealed two entries
  instead of one. Fixed generically with a shared `debounceClick(fn,
  ms=250)` wrapper (per-handler last-fire timestamp) applied to all four
  handlers (toggle, gesehen, ältere, per-row rescue), not patched
  one-by-one as each got reported. Worth wrapping any future WebKit-
  tested click handler in this project with the same helper preemptively.

**Reload-doesn't-pick-up-new-files gotcha, confirmed twice this session**:
`jobsite.reload all`/`reload source` reported success but did not
actually recompile `jobsite.cmd.set-prefs` after a fresh edit — verified
unambiguously by adding a literal marker field to the JSON reply and
watching it not appear across multiple reloads. Only a full `v7.restart
jobsite` picked it up. In hindsight this likely also explains part of the
earlier `jobsite.cmd.list-trashed` "diag=1 branch never fired" confusion
from the prior session entry above, which had been fully chalked up to
the File::stat bug — that bug was real and confirmed separately, but the
reload staleness was probably compounding it. **Practical rule going
forward**: after creating or editing a `jobsite.cmd.*` file [or likely
any zenka's newly-added command module], don't trust a "reload success"
message alone if a change doesn't visibly take effect — verify with an
unambiguous marker, and reach for a full zenka restart rather than
repeated reloads if one doesn't confirm.

**Real, pre-existing, unrelated bug found while diagnosing a false alarm**:
the "last export date" feature (`exported_stage`, server-synced per job,
NOT part of the new client-prefs mechanism above) has a silent-failure
gap. `exportCSV()` sets `jobs[j.id].exported_stage = j.stage` locally and
synchronously, then separately fires an async `pushChange()` per
exported row — if any of those pushes silently fails, the exporting
browser's own view already looks correct (masking the failure), while a
*different* browser reading true server state shows the job as still
unexported. Caught via a user-reported cross-browser discrepancy [4
entries showing "needs export" in the web-browser zenka, 0 in Firefox,
after a same-day export] — verified server-side ground truth via direct
YAML grep (`grep exported_stage /var/protocol-7/web/jobs/applied/*.yaml`)
found exactly 4 records with `exported_stage: <none>`, matching the
report precisely, confirming a real server-side gap rather than browser
cache staleness. Patched the 4 records live via direct `POST /jobs-sync`
calls (not hand-editing YAML, to keep the in-memory cache and
`last_modified` consistent). **Not fixed**: the underlying reliability
gap in `exportCSV()` itself — a batch of `Promise.all(pushChange(...))`
calls with individually-caught, individually-notified errors is easy to
miss in a large batch; flagged to the user as a known follow-up, not
addressed this session.

## Session 2026-07-31 — trash-tombstone watermark race (commit cab203d14),
## Fehler-badge false-positive diagnosed but not code-fixed

User reported two symptoms after a scan: (1) the "Fehler" badge lit up on
almost every card in the UI while the "fehler" tab and its error counter
stayed at 0, and (2) after the scan finished, 14 jobs that had just been
correctly trashed (deservedly low-scored, real content) kept showing up
in one Firefox tab's "alle" tab as if still unassessed — full title/
company, but score empty, stuck on `stage: new`.

**Bug 1 — Fehler badge, diagnosed, NOT fixed**: `index.html` checks
`repair_failed` two different ways — the badge (`if (j.repair_failed)`,
plain JS truthiness) vs. the tab filter/counter (`== 5 || === true`).
Pulled the live feed directly (`p7c web.jobs-data`) and found 22 of 23
jobs had `repair_failed` serialized as the **string** `"0"`, not the
number `0` — `Boolean("0")` is `true` in JS, so the badge false-positives
on nearly everything while the strict-equality checks stay correctly
empty. Root cause: this codebase's `use constant FALSE => 0;`
(`AMOS7.pm`) returns the *same shared scalar* every call; if that shared
scalar is ever used in a string context anywhere in the process (e.g. a
`%s`-formatted log line), Perl caches a string representation on it
permanently for the life of the process, and every later `// FALSE`
default (e.g. `jobsite.sync.push:82`) then serializes as JSON string
`"0"` for the rest of that zenka's uptime — a classic Perl/JSON::XS
dualvar footgun. **Not code-fixed this session** — the badge check at
`index.html:1103` should be tightened to match the `==5||===true` test
already used at the tab filter/counter, so a restart-triggered taint of
the shared constant can't cause this again. Flagged to the user; they
report it now displays correctly, most likely because the affected
zenka's process was restarted/reloaded during this session, clearing the
taint — this will resurface on its own the next time anything
process-wide stringifies the `FALSE` constant.

**Bug 2 — trash-tombstone watermark race, fixed, commit `cab203d14`**:
`plugin.web.jobs.data` built the `removed` array from a snapshot of
`<plugin.web.jobs.removed_log>`, then stamped the `ntime` watermark handed
back to the client *afterward*. A tombstone appended between those two
points [ interleaved event mid-request during the busy 32-minute scan ]
was silently excluded from that response's `removed` array while the
`ntime` handed back was already past it — permanently orphaning that
tombstone from every future delta poll of that client, since its
watermark can only move forward. Confirmed empirically, not just by code
reading: replayed the exact `since=` value from the stuck tab via `p7c
"web.jobs-data since=<lastNtime>"` and got 0 removed/0 jobs for the
affected ids, then replayed with an *older* since (one of the tombstones'
own ntimes) and got them back correctly — proving the tab's watermark had
already jumped past tombstones it never actually received. Fix: stamp
`$current_ntime` at the very top of the handler, before reading the
cache/removed-log, so anything appended mid-request is still `>=` the
watermark handed back and gets picked up on the client's next poll
instead of being skipped forever. **No retroactive fix for clients
already past the point of loss** — the only remedy for an already-
orphaned tab is clearing its `jobs_pipeline_v1` localStorage key to force
a fresh full load, confirmed clean server-side via `p7c web.jobs-data`
(23 real jobs, no ghosts) before recommending it.

**Diagnostic pattern worth repeating**: for any "one client shows stale/
wrong state, server looks fine" report in this sync system, replay the
client's own `since=`/`lastNtime` value directly against `p7c
web.jobs-data since=<value>` rather than trusting code-reading alone —
it's what turned a plausible-sounding race hypothesis into a proven one
here, and would have caught bug 1's dualvar taint just as fast if tried
first.

## Session 2026-08-06 — reassess to_apply-stage clobbering, salary refetch, job-upsert data-loss gap (commits d4b31f357, 01ec9c91a)

**Trigger**: user queued a reassess on an `apply`-stage job (already moved out of
`review`) to pick up a salary figure the original scrape missed; nothing visibly
changed and the score fields went blank with no replacement ever landing.

**Root causes, three separate bugs in the reassess path**:
1. `%protected_stage` in `task-created`/`assess-done`/`repair-done` covered
   `review applied interviewed responded rejected skipped archived` but never
   `to_apply` — even though the frontend's `USER_OWNED_STAGES` already treats it
   as user-owned. A reassess dispatch against a `to_apply` job could get its
   stage clobbered to `assessing` in `task-created`, then a low re-score would
   fall through to the normal threshold branch in `assess-done` and silently
   demote/trash a job the user had already decided to apply to. Traced the
   history: the July 15 fix (`6090ee533`) added `review` after its own incident
   but never added `to_apply`, which never had its own incident until now — same
   *class* of bug as the earlier review-tab fix, just never generalized to every
   user-owned stage. Fixed by adding `to_apply` to all three protected_stage sets.
2. Reassess never re-fetched the source posting — it just reran the LLM over
   whatever was already stored, so a field missing from the original scrape
   (e.g. `salary_estimate_min/max`) could *never* be corrected by reassessing,
   no matter how many times. Fixed: `apply_reverse`'s reassess branch now marks
   `<jobsite.tasks>->{$id}{'awaiting_refetch'}` and dispatches
   `site-yaml.import-url`; the actual LLM pass is deferred to new
   `jobsite.dispatch.reassess_now`, fired either from `job-upsert`'s
   `awaiting_refetch` check once fresh data lands, or as a fallback from new
   `jobsite.handler.reassess-refetch-queued` if the source url isn't
   refetchable at all (non-stepstone, pattern rejected) — so a job is never
   stranded waiting on a refetch that will never come. Verified end-to-end live
   against a real job (salary appeared, LLM score updated on the correct data).
3. **Standing gap, wider than reassess**: `jobsite.cmd.job-upsert`'s merge for
   an *existing* job only preserved `status score score_reason applied_at` from
   the record before overwriting with freshly-scraped fields — `stage`,
   `assertions`, `score_summary`, `notes`, `date_applied`, `repair_*` were all
   silently dropped on any re-upsert of an already-decided job. This isn't
   reassess-specific: the same code path fires whenever a periodic scan
   re-lists a posting whose id the store already has. Broadened the preserved
   set to match the protected_stage fields. Caught live mid-session: the first
   post-fix reassess test showed byte-identical stale score/reason text instead
   of a fresh result, traced to `$data{'jobs'}{'store'}` only being populated
   once at zenka init/reload (`jobsite.init_code:122`) and never refreshed from
   disk on a plain `jobsite.job.write` — so `job-upsert`'s `$existing` reflected
   whatever was cached at the last reload, not the just-cleared on-disk state.
   Resolves itself after a reload (which repopulates the cache from disk), but
   the caching gap itself is still open — flagged, not fixed.

**Profile-tuning additions this session** (`/etc/protocol-7/jobsite/profile.txt`,
NOT repo-tracked, external `/etc` path): an `Eligibility` hard-exclude section
(student-only postings — Masterarbeit/Bachelorarbeit/Werkstudent/Praktikum/
Ausbildung/duales Studium/Trainee — score 0-1, `delete:true`, regardless of
technical fit; live-verified against a real Masterarbeit posting that had
scored 7 on skill-keyword overlap alone before the fix), and a `Compensation`
section reframing below-market pay as non-disqualifying **if acceptable**,
paired with an explicit standing exception for exploitative/unstable pay — see
[[feedback-jobsite-candidate-preferences]] for why. Also added a **mechanical**
title-regex pre-filter in `job-upsert` for the same student-position class
(cheaper/more reliable than relying on the LLM every time — catches it before
any assessment dispatch at all, not just via profile guidance) and a
company-blacklist workflow note: for a company the user has already made a
firm, non-negotiable decision about (not a soft preference), prefer
`jobsite.blacklist-add <company>` — deterministic, checksum-gated before any
LLM call — over encoding the reasoning in `profile.txt` and hoping the model
infers it correctly every time from a posting's text.

**Debugging note**: this repo's outbound network egress proxy
(`10.0.110.7:4040`, from `$http_proxy`/`$https_proxy`) silently hung
(zero response, no error) against `stepstone.de` while a direct connection
(`curl --noproxy '*' ...`) succeeded in under a second. Worth trying
`--noproxy '*'` first if any live-page fetch/debug against a job-board domain
times out through the configured proxy.

#,,..,,.,,,.,,,,,,.,,,,.,,.,,,,..,,.,,.,,,,.,,..,,...,...,.,.,,,.,.,,,...,.,,,
#EET2V6MAHVQCPIGI3CCULWDJWU2TCQJOZTOB3IJBHEVER6UR5XHARJ6NLTULKUFG4UECGHW3BVLMY
#\\\|PWFU2SWQQDR4P7YSRDEWOCQD22YPHVBXHNAHDPWXBIDIZQA4TTL \ / AMOS7 \ YOURUM ::
#\[7]2OE6FWYNMJSFULI2QWPEVPR4UCEDP77RYZSWVRA4QCWI5IAWNQDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
