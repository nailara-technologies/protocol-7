---
name: topic-implicit-perspective-navigation
description: "curves/thresholds as the navigation-decision substrate; perspective as a calculated fit over weighted interest signals, not direct manipulation"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3c264315-73af-4677-a8b4-23ce085cb5a8
---

Design conversation 2026-07-16, spun off while scoping
[[project-web-browser-value-replay-waypoints]] (curve-smoothed exact-value
replay + waypoints for web-browser visualizations). Captures a general
navigation-philosophy principle that transcends that one task.

## curves/thresholds ARE the decision, not a separate layer over it

Already live in the code, not hypothetical: `visualization.html`'s
`CURVES.ZOOM_FOLLOW` / `velocityZoomOffset` decides whether a zoom
"feels like" it's overshooting purely through curve-constant shape — no
branch of logic ever evaluates "is this too fast." The momentum-reversal
bug root-caused this session ([[topic-zoom-jump-debug-instrumentation]])
was this exact mechanism doing something perceptually surprising while
being entirely correct as coded. The design principle: apply this one
level up — "which perspective/reference-point matters enough to commit
to next" should be decided by curve/threshold shape too, not a discrete
decision tree bolted alongside the smooth-motion math.

## two parallel navigation modes over the same substrate

1. **explicit** — direct perspective manipulation: set a target state
   (drag/wheel input, or a named waypoint) and curve-interpolate to it.
   This is what [[project-web-browser-value-replay-waypoints]] scopes
   concretely (write-back hook, curve-smoothed exact arrival, pinned
   waypoints).
2. **implicit** — adjust *interest/priority signals* on a set of
   reference points (a "layered priority sandwich" — multiple priority
   tiers stacking) instead of adjusting the perspective directly; the
   perspective/camera position then **calculates itself** to
   appropriately frame/include whatever is currently weighted, similar
   to an auto-fit camera continuously re-solving as importance shifts.
   Concrete example given: if a nearby-but-not-yet-visible element
   suddenly gets referenced (its interest signal spikes), the view
   auto-zooms-out to include it — nobody issues an explicit "zoom out"
   command, it falls out of the fit calculation reacting to the new
   signal. Both modes drive the same underlying curve-smoothed-exact-
   arrival mechanism; they differ only in what supplies the target state
   (given directly vs. derived from weighted interest).
3. **magnetic nudging between close-scoring clusters** — a third
   refinement on (2): when several reference points score similarly high
   on interest at once, that is *not* treated as ambiguity to resolve
   toward one winner. Instead the cluster of close-scoring high-value
   points forms its own local layer, and moving between members of that
   cluster is a fast, reliable "nudge" — distinct from, and not diluted
   by, the presence of other lower-scoring options that still exist
   elsewhere in the field. The magnetic-cluster grouping is what keeps
   many simultaneously-plausible high-interest points from blurring into
   an averaged, mushy perspective — they stay locally fast-switchable
   instead. This is the same curves-as-decision principle again, one
   level further: the *grouping itself* falls out of score proximity, not
   a separately coded clustering step.

## individualized point in generic space

The space/nesting substrate is maximally generic and seamless
([[topic-1001]] — "every gate opens to another gate with identical
proportions"; [[topic-ascii-desktop-domains]] — nested domains as nested
display planes, ascii/box-drawing/gtk3 as interchangeable "typers" of the
same logical structure). But the actual resting point any one client
occupies within it at a given moment is maximally individualized —
carries all of that session's entropy (whatever curves are currently
mid-transition for that client) — and is mutually exclusive with every
other simultaneous point another client could occupy in the same space.

Layering resolves this without a separate aggregation mechanism:
zooming out to a parent layer doesn't require bespoke "group view" logic
— the parent perspective is simply the aggregate/rest-state of the same
curves across every client occupying that region, composed rather than
computed fresh. A "visualizing parent" is always available for any
point because the mechanism scales up by composition, not because
someone built a summary view for it. Connects to
[[topic-reference-bubble]] (rhizome bubble, 5+2=7 — the actual
"neighbourhood" rule for what's near enough to matter, not naive
distance) and [[topic-perspective-layers]]/[[topic-observer-centric-space]]
(cube tunnel/gate nesting, client always at reference position 0 — the
"dive-in route" between layers that the explicit/implicit navigation
above actually executes).

## session-bound overlay, kept orthogonal

Extra visuals/datasets bound to a specific user's session or a specific
template are a personalization layer keyed by session, additive on top
of the shared space — the common space itself stays common; a session
just contributes its own extra visible layer, not a fork of the
structure.

## status

Pure design/vision, nothing implemented. The one concrete, buildable
piece motivating this is
[[project-web-browser-value-replay-waypoints]] — build that first; this
note exists so the larger shape it's a fragment of isn't lost in the
meantime.

## related

[[project-web-browser-value-replay-waypoints]] · [[topic-1001]] ·
[[topic-ascii-desktop-domains]] · [[topic-perspective-layers]] ·
[[topic-observer-centric-space]] · [[topic-reference-bubble]] ·
[[topic-node-group-geometry]] · [[topic-window-canvas-addressing]] ·
[[topic-zoom-jump-debug-instrumentation]]

#,,,,,,,.,.,,,,..,,.,,..,,,,,,,..,.,.,,,.,..,,..,,...,...,...,,..,...,,..,.,,,
#B2DQXCOQBY42UX4LHHABM7H7ICH3V2326XGIXJRRH2FA5N7XHPDT5FHYTAKMKTZL7MWNV2XANHG6M
#\\\|JTWC2T7TASLQMMRGWP4NOUKX5NNIDQNPSK3DSYEG7L46LBPUY7D \ / AMOS7 \ YOURUM ::
#\[7]6BARHDWRCLIU46XJRZ2KLTSYF5KRFEDHPL5W6TSOAEBBXMBT2SDQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
