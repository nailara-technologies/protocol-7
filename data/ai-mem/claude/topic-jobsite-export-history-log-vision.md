---
name: topic-jobsite-export-history-log-vision
description: "jobsite export tracking, SEED: recency-only scoped undo ('vergessen last export') is a cheap partial fix; true undo-to-any-point needs a real per-batch export history log + browsable UI, not yet built"
metadata:
  node_type: memory
  type: vision
---

Grew out of a 2026-08-07 incident: an accidental CSV export followed by clicking "letzten
export vergessen" wiped the `exported_stage` marker on every job this jobsite had ever
exported (back to July), not just the accidental batch, because the old
`clearExportHistory()` cleared unconditionally. Fixed same session (see
`data/web-root/vhosts/jobs.vhost/index.html`, `clearExportHistory()` /
`exportCSV()` / `syncLastExportTime()`) by adding a per-job `exported_at` epoch (batch-shared
timestamp, also added to the backend whitelist in `src/plugin.web.jobs.sync:57`) and
scoping "vergessen" to only clear jobs whose `exported_at` matches the *current* known
last-export epoch — i.e. undo-the-most-recent-action semantics, not intent detection
(nothing can detect intent; recency is the only signal available and is sufficient for the
button's own stated purpose).

**The real gap, correctly identified by the user**: recency-only scoping can only ever undo
the single most recent batch. If two exports happen in sequence without an undo in between
(intentional #1, then accidental #2), "vergessen" reaches #2 but not #1 — there's no way
back further than one step. Fixing that properly needs:
- A real history log: each export batch as its own record (timestamp + list of job ids/
  stages touched), not a single scalar `exported_at` per job.
- A UI to browse that history and selectively undo/delete any individual past batch, not
  just "the last one" — conceptually similar to the trash panel's list + rescue button
  pattern already in the same file (`loadTrashPanel()`/`rescueTrashJob()`), which already
  solves an analogous "browse + selectively restore from a list of past actions" problem for
  trashed jobs.

**Why not built now**: meaningfully bigger scope than the recency-scoped fix — needs a new
per-batch data structure server-side (not just a bigger field on each job), plus new list/
delete UI, versus a few-line scoping change to existing code. The user's own assessment,
which matches: "that is much more complicated in comparison, as it also needs UI components
besides the data."

**How to apply**: if picked up later, look at the trash panel's existing list+rescue pattern
first (`index.html` `loadTrashPanel()`, `rescueTrashJob()`, `getTrashWatermark()`/
`syncTrashWatermark()`) as the closest existing precedent for "list of past events the user
can browse and act on individually" — the export history log would likely reuse the same
shape (a small per-batch record store + shared-prefs-style cross-browser watermark) rather
than inventing a new pattern from scratch.

#,,,,,,..,,,.,.,.,,,,,...,.,.,,,,,..,,.,,,,,,,..,,...,...,,.,,...,,,.,,,.,,,.,
#IDEOIRJXCHCMPX5PTPXCCSV34NDI2VLNLWDUIES5YIEQPZWBNHQPBCCFAUADNJ6WM76GNXZZMMCU6
#\\\|XI6SAHGMCGZTSKQFSKI6H34XXTWQ65EP4W6IDS2HO2IONQDGECG \ / AMOS7 \ YOURUM ::
#\[7]FH4HRI6TH6ZWFQRLBH4I6HCY3ELGTFOKP4Z2HNLFBGM3FM5Q4IBA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
