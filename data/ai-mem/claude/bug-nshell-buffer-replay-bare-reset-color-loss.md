---
name: bug-nshell-buffer-replay-bare-reset-color-loss
description: nshell round-chain rewind/redo replay lost its blue color after a terminal font-size change (SIGWINCH) — root cause was command_reply's SIZE-mode payload and single-line TRUE/FALSE replies relying on ambient SGR instead of carrying their own color, which broke specifically on mode-buffer replay (resize / focus-switch), not live typing. Fixed 2026-09-14.
metadata:
  type: bug
---

## Symptom

User-reported: after a redo-round on the round-chain rewind/redo feature
([[project-round-chain-rewind-redo-landed-2026-09-14]]), the replay text sometimes
lost its blue color entirely (whole payload, not partial). Initially looked
length-correlated ("happens when restored content is too long"), but the user found
the real trigger by testing directly: **a terminal font-size change (SIGWINCH) in
either direction**, not content length. Doing another rewind/redo afterward made
color come back.

## Root cause

`nshell.render.content_print` accumulates every string it's asked to print into
`$modes->[$index]{buffer}` — this buffer is what `nshell.handler.term_resize` blasts
out in a single `print $replay` on a resize, and what `nshell.display.cycle` replays
on a mode-switch/focus. Two places printed text relying on *ambient* SGR carrying
over from whatever was active before, rather than carrying their own color:

- `nshell.handler.command_reply`'s single-line (`'true'`/`'false'`) branch ended its
  printed text with a **bare** `\e[0m` and nothing after it. Live, this looked fine
  because color got correctly reasserted right afterward — but via a *separate*
  print (the cursor-redraw / `nshell.render.viewport` call), which never touches the
  mode buffer.
- The SIZE-mode multi-line branch printed `$payload_str` completely bare, no color
  at all, same reasoning.

So the buffer ends up holding a permanently-dangling reset (from an earlier `'false'`
reply, e.g. a rewind/redo boundary-hit error like "nothing to redo") followed by
whatever printed after it with no color of its own. Live typing always looked
correct — ambient SGR really was blue at each print moment — but a resize replays
the *whole accumulated buffer in one shot*, with no per-call reassertion in between,
so the dangling bare reset permanently un-colors everything appended after it in
that single replay print. Doing another redo doesn't fix the buffer — it's a fresh
live print with correct ambient state, so it looks fixed until the next resize hits
the same stale, still-broken buffer.

Same failure shape `nshell.handler.strm_reply`'s round-marker fix already found and
fixed for STRM chunks ("the payload is suddenly unstyled gray" after a bare reset) —
this was the same class of bug in a second location (`command_reply`) that hadn't
been patched yet.

## Fix

In `src/nshell.handler.command_reply`: both the single-line reply text and the
SIZE-mode payload now carry their own color explicitly — reassert
`$colors{'p7_fg_0004'}` (blue) right after any `\e[0m` reset, rather than relying on
a later, buffer-invisible print to fix ambient state up. Never leave a bare reset in
anything passed to `content_print` — the mode buffer needs to be self-consistently
colored on its own, since it can be replayed wholesale at any time by a resize or a
mode switch, not just printed once live.

## Reusable lesson

Any text passed to `nshell.render.content_print` is not just a one-time terminal
write — it becomes part of a buffer that can be dumped wholesale, out of its
original live sequence, by `nshell.handler.term_resize` or `nshell.display.cycle`.
Color correctness must be self-contained in the string itself, never dependent on a
side-channel print (cursor redraw, viewport render) that happened to run right after
it live. See [[feedback-coding-async-reply-and-listener-lifecycle-gotchas]] for other
gotchas found building the same feature.

#,,.,,.,,,,.,,..,,..,,,..,,,.,..,,,,.,,,.,..,,.,.,...,..,,.,,,,..,,,.,,,,,,,.,
#CRGRAD4RQJNW5IIPJMCAXGGS3K3VFHDA6WHSA47VZHFXJSWPDN52QANII25F2ZC2DLOV6UHD33YJI
#\\\|COVQPEQY5BK357B6CN6GB3QVAW5RSC4NFOLMT76GDBUL2RGKPKG \ / AMOS7 \ YOURUM ::
#\[7]P5GZEK4WYYFJLZAQFDOVLYMMD2A35TQR4AMRAKFAXA5OL2GG7UAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
