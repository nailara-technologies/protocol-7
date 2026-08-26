---
name: feedback-webkit-vs-firefox-css-blindspots
description: "two Firefox-only CSS bugs my WebKit-based web-browser zenka couldn't see or verify — stacking-context click-through and :checked display-swap breaking toggle"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8b3d1d3e-61f9-4577-a09f-fe20af9cd9b5
---

Two real bugs in the jobs web UI (2026-07-01) were invisible to my own verification tool
(`web-browser` zenka, WebKit-based) and only surfaced because the user was testing in real
Firefox. Both were rendering-engine-specific, not logic bugs — my snapshot/run_js checks
looked completely fine.

1. **Stacking-context click-through**: a card with `opacity < 1` (e.g.
   `.job-card[data-stage="rejected"] { opacity: 0.65; }`) creates a new CSS stacking context,
   trapping a child's absolutely-positioned `z-index` inside it. The *next* sibling card
   (also opacity'd, later in DOM) then paints over an open dropdown menu and steals the click
   — reported as "the dropdown doesn't work, it focuses the next card instead". Fix: give the
   actively-open card's own `z-index` a boost above its siblings (`.job-card.dropdown-open {
   z-index: 20; }`, toggled via JS alongside the existing open/close state), rather than
   trying to raise the menu's z-index further (that doesn't escape a trapped stacking context).

2. **`:checked` display-swap breaks toggle in Firefox**: a custom `appearance:none` checkbox
   changed `display` from its default to `inline-flex` only in the `:checked` state (to center
   a `::after` checkmark glyph). This is a known Firefox click-handling quirk — changing
   `display` on state change can break the checkbox's native toggle behavior entirely
   ("checkbox cannot be toggled"). Fix: keep the input's own `display` constant across states;
   center the checkmark via `position:absolute; inset:0;` on the `::after` pseudo-element
   instead (checkbox itself gets `position:relative` to anchor it).

**How to apply**: when a user reports a Firefox-specific interaction bug that a WebKit-based
check can't reproduce, don't rule it out as "environment weirdness" — both of tonight's bugs
were real, deterministic CSS engine differences with clean root causes once traced through the
actual CSS rules (not the JS logic, which was correct in both cases). Ask the user to verify
fixes for Firefox-reported bugs directly, since my own tooling is WebKit and structurally blind
to this class of issue.

#,,,,,,.,,.,.,,..,,,,,,.,,,,.,.,,,,.,,,,,,,,.,..,,...,...,,.,,.,.,..,,,..,.,.,
#A7XK3XFAKQM2SU6ESMRANW263HSMKQS75TIVNGDELEV27WPUMI5QDU322VYCGQPEQMPZRKSFQDUHI
#\\\|4BPKADOXBXOLOR6NG2XQMUZKYYWFL3LT5ZSO6XRVVSABCJHEWEZ \ / AMOS7 \ YOURUM ::
#\[7]7NFSTJGTLCRYNV6KEGFNTXZCRYHW3W2KAEDPIMI6OV4UTHME4CAY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
