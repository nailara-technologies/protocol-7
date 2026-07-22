## task: protocol-level reply-count announcement for group-mode dispatch

### origin

Surfaced testing `zenka-name-routing-modes.md` live: `group` mode's original
dual-reply behavior is intact and correct (confirmed via `nshell`, two
`mod-test.heart` replies land as separate lines when the connection stays
open) — but `p7c`/`bin/c_src/p-7-r.c` (its remote sibling, same one-shot
design, implemented but not yet in active use) both read until the *first*
`TRUE`/`FALSE`/`SIZE`-shaped reply completes, then hard-exit
(`continue_read = 0` then `return 0`). A `group`-resolved target's second
(third, Nth) reply is silently discarded — not corrupted, just never seen —
with zero indication to the caller that more than one reply existed.

### why this is worse than it sounds for p7c/p-7-r specifically

p7c/p-7-r deliberately strip protocol reply-type prefixes (`TRUE`/`FALSE`/
`SIZE`/`STRM`) and map `FALSE` to a shell exit code, precisely so scripts
and pipe chains can consume clean output without stripping protocol
themselves. That design assumes exactly one reply per command. `group`
mode silently violates that assumption for any bare name with more than
one live session — a script gets one real answer presented as *the*
answer, with no signal it was one of several, and no way to have known in
advance.

### why a client-side fix (timing heuristics) can't work

Any client-side "wait a short grace window after the first reply, see if
more arrives" approach is fundamentally guessing — it can never
distinguish "reply #2 for this request" from "unrelated data" without
some server-side marker, and can never know when it has genuinely seen
*all* replies vs. just hasn't waited long enough. The information needed
(how many targets did this dispatch actually resolve to?) is a cube-side
fact, known precisely at the moment `route_to_target`'s group-mode branch
resolves `@send_sids` — it should be told to the client, not guessed by it.

### proposed protocol extension

A new immediate feedback notification, sent *before* any actual replies,
whenever a dispatch resolves to more than one target under `group` mode —
same idiom as the existing `STRM <bytes>` open-frame preamble before
chunks:

```
!GRP! <count>
```

or, correlated to a reply id exactly like every other reply-bearing frame
already is:

```
(1342)!GRP! 4
(1342)TRUE reply 1
(1342)TRUE reply 2
(1342)TRUE reply 3
(1342)TRUE reply 4
```

`route_to_target`'s group-mode branch emits this the moment it resolves
`@send_sids` to N > 1, before dispatching to any of them. Emitted only
when N > 1 — a single-target resolution (whether because `group` happened
to only match one live session, or because `routing_mode` collapsed to one
via `contact-oldest`/`newest-first`/`idle-longest`) looks exactly as it
does today, zero protocol change for the common case.

### must propagate across route hops — reuse the `!TERM!` mechanism, don't invent a new one

`!TERM!` already establishes this exact pattern and it must not be
reinvented: `httpd.handler.web-relay.strm_open`'s `$cancel_strm` sub doesn't
act only locally on stream cancellation — it looks up the route, finds
`route.source.cmd_id`, and forwards `"(%d)!TERM!\n"` to *that* session,
relaying backward through however many hops separate the cancellation
point from the original caller.

`!GRP!` needs the identical treatment. For a multi-hop routed command like
`atom.web.heart`, the point where `web` actually resolves to N > 1 targets
under `group` mode may not be the hop directly serving whoever issued the
original call — it could be one or more relays upstream. Without
propagation through each hop's `route.source.cmd_id`/`route.target.cmd_id`
translation (the same chain `!TERM!` already walks), a client several
hops removed from the resolution point would never see the notification
at all, silently defeating the entire point of announcing N up front.
Implementation should reuse whatever relay/forwarding code path `!TERM!`
already uses for this, not build a parallel one.

### what this unlocks

- **p7c/p-7-r, by default**: on seeing `!GRP! N` with N > 1, refuse
  cleanly *before* consuming any reply content — print an error
  ("target resolves to N sessions under group mode; single-reply client")
  and exit non-zero, instead of silently keeping just the first of several
  real replies. This is the actual fix for the "silently misleading"
  problem, and it's authoritative (cube telling the truth about what it's
  about to do) rather than a client-side guess.
- **`-g` / `--group` escape hatch**: a caller who explicitly wants to
  target a known-`group`-mode name via p7c/p-7-r (e.g. deliberately
  triggering a broadcast, not needing to capture every reply
  meaningfully) opts in explicitly; p7c reads and prints all N replies
  (newline-separated, letting the calling script decide how to consume
  multiple lines) instead of refusing.
- **Future smarter consumers**: any client informed of N up front can
  reliably wait for exactly N replies before doing something with them —
  e.g. a collapsing/diffing display (show identical replies once, only
  surface ones that actually differ) becomes possible once "how many to
  expect" is a known quantity instead of an open-ended guess. Not
  something to build now, but `!GRP! N` is the primitive that makes it
  buildable later without protocol changes at that point.

### relation to the numbered-sub-reply idea (deferred separately, same conversation)

That earlier idea (`(131.0)`/`(131.1)` per-target reply numbering) answers
a different question — *which specific target answered which reply* —
useful for e.g. debugging which instance said what, but a substantially
larger protocol change (every reply-bearing frame needs a sub-id, callers
using explicit ids need to understand the one-request-many-replies
possibility). `!GRP! N` answers *how many replies to expect at all*,
which is the more urgent, more contained gap (it's what's actually
misleading p7c/p-7-r today) and doesn't require per-reply origin
identification to be useful. The two are complementary, not the same
proposal — `!GRP! N` could ship alone; per-reply numbering could be
layered on top later if identifying which instance answered ever becomes
a real need.

### also: rename !TERM! to !TRM! in the same rollout

Same-conversation naming discussion, worth doing alongside this rather
than as a separate change: `!TRM!` matches `!GRP!`'s length exactly (5
chars each), giving the off-band bang-tokens a consistent, short-and-punchy
form distinct from the longer bare reply-type words (`TRUE`/`FALSE`/
`STRM`/`CHRSIZE`) — plus a byte saved per instance. Mechanically cheap
(`ncode replace` across the tree). Rollout-coordination concerns that
would normally apply to a live wire-protocol token rename don't apply
here: no cross-host traffic exists yet for this to desync across, and
without `*.reload`-style fleet-wide hot-reload syntax implemented, a
restart is already the only way any change propagates at all — inherently
atomic, no partial-version window possible. Do it as one coordinated
rename alongside the `!GRP!` work, not gradually.

### open questions

- Exact placement/timing: emit `!GRP! N` strictly before dispatching to
  any target, or is a small race window acceptable if the first reply
  happens to be faster than the notification write (shouldn't be, if
  emitted from the same synchronous resolution point before the dispatch
  loop, but worth confirming once implemented).
- Whether STRM-mode group dispatch (not just TRUE/FALSE/SIZE) should also
  get this treatment, or whether STRM's existing `base.strm.local.register`
  duplicate-slot guard (from `zenka-name-routing-modes.md`) already covers
  the STRM case adequately on its own.
- p7c/p-7-r implementation: both are near-identical C sources
  (`bin/c_src/p7c.c`, `bin/c_src/p-7-r.c`) — the `!GRP!` handling logic
  should land in both, ideally via shared code if one doesn't already
  exist between them, to avoid the same fix needing to be applied twice
  and potentially drifting.

#,,,,,..,,...,.,,,.,,,,,.,.,.,.,,,,..,,.,,..,,..,,...,...,..,,.,,,,..,...,.,.,
#ZJLBZOC4XTXHAH435W476N3GUSTZA67JWNZIPF4WWM37XBTGQLVJEKTPKMMUF4S4BN6BMEDTPJMVY
#\\\|2CFGUV6GE62EB7JTPS76GSCFXNLRL3N3KA3EG62UPCRMVY6EAU5 \ / AMOS7 \ YOURUM ::
#\[7]G2DSXXIRUSZPXIRPYNF4BQE7PF7MMPJ3MSQIUOW7SVK6O4PQJ4DI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
