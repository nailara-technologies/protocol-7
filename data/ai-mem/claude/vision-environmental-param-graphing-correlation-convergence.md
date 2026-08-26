---
name: vision-environmental-param-graphing-correlation-convergence
description: recurring pattern across zenki — graphing captured runtime parameters over time surfaces real bugs via visual correlation; self-test's http_500/context-size data is the next candidate, not a one-off need
metadata:
  type: vision
---

**Precedent, already live**: [[web-browser-param-capture-graphing]] /
`web-browser.cmd.graph-params` captured runtime debug values
(`debugZoom`, `debugManualZoom`, `debugVelocity`, `debugRotX`, `debugRotY`,
etc.) over time as graphed curves — and that graph is what actually
surfaced [[topic-zoom-jump-debug-instrumentation]]'s momentum-reversal bug:
a stray zero-movement click snapping `manualZoom` to 1.0 in one frame,
visible as a sharp discontinuity in the curve that neither of two prior
theories predicted. The bug was found *by looking at the graph*, not by
reasoning about the code first.

**Why this recurs rather than being a one-off**: any subsystem that emits
runtime state over time and occasionally fails in ways not obviously
explained by the immediate error message is a candidate for the same
treatment. Concrete next candidate raised in conversation: self-test's
`tier1_inference_failed: http_500` failures currently log just the HTTP
status, nothing about *why* — but the user's own experience is that 500s
are easily reproduced by pushing context size close to physical memory
limits. If self-test captured environmental parameters (context size in
use, memory headroom, request timing) alongside each failure the same way
web-browser captures `debugZoom`/`debugRotX`, a graph of those series
against failure occurrence would very plausibly surface the actual
correlation (or rule it out) the same way the zoom graph surfaced the
click-timing bug — visually, before anyone writes a correlation-detection
routine.

**The stated expectation**: this convergence is expected to keep
happening as more zenki grow debug/observability surfaces — "graph runtime
parameters, look for the correlation visually" is becoming a repeatable
move, not a one-off web-browser feature. A later step (explicitly named as
"somewhen," not now) is automating the correlation-finding itself once
enough of these graphed-parameter-sets exist to make a generic detector
worth building — but the graphical intermediate step is expected to stay
valuable even after that, the same way seeing the zoom-curve discontinuity
was more immediately diagnostic than any automated anomaly score would
have been on its own.

**Status**: vision-only, prompted by a real example (the zoom-graph
screenshots) during a session where self-test http_500 failure-cause
tagging was being scoped. Not a task — a "this shape will recur, build
toward it opportunistically" note. The immediate self-test work (extendable
tier1 retries, failure-class stats, primed second-pass prompt) proceeds
independently; if failure-class stats end up capturing context-size/memory
data per attempt, that data becomes exactly the input this note describes.

#,,,.,.,.,,,,,.,.,,,.,,.,,,.,,.,,,...,...,.,,,..,,...,...,..,,,,.,,,.,,,,,.,.,
#36N4HXWDIVTPBB77QQCIYI42BUDTPZRGBCWH2ADY3HPACBLE5EWYV7MM4JGYILHWKKQLW6Y5BQTAE
#\\\|N4D4XMYPY6KGEPNXAEPCP6XUGJ4S6I2FL2B7T3DXG3JOPG5VPG3 \ / AMOS7 \ YOURUM ::
#\[7]RQHK45JCTL2QWPKCQSWL3ZYH6VIQ533GDUQ6G67CZE5LE22MYQDA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
