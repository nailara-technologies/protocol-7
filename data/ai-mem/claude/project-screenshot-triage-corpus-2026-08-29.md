---
name: project-screenshot-triage-corpus-2026-08-29
description: "Status snapshot: the web-browser paged-capture batch against the 227-file what-AI-thinks/html-form corpus. 190/224 pages captured (531 images post-dedup), results at data/snapshots/screenshot-triage-2026-08-29/, 38 files still unattempted. Stage 1 of the original template-extraction vision."
metadata:
  type: project
---

**Why**: [[vision-generic-web-template-hybrid-doc-browser]]'s Stage 1 needed
real screenshots of the existing `data/asc/what-AI-thinks/html-form/` corpus
(227 files) to extract a generic CSS/style vocabulary, rather than hand-
reading every file. Building the capture pipeline itself surfaced 4 separate
real production bugs (see below) before any actual corpus data came out of
it — most of one session (2026-08-29) went into that, not the triage itself.

**Current state**:
- 190/224 non-archive, non-WebGL corpus pages successfully captured
  (multiple scroll positions each → 639 raw images).
- Deduped: 108 exact byte-duplicate images removed → **531 images remain**,
  ~48MB after `pngquant --quality=65-90` in-place compression (was 218MB).
- Location: `data/snapshots/screenshot-triage-2026-08-29/` (gitignored —
  see `.gitignore`'s `data/snapshots/` entry, commit `4dfd2425d` — never
  commit these, hundreds of MB of generated PNGs).
  - `images/` — the 531 files, named `<amos-chksum-of-source-uri>.<ntime>.png`
    (fixed naming convention, see [[reference-eval-code-batch-analysis-toolkit]]
    footnote and commit `4dfd2425d` for the code fix in
    `handler.capture_paged_snapshot`).
  - `manifest.tsv` — current, post-dedup manifest (`chksum\turi\tposition\tpath`).
  - `manifest.tsv.pre-dedup` / `manifest.tsv.old-naming` — historical, for
    audit/recovery if needed.
  - `timeouts.tsv` — pages that hit the per-page watchdog during capture.
  - `near-duplicates-report.tsv` — full 453-pair perceptual-similarity scan.
  - `exact-duplicates.tsv` (299 pairs, already acted on/deleted) /
    `needs-review.tsv` (154 pairs, NOT yet reviewed) — see
    [[reference-eval-code-batch-analysis-toolkit]] for the exact-vs-perceptual
    split methodology.

**Not yet done**:
- 38 files never successfully captured: the 32-file `visualizations/cubic-
  space/archive/` subtree (confirmed genuinely heavy/legacy — some real
  WebKit `frame load interrupted` errors, some consistent 20s+ timeouts,
  not artifacts of the bugs fixed this session), the 3 `webgl-template-
  concept*.html` files (confirmed CPU-hog: uncapped `requestAnimationFrame`
  + `THREE.WebGLRenderer`, caused the original incident-3 host memory
  emergency), and 3 stubborn `hyperspace-field-8cube-{basic,cyan-ambient,
  hue-rotation}.html` files that failed consistently across multiple retries
  even after all 4 bugs were fixed — likely need individual investigation,
  not just "try again."
- The 154 `needs-review.tsv` pairs — not visually reviewed at scale, only
  2 sample pairs checked by hand (see [[vision-screenshot-corpus-analysis-features]]
  for what that spot-check found).
- The actual template/style-extraction analysis this was all in service of
  — hasn't started. The screenshots exist now; nothing has looked at them
  for style patterns yet.

**4 real bugs found and fixed getting here** (all same session, same
`web-browser` zenka, commits `ad5670f98`, `87683910b`, `0cc0bae07`,
`4dfd2425d`):
1. Stale `swap_views` draw-signal never disconnected in headless mode →
   runaway `clear_bg_view` reload loop, real host memory emergency #1.
   [[bug-web-browser-stale-gtk-signal-headless-memory-leak]]
2. Stale async snapshot completion crashing the GTK main loop on undef path.
3. No hard per-page timeout + `stop_slideshow` not actually terminating a
   stuck page's JS → real host memory emergency #2 (required manual `v7`
   SIGINT). Led to the watchdog-timeout feature,
   `data/tasks/web-browser-page-load-watchdog-timeout.md`.
4. [[bug-web-browser-pacing-collapse-after-timeout]] — the watchdog itself
   introduced a pacing bug once triggered.

**How to apply**: if resuming this, start by reading this file plus
`data/tasks/web-browser-page-load-watchdog-timeout.md`'s full incident log
before touching the batch again — the failure modes here were subtle and
each took real live-debugging effort to find. Don't re-attempt the 38
outstanding files without treating them as individually suspect, not just
"forgot to run them."

**Update, 2026-08-31**: the `<ntime>` half of the `<chksum>.<ntime>.png`
naming (fixed by `4dfd2425d`, above) is itself still base32-encoded —
alphabetical listing of two independent base32 fields doesn't sort
chronologically, introducing jitter that matters for anything relying on
capture order (e.g. animations built from a sequence of frames). User
created `src/base.path-template.amos-ntime-dec` (`<[path-template.*]>`
namespace, already committed `c5dd834f9`) to render ntime as a sortable
decimal string instead. **Not yet done**: wiring this into
`handler.capture_paged_snapshot`'s naming, and — once wired — renaming
the existing 531 capture files (plus whatever's been added since) to the
new decimal-ntime scheme so the whole corpus becomes cleanly
time-sortable. Don't rename the files before the capture code itself is
switched over, or new captures will immediately reintroduce the mixed
naming this is meant to fix.

#,,.,,,..,,,.,..,,,..,,..,..,,..,,...,.,,,,..,..,,...,..,,,,,,..,,,.,,,,,,,,.,

#,,,,,,.,,.,,,,..,.,.,,..,.,,,,..,,,.,...,,.,,..,,...,...,..,,,.,,.,,,,,,,.,,,
#ESJZ2IPW6NMF2AMEL3CASVQBFS4PG4SB25CMADUI574MWBZOZZOHPP4IIBFMTSRJRCKKL64NL5QOS
#\\\|DQEEB3DQFDVCHGPLG5GTBFJD6FZ27PBJBIMSGOCBY4SAIXOZ2IK \ / AMOS7 \ YOURUM ::
#\[7]LF2QWBDN4FUXACYNQB2MT6FZHEZH2DF5LSHISZNBUF3FJAYZCYCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
