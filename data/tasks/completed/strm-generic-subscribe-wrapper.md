# generic STRM subscription wrapper — offline-safe, restart-clean

## status (2026-07-19) — IMPLEMENTED, verified live

built as `base.strm.subscribe` — six modules, mirroring
`base.zenka.push`'s layout and `zenka.push` namespace-swap convention:

- `src/base.strm.subscribe` — entry point: param validation,
  variable-target/fixed-suffix construction, registry, defer-or-attempt
- `src/base.strm.subscribe.attempt` — single route-send attempt,
  falls back to the notify_online wait on immediate failure
- `src/base.strm.subscribe.wait-online` — `v7.notify_online`
  registration with push-shaped exponential backoff (`2**n`, 60s cap,
  `waiting_no`/`last_attempt` gating)
- `src/base.strm.subscribe.reply-handler` — subscribe reply:
  TRUE marks subscribed, `client not present` falls back to the wait,
  anything else is logged as definitive error [ no blind retry ]
- `src/base.strm.subscribe.reply-handler.notify-online` —
  notify_online reply: TRUE resubscribes immediately, FALSE backs off
  with increasing delay and re-attempts
- `src/base.strm.subscribe.pre_init` — `base.swap_subs` into the
  `strm.subscribe` namespace

call shape (the one live test call used against cred-mesh):

```perl
<[strm.subscribe]>->({
    'publisher' => 'cred-mesh',           ## target zenka
    'command'   => 'subscribe_rotation',  ## its subscribe command
    'args'      => [ qw| * | ],           ## publisher-specific args
    'handler'   => 'cred-rotated',        ## notify suffix on own zenka
    'start'     => 0,                     ## :start: publisher if down
});
```

sends `cred-mesh.subscribe_rotation` with args `* proxy.cred-rotated`
when called from proxy — identical wire shape to the existing
hand-rolled call sites. `handler` is validated as a bare single-segment
suffix (dots rejected) and always prefixed with `<system.zenka.name>` —
the confused-deputy shape is unconstructable through this API.

**verified live via p7c** (proxy as the real-world consumer, production
call sites untouched, modules runtime-loaded via
`base.load_runtime_modules`):

1. validation: dotted handler / dotted publisher / whitespace-bearing
   arg token / missing handler all rejected (FALSE, nothing registered)
2. happy path: subscribe -> TRUE -> cred-mesh `rotation_subscribers`
   shows `*:proxy` (identity from cube's SOURCE_ZENKA alias, wrapper
   only ever requests its own name)
3. idempotent repeat call: no duplicate registration
4. generalized args: `args => ['rotation-test.api-key']` registered a
   second, distinct slot subscription cleanly
5. offline-safe: `v7.stop cred-mesh` -> subscribe attempt -> cube
   replies `client not present` -> wrapper registered the
   `v7.notify_online` wait (`waiting_no=5`)
6. restart-clean [ subscriber side ]: `v7.start cred-mesh` ->
   notify_online TRUE -> wrapper resubscribed automatically
   (`subscribed=5`, no timer guesswork anywhere in the path)
7. real event: `cred-mesh.rotate rotation-test.api-key <val>` fired
   `proxy.cred-rotated` end-to-end (`proxy.handler.cred_rotated:
   flushed 0 cache entries for slot rotation-test.api-key` in proxy's
   log — 0 flushed is correct for a test slot with no cache entry)
8. defer path: with `<system.zenka.initialized>` temporarily cleared,
   the call registered `deferred=5` + pushed one
   `<system.callbacks.initialized>` callback and sent nothing; firing
   the callback ran the attempt to `subscribed=5`

after the test, proxy was restarted: production fixed-delay-timer
subscribe path intact, fresh process has the wrapper compiled but
dormant (pre_init swap runs only for zenki that adopt it).

**adoption notes for future subscribers**: regen the zenka's whitelist
(`bin/dev/gen-sub-whitelist <zenka>`) so the pre_init swap runs at
startup; call once from `init_code` — the wrapper defers through
`<system.callbacks.initialized>` when the own cube session isn't up
yet, so no call-site guards or timers are needed.

**still open, by design** (out of scope here, see "what's needed"):
the publisher-restart re-affirm case — the persistent
`<base.strm.subscribe.registry>` entry deliberately survives success so
a future re-affirm hook (e.g. on `command route collapsed`, when the
subscribe is wired as a pending route) can re-issue the attempt as-is.

**signatures note**: module files intentionally left unsigned (no stub
signatures, per below) — sign with
`bin/Protocol-7 sourcecode update-signatures src/base.strm.subscribe*`
when the key password is available.

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
`src/base.session.cancel_route` and `ncode s src:radio TERM`
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

`base.zenka.push` (`src/base.zenka.push`) already solves the general
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
  this pattern working elsewhere (`src/content.update.send_notifications`,
  `src/rss.ticker.send_update`: target zenka list is variable/
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

#,,..,,.,,...,...,,,,,,,.,...,.,.,,,.,,.,,...,..,,...,...,,.,,,,.,.,,,,,.,...,
#KV7MTDL6UAZRSGBVMJZG576TI2QHKW62NZVY5UVPWM4CIMP7BI2DBQO7A4L2CCUNCYQDUSXCVPTZK
#\\\|M7NAQZJQIFUTSR6RYK3M7HNG7ZP4RWABWQVZRPWEYNDR5LGB23G \ / AMOS7 \ YOURUM ::
#\[7]LJM3TCINBPELYHIXOTTAFG4V745NW2DPVOPANOQ5Z6WX5DEVM6DQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
