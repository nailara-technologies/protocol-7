---
name: x11-resolution-profiles
description: open design requirement — X-11 zenka needs named/parseable resolution profiles per mode, xvfb especially, since it now serves varied headless-render use-cases (not just one fixed appliance-sim size like xephyr)
metadata:
  type: project
  originSessionId: b06671d8-4694-4f41-bf24-4268123a0ca0
---

## origin

Surfaced 2026-07-11 while building an HTML→PDF pipeline through the
`web-browser` zenka (WebKit snapshot → Graphics::Magick → PDF) for a job
application document. Needed a taller/different-aspect Xvfb screen than
the existing `X-11.dev.dimensions = 912x513` (16:9), which is deliberately
kept small to simulate an appliance on a work desktop via Xephyr. Landed
a first split as `X-11.dev.dimensions_xvfb = 1216x1368` (8:9) in
`configuration/zenki/X-11/start` — flat sibling key, not nested under
`X-11.dev.dimensions`, because that key is already a scalar and dot-path
config parsing throws `'eval error : string (...) as HASH ref while
strict refs'` if you try to nest under an existing scalar leaf
(`$data{'X-11'}{'dev'}{'dimensions'}{'xvfb'}` collides with
`$data{'X-11'}{'dev'}{'dimensions'} = '912x513'`).

## the actual requirement (not yet built)

Xvfb is turning into a general-purpose headless-render backend (documents
today, likely UI captures / other aspect ratios later) while Xephyr stays
single-purpose (fixed appliance viewport). That asymmetry means Xvfb
specifically will keep needing more resolution values over time — a
single override key won't scale past the second use case.

**Proposed mechanism** (user's sketch, not implemented): extend zenka
subname parsing to accept `xvfb:<W>x<H>`, e.g. start the zenka as
`X-11[xvfb:1920x1080]`. Checked the actual code —
`modules/X-11.init_code:14-31` matches `<system.zenka.subname>` against
`$modes_re = qr{^(host|xnest|nxagent|xorg|xephyr|xvfb)$}` as an **exact**
match; anything with a `:WxH` suffix fails the regex today and falls
through to "zenki mode not valid, keeping '<old>'" (logged, non-fatal).
To support the syntax: split subname on `:` first, validate the mode part
against the existing regex as today, then if a second part matches
`^\d+x\d+$`, use it to override `X-11.dev.dimensions_xvfb` (or a named
profile key) before `X-11.params.xvfb` gets built.

**Flagged requirement**: sanitize the WxH pair against excessive values
before use (bound both dimensions, e.g. reject anything above some sane
ceiling like 4096 either axis) — an arbitrary user/attacker-controlled
subname could otherwise request a huge Xvfb framebuffer as a cheap memory-
exhaustion vector (Xvfb allocates the full WxHx24 framebuffer up front).

## status

Not implemented — noted per user request ("we should at least note the
requirement") during the PDF-pipeline session, not acted on since it's a
one-sample-so-far need. Revisit once a second Xvfb use case with a
genuinely different resolution need actually shows up; if/when built,
also consider whether Xephyr profiles are wanted too (weather zenka
already has two commented-out fixed profiles at
`configuration/zenki/X-11/start:46-47` as a precedent for per-purpose
named sizes, though those are hardcoded overrides in the same file rather
than a subname-driven mechanism).

## related

[[topic-x11-protocol-hardening]]

#,,.,,,..,...,..,,,,,,,,.,...,.,,,,.,,,,.,,.,,..,,...,..,,,,.,.,,,,,.,...,.,,,

#,,,,,,,.,,.,,.,,,,,,,...,,..,..,,..,,..,,,.,,..,,...,..,,.,,,,..,.,.,...,,,,,
#J5S4DVZRP2HOUU2W6DA2UU6T5PH4JGHLH2PBQQ5OEHDH7VYK7OA55A5RXTSBUGRIEFE4FJDD4256O
#\\\|KHZXU7MBY22ESSN7NZNL42NKBAJEBBXZJP63K7UWUE3L26UI4CZ \ / AMOS7 \ YOURUM ::
#\[7]E3WOUEI7THDFUK6BGVYUO3UQP6MLXRNQNI4PH4ZKBSKVQMWN24AY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
