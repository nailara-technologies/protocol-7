# Task: bounded undo stack for jobs.vhost export-history actions

## Background
`exported_stage` sync across browsers landed this session (see git log
`jobs UI: ...export...` commits and `data/md/coding-tasks/sync-export-history-across-browsers.md`,
now implemented). While debugging that work we found two related risks:

1. **`clearExportHistory()` ("forget last export" button) is now a global
   action.** It pushes `exported_stage: null` for every job to the server,
   which propagates to *every* browser via the existing reverse-queue path
   (same mechanism as `stage`/`notes`/`date_applied`). One accidental click
   on any browser wipes every browser's export tracking, not just the
   clicking browser's — there is currently no undo.
2. **An aborted export can leave a partial batch.** `exportCSV()` builds the
   CSV, triggers the download, then does
   `await Promise.all(rows.map(j => pushChange(j.id, {exported_stage: j.stage})))`.
   If the browser/tab dies or the network drops mid-loop, some rows in that
   batch get `exported_stage` written and others don't — an inconsistent,
   hard-to-spot partial mark with no way to cleanly revert just that batch.

## Design (agreed in prior session's discussion, not yet built)
A **single generic "last state" backup slot is not enough** — if the user
exports again (or clears again) before noticing an aborted/bad batch, a
single slot gets overwritten and the mess becomes unrecoverable. Track a
short **bounded stack of the last ~5 actions** instead, each entry recording:
- `type`: `'export'` or `'clear'`
- the specific job IDs the action touched
- each touched job's `exported_stage` value *before* the action ran
- a timestamp

"Undo" pops the most recent entry (or lets the user pick from the last few,
not just always the newest) and restores exactly those job IDs to their
pre-action values — propagated via the same reverse-queue path so it lands
correctly on every browser, not just the one clicking undo.

**Critically: the stack itself must live server-side**, not in browser
localStorage. This session's actual incident: the `web-browser` zenka runs
with `cfg.ephemeral = 1` (`cfg/zenki/web-browser/zenka-startup.v7`)
— a WebKit private-browsing-style context where localStorage/cookies/
IndexedDB are wiped on every process restart. A client-local undo buffer
would silently recreate the exact same class of data loss this feature
exists to prevent. Store the stack in the web zenka's own cache
(`plugin.web.jobs.*`, same layer as `exported_stage` itself), not in the
browser.

## Scope — same boundary as the original export-sync task
Stay in `plugin.web.jobs.*` and the frontend only. Do not touch jobsite's
schema or the jobsite↔web sync/watermark machinery.

## Read first
- `data/web-root/vhosts/jobs.vhost/index.html`:
  - `exportCSV()` — where the export-marking batch happens; the undo stack
    needs to record, before the `Promise.all(rows.map(...))` push loop, the
    exact `{id: previous exported_stage}` set for every row in that batch.
  - `clearExportHistory()` — same pattern for the clear-all batch.
  - `migrateLegacyExportHistory()` — recently added; not directly relevant
    but nearby code, same file region.
- `src/plugin.web.jobs.sync` — `@browser_fields` handling; the backup
  stack likely needs its own small server-side storage (new field or a
  dedicated small cache file under `plugin.web.jobs.cache.path`), not a
  per-job field like `exported_stage` — it's a single shared stack, not
  per-job state.
- `src/plugin.web.jobs.cache.write` / `cache.path` — existing pattern
  for where/how the web zenka persists its own state to disk.

## Definition of done
- [ ] A batch action (export or clear) pushes an entry onto a server-side
      bounded stack (last ~5), recording type + affected ids + their prior
      `exported_stage` values + timestamp.
- [ ] An "undo" UI action reverts a chosen entry (defaulting to most recent),
      restoring exactly the affected jobs' prior values and propagating to
      all browsers via the existing reverse-queue path.
- [ ] Undoing an aborted/partial export batch correctly restores every job
      in that batch to its pre-export state, including ones that succeeded
      and ones that failed to POST — verified by simulating a partial batch
      (e.g. stop the browser mid-`Promise.all` in devtools) and confirming
      undo cleans up the entire batch, not just the failed rows.
      accidentally clicking "forget" no longer permanently loses history —
      undo restores it exactly, across a *different* browser than the one
      that clicked forget.
- [ ] Undo stack survives a restart of the `web-browser` (ephemeral) zenka —
      because it's server-side, not localStorage.
- [ ] No jobsite-side files touched; stays in `plugin.web.jobs.*` + frontend.

## Conventions (P7 house style, apply to any Perl changes)
- `<[base.logs]>->(severity, 'fmt %s', $arg)` logging only.
- Lowercase `[ word ]` bracket-style comments, narrative flow.
- No hand-written AMOS7 signature/footer blocks in new/modified Perl files
  — the project's signing tool generates those at commit time.

#,,,.,..,,,,,,,..,,.,,,,,,,..,.,,,..,,..,,...,..,,...,..,,...,.,.,,.,,..,,,.,,
#ZBDRDE5OKUGTNMAEX46H5REHEZLU3I47YW5QWR3I346YAJLC6XEDPKG3VQSA7UYY3E2FQMBIBOGLA
#\\\|2CDOXDRNGKPI5A46CD7FW2P5G5XIHKYLN6XGWE2XDQDZ3MIQ22U \ / AMOS7 \ YOURUM ::
#\[7]72PFU3DQIJVEDPKLAZPORTZXHDYP7GUQ3TSH6YUGDMVZIVWMKCDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
