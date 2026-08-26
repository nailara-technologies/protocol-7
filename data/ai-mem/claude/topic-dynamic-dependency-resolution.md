---
name: topic-dynamic-dependency-resolution
description: "dependency resolution as a generic fallback to achieve a stated intent — local-capability-first, then preference-ranked template match, then discovered external capability chains"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3c264315-73af-4677-a8b4-23ce085cb5a8
---

Design conversation 2026-07-16, same session as
[[topic-implicit-perspective-navigation]]. General principle: "dependency
resolution" isn't just a technical/infra concept (zenka start-file
dependencies) — it's the generic fallback mechanism whenever a stated
intent can't be satisfied directly, with a consistent resolution order.

## resolution order

1. **present-environment sufficiency, checked first** — does the
   immediate/local environment already have what's needed, satisfiable
   in-process, no external chain required? Concrete precedent, not
   hypothetical: `web-browser.cmd.graph-params` chose an in-page JS
   canvas overlay over cloning/adapting a `screen-setup`-style display
   zenka into a dedicated realtime-graphing zenka — the WebKit view
   already had JS execution + canvas + DOM, so the fastest resolution was
   "the present environment already qualifies," not "spawn/build
   something external." That choice was made manually in that design
   conversation; the generalization here is that this check should be the
   **first**, not incidental, step of intent resolution generically.
2. **preference-ranked match among available options** — e.g. choosing a
   display template for a dataset: score availability × relevance × match
   statistics, prefer a known-good match for *this* user if the network
   has learned one, else fall back to network-wide aggregate preference,
   else generic logic. Individual → collective → generic is the same
   fallback shape as [[topic-reference-bubble]]'s neighbourhood rule —
   nearest known-good thing first, widen scope only if nothing local
   matches.
3. **discovered external capability chains** — when neither (1) nor (2)
   resolves it, search available capabilities across the network for a
   path that satisfies the goal, execute it, and return the result
   *backward along the same discovered route* to the original requester
   (not a separately hardcoded return path). Concrete example: "screenshot
   from this angle in that space visualization" with no existing pipeline
   for it — resolve that it needs an xvfb-mode X-11 zenka, a web-browser
   zenka started inside it, navigation to the waypoint via the
   replay/verify mechanism ([[project-web-browser-value-replay-waypoints]]),
   a capture, and the result threaded back through whatever chain of
   zenki discovered/assembled that path.

## why this matters now, concretely

This is the literal missing piece for the "screenshot-batch across all
visualizations" idea parked in
[[project-input-capture-replay-website-templates]] as "a distinct
follow-up, not yet started" — without a capability resolver, that follow-up
would have to hardcode one pipeline per visualization; with it, "get a
screenshot from state X" is a single stated intent that resolves its own
path per visualization, discovering what's needed rather than being told.

## connects to (not a new mechanism, an application of existing ones)

[[topic-hybrid-namespace-routing]] (5 routing types — this generalizes
*routing to a known target* into *discovering* an unknown path first),
[[topic-self-assembling-network]] ("spec as pre-loaded potential"),
[[topic-network-as-computer]] (zenki-as-satellites), [[topic-reference-bubble]]
(the individual→collective→generic fallback shape), and
[[topic-implicit-perspective-navigation]] (the curves/thresholds-as-decision
principle applies here too — resolution *scoring*, not just resolution
*existence*, should ideally be curve/threshold-shaped rather than a
discrete decision tree, though this wasn't worked out in detail).

## status

Pure design/vision, nothing implemented. No concrete task spun off yet —
the graph-params precedent is real and shipped, but the generic resolver
itself doesn't exist as a mechanism anywhere in the codebase.

#,,,,,,.,,.,,,..,,.,,,,,.,...,,.,,,.,,,,.,...,..,,...,.,.,.,,,,,,,.,,,,,.,,.,,
#I6HUTBW7X3LILGTDIVFUIW72IXVF5JWY5ZC7H4JGKMZ7JD3T4KHRXYZLJBHLLKCIJVU4FLSLDIJO2
#\\\|XXXE3F3NAY5AS3JPGQFJJEKRARUZAOKFKNFW47UMHYNZIVX4IUV \ / AMOS7 \ YOURUM ::
#\[7]V65RSEHAHO3QVRRRHW4H7EPKU24AVVIK6GUVNXNC34F3VENMCMCQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
