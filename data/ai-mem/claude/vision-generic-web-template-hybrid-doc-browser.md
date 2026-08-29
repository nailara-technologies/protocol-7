---
name: vision-generic-web-template-hybrid-doc-browser
description: "SEED: four-stage plan — extract interview-cheatsheet CSS/component vocabulary into generic skin templates, then a src.v7.ax hybrid code+doc browser (type-to-search, file-history diff tooltips, expandable perspective frame that can 'become' the whole site), then a locked-down web-browser clone for local system config, then the same framework as a network-exportable/simulatable protocol-7 config builder on the site"
metadata:
  node_type: memory
  type: vision
---

Grew out of a 2026-08-28 cancelled job interview (customer filled the position before the
call). The prep doc that was built for it, `/data/interview/interview-cheatsheet.de.html`
(deliberately OUTSIDE the repo tree — real employer name, clearance levels, nationality,
financial history, see [[feedback-no-personal-data-in-repo-tree]]), turned out to be
polished enough in structure that the user wants to extract its *component vocabulary* —
not its content — into reusable base-branch templates.

**What's reusable from the cheatsheet** (pure CSS/JS pattern, no personal data): dark
violet/blue palette (`--bg-void`, `--spectrum-*`, `--glow-*` custom-property scheme),
sticky header that compacts on scroll, `.tt` abbreviation-tooltip pattern (hover/focus,
flips above/below depending on table-cell context), `.glossary` two-column definition
table, `.cue-list` bullet list with `▸` markers, `.tag`/`.flag` pill badges, `.anchor-cube`
callout block.

**Four-stage plan, roughly in dependency order**:
1. **Template extraction** — pull the above into a generic skin under the existing
   `template.*` / `web.skin_resolver` / `web.render_skinned_content` pipeline
   (`src/template.init_code` is Mustache-based server-side rendering with a skin cascade;
   this would add the client-side CSS/JS vocabulary as a skin, not replace the engine).
   Mechanical, low-risk, no design decisions blocking it.
2. **`src.v7.ax` vhost — hybrid code+documentation browser**: type-to-search (jobsite-style,
   though no dedicated jobsite search-UI module was found by name — likely inline in its
   vhost JS, not a `jobsite.*` src module), recent-file-history tooltips with animated
   diffs, click-through from a highlighted file to a full version-control view, an
   expandable parent frame for related perspectives/project topics so the browser can
   "become" the entire website incrementally. Needs real new build on the VCS side —
   `git.parent.get_log`/`git.parent.init_code` exist but are thin (log only, no diff
   rendering); `sourcecode.*` is signing/checksums, not browsing. Highest-leverage next
   step: read-only against the user's own repo, and it's the thing that actually proves
   stage 1's templates out.
3. **Locked-down local system config/setup/management UI**: reuses stage 1's templates,
   proposed as "a locked and stripped down clone of the web-browser zenka" for local,
   browser-accessible system configuration. Depends on stage 1 being solid plus a config
   schema/form-builder that doesn't exist yet — bigger scope than it first looks.
4. **Network-facing config builder**: same template framework, but for building/exporting
   a customized protocol-7 configuration on the website, "possibly even simulating and
   visualizing it." Export-on-demand is buildable now in principle; *saving* a built config
   to the network is explicitly gated by the user on a future user-account system
   ("once a form of user accounts in the network exist") — don't build the save-to-network
   path before that exists, export-only is fine.

**How to apply**: if resumed, start with stage 1 only unless the user has since said
otherwise — it's the common substrate every later stage depends on, and it's the only
stage with no open design questions blocking it. Don't build stage 3/4 UI or the
save-to-network path speculatively; stage 4's save path is explicitly blocked on
not-yet-built user accounts.

**2026-08-28, same session — stage 1 first slice landed**: added
`var/httpd/skins/spectrum.tmpl` (new selectable skin alongside `default.tmpl`, same
`<{title}>`/`<{menu}>`/`<{content}>` placeholder contract) plus a cross-zenka shared
component bucket at `data/web-root/shared/templates/components/` (new directory —
existing `shared/templates/*` were all per-zenka before this): `spectrum.css` (the
content-vocabulary classes, no page chrome, standalone-usable by any static vhost page),
`type-to-search.js` (debounced search input + auto-focus-on-keypress + `.search-hl`
highlighting, generalized from jobsite's `jobs.vhost/index.html` search bar — no
dedicated `jobsite.*` src module exists for it, it's inline vhost JS), `toast-notify.js`
(generalized from the same file's `notify()`). Caveat carried over from stage 1: the
skin/template engine (`web.render_skinned_content`) is confirmed NOT wired into
`httpd.route_dispatcher` or anywhere else in the request path — nothing currently serves
a skin per-vhost, `default.tmpl` isn't live either. And the new `shared/templates/components/`
JS/CSS files aren't confirmed reachable over HTTP yet either (no `shared/` reference found
in any existing vhost page, no route match for it) — treat both as ready-to-wire source,
not yet live.

**Style-source discovery**: `data/asc/what-AI-thinks/html-form/` holds 227 HTML files
(149 per its own `INDEX.md` from 2025-10-23, grown since), already categorized into
7 top-level dirs with per-dir `INDEX.md` (visualizations/ 97 files — mostly WebGL/Canvas
3D demos, different genre from the document-reading style (tooltips/glossary/typography)
relevant here; also frameworks/, protocol7/, documentation/, templates/, tools/,
branding/). Confirmed too large to manually read through this session — this is the
concrete target for the deferred "scan many documents for style elements" step.

**Correction, later same session — first version of this note overclaimed,
user caught it**: the batch SPEED fix was `<web-browser.slideshow.
no_scroll>` — an EXISTING flag, `//= 0` in `web-browser.init_code`,
already checked in `web-browser.callback.load_finished` to gate whether
`scroll_start` gets called at all. Set via devmod (`v7.devmod-enable
web-browser` then `web-browser.set web-browser.slideshow.no_scroll 1`),
zero new code, ~136s/page down to ~9s/page. Real lesson: check for an
existing config/flag before reaching for new code, even with a
plausible-sounding new-command design already in hand.

BUT this is NOT a strict improvement over the old scrolling behavior, and
does NOT make `set-pos-y`/`set-fg-pos`/`set-bg-pos-y`
(`data/tasks/web-browser-fast-scroll-position-commands.md`, built by kimi)
unnecessary — that was the actual over-claim. `no_scroll` freezes every
capture at the very TOP of the page. The OLD scrolling version never
supported capturing a deliberately-CHOSEN position either — because
`capture_on_fade` fires "one iteration behind" (right as the NEXT page
starts loading), a scrolling-enabled capture happened AFTER that page's
full auto-scroll-to-bottom had already completed, i.e. it captured the
BOTTOM of the page, not any targeted position. So the real comparison is
top-of-page/fast (now) vs. bottom-of-page/slow (before) — a trade, not a
regression fixed. Neither gives real position-targeted or paginated
capture. That still needs `set-pos-y` wired into actual paging logic
(decide how many "pages" a tall document needs given its rendered height
vs. viewport height, capture at each offset) — genuinely unbuilt, not
something this flag unlocks by itself. Don't claim this is done until
that paging layer exists.

**Scope clarification, user, same thread**: top-of-page-only IS still useful
— "a start for getting an overview" — but systematically misses below-the-
fold style elements (glossary tables, footers, cue-lists, anything past the
first viewport), which matters directly for the web-template-EXTRACTION use
case this whole plan is for, not just general browsing. Resolution: this
matches the two-pass plan already above, unchanged — the fast top-of-page
batch is PASS 1 (broad, cheap, palette/layout overview to shortlist ~15-20
promising candidates from all 227). Pass 2 (actually extracting reusable
components from the shortlist) needs full-page content, not top-of-page —
either the old scrolling capture re-run against just the shortlisted files
(slow is fine at that scale), or the paging system once built. Don't expect
component extraction to come out of the fast full-corpus batch itself.

**Screenshot-triage plan for that scan, refined 2026-08-28**: don't open 227 images
individually. Loop `web-browser.cmd.get_snapshot` over the corpus, tile ~9-10 thumbnails
per collage (→ ~24 collage images total) via an ImageMagick `montage`-style step, caption
each cell with a short id (first-8-chars-of-checksum or relative path — NOT the full AMOS
chksum rendered graphically, illegible at thumbnail scale) so cells stay self-identifying
without a separate legend. Two-pass: collage pass is triage only (palette/mood/layout
shape, not fine detail) to shortlist ~15-20 promising pages, then open only those
individually at full res for actual extraction. Not yet built — needs the get_snapshot
loop + montage/caption tool as its own small step before the actual scan can run.

**Reuse discovery, same session, before building any of the above**: don't write
similarity/clustering from scratch — a full `graphics-matrix` zenka already has it
(`src/graphics.matrix.visual.phash`, `.similarity`, `.hamming`, `.find-clusters`,
`.group-by-proximity`, `.group-by-color`, `.cluster-center`, plus the CLI entry
`graphics-matrix.cmd.assert-similarity`). It even already groups similarity clusters into
prioritized review batches (`graphics.matrix.visual.vision-batches`) — but that's built
for a different consumer: the `lm-vision` zenka analyzing *its own* image corpus for
`deduplication_analysis`, sphere/cubic-addressed, not for me (the interactive assistant)
reviewing HTML-page screenshots. Two live options for the actual triage step, not yet
decided between:
1. Cluster with the existing phash/similarity code, render our own collage images (short-id
   captioned, per the plan above) for me to open directly with my own vision.
2. Cluster the same way, then dispatch each cluster through `lm-vision.cmd.analyze_image`/
   `complete-analysis` to a local vision model and read back its TEXT description —
   cheaper on context than any image, but trades my own visual judgment for the local
   model's, which matters for a subjective call like "does this have good reusable style."
Either way the phash/clustering layer is reuse, not new code — only the render-collage
step (option 1) or the batch-dispatch-and-read step (option 2) is net-new.

**Further correction after reading the actual code (same session)**: `find-clusters`/
`group-by-proximity`/`group-by-color` are NOT generic — they cluster on a `cubic_coord`/
`sphere` classification that's specific to graphics-matrix's own cubic-pixel-color-space
addressing model, built for something like color-swatch cells, not full-page screenshots.
Not a drop-in clusterer. Also found two live bugs in the shared similarity code while
reading it (not yet fixed, out of scope to touch — it's shared zenka code, not owned by
this task): `graphics.matrix.visual.similarity`'s `resolution` param is read into
`$target_res` and never used anywhere in the function body (dead parameter); its
`color_sample` method always compares against fallback gray `[128,128,128]` for real
file-path images because `detect-resolution` never populates `rgb` for the file-path
branch (only for literal 1x1-pixel-array input) — so `color_sample` is silently
non-functional on real images today. `perceptual`/`cubic`/`structure` methods work
correctly on real files (confirmed `Image::Hash` IS installed at
`/usr/local/share/perl/5.42.3/Image/Hash.pm`, so `ahash()` runs for real, not the
byte-header fallback).

**Decided approach given the above**: don't call the live graphics-matrix zenka at all
for the O(n²) pairwise step (227 images → 25,651 pairs — impractical over per-pair p7c
round-trips anyway). Write a standalone script that reuses the *proven algorithm*
(Image::Hash ahash + Hamming/64) directly, computed at two preprocessing scales per the
user's 2026-08-28 suggestion: a dramatically-downscaled pass (color/region-level signal)
and a higher-resolution pass, combined as a weighted score — this is genuinely new logic
(the shared code picks one method, never blends), just built on the same proven primitive.
Clustering: a small new greedy loop modeled on `group-by-proximity`'s existing pattern
(threshold-gated greedy assignment) but keyed on the combined score instead of cubic
distance — `find-clusters` itself isn't reusable as-is per the correction above. Render
step: `montage`/`convert` (ImageMagick 7.1.2, confirmed installed) with `-label` captions
of short ids, no custom rendering code needed.

**Screenshot capture — GUI-fragility risk found and resolved, 2026-08-28**: 227 sequential
load+snapshot cycles through the live `web-browser` zenka would mean 227 live WebKitGTK
interactions under WSLg/Weston, which carries the documented freeze-needs-full-reboot
hazard (see [[feedback-weston-move-unreliable-use-compositor-grab]]). Resolved: run
`web-browser` under a headless `Xvfb :99` virtual display instead of the live WSLg
display — confirmed `Xvfb` is installed, confirmed `web-browser` zenka isn't currently
running and has no `DISPLAY` pinned anywhere in its config (`cfg/zenki/web-browser/`), so
this is purely an env-var choice at launch (`DISPLAY=:99 ./bin/Protocol-7 web-browser`),
no code/config changes needed, and it fully sidesteps the hazard since Xvfb has no
compositor to freeze. No headless-chromium/wkhtmltoimage/cutycapt alternative is
installed, so this Xvfb + the real web-browser zenka's `get_snapshot` is the path, not a
separate headless renderer.

**Not yet executed**: script not yet written, no batch run yet, nothing started (no Xvfb
process, no web-browser instance under it). Plan: write the driver, test on a small
subset (~10-15 files) end-to-end before committing to the full 227-file run.

**Blocked, 2026-08-28, same session**: attempted to start the Xvfb display and hit a real,
pre-existing crash-loop bug in `X-11.cmd.xvfb-start` — full detail
`data/tasks/x11-xvfb-start-async-refactor.md` and
[[feedback-x11-xvfb-blocking-connect-crash]]. One bug fixed (a dependency deadlock that
meant `xvfb-start` never did anything at all), one still open (a blocking `X11::Protocol
->new()` connect inside a timer callback stalls the whole X-11 zenka's event loop long
enough to trip v7's heartbeat watchdog — confirmed live 3 separate times, each one
crash-looping X-11 and its dependents). This whole collage-triage plan is downstream of
that fix landing — don't attempt the screenshot batch again until
`x11-xvfb-start-async-refactor.md`'s status changes.

**Update, later same session**: pivoted to the live web-browser zenka's existing mature
slideshow (`content.add-entry` + `web-browser.start_slideshow`) per the user's steer, and
attempted a var-watcher hook for snapshot capture (`event.add_var` on
`<web-browser.slideshow.url_index>`) so no slideshow code needed touching. Never got it
firing despite matching two independent working precedents exactly, and a second
unrelated crash-loop happened along the way (web-browser this time, different mechanism
than the X-11/alarm() one). Session called off by the user ("leave it broken.. this
session sounds degraded.."). Full detail, everything tried, and how to pick it up:
`data/tasks/web-browser-capture-slideshow-var-watcher.md`. The screenshot-triage plan
itself is now blocked on TWO unresolved things, not one: the X-11 Xvfb async bug, and
this capture-hook gap (or its external-polling fallback, not yet built either).

**Update, same session**: worked around the X-11 blocker per the user's own suggestion —
running the ALREADY-STARTED, regular (live-display, not headless) `web-browser` zenka
directly instead of waiting on the Xvfb fix. Confirmed `file://` URIs load fine through
the existing `web-browser.load_uri` with no changes needed. Two real capture-quality bugs
found and fixed before the batch could run cleanly: (1) needed a ~1.5s settle delay
between load and snapshot — `load_uri`'s "finished loading" is the DOM/resource load
event, not any CSS fade-in transition on top of it, so without the delay some pages would
get captured mid-fade; (2) zoom factor 1.0 came out as ~217% effective on this display
(HiDPI scaling compounding with the zoom factor) — way too cropped-in; 0.5 lands close to
a true 100% effective zoom, confirmed visually. Driver script:
`scratchpad/style-triage/capture-all.sh` (per-session scratchpad path, not repo-tracked),
clustering/collage script `scratchpad/style-triage/cluster-and-collage.pl`. User is
comfortable with animated pages rendering briefly live on their actual screen during the
batch (asked explicitly given their documented screen sensitivity, they said brief
exposure per page is fine).

**Early candidate hit, before the full triage batch even finished**:
`visualizations/spectrum/iris-spectrum.html` — a circular hue-wheel color picker with
Blacklight Intensity / Fluorescence Level / Iris Aperture / Rotation Speed sliders.
User's own reaction: "already amazing for a protocol-7 system color selection template."
Directly useful for stage 3/4 (local + network-facing config builder) — a circular hue
wheel is a natural color-selection UI, and the slider set is a ready-made pattern for
tunable-parameter controls generally, not just color. Worth extracting when stage 3/4
actually starts.

#,,,,,..,,...,,.,,...,,,.,,.,,,.,,,.,,,..,.,,,..,,...,...,,,,,,.,,,,.,,.,,,,.,
#WKH4Q2HYOS64U7CEOQ2GFZ6KIKB5HU3PRLUW2UA7PTB7GFXK2WGSXHBXSNZKQ4AT65SXZOOPWV2QM
#\\\|QYO4D3U25OPFBVMLKD4IPTZXVC5PMGCJ4ZPLNXN5TZBOLFPCQCM \ / AMOS7 \ YOURUM ::
#\[7]QKCPDX4UOMRANUVNHTEWXIPPRZ6CACIDDZMLUOW34TSBTHMSVMAI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
