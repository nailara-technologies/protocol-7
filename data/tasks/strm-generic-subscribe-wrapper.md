# generic STRM subscription wrapper — offline-safe, restart-clean

## why

surfaced 2026-07-18 while working `cred-mesh-rotation-subscription-cross-zenka.md`:
subscribing to a STRM-style event source currently means hand-rolling, per
subscriber, the same three things `proxy.handler.subscribe_rotation_deferred`
and `transport.handler.subscribe_rotation_deferred` do today:

1. a fixed-delay one-shot timer (`event.add_timer` `after => 0.5`) to dodge
   the startup race where the zenka's own cube session isn't up yet
   (bug 2 in the cred-mesh task file)
2. a bare `route-send` call to the publisher's `subscribe_*` command, with
   no retry if it fails
3. nothing at all to re-establish the subscription if the zenka restarts —
   the publisher's subscriber list lives in the publisher's own `%data`
   and is empty again until the deferred timer fires once more, which only
   happens because the *code path* runs unconditionally at every
   `init_code`, not because anything detects "I was subscribed before and
   need to be again"

the fixed-delay timer is a guess, not a guarantee — same class of race
bug 2 already found once. as more subscriptions move to the STRM
convention (which the project already prefers over the reflection-prone
pattern documented in `cred-mesh-subscribe-handler-reflection.md`), this
hand-rolled boilerplate will get copy-pasted again and again, each copy a
chance to reintroduce bug 2 or skip the retry logic entirely.

## the actual signal: 'command route collapsed', not !TERM!

`!TERM!` was a dead end for this direction — confirmed via
`modules/base.session.cancel_route` and `ncode s src:radio TERM`
(`plugin.httpd.radio.handler.strm_open`'s own comment: "send !TERM! to
radio via the route: stops the STRM at the source") that `!TERM!` is a
hard-unsubscribe signal traveling **consumer→producer**, the wrong
direction for "publisher restarted, subscriber finds out."

But `base.session.cancel_route` handles *both* directions in one function,
and the other half is exactly what's needed: when a session closes, for
each route where the closing session was the **target** (someone else's
command is still pending/deferred, waiting on a reply from the now-dead
session), it sends `"($s_cid)FALSE command route collapsed\n"` back to
that route's **source** — the waiting party. A STRM subscription is
naturally a long-lived/deferred route (same reply shape as
`v7.zenka.cmd.notify_online`'s own `{'mode' => 'deferred'}` pattern) — so
if the subscribe is wired as a genuine pending route rather than a
one-shot fire-and-forget command, the subscriber automatically receives
`command route collapsed` the moment the publisher's zenka session dies.
No new signal to invent — just make sure the subscription itself is
routed as a pending/deferred command, not fire-and-forget.

**The full loop, per the user:**

1. subscribe via a route left pending (deferred-reply shaped), so it can
   collapse
2. on receiving `command route collapsed` for that route: issue
   `v7.notify_online` for the publisher zenka, optionally with the
   `:start:` prefix (`v7.zenka.cmd.notify_online` already supports this —
   `ensure zenka is started before waiting`) if the publisher should be
   actively (re)started rather than just waited for
3. if `notify_online` replies **positively** (`TRUE`): re-subscribe
   immediately
4. if it replies **negatively** (`FALSE`): issue `notify_online` again,
   with some delay — increasing/backoff, not fixed — since a negative
   reply here means the zenka is failing at startup and may or may not get
   fixed; hammering it constantly would be wasteful, a growing delay gives
   room for a real fix to land

this is the precise wrapper design — no new liveness infrastructure, just
wiring three already-existing primitives together: deferred/pending
routes (so collapse fires), `command route collapsed` (the collapse
signal itself), and `v7.notify_online` with `:start:` + backoff (the
retry loop). `radio.audio.init`'s online/offline pair (still worth citing
as a working precedent for the general "wait for a zenka, react to
transitions" shape) solves a related but distinct problem — v7-level
zenka presence tracking, not a specific pending route's own collapse —
useful analogy, not the mechanism to copy verbatim here.

## a good existing example, still missing the same piece

`protocol-7-menu.pointer-stream-init` → `powershell.pointer-stream` (via
`protocol-7-menu.handler.pointer-stream-start` →
`powershell.pointer-stream-path` → SHM handoff) is a genuinely safe shape,
structurally immune to the reflection problem in
`cred-mesh-subscribe-handler-reflection.md`: it never sends a caller-
supplied command string to the remote party at all. It uses protocol-7's
standard `reply => { handler => ... }` convention — the handler name is
resolved *locally* by the requester when the reply arrives back through
the already-established route/reply-id, never stored by the remote party
and executed later with the remote's own permissions. That's the key
difference from `cred-mesh.subscribe_rotation`: a direct reply to one's
own request is safe by construction; a stored callback for an arbitrary
*future* unprompted push is the part that needs the variable-target/
fixed-suffix discipline described above.

It also solves bug 2's exact race (subscriber's own cube session not up
yet at init) more cleanly than the fixed-delay timer:
`protocol-7-menu.pointer-stream-init` is registered via
`push <system.callbacks.initialized>->@*, qw| protocol-7-menu.pointer-stream-init |`
— a real "my own zenka is actually ready" event, not a guessed delay. The
wrapper should use this instead of a fixed timer for the subscriber-
readiness half of the problem (still needs `notify_online`/backoff
separately for "is the *publisher* zenka up" — `system.callbacks.initialized`
only covers the subscriber's own side).

**But** — per the user, this example has the *same* gap this task is
about: nothing re-establishes the pointer-stream/SHM handshake if
`powershell` itself restarts. Good proof the reply-safety and the
re-subscription-on-restart problem are genuinely separate concerns; solving
one doesn't imply the other.

## the existing pattern to build on

`base.zenka.push` (`modules/base.zenka.push`) already solves the general
"offline-safe fire-and-forget delivery" problem properly, with no fixed
delays: attempt an immediate `route-send`, and only if that fails, ask
`v7.notify_online` to tell it when the target comes up
(`base.zenka.push.reply-handler.notify-online` resumes the send from
there), with exponential backoff (`2**backoff_n`, capped at 60s) if even
`notify_online` itself is unavailable. no blind timers anywhere in that
path — every retry is triggered by an actual state-change signal.

subscribing to a STRM source is the same shape of problem: "try now, and
if the target isn't ready yet, resume automatically once it is" — just in
the other direction (subscribing to a source, not pushing to a target).

## what's needed

a generic wrapper (naming TBD, something like `base.strm.subscribe` or
`base.zenka.subscribe`) that a zenka's `init_code` can call once, which:

- takes at minimum `{ publisher => 'cred-mesh', command => 'subscribe_rotation',
  slot => '*', handler => 'proxy.cred-rotated' }` (shape TBD — needs to
  generalize beyond cred-mesh's specific `slot`/`handler` args)
- attempts the subscribe immediately via `route-send`, same as
  `base.zenka.push` does for delivery — no fixed-delay timer; if the
  subscribing zenka's own cube session might not be up yet, hook
  `<system.callbacks.initialized>` (see `protocol-7-menu.pointer-stream-init`)
  rather than guessing a delay like the current `after => 0.5` timer does
- on failure, uses `v7.notify_online` (`:start:` prefix optional, matching
  `v7.zenka.cmd.notify_online`'s existing support for it) to wait for the
  publisher zenka specifically, then resumes the subscribe attempt when
  notified — reusing `base.zenka.push`'s backoff shape rather than
  reinventing one
- ideally also handles the publisher-side restart case: if the *publisher*
  restarts (its `%data` and subscriber list wiped), subscribers need to
  re-subscribe — this might need the publisher to broadcast something on
  its own startup, or subscribers to periodically re-affirm; not designed
  yet, flag as an open question rather than assuming a specific mechanism
- variable-target/fixed-suffix by construction, per
  `cred-mesh-subscribe-handler-reflection.md` — the project already has
  this pattern working elsewhere (`modules/content.update.send_notifications`,
  `modules/rss.ticker.send_update`: target zenka list is variable/
  configurable, but the command suffix invoked on each target is a fixed,
  locally-known string, never taken verbatim from the remote party). the
  wrapper should enforce this shape structurally: the subscriber's zenka
  identity comes from the authenticated request's own routing metadata
  (whatever cube/`base.handler.command` already resolves the caller to be),
  never from a caller-supplied string parameter, and the notify command
  suffix is a fixed value the wrapper itself owns (e.g. always
  `<subscriber_zenka>.cred-rotated`-shaped, never
  `<subscriber_zenka>.<whatever the subscriber asked for>`) — this way
  every future STRM subscription gets the safe shape for free instead of
  relying on each publisher to remember to validate

## scope note

this is infrastructure for *future* STRM subscriptions generally, not a
required fix for the currently-working `proxy`/`transport` → `cred-mesh`
rotation subscription (that one works today via the fixed-delay timer,
warts and all — bug 2 already fixed the worst of it). retrofitting the
existing cred-mesh subscribers onto this wrapper once it exists would be a
nice cleanup, not a prerequisite for building it.

note: `content.update.send_notifications`/`rss.ticker.send_update`'s
variable-target/fixed-suffix pattern (referenced above) is a safer
*baseline* than what cred-mesh currently does, not a pattern to carry
forward verbatim into new design — it has its own unvalidated-name gap
(`content.update.send_notifications` line 9: `# LLL: check zenka name
syntax!`). STRM-style subscription is already the project's preferred
newer convention over that.

## even later: route-less channels (not in scope here, direction only)

a further-out direction, not part of this wrapper's job: STRM channels
addressed by a base32-encoded public key rather than by zenka name/route
at all — the pubkey *is* the channel address, so which zenka currently
owns or relays a channel becomes irrelevant to subscribing or receiving
its updates, no relative routing maintenance needed. conceptually similar
to how the `discover` zenka already handles LAN presence via signed
multicast announce packets (`discover.format_discover_mcast_packet`) — a
route-less channel would be the same idea (signed, identity-addressed
announcement) carried over protocol-7's own transport instead of raw UDP
multicast. flagging so the direction isn't lost, not asking for a design
yet.

## signatures note

do NOT manually write or edit signature lines. do not add stub
signatures to new files.

#,,.,,.,.,,..,..,,,.,,,,,,,..,,,.,,.,,,,,,.,.,..,,...,...,...,,,.,.,,,.,.,...,
#VWTJLA5KFVPNGTX747E52QJJGOLARG5VCGLHRTRLZSBKL7JZPOAVMQEBXXTGU67PZRFXD2DSWPVTO
#\\\|4YBISRSYFUIDRZ4PIDNXMQY4G7DAY3E5KM7YJZD5SFIV2QGRJYG \ / AMOS7 \ YOURUM ::
#\[7]3S7FK325F6J5RBWV7FBZO4AXUQVSMJ27ZE2BYO32ITLCEG5OKUBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
