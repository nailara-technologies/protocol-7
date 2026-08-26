---
name: startup-race-send-before-connect
description: "recurring bug class: code fires a route-send-shaped command from init_code/idle-callback before the zenka's own cube session exists — diagnostic technique and the three fix shapes that actually apply"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 5bee1ae8-4294-40c4-b104-2b3953ff1456
---

Found and fixed ~6 independent instances of the same bug class in one
session (2026-07-18), across `cred-mesh`/`proxy` (commit `55abd6848`), then
`web`/`coding`/`discover`/`base.log.send-buffer` (commit `d6fdc1dc1`). The
user's own closing assessment: this "totally explains all of the recent
integration tests that silently did not work for esoteric reasons — most
of them unnoticed race conditions from implicitly or explicitly sending
before connecting." Worth recognizing this shape fast next time rather
than re-deriving it.

## the pattern

A zenka's `init_code` (or an idle-watcher/timer callback that can fire
very early) calls `route-send` or `protocol-7.command.send.local`
directly and unconditionally. But every zenka's `start` file runs
`[init_modules]` (which executes every `.init_code`) *before*
`[base.net.connect:'unix']` — so any such call is guaranteed to fire
before the zenka's own cube session exists. `send.local` drops it
silently (no exception, no retry of its own).

## two symptom shapes, easy to tell apart

- **`"no clients in session, dropping '<cmd>'"`** — the zenka's *own*
  cube session doesn't exist yet. This is the startup race proper.
- **`"unknown target : <name> [ cmd : ... ]"`** — the zenka's own
  session is fine, but it called `protocol-7.command.send.local`
  *directly* instead of `route-send`, so it only ever checked its own
  local session/user table for a directly-connected peer, never actually
  reached cube for multi-hop delivery. A giveaway: if the module's own
  `# descr` already says "via route-send" but the code calls
  `command.send.local`, that's the bug (found exactly this in
  `discover.orbital.get_local_p7ref`).

## the diagnostic technique that found all of these

Add caller-identifying logging to the shared choke point,
`base.protocol-7.command.send.local`'s two silent-failure branches (the
"no clients in session" early return and the `[LLL]`-marked "unknown
target" gap — both previously silent). Use `scalar <[base.caller]>->($caller_level - 1)`
for the caller name — the `-1` accounts for an event-callback dispatch
frame when the call originates inside a timer/idle-watcher rather than a
direct subroutine call (see [[base-caller-route-send-detection-off-by-one]]
for why `$caller_level` itself needed a separate off-by-one fix, found
via this same logging). Once the log line names the real call site, the
fix is usually a two-minute read of that one file.

## the three fix shapes — pick based on what the call needs

1. **`<system.callbacks.initialized>`** — for a one-time startup call that
   already has its own retry-on-failure logic (e.g. the orbital STRM
   subscribers' `schedule_*_retry`, or coding's X-11 GPU-stats
   `resolve_primary_sid` call). Push the function itself (or a thin
   wrapper) onto this list instead of calling it directly; it fires once
   the zenka is genuinely initialized, and the existing retry logic is
   left completely untouched — still needed for "the *target* zenka
   isn't up yet," a different problem this doesn't solve.
   **Do not** use `<system.init_reports>` here if the caller has its own
   reply-driven retry: `send_init_reports`'s flush is a blind one-shot
   `send.local` call with no failure handling — if the target still isn't
   registered when it flushes, the route never gets set up, the reply
   handler never fires, and any retry logic living *inside* that reply
   handler never triggers. Silently worse than the original bug.
2. **`<system.init_reports>`** — for a one-time call with *no* retry logic
   of its own, where the target is a permanent/always-present service
   (matches `base.log.send-buffer`'s case: target is `p7-log`, effectively
   always up). Push `{target_command, param, descr, handler, reply_params}`
   (extended in this session to support `reply_params` distinct from the
   command's own `param`, backward-compatible — the 3 pre-existing
   callers, `base.tmp_dir`/`base.file.temp`/`base.n_pipe.open`, are all
   fire-and-forget with no reply handler and are unaffected). Flushed
   once by `base.session.send_init_reports`, which already self-reschedules
   every 0.777s until `<system.zenka.initialized>` is true.
3. **Fix the call itself to use `route-send`** — when the symptom is
   "unknown target," not "no clients in session." No deferral needed at
   all; the call was just using the wrong primitive.

## dead ends encountered, don't re-try these

- **`!TERM!`** (`base.session.cancel_route`) is a hard-unsubscribe signal
  traveling **consumer→producer** ("stop pushing to me, I'm gone") — not
  useful for "the *publisher* I depend on restarted, tell me." Confirmed
  via `plugin.httpd.radio.handler.strm_open`'s own comment.
- Don't assume `v7.notify_online`/`v7.notify_offline` (the
  `radio.audio.init` pattern: register both, react to transitions) is the
  right tool for *every* "wait for a dependency" case — it's for
  zenka-level presence tracking. A specific pending/deferred *route*
  collapsing (`"command route collapsed"`, the other half of
  `cancel_route`) is the more precise signal when the thing you're
  waiting on is a particular in-flight request, not a whole zenka's
  lifecycle.

## a real, separate bug found via the same investigation

`base.log.send-buffer.send-idle-callback` still manually prepended
`<system.node.name>` to cube's own `node.zenka` value — a leftover from
*before* a 2026-06-19 commit changed `p7-log.cmd.append` to always prepend
the node name itself (compensating for `SOURCE_ZENKA` no longer carrying a
hostname prefix, a security/log-display cleanup, unrelated to tonight's
race-condition theme but found by reading the same file). Result: cube's
own log filename silently doubled (`NODE.NODE.cube.zenka.log`) for a full
month, with the correctly-named file going stale unnoticed. Fixed by
having cube send its bare zenka name instead of pre-joining the node name.
Lesson: when two independent commits each assume "the other side already
handles X," check both ends, not just the one you're touching.

## related

[[topic-strm-subscription-evolution]] · [[base-caller-route-send-detection-off-by-one]]

#,,..,,.,,...,,.,,...,,..,,,.,,.,,..,,.,.,..,,..,,...,...,,..,.,.,,.,,,,.,...,
#KHBBXM3I236YW43DDCRMFPWW46V2KA7FFO3PIBN5XB2VIVGKBWG5QA3DKEP47GBDNNDNOMSQECDUW
#\\\|5I2D4BBOADLGAHBD2XEEWSIWC5ATHTGKVIHTYSGEX5A4T26V7PU \ / AMOS7 \ YOURUM ::
#\[7]LFSJ4KHW3LLAXG33NGUUVSRO3EGVBGQTN2M6HZNBWLA2BINRO6CQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
