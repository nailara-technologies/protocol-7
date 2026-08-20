---
name: ondemand-idle-timeout-active-streams
description: "on-demand zenki serving STRM push subscribers no longer idle-shutdown mid-subscription; two follow-up regressions found and fixed via live testing -- a producer-side cleanup gap that permanently blocked re-arming after a subscriber disconnected, and a one-shot idle-watcher that needed a nudge to notice the cleanup happened"
metadata:
  node_type: memory
  type: project
  modified: 2026-07-20
---

## change (landed 9eba08e3d, then extended a4fdfa300)

`src/base.event.callback.io-idle-restart` now checks whether any session has an open
outbound STRM producer stream (`$data{'session'}{$sid}{'streams'}{$cmd_id}{'producer'}`) before
re-arming the on-demand shutdown timer. If any producer stream is open, the timer is not armed.

## why

On-demand zenki that serve long-lived push streams (e.g. `graphics-matrix.orbital-sync`) would
otherwise idle-shutdown mid-subscription, because outbound STRM traffic does not generate inbound
commands that would reset the idle timer.

## coverage

The fix is generic in `base.*` and covers every zenka that uses `base.stream.open` as a producer:
`graphics-matrix`, `X-11`, `nodes`, `kimi-web`, `ticker`, `radio`, `discover`, `external`, and
`mod-test`. `sys-deps` has no STRM producer streams, so the change is a no-op for it.

## two follow-up regressions, found by actually live-testing the fix (not just reasoning about it)

**1. Producer-side cleanup gap** (`a4fdfa300`): `base.stream.push` returns 0 on a gated/dead
handle but never deletes `$data{session}{$sid}{streams}{$cmd_id}` — only `base.stream.close`
does. 8 producers (`graphics-matrix.orbital.push_state_if_subscribed`,
`nodes.orbital.push_position_if_subscribed`, `discover.orbital.store_remote`,
`external.orbital.push_update`, `radio.gap_fill.tick`, `radio.handler.stream-chunk` ×2,
`X-11.emit.screen-change`, `ticker.emit_event`) dropped dead handles from their own zenka-side
listener lists without ever calling `base.stream.close` — so the base-level `producer` flag
leaked forever once a subscriber disconnected. Before this session's io-idle-restart fix, that
leak was harmless (a stale hash entry nobody checked). After it, the leak became a real
regression: it permanently blocked the idle-shutdown timer from ever re-arming. Confirmed live —
graphics-matrix sat online for 6+ minutes past a 13s test timeout with an empty `route` but a
stale `streams` entry, until an unrelated inbound command (`devmod-enable`) happened to trigger
cleanup as a side effect. Fix: all 8 sites now call `<[base.stream.close]>->($h)` on push failure
before dropping the handle from their own list.

**2. Idle-watcher needed a nudge** (`a4fdfa300`): even after fixing #1, `base.stream.close`
cleared the producer state but the shutdown timer still didn't fire promptly. Root cause:
`base.event.callback.io-idle-restart` (`src/base.event.init_code:14-17`) is a genuine
`Event->idle(..., repeat => 1)` watcher, but the callback calls `$event->w->stop` on itself every
time it fires — a one-shot in practice, only re-`start`ed by `base.handler.input:118-119` /
`base.handler.write:140-141` after real inbound/outbound I/O. A failed push writes nothing
locally (no I/O event), so nothing re-arms the watcher after the last stream closes — the zenka
sits correctly stream-free but with no live watcher left to notice, until some unrelated I/O
event comes along. Fix: `base.stream.close` now restarts that watcher itself (`$data{watcher}
{io}{transfer}->start if ... not ->is_active`) in both its branches, matching the existing
input/write pattern.

## separately found in the same debugging session (not a regression from this fix, pre-existing)

`graphics-matrix.init_code` was not reinit-safe: re-ran root-only `file.make_path` calls on every
reload (failing with permission-denied after `root.drop_privs` already ran once), and
re-registered its 45s orbital-push timer on every reload with no dedup (would have stacked
duplicate timers across repeated reloads, unnoticed until now since reloads were rare). Fixed with
the standard `my $reinit = shift // TRUE; my $already_initialized = $reinit;` guard pattern (see
`src/models.init_code` for the reference example) around both the mkdir block and the timer
registration. Worth checking other zenki's `init_code` for the same two anti-patterns
(root-requiring setup and unconditional timer registration) if this surfaces again elsewhere.

## live verification (both directions, confirmed by the user)

- positive: zenka stays online while genuinely subscribed, tested at both the real 547s
  `graphics-matrix` timeout and a temporary 13s test value — same session id held across 37+
  seconds of subscribed activity at the 13s setting.
- negative (no regression): idle-shutdown fires correctly and *promptly* once the subscription
  actually ends, with no unrelated interaction needed to nudge it — confirmed after fixing both
  regressions above.
- `graphics-matrix`'s `ondemand_timeout` reverted from an escalated `547` (a workaround for the
  underlying bug, applied incrementally 47→63→...→547 while chasing the symptom) back down to
  `47` now that the actual causes are fixed.

## related

[[project-sys-deps-wiring-completion]] · [[project-ondemand-zenki-registry-wipe]] ·
[[feedback-base-log-vs-logs-sprintf]]

#,,,,,..,,,.,,.,,,.,,,...,.,,,.,.,,..,,,.,.,.,..,,...,...,.,,,,..,.,.,.,.,,,.,
#OJ5NFPDE4JRS7AHFIK66L5IJFRZRUNLKJRVXFEERJXKPF6DE2FAQS2JXHKR7UU6GWNCNWKWTY7J7I
#\\\|7FZ76HSOCX2DLQAKHRI2ZKV3TQ372IN63VOI4HRGJK6KKKQRICQ \ / AMOS7 \ YOURUM ::
#\[7]GJDLWUZQEKIKZXPEWKTV33ND2NMS42XR6CQSYDSJUALCM3W2T6AI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
