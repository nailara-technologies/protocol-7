---
name: reference-eval-code-batch-analysis-toolkit
description: "How-to for running one-off batch analysis scripts (e.g. image dedup) inside a zenka via devmod eval-code: per-zenka access whitelist gotcha, event-loop-yielding for long loops, and exact-hash-vs-perceptual-hash duplicate discernment. Built running a 639-image near-duplicate scan, 2026-08-29."
metadata:
  type: reference
---

Built doing a perceptual-similarity near-duplicate scan across
[[project-screenshot-triage-corpus-2026-08-29]]'s captured images, using the
existing `graphics.matrix.visual.phash`/`.hamming`/`.similarity` functions
(`src/graphics-matrix.cmd.assert-similarity` is the network-callable
wrapper; `<[graphics.matrix.visual.phash]>`/`<[graphics.matrix.visual.
hamming]>` are the direct code-refs, faster for a batch since `similarity`'s
`perceptual` method recomputes both phashes fresh every single call).

**1. `eval-code` needs explicit per-zenka whitelisting, unlike `web-browser`.**
`devmod.cmd.eval-code` is a devmod command, available on any zenka once
`v7.devmod-enable <zenka>` loads the module — but each zenka's OWN
`access.cmd.usr.*` line in its `zenka.v7` startup file can still block it.
`web-browser`'s access line ends in a wildcard (`* *.*`), so eval-code just
worked there. `graphics-matrix`'s access line is a strict enumerated
whitelist with devmod commands explicitly commented out
(`# get set del dump exec-sub ## <-- devmod commands`). Fix: add the
specific commands needed (`eval-code get set`, not a broad wildcard) to the
zenka's `access.cmd.usr.cube` line, then a full `v7.stop` + `v7.start` (this
whitelist, like others, is startup-only, not `reload`-refreshed — see
[[topic-gtk-wsl-window-positioning]]'s sibling note on this pattern
elsewhere). Landed for `graphics-matrix`, commit `4dfd2425d`.

**2. A long synchronous loop inside one `eval-code` call blocks the WHOLE
event loop and can get the zenka TERM-killed.** First attempt: 638 phash
computations + ~1500 pairwise comparisons in one `eval-code` call →
"command route collapsed" (client-side timeout), then the routing layer's
own health check saw no response and issued a real `<TERM>` — v7
auto-restarted the zenka. Fix: call `<[event.once]>` (== `Event::loop(0)`,
a single non-blocking event-loop pump, `src/base.event.once`) inside the
loop — once per phash computation and once per pairwise comparison was
enough to keep the same zenka responsive through the full batch, still as
ONE synchronous `eval-code` call (no need to split into multiple round
trips). Watch the exact macro name: `<[event.once]>` resolves fine on its
own — do NOT add a `base.` prefix, `<[base.event.once]>` also fails, because
neither actually relates to a missing prefix — see the file-permission and
devmod-reload gotchas below, which were the REAL causes of two rounds of
"command does not exist" that looked like a naming problem but weren't.

**3. `devmod` does not survive a zenka crash/restart.** After the timeout-
kill above, EVERY subsequent `eval-code` call failed with "command does not
exist" — not because the function name was wrong, but because the crash-
triggered restart wiped devmod (it's a runtime-only SIGNUM53 attach, exactly
like [[feedback-editing-p7-owned-data-files-reowns-them]]'s sibling
gotcha about state not surviving a restart). Fix: `v7.devmod-enable
<zenka>` again after ANY unexpected restart, before assuming a genuine code
problem. Cheap to check first (`v7.list zenki` for a new instance/PID)
before debugging "command does not exist" as a naming/permissions issue.

**4. Cross-user file permissions.** Files created by the interactive shell
user (e.g. via `cp`) are NOT automatically readable/writable by the zenka's
own process user (`protocol-7` here) unless group/other permissions allow
it. `chmod o+r` on files to read, `o+w`/`o+x` on the directory to create new
files in it (e.g. a report file) — same root cause as, but distinct from,
[[feedback-editing-p7-owned-data-files-reowns-them]] (that one is about
Claude accidentally taking ownership of P7-owned files; this is the mirror
case, files Claude/the user owns not being readable BY a P7 zenka process).

**5. Exact-hash vs perceptual-hash for real duplicate discernment.**
Perceptual similarity alone is NOT reliable for deciding what's safe to
delete — confirmed by hand: two captures of an ANIMATED point-cloud
visualization scored phash similarity 1.0000 (the maximum) despite being
visibly different rotation states, with one apparently caught mid-fade-in
(dimmer UI text) — a real capture-quality issue, not just a hashing
artifact. Two captures of a STATIC/paused wireframe cube also scored 1.0000
and WERE genuinely pixel-identical. The reliable split found: cross-
reference the phash near-duplicate report against exact file hashes (md5).
Byte-identical files are safe to dedupe unconditionally (barring hash
collision, not a real concern at this scale). phash-only matches — even at
1.0000 — need visual review; treat them as a candidate list, never a
deletion list on their own. On the 453-pair report from this session: 299
were byte-identical (safe), 43 were phash=1.0 but NOT byte-identical
(confirmed false-positive class), 111 were phash<1.0 (mixed).

**How to apply**: for any future ad-hoc analysis script that needs to run
inside a zenka's own process (to reuse its already-loaded functions/data
rather than reimplementing them standalone), expect all five of the above
in roughly this order of likelihood: (1) access whitelist, (2) event-loop
blocking on anything looping over more than ~50-100 real items, (3) devmod
wiped after any crash/restart during the session, (4) file permissions
across the shell-user/zenka-user boundary, (5) for any *-hash-based
duplicate/similarity work specifically, treat exact hash as ground truth and
perceptual hash as a candidate filter only.

#,,.,,,..,,,.,..,,,..,,..,..,,..,,...,.,,,,..,..,,...,..,,,,,,..,,,.,,,,,,,,.,

#,,,,,..,,..,,,,.,,,,,..,,,.,,,..,...,,,.,...,..,,...,...,..,,.,,,...,,.,,...,
#AY577L3ASCEX46WPOFXODZDQMHH6ORVW3SKSNVRXGMWICQTJBJ3FAJWBB5W3QP2VP5KDLQV2X43LC
#\\\|XFIBJHXE5WHAJ47GGD65G5XKTAKKKJX7PHG6A4MFMUXXAORNJAR \ / AMOS7 \ YOURUM ::
#\[7]H75TA5A2TOJICIUZG7UZGIVE334NSHM6YZVRZIHR2BVD6EBBIABI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
