---
name: vision-screenshot-corpus-analysis-features
description: "SEED: feature ideas for the web-browser screenshot-triage pipeline and its downstream analysis, grown out of the 2026-08-29 224-file capture batch + dedup pass. Mix of user's and Claude's own ideas, not yet built."
metadata:
  node_type: memory
  type: vision
---

Grew out of the same session as [[project-screenshot-triage-corpus-2026-08-29]]
and [[bug-web-browser-pacing-collapse-after-timeout]]. Captured while the
corpus (639→531 images post-dedup) was still fresh in view.

**User's ideas, verbatim in spirit** (reacting to pngquant's palette-reduction
effect on the captures, "it does not look bad.. on the contrary"):
- **Blacklight palette extraction from gradients**: the dark cosmic/hyperspace
  aesthetic shared across most of this corpus (deep violet/blue backgrounds,
  glow-heavy UI) responds distinctively to palette quantization. Worth a
  dedicated tool that extracts the DOMINANT/gradient palette from a batch of
  images (this corpus, or any web-root screenshot batch) — directly useful
  for [[vision-generic-web-template-hybrid-doc-browser]]'s Stage 1 (extracting
  a generic CSS palette vocabulary), since it could derive the palette from
  REAL rendered output instead of eyeballing source CSS by hand.
- **Staged two-quality visual transfer**: something like progressive
  JPEG/PNG loading but deliberate — capture or serve a fast, tiny/quantized
  low-quality pass first, then a full-quality pass, useful for any UI that
  needs to show large batches of screenshots quickly (a review/collage tool,
  for instance) without waiting on full-resolution loads.

**Claude's own ideas, grown from tonight's concrete findings**:
- **Capture-time content-hash dedup** (the corrected version of tonight's
  naming fix — see the "not a bug, a missing feature" note in
  [[project-screenshot-triage-corpus-2026-08-29]]): move the checksum
  computation from the source URI (known before capture) to the actual PNG
  bytes (known only after `snapshot_save` completes), so byte-identical
  captures collapse to the same filename automatically instead of needing a
  post-hoc dedup pass like tonight's. Requires moving the manifest-write from
  `handler.capture_paged_snapshot` (pre-capture) to
  `capture_paged_snapshot_result`/`snapshot_save` (post-capture) — a real,
  contained refactor, not just a rename.
- **Animation-state tagging at capture time**: tonight's dedup work found a
  hard split — STATIC/paused pages give reliable exact-hash duplicates,
  ANIMATED pages give phash false positives (same coarse hash, genuinely
  different animation frames — confirmed visually with the point-cloud
  visualization, similarity 1.0000 despite different rotation state and even
  a mid-fade-in frame in one case). A page could self-report this cheaply:
  capture two snapshots ~200-300ms apart during the FIRST position only,
  compare them (exact hash is enough, no need for phash), and tag the
  manifest row `animated=0|1`. Every downstream dedup/review pass could then
  trust exact-hash-only for `animated=0` pages and always route `animated=1`
  pages to human/visual review — turning tonight's manual post-hoc split
  (299 safe / 154 needs-review, found only after the fact) into something
  known up front, per page, for free.
- **Animated-page preview capture**: given 176/227 corpus files use
  `requestAnimationFrame` (confirmed via corpus grep tonight), a single
  static PNG structurally under-represents most of this corpus for style/
  template review purposes. Worth considering a short animated-preview mode
  (a handful of keyframes, or a tiny WebP/GIF) specifically for pages tagged
  `animated=1` above, rather than trying to make a static screenshot pipeline
  do a job it's fundamentally not suited for.

**How to apply**: all speculative, none scoped or started. Natural follow-up
if/when the screenshot-triage or template-extraction work resumes — the
animation-tagging idea in particular pairs directly with a future capture
run, since it changes what gets written to the manifest at capture time, not
just post-processing.

#,,.,,,..,,,.,..,,,..,,..,..,,..,,...,.,,,,..,..,,...,..,,,,,,..,,,.,,,,,,,,.,

#,,..,..,,,..,.,,,,..,.,,,,..,,..,,,.,,.,,,,,,..,,...,...,...,..,,,,.,...,.,,,
#C5J3N7V3TP52DRSKX7CDOCGIVCRQNGYJDQX4WFOZMEOPF6GRL27LTCCKSVU4I2QJNAPFEGMYMWYUU
#\\\|WISX5CNSZJEOXCBLZ7WR6QGFVOXLE5BD6DVJFM5CNP62SPDPDEW \ / AMOS7 \ YOURUM ::
#\[7]HUB2ZO4UGG4FGU3QDUEGMMAGQIG2ERTDE7C2PUIHFTDMQQRFVEDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
