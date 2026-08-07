---
name: topic-generic-web-template-resource-error-tripwire
description: "generic web-template pattern, SEED: URL-tagged fetch errors as a passive tripwire for browser-blocked resources (e.g. custom fonts), escalating to active probe + contextualized message only once actually observed"
metadata:
  node_type: memory
  type: vision
---

Grew out of [[topic-jobsite-firefox-webfont-resolved]] (jobsite's custom font silently
failing in Firefox — root cause was a per-font `font_allowlist` exception, not
`use_document_fonts` itself, not the WOFF2 embed). Not yet implemented anywhere; agreed
design direction for the generic web templates the user is planning next, since full
control over used fonts is already a stated requirement for those.

**The pattern, three stages, cheapest-first:**

1. **Tag existing fetch errors with their URL.** Every `notify('... fehler: ' + e.message)`
   call site (jobsite has several: `JOBS_SYNC`, delete, re-assess, import, trash/rescue —
   see `data/web-root/vhosts/jobs.vhost/index.html` lines 966/1043/1272/1461/2042/2371/2424)
   should become `notify('... fehler: ' + url + ': ' + e.message)`, or centralize through one
   wrapped fetch helper that does this automatically. Near-zero cost, rides on error handling
   that already exists.

2. **Passive pattern-match as a tripwire, not a proactive check.** In the shared error path,
   string-match `e.message` against the browser's generic resource-block signature —
   Firefox: "NetworkError when attempting to fetch resource"; Chrome: "Failed to fetch";
   Safari: "Load failed". This rides on errors that already fire; it does not run any check
   on its own. Only escalate to stage 3 when this pattern actually appears *and* the tagged
   URL is a resource we care about (e.g. the font file) — don't probe preemptively on every
   page load.

3. **Active confirmation, only once the tripwire has actually fired.** Explicit
   `fetch(fontURL)` or a hidden-element canvas/DOM text-width comparison (custom-font vs.
   fallback rendered width) to confirm the resource genuinely failed to apply, as opposed to
   a one-off network blip. Once confirmed, replace the generic message with a minimal,
   purpose-specific one — agreed wording: `'custom font loading failed'` — as the
   confirmation hook, without jobsite itself needing to explain *why* (arkenfox/
   `use_document_fonts`/font_allowlist) since jobsite is a one-off custom page, not the
   template.

**Why the staged approach, not a single check:** avoids adding proactive cost (a FontFace
probe or canvas comparison) on every load for the common case where nothing is wrong; the
existing error-reporting plumbing already does 80% of the detection work for free, the
active probe is reserved for the rare confirmed-suspicious case.

**How to apply going forward:** when the generic web-template work actually starts, this
three-stage tripwire→probe→contextualized-message pattern is the intended shape for
resource-load diagnostics in general (not just fonts) — the *contextualized*, actionable
remediation text (e.g. explaining `use_document_fonts` / font-allowlist to the end user)
belongs in the generic template layer, not in one-off pages like jobsite, which only needs
the minimal confirmation string.

**Update 2026-08-07, stage 3 implemented in jobsite directly and fully verified live** (skipped straight
to an active probe rather than waiting on stage 1/2's passive tripwire, since jobsite has no
JS fetch for the font at all — there's nothing for a passive tripwire to ride on for this
specific resource): `checkCustomFontLoaded()` in `data/web-root/vhosts/jobs.vhost/index.html`
does a canvas `measureText` width comparison (custom-font-first vs. fallback-only string,
using the page's real fallback stack) once at startup after `document.fonts.ready`. On
mismatch it calls the extended `notify(msg, err, {timeout, onClick})` — `notify()` now
accepts a third options arg for a longer auto-hide timeout and a click handler — with a
6.5s timeout and `onClick: showFontFixPopup`, a styled modal (dark bg, blacklight border,
gold heading, explicitly avoiding white/gray) explaining the Firefox
`use_document_fonts`/font_allowlist mechanism from
[[topic-jobsite-firefox-webfont-resolved]]. Stage 1 (URL-tagging existing fetch errors) and
stage 2 (passive pattern-match tripwire riding on those) are still NOT implemented — only
worth doing if/when a resource that's actually fetched via JS (JSON sync, trash, etc.) needs
this same treatment, or for the generic templates where more resources are JS-fetched.

**Live end-to-end verification, same session**: user confirmed the full loop worked exactly
as designed — probe detected the missing font, clickable toast fired, popup showed the
`use_document_fonts`/font_allowlist explanation, user followed the popup's instructions
verbatim (added 'White Rabbit' to their Firefox font_allowlist), reloaded, font rendered
correctly and the toast no longer fired. Validates the detection mechanism (canvas
measureText comparison), the notify/popup UX (6.5s clickable timeout), and the popup's
remediation text itself, all in one pass — this pattern is now battle-tested, not just
designed, and safe to carry into the generic web-template work without re-verifying the
approach from scratch.

#,,,,,,,,,,.,,.,,,..,,,,,,,,,,,..,..,,..,,,,,,..,,...,.,.,.,.,,,,,,,,,,..,...,
#LFTJXCCHUY26MKREZRKMOUZAGKKFWCCLO7AW5EKX7G7MR4JY7WYMLT6LA44S2LO7LU4AUZJVSZHGM
#\\\|OB47IBGBB6FSPL4G762YEOBKX6JNYFBOH2WB2HF52FW3EBVGCRT \ / AMOS7 \ YOURUM ::
#\[7]KI2BMYV46ETWWVWW5YDNYE64HJJUI4RKQSX2N3FKZ67MIDPZOAAA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
