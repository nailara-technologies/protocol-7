---
name: topic-jobsite-ui-polish-queue-2026-08-07
description: "RESOLVED 2026-08-07: note-input cursor bug (was a draggable-card side effect, not a focus/selection bug) and the washed-out/near-white blue accent cluster, both fixed and live-verified"
metadata:
  node_type: memory
  type: project
---

Two fixes flagged during the font-notify session (2026-08-07), both landed later the same
session — see [[topic-jobsite-firefox-webfont-resolved]] and
[[topic-generic-web-template-resource-error-tripwire]] for the other work that session.

1. **Note-input cursor jump / no text selection anywhere on cards — FIXED, live-verified.**
   Original diagnosis in this memory (a focus/selectionRange bug in the note-open code) was
   **wrong**. Real root cause, found by the user's own recollection ("the same reason why no
   text from the cards can ever be selected using the cursor"): `el.draggable = true` on
   every `.job-card` (`index.html`) made the *entire* card an HTML5 drag source, hijacking
   any mousedown-plus-movement — including a plain click-drag to position a text caret —
   anywhere on the card, not just the note field. The drag-reorder feature it was for was
   also confirmed **dead code**: `reorderCards()` wrote a `sort_order` field that
   `sortedJobs()` never read, so dragging never had any visible effect regardless of sort
   mode. Fixed by removing the whole feature (`draggable`, the 5 drag listeners,
   `reorderCards()`, `dragSrcId`, both `sort_order` writes, `.dragging`/`.drag-over` CSS).
   Follow-on fix: with selection newly working, the card's manual single/double-click
   fold-toggle handler didn't know a click ending a text-selection drag (or a native
   double-click-to-select-word) wasn't meant to fold/expand or fire a stage action — added a
   `hasSelection()` guard (`window.getSelection().toString().length > 0`) to the card
   click handler, the `reasonEl`/`summaryEl` expand toggles, and the long-press handler.
   Separately, `.card-dims`/`.toggle-dim` ("▼ dimensionen") lacked `e.stopPropagation()`, so
   toggling them also bubbled up and toggled the main-text fold as an unwanted side effect —
   fixed with `stopPropagation()` in both handlers.

2. **Washed-out/near-white blue accents — FIXED, live-verified against screenshots.** Final
   choices (deliberately simpler than the first attempt, which introduced two new
   near-pure-blue hues — `--p7-true #0647C3` for the title and the body's inherited
   `--p7-fg #0028c0` for checkbox-panel labels — that turned out to be exactly the kind of
   outlier being fixed; both replaced with hues already inside the page's established range):
   - `Bewerbungsübersicht — <date>` title → `var(--p7-fg-bright)` (same hue as the page's own
     `<h1>`), not a separate "TRUE blue" hue.
   - `.export-section label` (covers "bereits exportierte ausblenden" and "current filter
     only") → explicit `var(--p7-text-soft)`, was inheriting body's near-pure-blue `--p7-fg`.
   - Every remaining `var(--p7-accent2)` (`#001EBB`, the over-saturated one) swept to
     `var(--p7-accent)` (blacklight `#4427AC`) project-wide in this file — table borders,
     CSV/download-link border, `.btn-note-toggle`, `.ftab:hover`, reassess button,
     card-summary/note-preview hover borders, add-form inputs, an inline `onfocus` handler,
     a divider border. `--p7-accent2` variable itself removed as dead once unused.
   - Checkbox `:checked` background → blacklight-tinted (`rgba(68,39,172,0.55)`), checkmark
     + border → `var(--p7-gold)` (was a near-white `#cfe0ff` checkmark on a saturated-blue
     background — the exact "same color as background + white checkmark" complaint).
   - `button.active` (e.g. "tabelle ausblenden" once toggled) → text + border both
     `var(--p7-gold)` (was near-white `#a0c0ff` text on a saturated-blue `rgba(0,58,255,...)`
     border).
   - General `button:hover` (applies to every plain button, not just the ones above) → was
     ALSO still saturated-blue background + near-white `#cfe0ff` text; the user caught this
     as a second round after the first pass looked "much better" but still had "some blue...
     and white... especially hover font color" — fixed to blacklight-tinted background +
     `var(--p7-fg-bright)` text.

**Lesson for next time a color gets flagged as an "outlier"**: the user's standard, stated
explicitly this round, is that near-pure/saturated hues (near-`#0000ff` blue, near-white)
break a fine-tuned, already-desaturated/violet-shifted palette even when the specific hue
[e.g. this project's own canonical "TRUE blue" `#0647c3`] is a legitimate brand color
elsewhere — on THIS page, prefer reusing a color already present in the established local
range (`--p7-fg-bright`, `--p7-text-soft`, `--p7-accent`, `--p7-gold`) over introducing any
new, more-saturated hue, even one from the same brand palette.

#,,..,.,.,,.,,,..,..,,,,,,.,,,.,,,..,,...,,,,,..,,...,...,,,,,...,..,,..,,..,,

#,,,.,,..,.,,,,,.,,,,,,.,,.,.,..,,,.,,,.,,...,..,,...,...,.,,,...,,..,,.,,,.,,
#WB3AAHCUW66LCPBAWS3T4TG6WGDEKJB3TPBMBRGJK3G3FLDRO3U6M3OW2KKPOCWGEG2V5HVD2EO44
#\\\|SBN6EPLII6O7X5QTMFUGQGXW6BSZNJLQMENSKLKZHJD2525XDQ2 \ / AMOS7 \ YOURUM ::
#\[7]WNDHVUDGFH2KI7WMB72HSZHSAAPTIYQNBOFNPXBR4R73X33GDADA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
