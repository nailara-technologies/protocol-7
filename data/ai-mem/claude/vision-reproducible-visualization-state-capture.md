---
name: vision-reproducible-visualization-state-capture
description: "SEED: automated position/state-capture infrastructure needed to make hand-tuned interactive visualization captures (sliders, camera angle, scroll position) reproducible instead of manual and fragile — grew out of an unrecoverable data-loss incident, 2026-08-28"
metadata:
  node_type: memory
  type: vision
---

Grew directly out of [[feedback-deleted-manually-tuned-captures-without-confirming]]: 117
files deleted from a shared snapshot directory, including hand-tuned interactive
visualization captures (cubic-space visualizations with manually-adjusted parameters) the
user intended to keep for the website. Unrecoverable — no filesystem snapshot/trash existed,
and the captured STATE (manual slider/camera/scroll adjustments) isn't reproducible from a
fresh page-load of the source HTML alone, which resets to default parameter values.

**User's own framing, verbatim in spirit**: partly his own fault too — he knew the directory
needed sorting/rescuing and postponed it because doing so manually was too much effort. Will
recreate the lost captures "someday" with "better infrastructure to make it reproducible" —
explicitly: not manually again.

**What "better infrastructure" means, concretely**: the `web-browser.cmd.set-pos-y` /
`set-fg-pos` / `set-bg-pos-y` commands built the same session (single-JS-call scroll
positioning, pixel or percent, see `data/tasks/web-browser-fast-scroll-position-commands.md`)
are a first piece, but only cover vertical SCROLL position. The visualizations that were lost
have richer interactive state than scroll alone — camera rotation/angle, slider values
(intensity/aperture/rotation-speed style controls, see the `iris-spectrum.html` color-picker
example already flagged as a good template candidate), possibly other UI control state. Full
reproducibility needs a way to:
1. Capture/record a page's FULL interactive state (not just scroll Y) — likely via a generic
   JS state-serialization convention these AI-generated visualization pages could adopt or
   already partially support (many already read URL params or expose global state objects,
   worth surveying `data/asc/what-AI-thinks/html-form/` for existing patterns before
   inventing a new one).
2. Restore that state programmatically on load (so re-capturing = replay a recorded state
   vector, not manual re-tuning by hand).
3. Only then is a capture of one of these pages a reproducible artifact rather than a
   one-off manual snapshot vulnerable to exactly this kind of accidental loss.

**How to apply**: don't build this speculatively. It's a real, user-confirmed future need,
but explicitly "someday" — wait for the user to actually pick this up rather than treating it
as an open task to start unprompted. The scroll-position commands already built are a
reusable piece regardless of when/whether this gets built further; nothing about them needs
to be redone. When resumed, start by surveying whether the existing 227-file corpus already
has any per-page state-serialization convention before designing a new one.

#,,.,,,..,,,.,..,,,..,,..,..,,..,,...,.,,,,..,..,,...,..,,,,,,..,,,.,,,,,,,,.,
#IUG3EJ57BI3A65A53KJOXLQRFSPWK4W76AVPTNQ6YF6KI4OXUYJFMUTMZKW6LXOZ3OWGRKVEE5GKC
#\\\|VHD66JVAH7UAFOQMXBUEHD4PZ3TT7CY72PJW42X5TKQFRUPECDH \ / AMOS7 \ YOURUM ::
#\[7]5RMUI3W3T6LAKX5IDHRCPQKNWQXUMKZAUEH6Q7JA4ZLMZX6VZ2AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
