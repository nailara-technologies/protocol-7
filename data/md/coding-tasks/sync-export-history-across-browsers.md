# Task: sync "already exported" job tracking across browsers

## Background
The jobs.vhost UI (`data/web-root/vhosts/jobs.vhost/index.html`) has an
"already exported" filter (checkbox "bereits exportierte ausblenden") used
when generating the application-tracking CSV/print export. It hides jobs
that were already included in a previous export **at the same stage** —
if a job's stage has since changed (e.g. `applied` → `rejected`), it should
reappear.

This was just implemented and fixed (two rounds, both caught via live
multi-browser testing — see git log for `jobs UI: re-include exported jobs`
and `jobs UI: fix legacy export-history migration`) as a **browser-local**
feature: `jobsite_last_export_ids` in `localStorage`, a map of
`{ id: stage-at-export-time }`.

**The gap**: this tracking is per-browser. Exporting from Firefox does not
tell the web-browser zenka (or any other browser/device) that those jobs
were exported, and vice versa. Each browser independently thinks it's the
only one exporting, so the same already-sent applications can resurface in
a different browser's export.

## Goal
Move the "exported at stage X" fact from browser-local `localStorage` to
server-synced state, so exporting from *any* browser marks it everywhere.

## Scope decision — keep this in the web layer, not jobsite
This is a UI/export-workflow concern with no bearing on the actual
application pipeline (assessment, scoring, dispatch). **Do not touch
jobsite's schema, `jobsite.job.write`, or the jobsite↔web sync/watermark
machinery** — that machinery just went through a long bug-fixing pass this
session (see [[topic-plugin-web-jobs]] equivalent context if available) and
is fragile ground to build on carelessly. Handle this entirely within
`plugin.web.jobs.*` (the web zenka's own cache layer), the same way
browser-owned fields like `stage`/`notes`/`date_applied` already work via
`plugin.web.jobs.sync`'s non-batch (single browser update) branch — read
that branch first, this is the same shape of change.

## Read first
- `src/plugin.web.jobs.sync` — the single-browser-update branch (not
  the `is_batch` branch) is where a new browser-owned field/action gets
  handled. See how `stage`/`notes`/`date_applied` are read from
  `$job_data`, applied to `$cached`, and how `%changed` + `reverse.queue`
  work for propagating a change back out to other browsers on their next
  poll.
- `src/plugin.web.jobs.cache.write` — where a job record actually gets
  persisted to disk; confirm a new field just rides along in the job hash
  without special-casing needed (it likely does, check for an explicit
  allow-list of fields before assuming).
- `src/plugin.web.jobs.data` — the `/jobs.json` GET response builder;
  confirm any new field on a job record is already included in what gets
  served (it likely is, this endpoint mostly just serializes the cached
  job hash) — needed so a job's `exported_stage` is visible to every
  browser via the normal poll, not a separate endpoint.
- `data/web-root/vhosts/jobs.vhost/index.html`:
  - `pushChange()` — existing pattern for POSTing a browser-owned field
    change to `/jobs-sync`. A new "mark exported" action should follow
    this same shape (see also `deleteJob()`'s `action: 'delete'` pattern
    for an action that isn't a plain field, if marking-exported ends up
    needing action semantics rather than a plain field).
  - `loadLastExportIds` / `saveLastExportIds` / `wasExportedAtCurrentStage`
    / `getExportRows` / `exportCSV` — the current browser-local
    implementation to replace. Once `exported_stage` is a real synced
    field on the job object (arriving via the normal `/jobs.json` poll,
    same as `stage`/`status`), `wasExportedAtCurrentStage(j)` collapses to
    a trivial `j.exported_stage != null && j.exported_stage === j.stage`
    with **no separate localStorage map or migration needed at all** —
    this should substantially simplify the client, not just move the bug
    surface.

## Design
1. New field on the web-cached job record: `exported_stage` (string or
   null/absent). Not a jobsite field — web-layer only.
2. `exportCSV()` in the frontend, after building the export rows, POSTs a
   batch update (or one POST per row, matching whatever's cheapest given
   the existing `/jobs-sync` request shape) marking each exported row's id
   with `exported_stage = <that row's current stage>`.
3. `plugin.web.jobs.sync` applies the update to the cached job record,
   persists it, and (like existing browser-owned field changes) queues it
   into the reverse-flow so other browsers see `exported_stage` on their
   next `/jobs.json` poll — no new endpoint needed, it rides the existing
   sync path.
4. Frontend read side: `wasExportedAtCurrentStage(j)` reads `j.exported_stage`
   directly off the synced job object. `loadLastExportIds`/
   `saveLastExportIds`/the legacy-array migration all get deleted — no
   longer needed once the server is the source of truth.
5. **Migration of existing per-browser `jobsite_last_export_ids` data**:
   decide whether it's worth writing a one-time migration that POSTs the
   existing local map to the server on first load under the new code (so
   already-recorded exports aren't silently forgotten and everything
   doesn't reappear once), or whether — given how small/personal this
   dataset is — it's simpler to just accept a one-time "everything shows
   up once more" reset when this lands, and note that tradeoff explicitly
   for sign-off rather than deciding it unilaterally.

## Conventions (P7 house style, apply to any Perl changes)
- `<[base.logs]>->(severity, 'fmt %s', $arg)` logging only.
- Lowercase `[ word ]` bracket-style comments, narrative flow.
- No hand-written AMOS7 signature/footer blocks in new/modified Perl files
  — the project's signing tool generates those at commit time.

## Definition of done
- [ ] Exporting from browser A marks jobs as exported; browser B's next
      poll (no manual action needed) reflects that — verify live across
      two actual browser sessions, not just code review, same as the
      local-only version's bugs were only caught by live testing.
- [ ] A job's stage changing after export makes it reappear in **every**
      browser's export table, not just the one where the stage change
      happened.
- [ ] `jobsite_last_export_ids`, `loadLastExportIds`, `saveLastExportIds`,
      and the legacy-array migration are removed from the frontend (or
      kept only as a one-time migration path, per the design-doc decision
      above — don't leave dead code either way).
- [ ] No jobsite-side files touched; change is contained to
      `plugin.web.jobs.*` and the frontend.
- [ ] Explicit migration-tradeoff decision (above) documented in the PR/
      commit message, not silently chosen.

#,,,,,,,.,,.,,..,,,..,,.,,,.,,,,,,.,,,,,,,,..,..,,...,..,,.,,,.,,,.,,,...,.,,,
#5V4N35GQAD4DVCX5LFEJXDAWBWBCEP7UUFQF6ZJX3KIRJBB2PKFLM5275LA3C4LN4QSWQ3QFGU46C
#\\\|FRSXYQQO2A6FGNIUJHQMQJHMFVO55FMKOO4Q5BT5D4WUEY77YPQ \ / AMOS7 \ YOURUM ::
#\[7]R6WN2MRHS3S4YR32NDMDXKCW5JHO6RUSA5TTV6BWXLI3ZPWLZOAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
