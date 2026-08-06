---
name: topic-mpv-ipc-reply-request-id-matching
description: "mpv IPC replies were matched to callers by shift()-order FIFO with no id in the payload; a single dropped/deferred/reordered reply permanently desynced routing for the rest of the zenka's life. Fixed with request_id tagging. Also unblocked a real fade-then-pause/unpause-then-fade fix."
metadata:
  node_type: memory
  type: project
---

## symptom (reported 2026-08-06, landed commit `ca1370fe9`)

User reported the Aug 3 `jobqueue.check_dependencies` splice fix (see
[[topic-jobqueue-check-dependencies-splice-bug]]) "still logs the same
issue" post-restart. Live probing (`mpv.get-volume`, `mpv.is-idle`,
`mpv.pos`) found the *real*, separate bug: `mpv.is-idle` hung forever, then
`mpv.get-volume` returned `no` (a boolean-shaped answer, not a percentage) —
the fingerprint of a misrouted reply.

## root cause

`modules/mpv.handler.pipe_output` matched every incoming mpv IPC reply to
the correct in-flight command by `shift()`-ing `mpv.reply_ids` /
`mpv.command.reply` in **arrival order**, with no id embedded in the
JSON payload. Every one of mpv's own `command`/`request_id` fields was
being ignored. If any single command's reply was ever dropped, delivered
out of order, or resolved via a deferred `jobqueue` job (see the splice-bug
note — this is almost certainly what originally seeded the desync), the
FIFO permanently shifted by one: every subsequent real mpv reply got
attributed to the wrong waiting command, forever, until zenka restart. No
timeout, no self-healing.

## fix

Tag every command with a monotonic `request_id` (`mpv.send_command` +
`mpv.json.command`, which now takes `<request_id> <command> [args...]` and
embeds it as a JSON sibling key, matching mpv's real IPC protocol). Match
replies against a `request_id`-keyed `mpv.pending_reply` hash in
`mpv.handler.pipe_output` instead of shift-order arrays.

`mpv.send_command` claims whatever reply bookkeeping the *caller* just
pushed (`mpv.reply_ids` / `mpv.command.reply` / `mpv.success_reply_str`)
and re-files it under the new `request_id` — always safe because the push
and the `send_command` call are synchronous and adjacent (single-threaded
event loop, no interleaving possible between them). This meant **none of
the ~30 `mpv.cmd.*` files needed to change** — they still push exactly as
before.

The consumer side did need changes: `mpv.handler.pipe.single_line`,
`.val_percent`, `.float`, `.playlist`, `.version`, `.command`, and
`mpv.handler.cmd_prop.pause` used to `shift @{<mpv.reply_ids>}` themselves
to find out who to reply to. They now take `reply_id` as an explicit
second argument, passed by `pipe_output`'s dispatch
(`$code{$command_handler}->( $decoded->{'data'}, $pending->{'reply_id'} )`).

**How to apply:** any future mpv IPC command flow must not rely on
push-order across `mpv.reply_ids`/`mpv.command.reply` surviving until the
matching reply arrives — always thread the id through `request_id` /
explicit params instead of a shared mutable array position.

## follow-on: pause/resume volume fading (same session)

Fixing reply-matching surfaced (via live testing) two further, real bugs
in `mpv.handler.cmd_prop.pause`'s pause/resume flow, not evident from
reading the reply-matching fix alone:

1. **Fade owned by the wrong event.** Original code called
   `mpv.callback.silenced` (hard-cut volume to 0 + device reassignment)
   directly from the pause command handler, and separately relied on
   `mpv.handler.event.property-change.core-idle`'s `not idle -> fade in`
   branch for resume. `core-idle` fires *after* mpv has already stopped
   producing audio at pause time — any fade attached to it is inaudible
   (confirmed live: fade completed per the log, well after the fact).
   Fixed by making `mpv.handler.cmd_prop.pause` drive fade-out-then-pause
   and unpause-then-fade-in **synchronously and deterministically** itself
   (`$do_pause`/`$do_resume` closures), not via the async event.

2. **`mpv.cmd.fade` clobbers its own target.** `<mpv.current.volume_target>
   = $volume` is set unconditionally on every fade call — fading out to 0
   for pause overwrote the very value resume needed to fade back up to.
   Fixed by capturing the pre-pause level (`<mpv.current.volume_target> //
   <mpv.current.volume> // <mpv.start_volume>`) into
   `<mpv.pause.prior_volume>` *before* the fade-to-0 starts, and reading it
   back (then deleting it) in `$do_resume`.

3. **`on_done_extra` hook must not live in shared mutable state.** First
   attempt stored the pause's post-fade callback in a global
   `<mpv.audio_fade.on_done_extra>` data key. Any other `cmd.fade` call
   racing the same ~4-8s fade window (e.g. `core-idle`'s still-live
   fade-in branch, or a stray external fade) would silently clear it before
   the curve completed — "fade finishes, nothing happens" with zero error.
   Fixed by threading it as a real parameter through
   `mpv.cmd.fade -> mpv.handler.audio_fade -> base.curve.register`'s
   `on_done` closure instead of a data key. Still not airtight: a
   **competing** `base.curve.register` on the same shared curve id
   (`mpv_audio_fade`) discards the whole curve entry including `on_done`
   regardless of closure-vs-data-key — not hit in practice this session,
   but a real remaining gap if something else fades concurrently with a
   pause-owned fade.

4. **`mpv.callback.silenced`'s real payload is the device reassignment,
   not the volume mute.** `mpv.audio_device`/`mpv.audio_channel` are never
   set anywhere else in the codebase — the call always resolves to the
   same hardcoded `'auto'`/`1`, every time. Its actual purpose is forcing
   mpv to reopen the audio device while idle, same family as the
   documented WSLg pulse-bridge cork/resume workaround in `mpv.init_code`.
   First pass removed it entirely from the pause path (assuming it was
   just a redundant volume mute); this **silently broke resume audio**
   (fade completed, volume climbed per the log, but no sound — device
   never reopened). Restored as a single call from inside `do_pause`,
   after pause has actually landed — not from `core-idle` (would race
   `do_resume`), and not duplicated in both places.

**Lesson:** don't guess at what a bluntly-named legacy callback
(`silenced`) actually does from its name or its most visible side effect
(volume=0) — check whether its config inputs are ever actually varied
elsewhere. If they aren't, the "obvious" effect is probably not the real
payload.

**Debugging method that worked after repeated wrong live-tested guesses:**
add throwaway `base.log` lines at the specific decision points in question
(branch taken, hook fired, event fired), run the *single* minimal
reproducing command, read the log, then strip the instrumentation once
confirmed. Cost one restart cycle; saved several more rounds of
plausible-on-paper/wrong-live guessing.

[[topic-jobqueue-check-dependencies-splice-bug]] [[critical-patterns]]

#,,..,,,,,..,,.,,,,.,,..,,,,,,,..,...,..,,,..,..,,...,...,.,.,.,.,.,,,,.,,,,,,
#ZLYE5QJ4XOKTZK3EWXJQFWBZJPBYQBU5XMP6D4V4M5IAVD5CBPJPSGWIPVCSH4F5NDEYHHYGRHKZA
#\\\|TK4YQXIZOJKYYNEPR2R7OAMJGXT4ZIWMOGHAGNOFPU63V5KN4UX \ / AMOS7 \ YOURUM ::
#\[7]NAYO5KIEYIP3EK3VBX4AGCSXUWH7VNDVHEA772RRMSPKZN24BGBI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
