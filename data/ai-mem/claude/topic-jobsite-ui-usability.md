---
name: topic-jobsite-ui-usability
description: "jobsite review-tab UI usability fixes — always-visible subtle/highlighted action buttons, sync render-gating to avoid interrupting in-progress edits"
metadata: 
  node_type: memory
  type: project
  originSessionId: 2fd2266d-f629-4896-958f-fa6ab8dd684a
---

Confirmed working and staged (2026-07-13): jobsite review-tab UI usability upgrade in `data/web-root/vhosts/jobs.vhost/index.html`.

- Apply/skip buttons moved out of the crowded `.card-actions` row into a new `.card-quick-actions` row pinned to the card bottom (`justify-content: space-between`; apply bottom-left, skip bottom-right), always rendered in the review tab instead of only appearing when the AI recommendation matched.
- Introduced `.badge-subtle` (dim/low-opacity) for the non-recommended state vs. existing `.badge-yes`/`.badge-no` for the recommended/highlighted state — buttons stay reachable at all times but only visually "pop" when actually recommended.
- Root cause of the "sync kicks you out of what you're doing" complaint: `syncPipeline()` called `render()` (full `list.innerHTML=''` rebuild) unconditionally on every poll tick, even when the delta fetch (`?since=lastNtime`) returned zero changes. Fixed by gating `render()` on `added>0 || updated>0 || removed>0 || migrated || wasInitial`.
- `migrateLegacyExportHistory()` never returned a value on any path — had to add `return true` at its end so the render-gate could detect it actually did something.
- Also added defense-in-depth for the case where render() *does* still fire mid-edit: capture/restore focused `.card-note-input` (by job id + cursor position), open `.stage-dropdown`, and list scrollTop across the rebuild.

**Why:** user explicitly flagged that editing a note (or anything else mid-interaction) got reset every ~30s poll cycle, and correctly diagnosed the root cause themselves ("I think it recreates the list even when no changes") before asking for the fix — trust that kind of root-cause guess from this user, they read the code.

**How to apply:** for future jobsite (or similar poll-driven) UI work, default to gating full-rebuild renders on an actual-change check rather than firing on every poll, and prefer capture/restore of interactive DOM state (focus, cursor, open menus, scroll) around any render() call that can land asynchronously mid-user-interaction. See [[topic-plugin-web-jobs]] for the broader jobsite plugin history.

## follow-up fix (2026-08-03, commit `7688320c5`)

Landed by the coding zenka in a session that had timed out; user committed directly with the zenka's suggested message.

- `mergeJobs()` was dropping notes on fresh loads / empty localStorage: server persists the field as `notes`, UI reads/renders `note` — no mapping existed between the two, so new jobs (or a cleared cache) silently lost existing notes on merge. Fixed by mapping server `notes` → UI `note` inside `mergeJobs()`.
- `repair_failed` badge/stat checks used `=== true`/similar, which never matches the zenka's `TRUE=5` constant arriving over JSON — see [[critical-patterns]]'s TRUE≠1 entry, now cross-referenced there. Fixed in `renderCard()` (badge display) and `updateStats()` (rfl metric count).

#,,..,,..,..,,...,...,,,,,.,.,,,.,.,.,,,,,,..,..,,...,...,,,.,...,,,.,...,.,.,
#BNGSUVROI32PNHKH6CJQ45IDXO3NYB7VQWOZW73NRWBUJYGV3E6IVXIPRULVC7WDVAV5LLGN2T2ZS
#\\\|JFNMMIDQJKGZTFLSEZE6WWI75EDGZKL6GC5P6GSGWSTOOWFCEHC \ / AMOS7 \ YOURUM ::
#\[7]BJL5LVUSAS3RY3N74RKK5QMANEHTOEYVG64TNUYBEJILK6JUC6DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
