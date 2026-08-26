---
name: strm-subscription-evolution
description: "subscription-notify design lineage: reflection-prone handler-as-command -> variable-target/fixed-suffix -> STRM -> future route-less pubkey-addressed channels"
metadata:
  node_type: memory
  type: vision
  originSessionId: 5bee1ae8-4294-40c4-b104-2b3953ff1456
---

Captured 2026-07-18 during `cred-mesh-rotation-subscription-cross-zenka.md`
work — the user laid out an explicit design lineage for how subscribe/
notify patterns should evolve in this project. Not a single fix, a stated
direction across three stages.

**Stage 0 (found, vulnerable)**: `cred-mesh.subscribe_rotation` lets a
caller supply an arbitrary `handler` string, later fired verbatim as a
`route-send` command target with the *publisher's* (cred-mesh's) own
permissions — confused-deputy/reflection. See
[[cred-mesh-subscribe-handler-reflection]] (task file
`cred-mesh-subscribe-handler-reflection.md`).

**Stage 1 (existing safer baseline, not the target)**:
`content.update.send_notifications`/`rss.ticker.send_update` keep the
*target list* variable/configurable but the *command suffix* fixed and
locally-known (never taken verbatim from a remote party) — e.g.
`"cube.$target_zenka.$fixed_suffix"`. Explicitly called out by the user as
**safer than the current cred-mesh pattern but not something to carry
forward into new design** — it has its own gap
(`content.update.send_notifications` line 9: `# LLL: check zenka name
syntax!`, unvalidated). STRM-style subscription supersedes it as the
project's preferred convention.

**Good existing precedent, orthogonal concern**: `protocol-7-menu`
subscribing to `powershell`'s `pointer-stream` (`protocol-7-menu.pointer-stream-init`
→ `powershell.pointer-stream` → SHM handoff) is structurally immune to the
Stage-0 reflection problem — it uses protocol-7's standard
`reply => { handler => ... }` convention (resolved locally by the requester
via the existing route/reply-id when the reply arrives, never stored by
the remote party as a future-executable command). It also solves the
subscriber-own-readiness race (bug 2's problem) cleanly via
`<system.callbacks.initialized>` instead of a guessed fixed-delay timer.
**But it has the identical re-subscription gap** this whole lineage is
about: nothing re-establishes the SHM handshake if `powershell` restarts.
Confirms reply-safety and re-subscription-on-restart are genuinely
separate problems — solving one doesn't solve the other.

**Stage 2 (current best practice, needs infra)**: STRM-type subscriptions
are the "latest method" — but currently hand-rolled per subscriber
(`proxy`/`transport` → `cred-mesh` rotation) with no shared re-
subscription-on-restart handling and a fragile fixed-delay timer instead
of the offline-safe `base.zenka.push`/`v7.notify_online`+backoff pattern
that already exists elsewhere in the codebase.

Key structural fact, corrected twice en route to the right answer:
`!TERM!` (`base.session.cancel_route`, called from
`base.session.check.close`) is a hard-unsubscribe signal traveling
**consumer→producer** (confirmed via `plugin.httpd.radio.handler.strm_open`'s
own comment: "send !TERM! to radio via the route: stops the STRM at the
source") — wrong direction for "publisher restarted, subscriber finds
out."

The actual signal is the *other* half of the same function:
`base.session.cancel_route` sends `"($s_cid)FALSE command route
collapsed\n"` to a route's **source** when that route's target session
(the one it's still waiting on a reply from) dies. A STRM subscription is
naturally a long-lived/deferred route (same reply shape as
`v7.zenka.cmd.notify_online`'s own `{'mode' => 'deferred'}`), so as long as
the subscribe is wired as a genuine pending route rather than fire-and-
forget, the subscriber gets `command route collapsed` automatically the
moment the publisher's session dies — no new signal to invent.

**The user's full loop**: (1) subscribe via a pending/deferred route so it
can collapse; (2) on `command route collapsed`, issue `v7.notify_online`
for the publisher, optionally with `:start:` to also (re)start it; (3) on
a positive reply, re-subscribe immediately; (4) on a negative reply, retry
`notify_online` again with an increasing/backoff delay — a negative reply
here means the zenka is failing at its own startup, which may or may not
get fixed, so don't hammer it.

`radio.audio.init`'s `notify_online`/`notify_offline` pair (register both
up front, `_online` resumes idempotently, `_offline` re-arms via re-init)
is a related, real, working precedent — but for v7-level zenka-presence
tracking, not a specific pending route's own collapse. Useful analogy for
the "wait/react to transition" shape, not the mechanism to copy verbatim
for this specific problem. See [[strm-generic-subscribe-wrapper]] (task
file `strm-generic-subscribe-wrapper.md`) — the immediate next build
target.

**Stage 3 (future direction, not yet designed)**: "route-less" channels —
addressed by a base32-encoded public key rather than by zenka name/route.
The pubkey *is* the channel address; which zenka currently owns/relays a
channel becomes irrelevant to subscribing or receiving updates, no
relative-routing maintenance needed. User's own analogy: similar to how
the `discover` zenka already handles LAN presence via signed multicast
announce packets (confirmed live: `discover.format_discover_mcast_packet`
= "format and sign mcast broadcast packet string") — a route-less channel
would carry the same idea (signed, identity-addressed announcement) over
protocol-7's own transport instead of raw UDP multicast.

**How to apply**: when reviewing or designing any future subscribe/notify
mechanism in this codebase, place it on this lineage rather than treating
each one as independent — don't recommend the Stage 1 pattern as a
long-term model (it's a stepping stone, explicitly not the destination),
push toward Stage 2's shared infra first, and keep Stage 3's pubkey-
addressed route-less shape in mind as the eventual target so Stage 2's
design doesn't paint it into a corner (e.g. don't hardcode zenka-name-based
addressing so deeply that a pubkey-addressed channel can't slot in later).

## related

[[cred-mesh-subscribe-handler-reflection]] ·
[[strm-generic-subscribe-wrapper]] ·
[[topic-kimi-dispatch-infra-hardening]]

#,,.,,.,.,...,,,,,,..,,..,.,.,,.,,,,.,,..,,.,,..,,...,...,...,,.,,.,.,,,,,,..,
#XL7DFRPU5DPDGKYJB73L2W7LHMM66KYX7RYZLU2JTZNNHS3H64S3ZVU27KWCMSZF772U7DASPSHUC
#\\\|52NTUEMGUJQNFDQYLPN5ZT3Y47KJXPHDOLVGXI2542DWADUZSDL \ / AMOS7 \ YOURUM ::
#\[7]NI5XRCOPT2LRBMMGJPM5CTHQ2ZJYSJCWYAAMME2ZKL3QV6X3YCDY 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
