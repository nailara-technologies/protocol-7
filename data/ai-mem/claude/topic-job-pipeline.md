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

#,,..,,,,,...,..,,.,,,,,.,...,.,.,,..,.,.,.,.,..,,...,...,.,,,,..,,,,,,..,,.,,
#KJVYZUF2WZQKGIRYWLA5KSH3CZ7ZA5MPAXLN5FQ3AZY6Q7UWYQPEZ4Q6QU3VW32MJYPLHDZWS45ZA
#\\\|QIWOXGVTXEUESRLBGC2SYYPC2PCLIRXRZINKO32OIA5G43EPXKM \ / AMOS7 \ YOURUM ::
#\[7]WCDE7UHLYMYRKGXTXROMOY3VHCHRVEOZQ7NKC5LS55BGKCEWSQCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
