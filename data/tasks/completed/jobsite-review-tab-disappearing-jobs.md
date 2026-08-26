## task: fix jobsite review-tab jobs vanishing after reassessment

### symptom

Triggering a reassessment on a job in the jobsite web UI's review tab
(single-card "↺" or a whole-tab re-run against a different model) could make
the job disappear from the UI even though the underlying job files on disk
were untouched or only partially affected. Reported as recurring across
multiple days, not a one-off.

Turned out to be four separate, independently-triggerable bugs plus one
related UX gap and one unrelated regex miss, found by tracing one concrete
repro (`13792679` / `U525E`, "Endpoint Security Engineer - OT (f/m/x)") end
to end through jobsite → web cache → browser.

---

### root causes and fixes

1. **auto-trash on reassess of a review-stage job**
   `src/jobsite.handler.assess-done` — `protected_stage` (the set of
   stages a re-score is never allowed to evict a job out of) was missing
   `review`. A manual reassess that came back below `<jobsite.cfg.threshold>`
   fell into the generic "below threshold → trash" branch and moved the job
   out of `review` into `jobs/trash/`, even though the user explicitly asked
   for a fresh opinion on a job they were actively looking at.
   **Fix:** added `review` to `protected_stage`. Score/reason still update
   for the user's own judgement; placement no longer gets silently revoked.

2. **delta-sync watermark race (web cache → browser)**
   `src/plugin.web.jobs.sync` copied jobsite's own write-time
   `last_modified` straight into the web cache when a batch push landed.
   Since that timestamp reflects when jobsite wrote its local file — not
   when the update actually became visible in the web cache — a browser
   poll landing in the gap between those two times would adopt a watermark
   (`ntime`) newer than the eventual cache write's `last_modified`,
   permanently excluding that job from all future delta responses even
   though the cache/disk data was completely correct.
   **Fix:** removed `last_modified` from `@pipeline_fields` and explicitly
   `delete $cached->{'last_modified'}` before every batch-push write, so
   `plugin.web.jobs.cache.write`'s existing "stamp fresh time if missing"
   fallback fires on every real update instead of only the first one.

3. **hard inference-failure path also evicted jobs from their stage**
   Same file, the `mode eq 'false'` branch (task errored out with no model
   result at all) unconditionally set `stage='failed', status='assessed'`.
   `failed` has no UI tab, and `status='assessed'` is a legacy value that
   `plugin.web.jobs.init_code` actively purges from disk on every web
   restart — a transient infra failure could permanently disappear a job.
   **Fix:** leave stage/status untouched on hard failure; set
   `repair_failed = TRUE` instead, same signal as a failed validation
   repair, so the job surfaces in the `fehler` tab without losing its place.

4. **`fehler` tab was dead on arrival**
   `repair_attempted`/`repair_failed` were never in
   `plugin.web.jobs.sync`'s `@pipeline_fields`, so even the pre-existing
   "repair tried and still invalid" path (bug 3's sibling) never reached the
   browser. The tab existed, the badge-rendering existed, the field never
   made the trip.
   **Fix:** added `repair_attempted repair_failed` to `@pipeline_fields`.

5. **stale client-side stage overlay never re-validated against the server**
   `data/web-root/vhosts/jobs.vhost/index.html` — `mergeJobs()` unconditionally
   re-applied a locally-remembered user-owned stage (`userDecisions[id].stage`)
   on every sync, with no check for whether the server's record had since
   moved for an unrelated reason (a reassess, a `jobsite.rescue`, ...). A
   `to_apply` decision made once could permanently pin a card to the wrong
   tab, invisible under `review` forever, regardless of what the server said.
   **Fix:** `setStage()` now stamps the decision with the server's
   `last_modified` at decision time (`base_last_modified`). `mergeJobs()`
   drops the stage override once the server's `last_modified` diverges from
   that stamp, instead of trusting it forever. Legacy `userDecisions` entries
   without the new field keep the old always-honored behavior (no surprise
   reverts for existing state); one manual dropdown correction is needed to
   requalify them.

### related UX gap (not a bug, closed anyway)

`data/web-root/vhosts/jobs.vhost/index.html` — the quick apply/skip badge
row was entirely hidden whenever a job had a delete suggestion (`sug.delete
=== 'true'`), leaving only a passive header badge with no one-click action.
This actively worked against the case that motivated checking it: re-running
a whole review tab through a different/better model surfaces fresh delete
suggestions, and the fast per-card triage path disappeared right when it was
needed most. Added a `🗑 löschen` quick-action badge (new `.badge-delete`
style) wired to the existing `deleteJob()`, shown in place of `✓ apply` when
delete is suggested; `✗ skip` stays available alongside it.

### unrelated fix picked up along the way

`src/jobsite.cmd.job-upsert` — the gender/diversity-marker suffix strip
(`(m/w/d)` etc.) was a hardcoded list of specific permutations. A live job
title used `(f/m/x)`, a combination not in the list, so it survived into the
title unstripped. Replaced the fixed list with a general pattern matching
any 2-4 letter permutation of `{m,w,f,d,x}` slash-separated in parens.

---

### data recovery performed

- `jobsite.rescue U525E review` — restored the one job actually misfiled
  into `jobs/trash/` by bug 1 (score/reason/assertions from the real
  reassessment were intact, just sitting under the wrong status).
- `jobsite.rescue 7HVNS review` / `jobsite.rescue BWZNS review` — no-op
  stage rewrites (`review → review`) used purely to force each record
  through a fresh write under the corrected watermark logic, unsticking
  browsers whose delta cursor had already stepped past the old, incorrectly
  stamped update (bug 2).
- One of those two (`BWZNS`) turned out to also be carrying a stale client
  overlay (bug 5) from an earlier `to_apply` + note decision; corrected
  manually via the stage dropdown once bug 5's fix was live.

### files touched

- `src/jobsite.handler.assess-done`
- `src/plugin.web.jobs.sync`
- `src/jobsite.cmd.job-upsert`
- `data/web-root/vhosts/jobs.vhost/index.html`

### verification

- Live-reproduced bug 1 during the session (job `13792679` reassessed,
  scored 6, watched it land in `jobs/trash/V7L36RQ/U525E.yxz.B32`).
- Confirmed bug 2 by diffing `last_modified` between jobsite's own job file
  and the web-cache copy before/after the fix — identical (copied) before,
  independently stamped after.
- Confirmed bug 4 by inspecting `@pipeline_fields` directly; no live
  `repair_failed` job existed yet to observe end-to-end.
- Confirmed bug 5 from the user's own report: server showed `stage: review`
  while the browser displayed the card under the `apply` tab with a note
  that was never pushed by jobsite-side data.
- Final state cross-checked against `jobsite.status` output
  (`apply: 1, review: 1, skipped: 1`) matching the three affected jobs'
  intended end states.

#,,.,,,.,,.,.,,,,,,,,,,..,,,,,,,,,.,,,,,,,..,,..,,...,...,..,,.,.,,.,,...,.,.,
#DYSEMEBNN5FXIJO4SRVRK6JTYKZF6Z2CN4UNGKNM2QWNIORNSMMGADA3CO3UWU6W6BLQS2DIOUTFS
#\\\|SKINP4IR6OSTT5TMIPXIV5EZS36HJ2HB3H6FLUQOKHX3PNUEAGF \ / AMOS7 \ YOURUM ::
#\[7]FW267VKPS5VWFIQNRYM5SY4CSKEJOB7KYUDILKQDMWJIP6IYZWDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
