---
name: feedback-coding-async-reply-and-listener-lifecycle-gotchas
description: three reusable gotchas found live-testing coding-zenka/nshell async command UX — session.listeners lifecycle, reply mode for multi-line content, premature client-side clearing
metadata:
  type: feedback
---

Found while building/live-testing round-chain rewind/redo/round-regen (see
[[project-round-chain-rewind-redo-landed-2026-09-14]]), but all three apply to any future
coding-zenka command nshell reacts to on a keypress, not just that feature.

## 1. `<coding.session.listeners>` only gets cleaned up by a REAL round completing

`coding.async.state_machine`'s `STATE_COMPLETE`/`STATE_ERROR` handling is the only thing that
closes + deregisters a task's live-view listeners. A client-side action that opens a fresh
listener (`coding.cmd.subscribe-session`) but does NOT go through that state transition — e.g. a
pure navigation/pointer-move command — leaves that listener handle sitting there forever. Repeat
the action a few times and handles accumulate (confirmed live: 14, then 41 stale handles on one
task) with no natural cleanup point. The accumulation isn't just wasted memory — it was confirmed
live to break a LATER real round's actual content streaming (multiple stale handles under
different `cmd_id`s each receiving pushed chunks apparently confuses nshell's client-side stream
routing).

**How to apply:** never call `subscribe-session` before a command that does not itself complete
a round via the normal state machine. If a client-side action needs to show the user something
right now, prefer embedding it directly in that command's own reply (see gotcha 2) over opening a
fresh live-view subscription for a one-shot push. If you must push to `session.listeners` from a
non-round-completing path, you're responsible for closing whatever you opened yourself — there is
no ambient cleanup for it. If listeners for a task already look wrong, `coding.session.listeners`
can be reset via `tree_write` (`{"path":"coding.session.listeners","value":{}}` clears all tasks,
or write just that task's key to `[]`).

## 2. `mode=>'true'`/`'false'` replies are single-line; multi-line content needs `mode=>'size'`

A command handler returning `{'mode'=>'true', 'data'=>"line one\n\nline two"}` — a real embedded
newline in the string — does NOT render as an actual line break in nshell; confirmed live it
shows the literal two-character `\n` as text. `'true'`/`'false'` is for a short single-line human
message (colorized by `nshell.handler.command_reply` based on which of the two it is). Genuine
multi-line content must use `'mode'=>'size'`, exactly like `base.cmd.show-buffer` and
`devmod.cmd.eval-code` already do — that branch prints the payload via `content_print` with no
premature line-splitting.

**How to apply:** before returning multi-line text from a `.cmd.` handler, check which mode it
uses. If it's `'true'`/`'false'` and the data can ever contain a real `\n`, switch to `'size'`.

## 3. Clearing the buffer / requesting a redraw BEFORE an async reply arrives loses context on failure

A `.cmd.` handler dispatched fire-and-forget (queued into
`$data{session}{$sid}{buffer}{output}`, not awaited) means the CALLER (an nshell plugin hook like
`on_escape`/`on_redo`) returns before knowing whether that command will succeed or fail. If the
hook optimistically clears `$mode->{buffer}` and/or returns `redraw=>TRUE` (which independently
wipes the physical terminal content area via `nshell.editor.process`'s own redraw logic,
regardless of whether the mode buffer was touched), a FAILED command's short error reply becomes
the only thing left on screen — whatever was previously shown is already gone. Confirmed live
this happens on both rewind and redo's rejection paths.

**How to apply:** for a fire-and-forget command whose failure is a normal, expected outcome (not
a crash), don't touch the display speculatively — return `claimed=>TRUE, redraw=>FALSE` and leave
it to the command's own eventual reply (success or failure) to print via the normal
`content_print` path. This is the same pattern `on_escape`'s first-press abort branch already
used; the mistake was not applying it consistently to the later branches added afterward.

#,,,,,...,...,.,.,..,,.,.,,..,.,.,..,,,,,,.,,,..,,...,...,,.,,...,.,.,,,.,,,.,
#TMXSR2YIJZP3TDPDFZ5FBN2S6QRTKTLROGR44MQLWISWL5NKSCLNJKWFXUOKMP4SYGAFORQ5XEBN4
#\\\|X3SUIAKGW2FQDBRUFZV2SJWXFDDLEDVUYFFJBANSMZXNOJ7YDNG \ / AMOS7 \ YOURUM ::
#\[7]PPQXG3AKELNOX5STFDHHOBUJLSFLTYN37RI3YDC2POC5PJH4NSAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
